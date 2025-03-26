/// Stream-based server implementation for the MCP protocol.
///
/// This file provides an implementation of an MCP server that communicates
/// via input/output streams, allowing for flexible integration with various
/// transport mechanisms including standard input/output, sockets, and more.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' show dirname;
import 'package:straw_mcp/src/json_rpc/codec.dart';
import 'package:straw_mcp/src/json_rpc/message.dart';
import 'package:straw_mcp/src/mcp/types.dart';
import 'package:straw_mcp/src/server/server.dart';
import 'package:straw_mcp/src/shared/stdio_buffer.dart';
import 'package:straw_mcp/src/shared/transport.dart';
import 'package:synchronized/synchronized.dart';

/// A function that can be used to customize context for stream server.
typedef StreamServerTransportContextFunction =
    void Function(NotificationContext context);

/// Configuration options for stream server.
class StreamServerTransportOptions {
  /// Creates a new set of stream server options.
  ///
  /// - [logger]: Optional logger for error messages
  /// - [contextFunction]: Optional function to customize client context
  /// - [logFilePath]: Optional path to a log file for recording server events
  /// - [stream]: Input stream for receiving messages
  /// - [sink]: Output sink for sending responses
  StreamServerTransportOptions({
    required this.stream,
    required this.sink,
    this.logger,
    this.contextFunction,
    this.logFilePath,
  });

  /// Creates a new set of stream server options using standard input/output streams.
  ///
  /// - [logger]: Optional logger for error messages
  /// - [contextFunction]: Optional function to customize client context
  /// - [logFilePath]: Optional path to a log file for recording server events
  factory StreamServerTransportOptions.stdio({
    Logger? logger,
    StreamServerTransportContextFunction? contextFunction,
    String? logFilePath,
  }) {
    return StreamServerTransportOptions(
      stream: stdin.asBroadcastStream(),
      sink: stdout,
      logger: logger,
      contextFunction: contextFunction,
      logFilePath: logFilePath,
    );
  }

  /// Input stream for receiving messages.
  final Stream<List<int>> stream;

  /// Output sink for sending responses.
  final StreamSink<List<int>> sink;

  /// Logger for error messages.
  final Logger? logger;

  /// Function to customize client context.
  final StreamServerTransportContextFunction? contextFunction;

  /// Path to log file (optional)
  final String? logFilePath;
}

/// MCP server implementation that communicates via input/output streams.
abstract class StreamServerTransport extends TransportBase {
  /// Creates a new stream-based MCP server.
  ///
  /// - [server]: The MCP server to wrap
  /// - [options]: Optional configuration options for the server
  StreamServerTransport(
    this.server, {
    required StreamServerTransportOptions options,
  }) : logger = options.logger,
       contextFunction = options.contextFunction,
       logFilePath = options.logFilePath,
       stream = options.stream,
       sink = options.sink {
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
  }

  /// The wrapped MCP server.
  final Server server;

  /// Logger for error messages.
  final Logger? logger;

  /// Function to customize client context.
  final StreamServerTransportContextFunction? contextFunction;

  /// Path to log file.
  final String? logFilePath;

  /// Input stream for receiving messages.
  final Stream<List<int>> stream;

  /// Output sink for sending responses.
  final StreamSink<List<int>> sink;

  /// File for logging if logFilePath is specified.
  IOSink? _logFile;

  /// JSON-RPC codec for message encoding/decoding.
  final JsonRpcCodec _codec = JsonRpcCodec();

  /// Whether the server is currently running.
  bool _isRunning = false;

  /// Subscription for notifications.
  StreamSubscription<ServerNotification>? _notificationSubscription;

  /// Subscription for input stream.
  StreamSubscription<List<int>>? _inputSubscription;

  /// Read buffer for processing incoming data.
  ///
  /// Accumulates data until complete JSON-RPC messages can be extracted.
  final ReadBuffer _readBuffer = ReadBuffer();

  /// Lock for synchronizing buffer reading operations.
  ///
  /// Ensures thread-safe access to the read buffer.
  final Lock _readLock = Lock();

  /// Lock for synchronizing write operations.
  ///
  /// Ensures that responses are written atomically to the output stream.
  final Lock _writeLock = Lock();

  /// Standard client context.
  static final NotificationContext _defaultContext = NotificationContext(
    'stream',
    'stream',
  );

  @override
  Future<void> start() async {
    if (_isRunning) {
      return;
    }

    _isRunning = true;
    _log('Starting server');

    // Set up client context
    final context = _defaultContext;
    contextFunction?.call(context);
    server.setCurrentClient(context);
    _log('Client context set up');

    // Handle notifications from server
    _notificationSubscription = server.notifications.listen((notification) {
      // Only handle notifications for this client
      if (notification.context.clientId == _defaultContext.clientId) {
        try {
          _logDebug(
            'Sending notification: ${notification.notification.method}',
          );
          send(notification.notification);
        } on Exception catch (e) {
          _logError('Error writing notification response: $e');
        }
      }
    });
    _log('Notification listener set up');

    // データ受信処理を設定
    _inputSubscription = stream.listen(
      _onData,
      onError: (Object error) {
        _logError('Error reading from input stream: $error');
        handleError(error);
      },
      onDone: () {
        _log('Input stream closed');
        close();
      },
    );
    _log('Input stream set up');

    // 永続的に実行し続ける
    while (_isRunning) {
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  /// データ受信時の処理
  void _onData(List<int> data) {
    _readBuffer.append(data);
    _processBuffer();
  }

  /// バッファ処理
  void _processBuffer() {
    _readLock.synchronized(() async {
      while (_isRunning) {
        try {
          final jsonMap = _readBuffer.readMessage();
          if (jsonMap == null) {
            break;
          }

          await _processMessage(jsonMap);
        } on Exception catch (e) {
          _logError('Error processing buffer: $e');
          handleError(e);

          // エラーレスポンスを送信
          try {
            final errorResponse = createErrorResponse(
              null,
              internalError,
              'Internal error: $e',
            );
            await send(errorResponse);
          } on Exception catch (respError) {
            _logError('Failed to send error response: $respError');
          }
        }
      }
    });
  }

  /// Processes a single JSON-RPC message.
  Future<void> _processMessage(Map<String, dynamic> jsonMap) async {
    _logDebug(
      'Processing message: ${jsonMap.containsKey("method") ? "Method: ${jsonMap["method"]}" : "Response ID: ${jsonMap["id"]}"}',
    );

    try {
      // メッセージをJSON文字列に変換
      final messageJson = json.encode(jsonMap);

      // 受信したメッセージを通知
      handleMessage(messageJson);

      // Handle the message using the wrapped server
      JsonRpcMessage? response;
      try {
        _log(
          'Handling message: ${jsonMap.containsKey("method") ? jsonMap["method"] : "(response/notification)"} ${jsonMap.containsKey("id") ? "(ID: ${jsonMap["id"]})" : ""}',
        );
        response = await server.handleMessage(messageJson);
        _logDebug(
          'Server processed message${response != null ? " and returned a response" : " (no response needed)"}',
        );
      } on Exception catch (handleError) {
        _logError('Error handling message: $handleError');
        // Send internal error
        final errorResponse = createErrorResponse(
          jsonMap['id'],
          internalError,
          'Server error: $handleError',
        );
        await send(errorResponse);
        return;
      }

      // Only write response if there is one (not for notifications)
      if (response != null) {
        try {
          _log('Sending response for ID: ${jsonMap["id"]}');
          await send(response);
        } on Exception catch (writeError) {
          _logError('Error writing response: $writeError');
        }
      }
    } on Exception catch (e) {
      // Catch-all for any other errors
      _logError('Unexpected error processing message: $e');
      handleError(e);

      try {
        final errorResponse = createErrorResponse(
          null,
          internalError,
          'Unexpected error: $e',
        );
        await send(errorResponse);
      } on Exception catch (respError) {
        _logError('Failed to send error response: $respError');
      }
    }
  }

  @override
  Future<void> send(JsonRpcMessage message) async {
    return _writeLock.synchronized(() async {
      try {
        Map<String, dynamic> jsonMap;

        // Handle different response types
        try {
          if (message is JsonRpcResponse) {
            jsonMap = _codec.encodeResponse(message);
          } else if (message is JsonRpcError) {
            jsonMap = _codec.encodeResponse(message);
          } else if (message is JsonRpcNotification) {
            jsonMap = _codec.encodeNotification(message);
          } else {
            _logError('Unknown response type: ${message.runtimeType}');
            return;
          }
        } on Exception catch (encodeError) {
          _logError('Error encoding response: $encodeError');
          try {
            // Fallback to a simple error response if encoding fails
            jsonMap = {
              'jsonrpc': jsonRpcVersion,
              'error': {
                'code': internalError,
                'message': 'Failed to encode response: $encodeError',
              },
              'id': null,
            };
          } on Exception catch (fallbackError) {
            _logError(
              'Failed to create fallback error response: $fallbackError',
            );
            return;
          }
        }

        try {
          // Encode the JSON map to a string
          final jsonString = StdioUtils.serializeMessage(jsonMap);

          // Write response as JSON followed by newline
          sink.add(utf8.encode(jsonString));
          await flushOutput();
        } on Exception catch (writeError) {
          _logError('Error writing to output stream: $writeError');
          handleError(writeError);
        }
      } on Exception catch (e) {
        _logError('Unexpected error writing response: $e');
        handleError(e);
      }
    });
  }

  /// Flushes any buffered output to the client.
  @protected
  Future<void> flushOutput();

  @override
  Future<void> close() async {
    if (!_isRunning) {
      return;
    }

    _isRunning = false;

    // 通知サブスクリプションのキャンセル
    await _notificationSubscription?.cancel();
    _notificationSubscription = null;

    // 入力ストリームサブスクリプションのキャンセル
    await _inputSubscription?.cancel();
    _inputSubscription = null;

    // バッファのクリア
    _readBuffer.clear();

    // Close log file if open
    if (_logFile != null) {
      _writeToLogFile('[INFO] Closing server');
      await _logFile!.flush();
      await _logFile!.close();
      _logFile = null;
    }

    // 接続終了を通知
    handleClose();
  }

  /// Logs an error message.
  void _logError(String message) {
    logger?.severe(message);
    _writeToLogFile('[ERROR] $message');
  }

  /// Logs an informational message.
  void _log(String message) {
    logger?.info(message);
    _writeToLogFile('[INFO] $message');
  }

  /// Logs a debug message.
  void _logDebug(String message) {
    logger?.fine(message);
    _writeToLogFile('[DEBUG] $message');
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
