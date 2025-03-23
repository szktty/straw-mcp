import 'dart:convert';

import 'package:straw_mcp/src/shared/stdio_buffer.dart';
import 'package:test/test.dart';

// ignore_for_file: avoid_print, avoid_dynamic_calls, avoid_slow_async_io

void main() {
  group('ReadBuffer', () {
    late ReadBuffer buffer;

    setUp(() {
      buffer = ReadBuffer();
    });

    test('Initial state is empty', () {
      expect(buffer.isEmpty, isTrue);
      expect(buffer.length, equals(0));
    });

    test('Add and read a single buffer', () {
      // Create JSON-RPC message
      final message = {
        'jsonrpc': '2.0',
        'method': 'test',
        'params': {},
        'id': 1,
      };
      final jsonStr = '${json.encode(message)}\n';
      final bytes = utf8.encode(jsonStr);

      // Add to buffer
      buffer.append(bytes);

      expect(buffer.isEmpty, isFalse);
      expect(buffer.length, equals(bytes.length));

      // Read message
      final result = buffer.readMessage();
      expect(result, isNotNull);
      expect(result, equals(message));

      // Buffer becomes empty after reading
      expect(buffer.isEmpty, isTrue);
    });

    test('Concatenate and read multiple buffers', () {
      // Create two messages
      final message1 = {
        'jsonrpc': '2.0',
        'method': 'method1',
        'params': {},
        'id': 1,
      };
      final message2 = {
        'jsonrpc': '2.0',
        'method': 'method2',
        'params': {},
        'id': 2,
      };

      final jsonStr1 = '${json.encode(message1)}\n';
      final jsonStr2 = '${json.encode(message2)}\n';

      final bytes1 = utf8.encode(jsonStr1);
      final bytes2 = utf8.encode(jsonStr2);

      // Add to buffer
      buffer.append(bytes1);
      buffer.append(bytes2);

      // Read first message
      final result1 = buffer.readMessage();
      expect(result1, equals(message1));

      // Read second message
      final result2 = buffer.readMessage();
      expect(result2, equals(message2));

      // Buffer becomes empty after reading all
      expect(buffer.isEmpty, isTrue);
    });

    test('Read partial message', () {
      // Incomplete message without newline
      const partialJson = '{"jsonrpc":"2.0","method":"test"';
      final bytes = utf8.encode(partialJson);

      buffer.append(bytes);

      // Cannot read without newline
      final result = buffer.readMessage();
      expect(result, isNull);

      // Buffer is not consumed
      expect(buffer.isEmpty, isFalse);
      expect(buffer.length, equals(bytes.length));

      // Add remaining message and newline
      const remaining = ',"params":{},"id":1}\n';
      buffer.append(utf8.encode(remaining));

      // Can read as complete message
      final completeResult = buffer.readMessage();
      expect(completeResult, isNotNull);
      expect(completeResult!['method'], equals('test'));
      expect(completeResult['id'], equals(1));
    });

    test('Read messages spanning multiple lines', () {
      // Add multiple messages to buffer
      final message1 = {'jsonrpc': '2.0', 'method': 'method1', 'id': 1};
      final message2 = {'jsonrpc': '2.0', 'method': 'method2', 'id': 2};
      final message3 = {'jsonrpc': '2.0', 'method': 'method3', 'id': 3};

      final combined = utf8.encode(
        '${json.encode(message1)}\n${json.encode(message2)}\n${json.encode(message3)}\n',
      );

      buffer.append(combined);

      // Read in order
      expect(buffer.readMessage(), equals(message1));
      expect(buffer.readMessage(), equals(message2));
      expect(buffer.readMessage(), equals(message3));
      expect(buffer.readMessage(), isNull); // No more messages
    });

    test('Clear buffer', () {
      final message = {'jsonrpc': '2.0', 'method': 'test', 'id': 1};
      final jsonStr = '${json.encode(message)}\n';

      buffer.append(utf8.encode(jsonStr));
      expect(buffer.isEmpty, isFalse);

      // Clear buffer
      buffer.clear();

      // Buffer is empty after clearing
      expect(buffer.isEmpty, isTrue);
      expect(buffer.length, equals(0));
      expect(buffer.readMessage(), isNull);
    });

    test('Handle invalid JSON error', () {
      // Add invalid JSON to buffer
      buffer.append(utf8.encode('{"not valid json"\n'));

      // Error on reading
      expect(() => buffer.readMessage(), throwsA(isA<FormatException>()));

      // Buffer is cleared after error
      expect(buffer.isEmpty, isTrue);
    });

    test('Handle empty message', () {
      // Case with only newline
      buffer.append(utf8.encode('\n'));

      expect(() => buffer.readMessage(), throwsA(isA<FormatException>()));
      expect(buffer.isEmpty, isTrue);
    });

    test('Handle large message', () {
      // Create large message of 10KB
      final largeObject = <String, dynamic>{
        'jsonrpc': '2.0',
        'method': 'largeMethod',
        'id': 1,
        'params': {'data': List.generate(1000, (i) => 'data$i').join(',')},
      };

      final jsonStr = '${json.encode(largeObject)}\n';
      final bytes = utf8.encode(jsonStr);

      // Add to buffer
      buffer.append(bytes);

      // Read message
      final result = buffer.readMessage();
      expect(result, isNotNull);
      expect(result!['method'], equals('largeMethod'));
      expect(result['params']['data'].length, greaterThan(5000));
    });

    test('Handle multibyte characters', () {
      // Message containing Japanese
      final japaneseMessage = {
        'jsonrpc': '2.0',
        'method': 'testJapanese',
        'id': 1,
        'params': {'text': '日本語のテスト'},
      };

      final jsonStr = '${json.encode(japaneseMessage)}\n';
      final bytes = utf8.encode(jsonStr);

      buffer.append(bytes);

      final result = buffer.readMessage();
      expect(result, isNotNull);
      expect(result!['params']['text'], equals('日本語のテスト'));
    });
  });

  group('StdioUtils', () {
    test('Serialize message', () {
      final message = {'jsonrpc': '2.0', 'method': 'test', 'id': 1};
      final result = StdioUtils.serializeMessage(message);

      expect(result, equals('{"jsonrpc":"2.0","method":"test","id":1}\n'));
    });

    test('Deserialize message', () {
      const jsonStr = '{"jsonrpc":"2.0","method":"test","id":1}';
      final result = StdioUtils.deserializeMessage(jsonStr);

      expect(result, isA<Map<String, dynamic>>());
      expect(result['jsonrpc'], equals('2.0'));
      expect(result['method'], equals('test'));
      expect(result['id'], equals(1));
    });

    test('Deserialize invalid JSON error', () {
      const invalidJson = '{"not valid json"';

      expect(
        () => StdioUtils.deserializeMessage(invalidJson),
        throwsA(isA<FormatException>()),
      );
    });

    test('Consistency between serialization and deserialization', () {
      final originalMessage = {
        'jsonrpc': '2.0',
        'method': 'testMethod',
        'id': 123,
        'params': {
          'complex': {
            'nested': [1, 2, 3],
            'value': true,
          },
        },
      };

      // Serialize
      final serialized = StdioUtils.serializeMessage(originalMessage);

      // Remove newline
      final withoutNewline = serialized.substring(0, serialized.length - 1);

      // Deserialize
      final deserialized = StdioUtils.deserializeMessage(withoutNewline);

      // Check if it matches the original message
      expect(deserialized, equals(originalMessage));
    });
  });
}
