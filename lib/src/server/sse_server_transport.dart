/// HTTP server implementation for the MCP protocol.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:straw_mcp/src/json_rpc/codec.dart';
import 'package:straw_mcp/src/json_rpc/message.dart';
import 'package:straw_mcp/src/mcp/types.dart';
import 'package:straw_mcp/src/server/server.dart';
import 'package:straw_mcp/src/shared/logging/logging_options.dart';
import 'package:straw_mcp/src/shared/transport.dart';

/// Configuration options for SSE server.
class SseServerTransportOptions {
  /// Creates a new set of SSE server options.
  const SseServerTransportOptions({
    this.host = 'localhost',
    this.port = 9000,
    this.maxIdleTime = const Duration(minutes: 2),
    this.maxConnectionTime = const Duration(minutes: 30),
    this.heartbeatInterval = const Duration(seconds: 30),
    this.logging = const LoggingOptions(),
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

  /// Logging options for transport events.
  final LoggingOptions logging;
}

/// HTTP server implementation for MCP using Server-Sent Events (SSE).
///
/// Provides an HTTP interface to an MCP server.
class SseServerTransport extends TransportBase {
  /// Creates a new HTTP MCP server.
  SseServerTransport({
    required SseServerTransportOptions options,
    this.onServerClose,
  }) : host = options.host,
       port = options.port,
       maxIdleTime = options.maxIdleTime,
       maxConnectionTime = options.maxConnectionTime,
       heartbeatInterval = options.heartbeatInterval,
       super(logging: options.logging);

  /// Callback triggered when the server is closed
  final void Function()? onServerClose;

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

  /// The HTTP server instance.
  HttpServer? _httpServer;

  /// JSON-RPC codec for message encoding/decoding.
  final JsonRpcCodec _codec = JsonRpcCodec();

  /// Active SSE connections mapped by session ID
  final Map<String, HttpResponse> _sseConnections = {};

  @override
  Future<void> start() async {
    if (isRunning) {
      log('Server already running');
      return;
    }

    try {
      _httpServer = await HttpServer.bind(host, port);
      isRunning = true;
      log('MCP Server running on http://$host:$port');

      // Process incoming requests
      await _processRequests();
    } catch (e) {
      logError('Failed to start server: $e');
      handleError(e);
      rethrow;
    }
  }

  /// Process incoming HTTP requests.
  Future<void> _processRequests() async {
    if (_httpServer == null) return;

    try {
      await for (final HttpRequest request in _httpServer!) {
        if (!isRunning) break;

        try {
          if (request.method == 'POST' && request.uri.path == '/jsonrpc') {
            await _handleJsonRpcRequest(request);
          } else if (request.method == 'GET' && request.uri.path == '/sse') {
            await _handleSseRequest(request);
          } else {
            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
          }
        } catch (e) {
          logError('Error handling request: $e');
          try {
            request.response.statusCode = HttpStatus.internalServerError;
            await request.response.close();
          } catch (_) {
            // Ignore errors when trying to close response
          }
        }
      }
    } catch (e) {
      if (isRunning) {
        logError('Error processing requests: $e');
        handleError(e);
      }
    }
  }

  @override
  Future<void> close() async {
    if (!isRunning) return;

    isRunning = false;
    log('Stopping SSE server');

    // Close all active SSE connections
    for (final response in _sseConnections.values) {
      try {
        await response.close();
      } catch (_) {
        // Ignore errors when closing responses
      }
    }
    _sseConnections.clear();

    // Close the HTTP server
    await _httpServer?.close();
    log('HTTP server closed');

    // Trigger server close callback
    onServerClose?.call();

    // Call superclass's close to handle log file closing and event firing
    await super.close();
  }

  @override
  Future<void> send(JsonRpcMessage message) async {
    if (!isRunning) {
      logWarning('Server not running, cannot send message');
      return;
    }

    try {
      Map<String, dynamic> jsonMap;

      // Handle different message types
      if (message is JsonRpcResponse) {
        jsonMap = _codec.encodeResponse(message);
      } else if (message is JsonRpcError) {
        jsonMap = _codec.encodeResponse(message);
      } else if (message is JsonRpcNotification) {
        jsonMap = _codec.encodeNotification(message);
      } else {
        logError('Unknown message type: ${message.runtimeType}');
        return;
      }

      // Encode as JSON
      final data = json.encode(jsonMap);

      // Broadcast to all connected SSE clients
      for (final response in _sseConnections.values) {
        try {
          response.write('data: $data\n\n');
        } catch (e) {
          logWarning('Error sending message to client: $e');
        }
      }
    } catch (e) {
      logError('Error encoding message: $e');
      handleError(e);
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

    try {
      // メッセージをクライアントに通知
      handleMessage(body);

      // レスポンスはサーバーから非同期に送信されるため、ここでは何もしない
      // リクエストは正常に受け付けたことを返す
      request.response.headers.set('Content-Type', 'application/json');
      request.response.statusCode = HttpStatus.accepted;
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
    log(
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

    // Save the connection
    _sseConnections[sessionId] = request.response;

    // ハートビートタイマー
    Timer? heartbeatTimer;

    // クリーンアップ処理
    void cleanup() {
      if (!isClosed) {
        isClosed = true;
        log('Closing SSE connection for session: $sessionId');
        heartbeatTimer?.cancel();
        _sseConnections.remove(sessionId);
        try {
          request.response.close();
        } catch (e) {
          logWarning('Error closing SSE connection: $e');
        }
      }
    }

    // アイドルタイマー
    Timer? idleTimer;
    void resetIdleTimer() {
      idleTimer?.cancel();
      idleTimer = Timer(maxIdleTime, () {
        log('SSE connection idle timeout for session: $sessionId');
        cleanup();
      });
    }

    // ハートビートの設定
    heartbeatTimer = Timer.periodic(heartbeatInterval, (timer) {
      if (isClosed) {
        timer.cancel();
        return;
      }

      try {
        // ハートビート送信
        request.response.write(': heartbeat\n\n');

        // アクティビティタイムスタンプを更新
        lastActivityTime = DateTime.now();

        // 接続期間の確認
        final connectionDuration = lastActivityTime.difference(
          connectionStartTime,
        );
        if (connectionDuration > maxConnectionTime) {
          log('SSE connection max time reached for session: $sessionId');
          cleanup();
          timer.cancel();
        }
      } catch (e) {
        logWarning('Error sending heartbeat: $e');
        cleanup();
        timer.cancel();
      }
    });

    // 最初のアイドルタイマー設定
    resetIdleTimer();

    // 接続が閉じられたときのクリーンアップ
    request.response.done
        .then((_) {
          log('SSE connection closed by client: $sessionId');
          cleanup();
        })
        .catchError((e) {
          logWarning('Error in SSE connection: $e');
          cleanup();
        });
  }

  /// ステータスコード200のJSON-RPC エラーレスポンスを送信します。
  void _sendErrorResponse(HttpResponse response, JsonRpcError error) {
    response
      ..headers.set('Content-Type', 'application/json')
      ..statusCode = HttpStatus.ok
      ..write(json.encode(_codec.encodeResponse(error)));
  }
}
