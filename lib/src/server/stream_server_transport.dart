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
import 'package:straw_mcp/src/json_rpc/codec.dart';
import 'package:straw_mcp/src/json_rpc/message.dart';
import 'package:straw_mcp/src/mcp/types.dart';
import 'package:straw_mcp/src/shared/logging/logging_options.dart';
import 'package:straw_mcp/src/shared/stdio_buffer.dart';
import 'package:straw_mcp/src/shared/transport.dart';
import 'package:synchronized/synchronized.dart';

/// Configuration options for stream server.
class StreamServerTransportOptions {
  /// Creates a new set of stream server options.
  ///
  /// - [stream]: Input stream for receiving messages
  /// - [sink]: Output sink for sending responses
  /// - [logging]: Optional logging configuration for the transport
  const StreamServerTransportOptions({
    required this.stream,
    required this.sink,
    this.logging = const LoggingOptions(),
  });

  /// Input stream for receiving messages.
  final Stream<List<int>> stream;

  /// Output sink for sending responses.
  final StreamSink<List<int>> sink;

  /// Logging options for transport events.
  final LoggingOptions logging;
}

/// MCP server implementation that communicates via input/output streams.
abstract class StreamServerTransport extends TransportBase {
  /// Creates a new stream-based MCP server.
  ///
  /// - [options]: Configuration options for the server
  StreamServerTransport({required StreamServerTransportOptions options})
    : stream = options.stream,
      sink = options.sink,
      super(logging: options.logging);

  /// Input stream for receiving messages.
  final Stream<List<int>> stream;

  /// Output sink for sending responses.
  final StreamSink<List<int>> sink;

  /// JSON-RPC codec for message encoding/decoding.
  final JsonRpcCodec _codec = JsonRpcCodec();

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

  @override
  Future<void> start() async {
    if (isRunning) {
      return;
    }

    isRunning = true;
    log('Starting transport');

    // データ受信処理を設定
    _inputSubscription = stream.listen(
      _onData,
      onError: (Object error) {
        logError('Error reading from input stream: $error');
        handleError(error);
      },
      onDone: () {
        log('Input stream closed');
        close();
      },
    );
    log('Input stream set up');
  }

  /// データ受信時の処理
  void _onData(List<int> data) {
    _readBuffer.append(data);
    _processBuffer();
  }

  /// バッファ処理
  void _processBuffer() {
    _readLock.synchronized(() async {
      while (isRunning) {
        try {
          final jsonMap = _readBuffer.readMessage();
          if (jsonMap == null) {
            break;
          }

          // メッセージをJSON文字列に変換
          final messageJson = json.encode(jsonMap);

          // 受信したメッセージを通知
          handleMessage(messageJson);
        } on Exception catch (e) {
          logError('Error processing buffer: $e');
          handleError(e);
        }
      }
    });
  }

  @override
  Future<void> send(JsonRpcMessage message) async {
    return _writeLock.synchronized(() async {
      if (!isRunning) {
        logWarning('Transport not running, cannot send message');
        return;
      }

      try {
        Map<String, dynamic> jsonMap;

        // Handle different message types
        try {
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
        } on Exception catch (encodeError) {
          logError('Error encoding message: $encodeError');
          try {
            // Fallback to a simple error response if encoding fails
            jsonMap = {
              'jsonrpc': jsonRpcVersion,
              'error': {
                'code': internalError,
                'message': 'Failed to encode message: $encodeError',
              },
              'id': null,
            };
          } on Exception catch (fallbackError) {
            logError(
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
          logError('Error writing to output stream: $writeError');
          handleError(writeError);
        }
      } on Exception catch (e) {
        logError('Unexpected error writing message: $e');
        handleError(e);
      }
    });
  }

  /// Flushes any buffered output to the client.
  @protected
  Future<void> flushOutput();

  @override
  Future<void> close() async {
    if (!isRunning) {
      return;
    }

    // 入力ストリームサブスクリプションのキャンセル
    await _inputSubscription?.cancel();
    _inputSubscription = null;

    // バッファのクリア
    _readBuffer.clear();

    // スーパークラスのclose()を呼び出す
    await super.close();
  }
}
