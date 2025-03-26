/// HTTP server implementation for the MCP protocol.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' show dirname;

import 'package:straw_mcp/src/json_rpc/codec.dart';
import 'package:straw_mcp/src/json_rpc/message.dart';
import 'package:straw_mcp/src/mcp/types.dart';
import 'package:straw_mcp/src/server/server.dart';

/// Configuration options for SSE server.
class SseServerTransportOptions {
  /// Creates a new set of SSE server options.
  SseServerTransportOptions({
    this.host = 'localhost',
    this.port = 9000,
    this.maxIdleTime = const Duration(minutes: 2),
    this.maxConnectionTime = const Duration(minutes: 30),
    this.heartbeatInterval = const Duration(seconds: 30),
    this.logger,
    this.logFilePath,
  });

  /// The hostname to bind to.
  final String host;

  /// The port to listen on.
  final int port;

  /// Maximum idle time before closing connection.
  final Duration maxIdleTime;

  /// Maximum total connection time.
  final Duration maxConnectionTime;

  /// Interval for sending heartbeats.
  final Duration heartbeatInterval;

  /// Logger for server events.
  final Logger? logger;

  /// Path to log file (optional)
  final String? logFilePath;
}

/// HTTP server implementation for MCP.
///
/// Provides an HTTP interface to an MCP server.
class SseServerTransport {
  /// Creates a new HTTP MCP server.
  SseServerTransport(
    this.server, {
    required this.host,
    required this.port,
    required this.maxIdleTime,
    required this.maxConnectionTime,
    required this.heartbeatInterval,
    this.logger,
    this.logFilePath,
  });

  /// The MCP server instance.
  final Server server;

  /// The hostname to bind to.
  final String host;

  /// The port to listen on.
  final int port;

  /// Maximum idle time before closing connection.
  final Duration maxIdleTime;

  /// Maximum total connection time.
  final Duration maxConnectionTime;

  /// Interval for sending heartbeats.
  final Duration heartbeatInterval;

  /// Logger for HTTP server events
  final Logger? logger;

  /// Path to log file (optional)
  final String? logFilePath;

  /// The HTTP server instance.
  HttpServer? _httpServer;

  /// Flag indicating if the server is running.
  bool _isRunning = false;

  /// JSON-RPC codec for message encoding/decoding.
  final JsonRpcCodec _codec = JsonRpcCodec();

  /// File for logging if logFilePath is specified.
  IOSink? _logFile;

  /// Starts the HTTP server.
  Future<void> start() async {
    if (_isRunning) {
      _log('Server already running');
      return;
    }

    // Open log file if path is specified
    if (logFilePath != null) {
      try {
        final logDir = Directory(dirname(logFilePath!));
        if (!logDir.existsSync()) {
          logDir.createSync(recursive: true);
        }
        final logFileObj = File(logFilePath!);
        _logFile = logFileObj.openWrite(mode: FileMode.append);
        _log('Initialized log file at $logFilePath');
      } on Exception catch (e) {
        _logError('Failed to open log file at $logFilePath: $e');
      }
    }

    try {
      _httpServer = await HttpServer.bind(host, port);
      _isRunning = true;
      server.logInfo('MCP Server running on http://$host:$port');
      _log('MCP Server running on http://$host:$port');

      // Process incoming requests
      await _processRequests();
    } catch (e) {
      _logError('Failed to start server: $e');
      rethrow;
    }
  }

  /// Process incoming HTTP requests.
  Future<void> _processRequests() async {
    if (_httpServer == null) return;

    try {
      await for (final HttpRequest request in _httpServer!) {
        if (!_isRunning) break;

        if (request.method == 'POST' && request.uri.path == '/jsonrpc') {
          await _handleJsonRpcRequest(request);
        } else if (request.method == 'GET' && request.uri.path == '/sse') {
          await _handleSseRequest(request);
        } else {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        }
      }
    } catch (e) {
      if (_isRunning) {
        _logError('Error processing requests: $e');
      }
    }
  }

  /// Stops the HTTP server.
  Future<void> stop() async {
    if (!_isRunning) return;

    _isRunning = false;
    _log('Stopping SSE server');

    try {
      await _httpServer?.close();
      _log('HTTP server closed');
    } catch (e) {
      _logError('Error closing HTTP server: $e');
    }

    try {
      if (_logFile != null) {
        await _logFile!.flush();
        await _logFile!.close();
        _logFile = null;
        _log('Log file closed');
      }
    } catch (e) {
      _logError('Error closing log file: $e');
    }
  }

  /// Handles a JSON-RPC request.
  Future<void> _handleJsonRpcRequest(HttpRequest request) async {
    String body;
    try {
      body = await utf8.decoder.bind(request).join();
    } on FormatException catch (e) {
      _sendErrorResponse(
        request.response,
        createErrorResponse(null, parseError, 'Invalid UTF-8: $e'),
      );
      return;
    }

    final clientId = request.headers.value('X-Client-ID') ?? 'unknown';
    final sessionId = request.headers.value('X-Session-ID') ?? 'unknown';

    final context = NotificationContext(clientId, sessionId);
    server.setCurrentClient(context);

    try {
      final response = await server.handleMessage(body);

      request.response.headers.set('Content-Type', 'application/json');

      if (response != null) {
        final jsonResponse = _codec.encodeResponse(response);
        request.response.write(json.encode(jsonResponse));
      } else {
        // No response for notifications
        request.response.statusCode = HttpStatus.noContent;
      }
    } on Exception catch (e) {
      _sendErrorResponse(
        request.response,
        createErrorResponse(null, internalError, 'Server error: $e'),
      );
    } finally {
      await request.response.close();
    }
  }

  /// Handles a Server-Sent Events (SSE) request.
  Future<void> _handleSseRequest(HttpRequest request) async {
    final clientId = request.headers.value('X-Client-ID') ?? 'unknown';
    final sessionId = request.headers.value('X-Session-ID') ?? 'unknown';

    // ログ記録
    _log(
      'SSE connection established from client: $clientId, session: $sessionId',
    );

    // Set up SSE headers
    request.response.headers.set('Content-Type', 'text/event-stream');
    request.response.headers.set('Cache-Control', 'no-cache');
    request.response.headers.set('Connection', 'keep-alive');
    request.response.headers.set('Access-Control-Allow-Origin', '*');

    // 接続タイムアウト設定
    // 最終アクティビティタイムスタンプの追跡
    var lastActivityTime = DateTime.now();

    // 接続開始時間
    final connectionStartTime = DateTime.now();

    // クリーンアップフラグ
    var isClosed = false;

    // サブスクリプションを定義
    StreamSubscription<ServerNotification>? subscription;
    Timer? heartbeatTimer;

    // クリーンアップ処理
    void cleanup() {
      if (!isClosed) {
        isClosed = true;
        subscription?.cancel();
        heartbeatTimer?.cancel();
        try {
          request.response.close();
        } catch (e) {
          _logWarning('Error closing SSE response: $e');
        }
      }
    }

    // Listen for server notifications
    subscription = server.notifications.listen(
      (notification) {
        if (isClosed) return;

        if (notification.context.clientId == clientId &&
            notification.context.sessionId == sessionId) {
          try {
            final jsonNotification = _codec.encodeNotification(
              notification.notification,
            );
            final data = json.encode(jsonNotification);

            // Send the notification as an SSE event
            request.response.write('data: $data\n\n');

            // アクティビティ時間の更新
            lastActivityTime = DateTime.now();
          } on Object catch (e) {
            _logWarning('Error sending SSE notification: $e');
          }
        }
      },
      onError: (Object e) {
        _logWarning('Error in notification stream: $e');
        cleanup();
      },
      onDone: () {
        _log('Notification stream closed for client: $clientId');
        cleanup();
      },
    );

    // Keep the connection alive with heartbeats
    heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      if (isClosed) return;

      try {
        request.response.write(': heartbeat\n\n');

        // アクティビティ時間の更新（ハートビート送信は活動とみなす）
        lastActivityTime = DateTime.now();

        // タイムアウトチェック
        final idleTime = DateTime.now().difference(lastActivityTime);
        final connectionTime = DateTime.now().difference(connectionStartTime);

        // アイドルタイムアウトのチェック
        if (idleTime > maxIdleTime) {
          _log(
            'SSE connection idle timeout for client: $clientId (${idleTime.inSeconds}s)',
          );
          cleanup();
          return;
        }

        // 最大接続時間のチェック
        if (connectionTime > maxConnectionTime) {
          _log(
            'SSE connection max time reached for client: $clientId (${connectionTime.inMinutes}m)',
          );
          cleanup();
          return;
        }
      } catch (e) {
        _logWarning('Error sending heartbeat: $e');
        cleanup();
      }
    });

    // Clean up when the client disconnects
    try {
      await request.response.done;
      _log('SSE connection closed normally for client: $clientId');
    } catch (e) {
      _logWarning('SSE connection error for client: $clientId - $e');
    } finally {
      cleanup();
    }
  }

  /// Sends an error response.
  void _sendErrorResponse(HttpResponse response, JsonRpcError error) {
    response
      ..headers.set('Content-Type', 'application/json')
      ..statusCode = HttpStatus.ok
      ..write(json.encode(_codec.encodeResponse(error)));
  }

  /// Logs an error message.
  void _logError(String message) {
    logger?.severe(message);
    _writeToLogFile('[ERROR] $message');
  }

  /// Logs a warning message.
  void _logWarning(String message) {
    logger?.warning(message);
    _writeToLogFile('[WARNING] $message');
  }

  /// Logs an informational message.
  void _log(String message) {
    logger?.info(message);
    _writeToLogFile('[INFO] $message');
  }

  /// Writes a message to the log file if available.
  void _writeToLogFile(String message) {
    if (_logFile != null) {
      try {
        final timestamp = DateTime.now().toIso8601String();
        _logFile!.writeln('$timestamp $message');
      } on Exception catch (e) {
        // Avoid recursive logging if writing to log file fails
        logger?.severe('Failed to write to log file: $e');
      }
    }
  }
}

/// Create an HTTP MCP server.
///
/// Returns a [SseServerTransport] instance that can be used to control the server.
/// Use the [SseServerTransport.start] method to begin listening for connections.
SseServerTransport serveSse(
  Server server, {
  SseServerTransportOptions? options,
  String? logFilePath,
  Logger? logger,
}) {
  // Combine provided options with defaults
  final effectiveOptions = options ?? SseServerTransportOptions();

  return SseServerTransport(
    server,
    host: effectiveOptions.host,
    port: effectiveOptions.port,
    maxIdleTime: effectiveOptions.maxIdleTime,
    maxConnectionTime: effectiveOptions.maxConnectionTime,
    heartbeatInterval: effectiveOptions.heartbeatInterval,
    logger: logger ?? effectiveOptions.logger ?? Logger('SseServer'),
    logFilePath: logFilePath ?? effectiveOptions.logFilePath,
  );
}
