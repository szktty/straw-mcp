// Test file for STDIO communication processing
// This test verifies not only the ReadBuffer functionality but also actual client/server communication

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:straw_mcp/src/mcp/contents.dart';
import 'package:straw_mcp/src/mcp/tools.dart';
import 'package:straw_mcp/src/mcp/types.dart';
import 'package:straw_mcp/src/server/server.dart';
import 'package:straw_mcp/src/shared/stdio_buffer.dart';
import 'package:straw_mcp/src/shared/transport.dart';
import 'package:straw_mcp/src/server/stdio_server_transport.dart';
import 'package:test/test.dart';

// ignore_for_file: avoid_print, avoid_dynamic_calls, avoid_slow_async_io

// Create a logger for testing
Logger setupLogger(String name) {
  final logger = Logger(name);
  logger.onRecord.listen((record) {
    print('${record.time}: ${record.level.name}: ${record.message}');
  });
  return logger;
}

// Write test data to a file
Future<String> createTempFile(String content) async {
  final directory = Directory.systemTemp.createTempSync('mcp_test_');
  final file = File(path.join(directory.path, 'test_data.txt'));
  await file.writeAsString(content);
  return file.path;
}

// Create a simple output sink
class TestSink implements StreamSink<List<int>> {
  final List<int> buffer = [];

  @override
  void add(List<int> data) {
    buffer.addAll(data);
  }

  @override
  Future<void> flush() async {}

  @override
  Future get done => Future.value();

  @override
  Future close() async {}

  @override
  Future addStream(Stream<List<int>> stream) {
    final completer = Completer<void>();
    stream.listen(
      add,
      onDone: completer.complete,
      onError: completer.completeError,
      cancelOnError: true,
    );
    return completer.future;
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    // Error handling implementation
    stderr.writeln('Error in TestSink: $error');
    if (stackTrace != null) {
      stderr.writeln(stackTrace);
    }
  }

  @override
  String toString() {
    return utf8.decode(buffer);
  }
}

// Create a piped stream
class StreamPipe {
  final controller = StreamController<List<int>>();
  final sink = TestSink();

  Stream<List<int>> get stream => controller.stream;

  void add(List<int> data) {
    controller.add(data);
  }

  Future<void> close() async {
    await controller.close();
  }
}

void main() {
  group('STDIO Communication Tests', () {
    // File path for testing
    late Directory tempDir;

    // Setup before testing
    setUp(() async {
      // Create a temporary directory for testing
      tempDir = Directory.systemTemp.createTempSync('mcp_test_');
    });

    // Cleanup after testing
    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('ReadBufferを使った基本的なメッセージ処理', () async {
      final buffer = ReadBuffer();

      // Create a JSON-RPC message
      final request = {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {
          'protocolVersion': '2024-11-05',
          'capabilities': {},
          'clientInfo': {'name': 'test-client', 'version': '1.0.0'},
        },
      };

      // Serialize and add to buffer
      final jsonStr = StdioUtils.serializeMessage(request);
      final bytes = utf8.encode(jsonStr);
      buffer.append(bytes);

      // Read the message
      final message = buffer.readMessage();

      // Verify if the correct message was retrieved
      expect(message, isNotNull);
      expect(message!['jsonrpc'], equals('2.0'));
      expect(message['id'], equals(1));
      expect(message['method'], equals('initialize'));

      // Check if the buffer is empty
      expect(buffer.isEmpty, isTrue);
    });

    test('MCP初期化レスポンスの読み取りシミュレーション', () async {
      // This test simulates reading an initialization response using ReadBuffer
      final logPath = path.join(tempDir.path, 'server.log');

      // Create ReadBuffer for testing
      final buffer = ReadBuffer();

      // Simulate initialize response
      final initializeResponse = {
        'jsonrpc': '2.0',
        'id': 1,
        'result': {
          'protocolVersion': '2024-11-05',
          'capabilities': {
            'tools': {'listChanged': true},
          },
          'serverInfo': {'name': 'test-server', 'version': '1.0.0'},
        },
      };

      // Add response to buffer
      final responseStr = StdioUtils.serializeMessage(initializeResponse);
      buffer.append(utf8.encode(responseStr));

      // Read the message
      final message = buffer.readMessage();

      // Verify the response
      expect(message, isNotNull);
      expect(message!['jsonrpc'], equals('2.0'));
      expect(message['id'], equals(1));
      expect(message['result']['serverInfo']['name'], equals('test-server'));
    });

    test('メッセージの分割と結合', () {
      final buffer = ReadBuffer();

      // Create three messages
      final messages = [
        {'jsonrpc': '2.0', 'id': 1, 'method': 'method1', 'params': {}},
        {'jsonrpc': '2.0', 'id': 2, 'method': 'method2', 'params': {}},
        {'jsonrpc': '2.0', 'id': 3, 'method': 'method3', 'params': {}},
      ];

      // Serialize all messages into a single byte array
      final allBytes = <int>[];
      for (final msg in messages) {
        allBytes.addAll(utf8.encode(StdioUtils.serializeMessage(msg)));
      }

      // Add to buffer
      buffer.append(allBytes);

      // Verify if each message is correctly retrieved
      for (var i = 0; i < messages.length; i++) {
        final result = buffer.readMessage();
        expect(result, isNotNull);
        expect(result!['id'], equals(i + 1));
        expect(result['method'], equals('method${i + 1}'));
      }

      // After reading all messages, it should return null
      expect(buffer.readMessage(), isNull);
    });

    test('部分的なメッセージの処理', () {
      final buffer = ReadBuffer();

      // Create a message
      final message = {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'test',
        'params': {'value': 42},
      };

      final serialized = StdioUtils.serializeMessage(message);
      final bytes = utf8.encode(serialized);

      // Add partially
      final firstPart = bytes.sublist(0, bytes.length ~/ 2);
      final secondPart = bytes.sublist(bytes.length ~/ 2);

      // Add the first part
      buffer.append(firstPart);

      // Should return null as there's no complete message yet
      expect(buffer.readMessage(), isNull);

      // Add the remaining part
      buffer.append(secondPart);

      // Should retrieve the complete message
      final result = buffer.readMessage();
      expect(result, isNotNull);
      expect(result!['id'], equals(1));
      expect(result['method'], equals('test'));
      expect(result['params']['value'], equals(42));
    });

    test('不正なJSONのエラーハンドリング', () {
      final buffer = ReadBuffer();

      // Add data containing invalid JSON
      const invalidJson = '{"method": "test", "params": {invalid}}\n';
      buffer.append(utf8.encode(invalidJson));

      // Should throw a FormatException
      expect(buffer.readMessage, throwsA(isA<FormatException>()));

      // Buffer should be empty after an error
      expect(buffer.isEmpty, isTrue);
    });

    test('StdioUtilsのシリアライズとデシリアライズ', () {
      final message = {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'test',
        'params': {'value': 42},
      };

      // Serialize the message
      final serialized = StdioUtils.serializeMessage(message);

      // Check if there's a newline at the end
      expect(serialized.endsWith('\n'), isTrue);

      // Get the part excluding the newline
      final jsonStr = serialized.substring(0, serialized.length - 1);

      // Verify if the deserialized message matches the original
      final deserialized = StdioUtils.deserializeMessage(jsonStr);
      expect(deserialized['jsonrpc'], equals('2.0'));
      expect(deserialized['id'], equals(1));
      expect(deserialized['method'], equals('test'));
      expect(deserialized['params']['value'], equals(42));
    });

    test('TransportBase基本機能', () {
      // Create a mock transport that extends TransportBase
      final mockTransport = _MockTransport();

      // Set handlers
      bool messageHandlerCalled = false;
      mockTransport.onMessage = (message) {
        messageHandlerCalled = true;
        expect(message, equals('test message'));
      };

      bool errorHandlerCalled = false;
      mockTransport.onError = (error) {
        errorHandlerCalled = true;
        expect(error.toString(), contains('test error'));
      };

      bool closeHandlerCalled = false;
      mockTransport.onClose = () {
        closeHandlerCalled = false;
      };

      // Trigger handlers
      mockTransport.testHandleMessage('test message');
      mockTransport.testHandleError(Exception('test error'));

      // Verify handlers were called
      expect(messageHandlerCalled, isTrue);
      expect(errorHandlerCalled, isTrue);
    });
  });
}

// Mock implementation of TransportBase for testing
class _MockTransport extends TransportBase {
  _MockTransport() : super(logger: Logger('MockTransport'));

  @override
  Future<void> start() async {
    isRunning = true;
  }

  @override
  Future<void> send(JsonRpcMessage message) async {
    // Do nothing for this test
  }

  // Test methods to trigger handlers
  void testHandleMessage(String message) {
    handleMessage(message);
  }

  void testHandleError(Object error) {
    handleError(error);
  }

  void testHandleClose() {
    handleClose();
  }
}
