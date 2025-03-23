/// HTTP+SSE client implementation for the MCP protocol.
///
/// This file provides an implementation of an MCP client that communicates
/// via HTTP for requests and Server-Sent Events (SSE) for receiving server
/// notifications, allowing for efficient streaming.
library;

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:straw_mcp/src/client/client.dart';
import 'package:straw_mcp/src/client/sse/sse_client_transport.dart';
import 'package:straw_mcp/src/mcp/prompts.dart';
import 'package:straw_mcp/src/mcp/resources.dart';
import 'package:straw_mcp/src/mcp/tools.dart';
import 'package:straw_mcp/src/mcp/types.dart';

/// MCP client implementation that communicates via HTTP+SSE.
class SseClient implements Client {
  /// Creates a new SSE MCP client.
  SseClient(this.baseUrl, {SseClientOptions? options})
    : _transport = SseClientTransport(baseUrl, options: options),
      _logger = options?.logger ?? Logger('SseClient');

  /// The base URL of the MCP server.
  final String baseUrl;

  /// The underlying transport.
  final SseClientTransport _transport;

  /// Logger for events.
  final Logger _logger;

  /// Controllers for handling responses.
  final Map<dynamic, Completer<dynamic>> _responseCompleters = {};

  /// Current request ID.
  int _nextId = 1;

  /// Whether the client is connected.
  bool _isConnected = false;

  /// Stream controller for incoming notifications.
  final StreamController<JsonRpcNotification> _notificationController =
      StreamController<JsonRpcNotification>.broadcast();

  /// Connects to the MCP server.
  Future<void> connect() async {
    if (_isConnected) {
      return;
    }

    _isConnected = true;

    // Setup transport callbacks
    _transport.onMessage = _handleMessage;
    _transport.onError = _handleError;
    _transport.onClose = _handleClose;

    try {
      await _transport.start();
      _logger.info('Connected to MCP server at $baseUrl');
    } catch (e) {
      _isConnected = false;
      _logger.severe('Failed to connect to MCP server: $e');
      rethrow;
    }
  }

  /// Handles a message from the server.
  void _handleMessage(JsonRpcMessage message) {
    try {
      if (message is JsonRpcNotification) {
        // Handle notification
        _notificationController.add(message);
      } else if (message is JsonRpcResponse) {
        // Handle response
        final completer = _responseCompleters[message.id];
        if (completer != null) {
          _responseCompleters.remove(message.id);
          completer.complete(message.result);
        } else {
          _logger.warning('Received response with unknown ID: ${message.id}');
        }
      } else if (message is JsonRpcError) {
        // Handle error
        final completer = _responseCompleters[message.id];
        if (completer != null) {
          _responseCompleters.remove(message.id);
          completer.completeError(
            McpError(message.error.code, message.error.message),
          );
        } else {
          _logger.warning('Received error with unknown ID: ${message.id}');
        }
      } else {
        _logger.warning(
          'Received message of unknown type: ${message.runtimeType}',
        );
      }
    } catch (e) {
      _logger.severe('Error handling message: $e');
    }
  }

  /// Handles an error from the transport.
  void _handleError(Error error) {
    _logger.severe('Transport error: $error');

    // If transport error occurs, all pending requests might be affected
    if (_responseCompleters.isNotEmpty) {
      _logger.warning(
        'Completing ${_responseCompleters.length} pending requests with error',
      );
      for (final completer in _responseCompleters.values) {
        if (!completer.isCompleted) {
          completer.completeError(
            McpError(internalError, 'Transport error: $error'),
          );
        }
      }
      _responseCompleters.clear();
    }
  }

  /// Handles transport close.
  void _handleClose() {
    if (!_isConnected) {
      return;
    }

    _logger.info('Transport closed');
    _isConnected = false;

    // Complete all pending requests with an error
    for (final completer in _responseCompleters.values) {
      if (!completer.isCompleted) {
        completer.completeError(McpError(internalError, 'Transport closed'));
      }
    }
    _responseCompleters.clear();

    // Don't close the notification controller here as we might
    // reconnect later and continue using the same controller
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

    try {
      // Send request
      await _transport.send(request);

      // Wait for response
      return await completer.future as T;
    } catch (e) {
      // Remove from pending requests
      _responseCompleters.remove(id);

      // Log and propagate error
      _logger.severe('Error sending request: $e');

      if (e is McpError) {
        rethrow;
      } else {
        throw McpError(internalError, 'Error sending request: $e');
      }
    }
  }

  @override
  Future<void> close() async {
    if (!_isConnected) {
      return;
    }

    _logger.info('Closing MCP client');
    _isConnected = false;

    try {
      // Send cancellation notifications for pending requests
      if (_responseCompleters.isNotEmpty) {
        _logger.info(
          'Cancelling ${_responseCompleters.length} pending requests',
        );

        // Complete all pending requests with an error
        for (final entry in _responseCompleters.entries) {
          if (!entry.value.isCompleted) {
            entry.value.completeError(McpError(internalError, 'Client closed'));
          }
        }
        _responseCompleters.clear();
      }

      // Close the transport
      await _transport.close();

      // Close notification controller
      await _notificationController.close();

      _logger.info('MCP client closed successfully');
    } catch (e) {
      _logger.severe('Error during MCP client shutdown: $e');
      // Continue with closing even if there's an error
    }
  }

  @override
  void onNotification(void Function(JsonRpcNotification notification) handler) {
    _notificationController.stream.listen(handler);
  }

  // Client interface implementation

  @override
  Future<InitializeResult> initialize(InitializeRequest request) async {
    final result = await _sendRequest<Map<String, dynamic>>(
      'initialize',
      request.params,
    );
    return InitializeResult.fromJson(result);
  }

  @override
  Future<void> ping() async {
    await _sendRequest<Map<String, dynamic>>('ping', {});
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
  Future<ReadResourceResult> readResource(ReadResourceRequest request) async {
    final result = await _sendRequest<Map<String, dynamic>>(
      'resources/read',
      request.params,
    );
    return ReadResourceResult.fromJson(result);
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

  @override
  Future<ListPromptsResult> listPrompts(ListPromptsRequest request) async {
    final result = await _sendRequest<Map<String, dynamic>>(
      'prompts/list',
      request.params,
    );
    return ListPromptsResult.fromJson(result);
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
  Future<ListToolsResult> listTools(ListToolsRequest request) async {
    final result = await _sendRequest<Map<String, dynamic>>(
      'tools/list',
      request.params,
    );
    return ListToolsResult.fromJson(result);
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
  Future<void> setLevel(SetLevelRequest request) async {
    await _sendRequest<Map<String, dynamic>>(
      'logging/setLevel',
      request.params,
    );
  }

  @override
  Future<CompleteResult> complete(CompleteRequest request) async {
    final result = await _sendRequest<Map<String, dynamic>>(
      'completion/complete',
      request.params,
    );
    return CompleteResult.fromJson(result);
  }
}
