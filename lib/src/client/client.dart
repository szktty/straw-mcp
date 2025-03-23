import 'dart:async';

import 'package:straw_mcp/src/mcp/prompts.dart';
import 'package:straw_mcp/src/mcp/resources.dart';
import 'package:straw_mcp/src/mcp/tools.dart';
import 'package:straw_mcp/src/mcp/types.dart';

/// Error class for MCP client errors.
class McpError extends Error {
  /// Creates a new MCP error.
  ///
  /// - [code]: Numeric error code defining the error type
  /// - [message]: Human-readable error message
  McpError(this.code, this.message);

  /// Error code.
  final int code;

  /// Error message.
  final String message;

  @override
  String toString() => 'McpError($code): $message';
}

/// Client interface for the Model Context Protocol (MCP).
///
/// Provides methods for communicating with an MCP server.
abstract class Client {
  /// Sends an initialize request to the server.
  Future<InitializeResult> initialize(InitializeRequest request);

  /// Checks if the server is alive with a ping request.
  Future<void> ping();

  /// Lists available resources from the server.
  Future<ListResourcesResult> listResources(ListResourcesRequest request);

  /// Lists available resource templates from the server.
  Future<ListResourceTemplatesResult> listResourceTemplates(
    ListResourceTemplatesRequest request,
  );

  /// Reads a specific resource from the server.
  Future<ReadResourceResult> readResource(ReadResourceRequest request);

  /// Subscribes to updates for a specific resource.
  Future<void> subscribe(SubscribeRequest request);

  /// Unsubscribes from updates for a specific resource.
  Future<void> unsubscribe(UnsubscribeRequest request);

  /// Lists available prompts from the server.
  Future<ListPromptsResult> listPrompts(ListPromptsRequest request);

  /// Gets a specific prompt from the server.
  Future<GetPromptResult> getPrompt(GetPromptRequest request);

  /// Lists available tools from the server.
  Future<ListToolsResult> listTools(ListToolsRequest request);

  /// Calls a specific tool on the server.
  Future<CallToolResult> callTool(CallToolRequest request);

  /// Sets the logging level on the server.
  Future<void> setLevel(SetLevelRequest request);

  /// Requests completion options for a given reference and argument.
  Future<CompleteResult> complete(CompleteRequest request);

  /// Closes the client connection.
  Future<void> close();

  /// Registers a handler for notifications from the server.
  ///
  /// The provided [handler] function will be called whenever a notification
  /// is received from the server. This is used to handle events like resource
  /// updates, tool list changes, and progress notifications.
  void onNotification(void Function(JsonRpcNotification notification) handler);
}

/// Request for setting the logging level on the server.
///
/// This allows clients to control the detail level of log messages
/// sent from the server via logging notifications.
class SetLevelRequest extends Request {
  SetLevelRequest(LoggingLevel level)
    : super('logging/setLevel', {'level': level.toString()});
}

/// Types of logging levels in the MCP protocol.
///
/// These levels follow the severity conventions in syslog (RFC 5424).
enum LoggingLevel {
  debug,
  info,
  notice,
  warning,
  error,
  critical,
  alert,
  emergency;

  @override
  String toString() => name;
}

/// Request for getting completion options.
class CompleteRequest extends Request {
  CompleteRequest({
    required Object ref,
    required String argumentName,
    required String argumentValue,
  }) : super('completion/complete', {
         'ref':
             ref is PromptReference || ref is ResourceReference
                 ? ref
                 : throw ArgumentError(
                   'ref must be a PromptReference or ResourceReference',
                 ),
         'argument': {'name': argumentName, 'value': argumentValue},
       });
}

/// Reference to a prompt for completion requests.
///
/// Used in completion requests to identify which prompt
/// the completion is being requested for.
class PromptReference {
  PromptReference(this.name);

  final String type = 'prompt';
  final String name;

  Map<String, dynamic> toJson() {
    return {'type': type, 'name': name};
  }
}

/// Reference to a resource for completion requests.
///
/// Used in completion requests to identify which resource
/// the completion is being requested for.
class ResourceReference {
  ResourceReference(this.uri);

  final String type = 'resource';
  final String uri;

  Map<String, dynamic> toJson() {
    return {'type': type, 'uri': uri};
  }
}

/// Result of the complete request.
class CompleteResult extends Result {
  CompleteResult({required this.completion, super.meta});

  /// Creates a complete result from a JSON map.
  factory CompleteResult.fromJson(Map<String, dynamic> json) {
    return CompleteResult(
      completion: CompletionValues.fromJson(
        json['completion'] as Map<String, dynamic>,
      ),
      meta: json['_meta'] as Map<String, dynamic>?,
    );
  }

  final CompletionValues completion;

  @override
  Map<String, dynamic> toJson() {
    final result = super.toJson();

    result['completion'] = completion.toJson();

    return result;
  }
}

/// Values for completion options returned by the server.
///
/// Contains the suggested completions along with metadata
/// about whether there are more options available.
class CompletionValues {
  CompletionValues({required this.values, this.total, this.hasMore = false});

  /// Creates completion values from a JSON map.
  factory CompletionValues.fromJson(Map<String, dynamic> json) {
    return CompletionValues(
      values: (json['values'] as List).cast<String>(),
      total: json['total'] as int?,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }

  final List<String> values;
  final int? total;
  final bool hasMore;

  /// Converts completion values to a JSON map.
  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{'values': values};

    if (total != null) {
      result['total'] = total;
    }

    if (hasMore) {
      result['hasMore'] = true;
    }

    return result;
  }
}
