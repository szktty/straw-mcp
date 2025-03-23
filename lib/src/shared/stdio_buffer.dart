import 'dart:convert';
import 'dart:typed_data';

/// Efficient buffering and reading mechanism for JSON-RPC messages.
///
/// This class improves data integrity and processing efficiency in communication
/// through standard input/output. It combines fragmentary received byte data and
/// extracts it into a JSON object when a complete JSON-RPC message becomes available.
class ReadBuffer {
  /// Creates a new read buffer.
  ReadBuffer();

  /// Internal buffer for accumulated data.
  Uint8List? _buffer;

  /// Appends chunk data to the buffer.
  ///
  /// Efficiently combines new data with existing buffer contents.
  void append(List<int> chunk) {
    if (_buffer == null) {
      // 新規バッファの場合は直接Uint8Listに変換
      _buffer = Uint8List.fromList(chunk);
    } else {
      // 既存バッファがある場合は連結
      final newBuffer = Uint8List(_buffer!.length + chunk.length)
        ..setRange(0, _buffer!.length, _buffer!);
      newBuffer.setRange(_buffer!.length, newBuffer.length, chunk);
      _buffer = newBuffer;
    }
  }

  /// Reads a single message from the buffer.
  ///
  /// Returns the parsed JSON if a complete message is available,
  /// null if there is no complete message yet,
  /// or throws a FormatException if the JSON is invalid.
  Map<String, dynamic>? readMessage() {
    if (_buffer == null || _buffer!.isEmpty) {
      return null;
    }

    // 改行文字を探す
    final newlineIndex = _buffer!.indexOf(10); // 10 is '\n' in ASCII
    if (newlineIndex == -1) {
      // 改行がなければ完全なメッセージがない
      return null;
    }

    // メッセージの抽出
    final messageBytes = Uint8List(newlineIndex)
      ..setRange(0, newlineIndex, _buffer!);

    // バッファの更新（読み取り部分を削除）
    if (newlineIndex + 1 < _buffer!.length) {
      final remainingLength = _buffer!.length - (newlineIndex + 1);
      final newBuffer = Uint8List(remainingLength)
        ..setRange(0, remainingLength, _buffer!, newlineIndex + 1);
      _buffer = newBuffer;
    } else {
      // バッファを空にする
      _buffer = Uint8List(0);
    }

    try {
      // UTF-8デコード
      final jsonString = utf8.decode(messageBytes);
      // JSONパース
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Invalid JSON message: $e');
    }
  }

  /// Clears the buffer, releasing memory.
  void clear() {
    _buffer = null;
  }

  /// Gets the current size of the buffer in bytes.
  int get length => _buffer?.length ?? 0;

  /// Checks if the buffer is empty.
  bool get isEmpty => _buffer == null || _buffer!.isEmpty;
}

/// Utility functions for stdio communication in the MCP protocol.
class StdioUtils {
  /// Serializes a message to a string with a trailing newline.
  ///
  /// This is the format expected by MCP when communicating over stdio.
  static String serializeMessage(dynamic message) {
    return '${json.encode(message)}\n';
  }

  /// Deserializes a string into a JSON map.
  ///
  /// Throws a FormatException if the string is not valid JSON.
  static Map<String, dynamic> deserializeMessage(String line) {
    try {
      final jsonMap = json.decode(line) as Map<String, dynamic>;
      return jsonMap;
    } catch (e) {
      throw FormatException('Failed to parse JSON: $e');
    }
  }
}
