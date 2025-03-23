/// Event source implementation for Server-Sent Events.
///
/// This file provides an implementation of the EventSource API for Dart,
/// compatible with the W3C specification for server-sent events.
library;

import 'dart:async';
import 'dart:convert';

/// A single server-sent event.
class ServerSentEvent {
  /// Creates a new server-sent event.
  ServerSentEvent({required this.data, this.event, this.id, this.retry});

  /// The event data.
  final String data;

  /// The event type (optional).
  final String? event;

  /// The event ID (optional).
  final String? id;

  /// The reconnection time in milliseconds (optional).
  final int? retry;

  @override
  String toString() =>
      'ServerSentEvent(data: $data, event: $event, id: $id, retry: $retry)';
}

/// EventSource for handling Server-Sent Events.
class EventSource {
  /// Creates a new EventSource from an HTTP response.
  EventSource(this._lines) {
    _process();
  }

  final Stream<String> _lines;
  final StreamController<ServerSentEvent> _controller =
      StreamController<ServerSentEvent>.broadcast();
  String _data = '';
  String? _event;
  String? _id;
  int? _retry;
  bool _closed = false;
  StreamSubscription<String>? _subscription;

  /// Stream of server-sent events.
  Stream<ServerSentEvent> get events => _controller.stream;

  /// Whether the connection is closed.
  bool get isClosed => _closed;

  /// Processes the incoming lines from the server.
  void _process() {
    _subscription = _lines.listen(
      _processLine,
      onDone: _complete,
      onError: _handleError,
    );
  }

  /// Processes a single line from the server.
  void _processLine(String line) {
    // Process event stream line by line
    if (line.isEmpty) {
      // Empty line means dispatch the event
      if (_data.isNotEmpty) {
        // Remove the last newline character
        if (_data.endsWith('\n')) {
          _data = _data.substring(0, _data.length - 1);
        }
        final event = ServerSentEvent(
          data: _data,
          event: _event,
          id: _id,
          retry: _retry,
        );
        _controller.add(event);
      }

      // Reset data field but keep the rest of the event state
      _data = '';
      _event = null;
    } else if (line.startsWith(':')) {
      // Comment - ignore
    } else if (line.contains(':')) {
      // Field: value
      final index = line.indexOf(':');
      final field = line.substring(0, index);

      // Skip initial space after colon if present
      var value = index + 1 < line.length ? line.substring(index + 1) : '';
      if (value.startsWith(' ')) {
        value = value.substring(1);
      }

      switch (field) {
        case 'event':
          _event = value;
        case 'data':
          _data = _data.isEmpty ? value : '$_data\n$value';
        case 'id':
          _id = value;
        case 'retry':
          try {
            _retry = int.parse(value);
          } catch (_) {
            // Ignore invalid retry values
          }
      }
    } else {
      // Malformed line - ignore
    }
  }

  /// Completes the event stream.
  void _complete() {
    if (!_closed) {
      _closed = true;
      _controller.close();
    }
  }

  /// Handles errors in the event stream.
  void _handleError(Object error, [StackTrace? stackTrace]) {
    if (!_controller.isClosed) {
      _controller.addError(error, stackTrace);
    }
    close();
  }

  /// Closes the event source.
  Future<void> close() async {
    if (_closed) return;

    _closed = true;
    await _subscription?.cancel();

    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}

/// Parses an HTTP response stream into a stream of lines.
Stream<String> parseSseLines(Stream<List<int>> byteStream) {
  final streamController = StreamController<String>();

  var buffer = '';
  const lineBreak = '\n';
  const returnBreak = '\r';

  byteStream
      .transform(utf8.decoder)
      .listen(
        (chunk) {
          buffer += chunk;

          final lines = <String>[];
          while (true) {
            final lineBreakIndex = buffer.indexOf(lineBreak);
            final returnIndex = buffer.indexOf(returnBreak);

            if (lineBreakIndex == -1 && returnIndex == -1) {
              break;
            }

            var breakIndex = -1;
            if (lineBreakIndex >= 0 && returnIndex >= 0) {
              breakIndex =
                  lineBreakIndex < returnIndex ? lineBreakIndex : returnIndex;
            } else {
              breakIndex = lineBreakIndex >= 0 ? lineBreakIndex : returnIndex;
            }

            final line = buffer.substring(0, breakIndex);
            lines.add(line);

            // Handle \r\n case
            if (buffer.length > breakIndex + 1 &&
                buffer[breakIndex] == returnBreak &&
                buffer[breakIndex + 1] == lineBreak) {
              buffer = buffer.substring(breakIndex + 2);
            } else {
              buffer = buffer.substring(breakIndex + 1);
            }
          }

          for (final line in lines) {
            streamController.add(line);
          }
        },
        onDone: () {
          // Add the remaining buffer if not empty
          if (buffer.isNotEmpty) {
            streamController.add(buffer);
          }
          streamController.close();
        },
        onError: streamController.addError,
      );

  return streamController.stream;
}
