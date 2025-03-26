/// Stream-based client implementation for the MCP protocol.
///
/// This file provides an implementation of an MCP client that communicates
/// via input and output streams, allowing for flexible integration with
/// various transport mechanisms including standard input/output, sockets,
/// and more.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:straw_mcp/src/client/client.dart';
import 'package:straw_mcp/src/json_rpc/codec.dart';
import 'package:straw_mcp/src/mcp/prompts.dart';
import 'package:straw_mcp/src/mcp/resources.dart';
import 'package:straw_mcp/src/mcp/tools.dart';
import 'package:straw_mcp/src/mcp/types.dart';

/// Configuration options for stream client.
class StreamClientOptions {
  /// Creates a new set of stream client options.
  ///
  /// - [logger]: Optional logger for error messages
  /// - [inputStream]: Optional input stream to read from
  /// - [outputSink]: Optional output sink to write to
  StreamClientOptions({
    required this.inputStream,
    required this.outputSink,
    this.logger,
  });

  /// Creates a new options using standard input/output streams.
  factory StreamClientOptions.stdio({Logger? logger}) {
    return StreamClientOptions(
      logger: logger,
      inputStream: stdin.asBroadcastStream(),
      outputSink: stdout,
    );
  }

  /// Logger for error messages.
  final Logger? logger;

  /// Input stream to read from (defaults to stdin).
  final Stream<List<int>> inputStream;

  /// Output sink to write to (defaults to stdout).
  final IOSink outputSink;
}

/// MCP client implementation that communicates via input/output streams.
class StreamClient implements Client {
  /// Creates a new stream-based MCP client.
  ///
  /// - [options]: Optional configuration options for the client
  StreamClient({required StreamClientOptions options})
    : logger = options.logger,
      _inputStream = options.inputStream,
      _outputSink = options.outputSink;

  /// Creates a new client using standard input/output streams.
  ///
  /// This is a convenience constructor equivalent to using the default
  /// options with stdin/stdout.
  ///
  /// - [logger]: Optional logger for error messages
  factory StreamClient.stdio({Logger? logger}) {
    return StreamClient(options: StreamClientOptions.stdio(logger: logger));
  }

  /// Logger for error messages.
  final Logger? logger;

  /// Input stream to read from.
  ///
  /// Defaults to stdin if not provided in options.
  final Stream<List<int>> _inputStream;

  /// Output sink to write to.
  ///
  /// Defaults to stdout if not provided in options.
  final IOSink _outputSink;

  /// JSON-RPC codec for message encoding/decoding.
  ///
  /// Used to encode/decode messages between JSON-RPC and Dart objects.
  final JsonRpcCodec _codec = JsonRpcCodec();

  /// Controllers for handling responses.
  ///
  /// Maps request IDs to completers that will be resolved when
  /// the corresponding response is received.
  final Map<dynamic, Completer<dynamic>> _responseCompleters = {};

  /// Current request ID.
  int _nextId = 1;

  /// Whether the client is connected.
  bool _isConnected = false;

  /// Stream controller for incoming notifications.
  ///
  /// Broadcasts notifications from the server to registered handlers.
  final StreamController<JsonRpcNotification> _notificationController =
      StreamController<JsonRpcNotification>.broadcast();

  /// Subscription for input stream.
  StreamSubscription<String>? _inputSubscription;

  /// Connects to the MCP server.
  Future<void> connect() async {
    if (_isConnected) {
      return;
    }

    _isConnected = true;

    // Set up line-based stdin reader
    final lineReader = _inputStream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    // Start listening for responses
    _inputSubscription = lineReader.listen(
      _handleResponse,
      onError: (Object error) {
        _logError('Error reading from input: $error');
        _isConnected = false;
      },
      onDone: () {
        _isConnected = false;
      },
    );
  }

  /// Handles a response from the server.
  void _handleResponse(String line) {
    try {
      final jsonMap = json.decode(line) as Map<String, dynamic>;

      // Check if it's a notification
      if (!jsonMap.containsKey('id')) {
        final notification = _codec.decodeNotification(jsonMap);
        _notificationController.add(notification);
        return;
      }

      // Handle response or error
      final id = jsonMap['id'];
      final completer = _responseCompleters[id];

      if (completer == null) {
        _logError('No pending request for ID: $id');
        return;
      }

      _responseCompleters.remove(id);

      if (jsonMap.containsKey('error')) {
        final error = _codec.decodeResponse(jsonMap) as JsonRpcError;
        completer.completeError(
          McpError(error.error.code, error.error.message),
        );
      } else {
        final response = _codec.decodeResponse(jsonMap) as JsonRpcResponse;
        completer.complete(response.result);
      }
    } on FormatException catch (e) {
      _logError('Error handling response: $e');
    }
  }

  /// Sends a request to the server and waits for a response.
  Future<T> _sendRequest<T>(String method, Map<String, dynamic> params) async {
    if (!_isConnected) {
      await connect();
    }

    final id = _nextId++;
    final request = JsonRpcRequest(
      jsonRpcVersion,
      id,
      params,
      Request(method, params),
    );

    final completer = Completer<dynamic>();
    _responseCompleters[id] = completer;

    // Send request
    _writeRequest(request);

    // Wait for response
    return await completer.future as T;
  }

  /// Writes a request to the output stream.
  void _writeRequest(JsonRpcRequest request) {
    try {
      final jsonMap = _codec.encodeRequest(request);
      _outputSink.writeln(json.encode(jsonMap));
    } catch (e) {
      _logError('Error writing request: $e');

      // Complete the pending request with an error
      final completer = _responseCompleters[request.id];
      if (completer != null) {
        _responseCompleters.remove(request.id);
        completer.completeError(
          McpError(internalError, 'Error writing request: $e'),
        );
      }
    }
  }

  /// Logs an error message.
  void _logError(String message) {
    logger?.severe(message);
  }

  @override
  Future<void> close() async {
    if (!_isConnected) {
      // Do nothing if already closed
      return;
    }

    _logError('Closing MCP client connection');
    _isConnected = false;

    // Close all communications
    try {
      // Cancel input subscription
      await _inputSubscription?.cancel();
      _inputSubscription = null;

      // Send cancel notifications (if there are ongoing requests)
      if (_responseCompleters.isNotEmpty) {
        try {
          // Send cancel notifications for all pending requests
          for (final id in List<dynamic>.from(_responseCompleters.keys)) {
            final cancelNotification = JsonRpcNotification(
              version: jsonRpcVersion,
              method: 'notifications/cancelled',
              params: {'requestId': id, 'reason': 'Client closing'},
            );
            try {
              final jsonMap = _codec.encodeNotification(cancelNotification);
              _outputSink.writeln(json.encode(jsonMap));
            } catch (e) {
              _logError('Error sending cancel notification: $e');
            }
          }

          // Give time to flush the output buffer
          await Future<void>.delayed(const Duration(milliseconds: 50));
        } catch (e) {
          _logError('Error sending cancellation notifications: $e');
        }
      }

      // Complete pending requests with an error
      for (final completer in _responseCompleters.values) {
        completer.completeError(McpError(internalError, 'Client closed'));
      }
      _responseCompleters.clear();

      // Close notification controller
      await _notificationController.close();

      // Log final output
      _logError('MCP client connection closed successfully');
    } catch (e) {
      _logError('Error during MCP client shutdown: $e');
      // Continue and release resources as much as possible even if there is an error
    }
  }

  @override
  void onNotification(void Function(JsonRpcNotification notification) handler) {
    _notificationController.stream.listen(handler);
  }

  // Client interface implementation

  @override
  Future<InitializeResult> initialize(InitializeRequest request) async {
    // Extract parameters directly from InitializeRequest
    final params = {
      'protocolVersion': request.params['protocolVersion'],
      'capabilities': request.params['capabilities'],
      'clientInfo': request.params['clientInfo'],
    };
    final result = await _sendRequest<Map<String, dynamic>>(
      'initialize',
      params,
    );
    return InitializeResult.fromJson(result);
  }

  @override
  Future<void> ping() async {
    await _sendRequest<Map<String, dynamic>>('ping', {});
  }

  @override
  Future<CompleteResult> complete(CompleteRequest request) async {
    final result = await _sendRequest<Map<String, dynamic>>(
      'completion/complete',
      request.params,
    );
    return CompleteResult.fromJson(result);
  }

  @override
  Future<CallToolResult> callTool(CallToolRequest request) async {
    final result = await _sendRequest<Map<String, dynamic>>(
      'tools/call',
      request.params,
    );
    return CallToolResult.fromJson(result);
  }

  @override
  Future<GetPromptResult> getPrompt(GetPromptRequest request) async {
    final result = await _sendRequest<Map<String, dynamic>>(
      'prompts/get',
      request.params,
    );
    return GetPromptResult.fromJson(result);
  }

  @override
  Future<ListPromptsResult> listPrompts(ListPromptsRequest request) async {
    final result = await _sendRequest<Map<String, dynamic>>(
      'prompts/list',
      request.params,
    );
    return ListPromptsResult.fromJson(result);
  }

  @override
  Future<ListResourcesResult> listResources(
    ListResourcesRequest request,
  ) async {
    final result = await _sendRequest<Map<String, dynamic>>(
      'resources/list',
      request.params,
    );
    return ListResourcesResult.fromJson(result);
  }

  @override
  Future<ListResourceTemplatesResult> listResourceTemplates(
    ListResourceTemplatesRequest request,
  ) async {
    final result = await _sendRequest<Map<String, dynamic>>(
      'resources/templates/list',
      request.params,
    );
    return ListResourceTemplatesResult.fromJson(result);
  }

  @override
  Future<ListToolsResult> listTools(ListToolsRequest request) async {
    final result = await _sendRequest<Map<String, dynamic>>(
      'tools/list',
      request.params,
    );
    return ListToolsResult.fromJson(result);
  }

  @override
  Future<ReadResourceResult> readResource(ReadResourceRequest request) async {
    final result = await _sendRequest<Map<String, dynamic>>(
      'resources/read',
      request.params,
    );
    return ReadResourceResult.fromJson(result);
  }

  @override
  Future<void> setLevel(SetLevelRequest request) async {
    await _sendRequest<Map<String, dynamic>>(
      'logging/setLevel',
      request.params,
    );
  }

  @override
  Future<void> subscribe(SubscribeRequest request) async {
    await _sendRequest<Map<String, dynamic>>(
      'resources/subscribe',
      request.params,
    );
  }

  @override
  Future<void> unsubscribe(UnsubscribeRequest request) async {
    await _sendRequest<Map<String, dynamic>>(
      'resources/unsubscribe',
      request.params,
    );
  }
}
