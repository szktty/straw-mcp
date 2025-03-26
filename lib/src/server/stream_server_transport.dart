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
import 'package:path/path.dart' show dirname;
import 'package:straw_mcp/src/json_rpc/codec.dart';
import 'package:straw_mcp/src/json_rpc/message.dart';
import 'package:straw_mcp/src/mcp/types.dart';
import 'package:straw_mcp/src/server/server.dart';
import 'package:straw_mcp/src/shared/stdio_buffer.dart';
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
  final IOSink sink;

  /// Logger for error messages.
  final Logger? logger;

  /// Function to customize client context.
  final StreamServerTransportContextFunction? contextFunction;

  /// Path to log file (optional)
  final String? logFilePath;
}

/// MCP server implementation that communicates via input/output streams.
class StreamServerTransport {
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

  /// Factory constructor for creating a server using standard input/output streams.
  ///
  /// This is the recommended way to create a server for command-line integration
  /// and desktop applications that use stdio.
  ///
  /// Uses a broadcast stream for stdin to allow multiple listeners.
  ///
  /// - [logger]: Optional logger for error messages
  /// - [contextFunction]: Optional function to customize client context
  /// - [logFilePath]: Optional path to a log file for recording server events
  factory StreamServerTransport.stdio(
    Server server, {
    Logger? logger,
    StreamServerTransportContextFunction? contextFunction,
    String? logFilePath,
  }) {
    return StreamServerTransport(
      server,
      options: StreamServerTransportOptions.stdio(
        logger: logger,
        contextFunction: contextFunction,
        logFilePath: logFilePath,
      ),
    );
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
  final IOSink sink;

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

  /// Starts listening on input stream and processing messages.
  Future<void> listen() async {
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
          _writeResponse(notification.notification, sink);
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

          // エラーレスポンスを送信
          try {
            final errorResponse = createErrorResponse(
              null,
              internalError,
              'Internal error: $e',
            );
            await _writeResponse(errorResponse, sink);
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
        await _writeResponse(errorResponse, sink);
        return;
      }

      // Only write response if there is one (not for notifications)
      if (response != null) {
        try {
          _log('Sending response for ID: ${jsonMap["id"]}');
          await _writeResponse(response, sink);
        } on Exception catch (writeError) {
          _logError('Error writing response: $writeError');
        }
      }
    } on Exception catch (e) {
      // Catch-all for any other errors
      _logError('Unexpected error processing message: $e');
      try {
        final errorResponse = createErrorResponse(
          null,
          internalError,
          'Unexpected error: $e',
        );
        await _writeResponse(errorResponse, sink);
      } on Exception catch (respError) {
        _logError('Failed to send error response: $respError');
      }
    }
  }

  /// Writes a JSON-RPC response to the specified output stream.
  Future<void> _writeResponse(JsonRpcMessage response, IOSink output) async {
    return _writeLock.synchronized(() async {
      try {
        Map<String, dynamic> jsonMap;

        // Handle different response types
        try {
          if (response is JsonRpcResponse) {
            jsonMap = _codec.encodeResponse(response);
          } else if (response is JsonRpcError) {
            jsonMap = _codec.encodeResponse(response);
          } else if (response is JsonRpcNotification) {
            jsonMap = _codec.encodeNotification(response);
          } else {
            _logError('Unknown response type: ${response.runtimeType}');
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
          output.write(jsonString);
          await output.flush(); // Ensure the response is sent immediately
        } on Exception catch (writeError) {
          _logError('Error writing to output stream: $writeError');
        }
      } on Exception catch (e) {
        _logError('Unexpected error writing response: $e');
      }
    });
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

  /// Closes the server and releases resources.
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
  }
}

/// Convenience function to serve an MCP server over stdio.
///
/// This function creates a new StreamServer.stdio and starts listening
/// for JSON-RPC messages on standard input, writing responses to
/// standard output. It handles signals and stdin closure for graceful
/// shutdown and ensures proper resource cleanup.
Future<void> serveStdio(
  Server server, {
  StreamServerTransportOptions? options,
}) async {
  final log = options?.logger ?? Logger('StreamServer');
  final streamServer = StreamServerTransport.stdio(
    server,
    logger: log,
    contextFunction: options?.contextFunction,
    logFilePath: options?.logFilePath,
  );

  // シャットダウン処理のセットアップ
  final shutdownCompleter = Completer<void>();

  // stdinのクローズを検出するためのリスナー
  final stdinSubscription = streamServer.stream.listen(
    (_) {
      // データ処理はStreamServerに任せる
    },
    onDone: () async {
      log.info('stdin stream closed, shutting down');
      try {
        await server.close();
        await streamServer.close();

        if (!shutdownCompleter.isCompleted) {
          shutdownCompleter.complete();
        }
      } catch (e) {
        log.severe('Error during shutdown: $e');
        if (!shutdownCompleter.isCompleted) {
          shutdownCompleter.completeError(e);
        }
      }
    },
    onError: (Object error) {
      log.severe('Error on stdin: $error');
      if (!shutdownCompleter.isCompleted) {
        shutdownCompleter.completeError(error);
      }
    },
  );

  // シグナルハンドラーのセットアップ
  StreamSubscription<ProcessSignal>? sigintSubscription;
  StreamSubscription<ProcessSignal>? sigtermSubscription;

  sigintSubscription = ProcessSignal.sigint.watch().listen((_) async {
    log.info('Received SIGINT, shutting down');
    try {
      await server.close();
      await streamServer.close();
      await sigintSubscription?.cancel();
      await sigtermSubscription?.cancel();
      exit(0);
    } catch (e) {
      log.severe('Error during SIGINT shutdown: $e');
      exit(1);
    }
  });

  sigtermSubscription = ProcessSignal.sigterm.watch().listen((_) async {
    log.info('Received SIGTERM, shutting down');
    try {
      await server.close();
      await streamServer.close();
      await sigintSubscription?.cancel();
      await sigtermSubscription?.cancel();
      exit(0);
    } on Exception catch (e) {
      log.severe('Error during SIGTERM shutdown: $e');
      exit(1);
    }
  });

  // サーバーの状態を監視
  server.closeState.listen((isClosed) {
    if (isClosed && !shutdownCompleter.isCompleted) {
      log.info('Server requested shutdown');
      shutdownCompleter.complete();
    }
  });

  // リッスン開始
  try {
    await streamServer.listen();
  } catch (e) {
    log.severe('Error in stream server: $e');
    if (!shutdownCompleter.isCompleted) {
      shutdownCompleter.completeError(e);
    }
  }

  // シャットダウンが完了するまで待機
  await shutdownCompleter.future;

  // リソースの解放
  try {
    await sigintSubscription.cancel();
    await sigtermSubscription.cancel();
    await stdinSubscription.cancel();

    // 最終的な終了ログ
    log.info('MCP server completely shut down');
  } catch (e) {
    log.severe('Error during final cleanup: $e');
  }
}
