/// HTTP+SSE client transport implementation for the MCP protocol.
///
/// This file provides an implementation of an MCP client transport
/// that communicates via HTTP for requests and Server-Sent Events (SSE)
/// for receiving server notifications, allowing for efficient streaming.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:straw_mcp/src/client/sse/event_source.dart';
import 'package:straw_mcp/src/json_rpc/codec.dart';
import 'package:straw_mcp/src/mcp/types.dart';
import 'package:straw_mcp/straw_mcp.dart';

/// Configuration options for the SSE client.
class SseClientOptions {
  /// Creates a new set of SSE client options.
  SseClientOptions({
    this.headers,
    this.logger,
    this.connectionTimeout = const Duration(seconds: 30),
    this.eventTimeout = const Duration(minutes: 5),
    this.requestTimeout = const Duration(seconds: 30),
    this.httpClient,
    this.clientId,
    this.sessionId,
    this.maxRetries = 3,
    this.retryInterval = const Duration(seconds: 3),
  });

  /// Additional headers to send with requests.
  final Map<String, String>? headers;

  /// Logger for events.
  final Logger? logger;

  /// Timeout for establishing a connection.
  final Duration connectionTimeout;

  /// Timeout for receiving events.
  final Duration eventTimeout;

  /// Timeout for HTTP requests.
  final Duration requestTimeout;

  /// HTTP client to use.
  final http.Client? httpClient;

  /// Client ID for identifying this client.
  final String? clientId;

  /// Session ID for identifying this session.
  final String? sessionId;

  /// Maximum number of retries for failed requests.
  final int maxRetries;

  /// Interval to wait between retries.
  final Duration retryInterval;
}

/// A transport implementation that uses HTTP+SSE to communicate with an MCP server.
class SseClientTransport {
  /// Creates a new SSE client transport.
  SseClientTransport(this.baseUrl, {SseClientOptions? options})
    : _headers = options?.headers ?? {},
      _logger = options?.logger ?? Logger('SseClientTransport'),
      _connectionTimeout =
          options?.connectionTimeout ?? const Duration(seconds: 30),
      _eventTimeout = options?.eventTimeout ?? const Duration(minutes: 5),
      _requestTimeout = options?.requestTimeout ?? const Duration(seconds: 30),
      _httpClient = options?.httpClient ?? http.Client(),
      _clientId =
          options?.clientId ??
          'client-${DateTime.now().millisecondsSinceEpoch}',
      _sessionId =
          options?.sessionId ??
          'session-${DateTime.now().millisecondsSinceEpoch}',
      _maxRetries = options?.maxRetries ?? 3,
      _retryInterval = options?.retryInterval ?? const Duration(seconds: 3);

  /// The base URL of the MCP server.
  final String baseUrl;

  /// Additional headers to send with requests.
  final Map<String, String> _headers;

  /// Logger for events.
  final Logger _logger;

  /// Timeout for establishing a connection.
  final Duration _connectionTimeout;

  /// Timeout for receiving events.
  final Duration _eventTimeout;

  /// Timeout for HTTP requests.
  final Duration _requestTimeout;

  /// HTTP client to use.
  final http.Client _httpClient;

  /// Client ID for identifying this client.
  final String _clientId;

  /// Session ID for identifying this session.
  final String _sessionId;

  /// Maximum number of retries for failed requests.
  final int _maxRetries;

  /// Interval to wait between retries.
  final Duration _retryInterval;

  /// JSON-RPC codec for message encoding/decoding.
  final JsonRpcCodec _codec = JsonRpcCodec();

  /// Event source for SSE events.
  EventSource? _eventSource;

  /// Event timeout timer.
  Timer? _eventTimeoutTimer;

  /// Whether the transport is started.
  bool _started = false;

  /// Whether the transport is closed.
  bool _closed = false;

  /// Whether we should attempt to reconnect if disconnected.
  bool _shouldReconnect = true;

  /// The number of consecutive connection attempts.
  int _connectionAttempts = 0;

  /// The completer for the connection.
  late Completer<void>? _connectionCompleter;

  /// Callback for message events.
  void Function(JsonRpcMessage message)? onMessage;

  /// Callback for error events.
  void Function(Error error)? onError;

  /// Callback for close events.
  void Function()? onClose;

  Future<void> start() async {
    if (_started || _closed) {
      return;
    }

    _started = true;
    _shouldReconnect = true;
    _connectionAttempts = 0;

    try {
      await _connectSse();
    } catch (e) {
      _logError('Failed to establish SSE connection: $e');
      onError?.call(Error());

      // If connection fails initially, don't set started to false
      // to allow reconnection attempts
      if (_shouldReconnect && !_closed) {
        _scheduleReconnect();
      }
    }
  }

  /// Connects to the SSE endpoint.
  Future<void> _connectSse() async {
    if (_closed) {
      return;
    }

    _connectionAttempts++;
    _connectionCompleter = Completer<void>();

    try {
      _logger.info(
        'Connecting to SSE endpoint: $baseUrl/sse (attempt $_connectionAttempts)',
      );

      // Create a specialized HTTP client for SSE
      final httpClient = HttpClient()..connectionTimeout = _connectionTimeout;

      final request = await httpClient.getUrl(Uri.parse('$baseUrl/sse'));

      // Add custom headers
      request.headers.add('Accept', 'text/event-stream');
      request.headers.add('Cache-Control', 'no-cache');
      request.headers.add('X-Client-ID', _clientId);
      request.headers.add('X-Session-ID', _sessionId);

      // Add any custom headers
      _headers.forEach((name, value) {
        request.headers.add(name, value);
      });

      // Set up a connection timeout
      final responseCompleter = Completer<HttpClientResponse>();
      final connectionTimeoutTimer = Timer(_connectionTimeout, () {
        if (!responseCompleter.isCompleted) {
          responseCompleter.completeError(
            TimeoutException(
              'Connection timeout after ${_connectionTimeout.inSeconds} seconds',
              _connectionTimeout,
            ),
          );
        }
      });

      // Send the request
      final response = await request
          .close()
          .then((r) {
            if (!responseCompleter.isCompleted) {
              responseCompleter.complete(r);
            }
            return r;
          })
          .catchError((Object error) {
            if (!responseCompleter.isCompleted) {
              responseCompleter.completeError(error);
            }

            final wrappedError = McpError(
              internalError,
              'Failed to connect to SSE endpoint: $error',
            );
            onError?.call(wrappedError);
            throw wrappedError;
          });

      // Cancel the timeout timer
      connectionTimeoutTimer.cancel();

      if (response.statusCode != 200) {
        httpClient.close();
        throw Exception(
          'Failed to connect to SSE endpoint: HTTP ${response.statusCode}',
        );
      }

      // Convert the response to lines
      final lines = parseSseLines(response);

      // Create an event source
      _eventSource = EventSource(lines);

      // Start the event timeout timer
      _resetEventTimeoutTimer();

      // Listen for events
      _eventSource!.events.listen(
        (event) {
          // Reset the event timeout timer when we receive an event
          _resetEventTimeoutTimer();

          try {
            // Ignore heartbeat events
            if (event.event == null && event.data.isEmpty) {
              return;
            }

            // Parse the JSON message
            final jsonMap = json.decode(event.data) as Map<String, dynamic>;
            final message = _codec.decodeNotification(jsonMap);

            // Notify the handler
            onMessage?.call(message);
          } catch (e) {
            _logError('Error processing SSE event: $e');
            onError?.call(Error());
          }
        },
        onDone: () {
          _logger.info('SSE connection closed by server');
          _cleanup();

          // Attempt reconnection if needed
          if (_shouldReconnect && !_closed) {
            _scheduleReconnect();
          } else {
            onClose?.call();
          }
        },
        onError: (Object e) {
          _logError('Error in SSE connection: $e');

          _cleanup();
          onError?.call(Error());

          // Attempt reconnection if needed
          if (_shouldReconnect && !_closed) {
            _scheduleReconnect();
          } else {
            onClose?.call();
          }
        },
      );

      _logger.info('SSE connection established successfully');

      // Mark connection as successful
      if (!_connectionCompleter!.isCompleted) {
        _connectionCompleter!.complete();
      }

      // Reset connection attempts
      _connectionAttempts = 0;
    } catch (e) {
      _logError('Error establishing SSE connection: $e');

      // Clean up resources
      _cleanup();

      // Complete the completer with an error
      if (!_connectionCompleter!.isCompleted) {
        _connectionCompleter!.completeError(e);
      }

      // Propagate the error
      rethrow;
    }

    return _connectionCompleter!.future;
  }

  /// Resets the event timeout timer.
  void _resetEventTimeoutTimer() {
    _eventTimeoutTimer?.cancel();
    _eventTimeoutTimer = Timer(_eventTimeout, () {
      _logError('SSE event timeout after ${_eventTimeout.inSeconds} seconds');

      // Close the current connection and try to reconnect
      _cleanup();

      // Trigger an error
      onError?.call(Error());

      // Attempt reconnection if needed
      if (_shouldReconnect && !_closed) {
        _scheduleReconnect();
      }
    });
  }

  /// Schedules a reconnection attempt.
  void _scheduleReconnect() {
    if (_closed) {
      return;
    }

    // Calculate delay with exponential backoff
    final delay = Duration(
      milliseconds:
          _retryInterval.inMilliseconds *
          (1 << _connectionAttempts.clamp(0, 10)),
    );

    _logger.info(
      'Scheduling reconnection attempt $_connectionAttempts in ${delay.inSeconds} seconds',
    );

    // Schedule reconnection
    Future.delayed(delay, () {
      if (!_closed && _shouldReconnect) {
        _connectSse().catchError((Object error) {
          _logError('Reconnection attempt failed: $error');

          // If we've reached the maximum number of retries, give up
          if (_connectionAttempts >= _maxRetries) {
            _logError('Maximum reconnection attempts reached, giving up');
            _shouldReconnect = false;
            onClose?.call();
          } else if (!_closed && _shouldReconnect) {
            // Otherwise, try again
            _scheduleReconnect();
          }
        });
      }
    });
  }

  /// Cleans up resources.
  void _cleanup() {
    // Cancel timers
    _eventTimeoutTimer?.cancel();
    _eventTimeoutTimer = null;

    // Close event source
    _eventSource?.close();
    _eventSource = null;
  }

  Future<void> send(JsonRpcMessage message) async {
    if (_closed) {
      throw Exception('Cannot send message on closed transport');
    }

    try {
      // Encode the message
      final jsonMap = _encodeMessage(message);
      final jsonData = json.encode(jsonMap);

      // Build headers
      final headers = Map<String, String>.from(_headers);
      headers['Content-Type'] = 'application/json';
      headers['X-Client-ID'] = _clientId;
      headers['X-Session-ID'] = _sessionId;

      // Retry sending the message
      http.Response? response;
      Exception? lastError;

      for (var i = 0; i < _maxRetries; i++) {
        try {
          response = await _httpClient
              .post(
                Uri.parse('$baseUrl/jsonrpc'),
                headers: headers,
                body: jsonData,
              )
              .timeout(_requestTimeout);

          // Break out of the retry loop if successful
          if (response.statusCode == 200 || response.statusCode == 204) {
            break;
          }

          _logError('HTTP error: ${response.statusCode} - ${response.body}');
          lastError = Exception('HTTP error: ${response.statusCode}');
        } on Object catch (e) {
          _logError('Request error (attempt ${i + 1}/$_maxRetries): $e');
          lastError = e is Exception ? e : Exception(e.toString());

          // Wait before retrying, if not the last attempt
          if (i < _maxRetries - 1) {
            await Future<void>.delayed(_retryInterval);
          }
        }
      }

      // If we still don't have a valid response after all retries
      if (response == null ||
          (response.statusCode != 200 && response.statusCode != 204)) {
        throw lastError ??
            Exception('Failed to send message after $_maxRetries attempts');
      }

      // If the response is a notification or has no content, we're done
      if (response.statusCode == 204 || response.body.isEmpty) {
        return;
      }

      // Otherwise, handle the response
      try {
        final jsonResponse = json.decode(response.body) as Map<String, dynamic>;

        // Check if it's an error
        if (jsonResponse.containsKey('error')) {
          _logError('Received error response: ${jsonResponse['error']}');
          onError?.call(Error());
          return;
        }

        // Process the response
        if (jsonResponse.containsKey('result')) {
          // It's a response to a request
          final messageResponse = _codec.decodeResponse(jsonResponse);
          onMessage?.call(messageResponse);
        }
      } catch (e) {
        _logError('Error decoding response: $e');
        onError?.call(Error());
      }
    } catch (e) {
      _logError('Error sending message: $e');
      onError?.call(Error());
      rethrow;
    }
  }

  /// Encodes a message for sending.
  Map<String, dynamic> _encodeMessage(JsonRpcMessage message) {
    if (message is JsonRpcRequest) {
      return _codec.encodeRequest(message);
    } else if (message is JsonRpcNotification) {
      return _codec.encodeNotification(message);
    } else if (message is JsonRpcResponse) {
      return _codec.encodeResponse(message);
    } else if (message is JsonRpcError) {
      return _codec.encodeResponse(message);
    } else {
      throw Exception('Unknown message type: ${message.runtimeType}');
    }
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }

    _logger.info('Closing SSE client transport');
    _closed = true;
    _shouldReconnect = false;

    // Cancel timers and cleanup resources
    _cleanup();

    // Close HTTP client
    _httpClient.close();

    // Notify listeners
    onClose?.call();
  }

  /// Logs an error message.
  void _logError(String message) {
    _logger.severe('SSEClientTransport: $message');
  }
}
