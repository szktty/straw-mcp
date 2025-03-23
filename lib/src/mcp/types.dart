/// Core types and interfaces for the Model Context Protocol (MCP).
///
/// This file defines the fundamental types used in the MCP protocol, including
/// JSON-RPC messages, requests, responses, and MCP-specific types.
library;

/// Latest version of the MCP protocol.
const String latestProtocolVersion = '2024-11-05';

/// JSON-RPC version used by MCP.
const String jsonRpcVersion = '2.0';

/// Standard JSON-RPC error codes
const int parseError = -32700;
const int invalidRequest = -32600;
const int methodNotFound = -32601;
const int invalidParams = -32602;
const int internalError = -32603;

/// Base class for all JSON-RPC messages in the MCP protocol.
abstract class JsonRpcMessage {}

/// Type for request IDs, which can be strings or integers.
typedef RequestId = Object;

/// Type for progress tokens used in progress notifications.
typedef ProgressToken = Object;

/// Type for pagination cursors.
typedef Cursor = String;

/// Type for generic parameter maps.
typedef Params = Map<String, dynamic>;

/// Base class for all MCP requests.
class Request {
  Request(this.method, this.params);

  final String method;
  final Map<String, dynamic> params;
}

/// Base class for all MCP notifications.
class Notification {
  Notification(this.method, this.params);

  final String method;
  final NotificationParams params;
}

/// Parameters for MCP notifications.
class NotificationParams {
  NotificationParams({this.meta, Map<String, dynamic>? additionalFields})
    : additionalFields = additionalFields ?? {};

  /// Creates a NotificationParams instance from JSON.
  factory NotificationParams.fromJson(Map<String, dynamic> json) {
    final params = NotificationParams();

    json.forEach((key, value) {
      if (key == '_meta' && value is Map<String, dynamic>) {
        params.meta = value;
      } else {
        params.additionalFields[key] = value;
      }
    });

    return params;
  }

  Map<String, dynamic>? meta;
  Map<String, dynamic> additionalFields;

  /// Converts the notification parameters to JSON.
  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};
    if (meta != null) {
      result['_meta'] = meta;
    }
    additionalFields.forEach((key, value) {
      if (key != '_meta') {
        result[key] = value;
      }
    });
    return result;
  }
}

/// Base class for all MCP results.
class Result {
  Result({this.meta});

  Map<String, dynamic>? meta;

  /// Converts the result to JSON.
  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};
    if (meta != null) {
      result['_meta'] = meta;
    }
    return result;
  }
}

/// Represents a JSON-RPC request.
class JsonRpcRequest implements JsonRpcMessage {
  JsonRpcRequest(this.jsonrpc, this.id, this.params, this.request);

  /// Creates a JSON-RPC request from a JSON map.
  factory JsonRpcRequest.fromJson(Map<String, dynamic> json) {
    final req = Request(
      json['method'] as String,
      json['params'] as Map<String, dynamic>? ?? {},
    );

    return JsonRpcRequest(
      json['jsonrpc'] as String,
      json['id'] as RequestId,
      json['params'],
      req,
    );
  }

  final String jsonrpc;
  final RequestId id;
  final dynamic params;
  final Request request;

  /// Converts the request to a JSON map.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'jsonrpc': jsonrpc,
      'id': id,
      'method': request.method,
      'params': params,
    };
  }
}

/// Represents a JSON-RPC notification.
class JsonRpcNotification implements JsonRpcMessage {
  JsonRpcNotification(this.jsonrpc, this.notification);

  /// Creates a JSON-RPC notification from a JSON map.
  factory JsonRpcNotification.fromJson(Map<String, dynamic> json) {
    final notif = Notification(
      json['method'] as String,
      NotificationParams.fromJson(
        json['params'] as Map<String, dynamic>? ?? {},
      ),
    );

    return JsonRpcNotification(json['jsonrpc'] as String, notif);
  }

  final String jsonrpc;
  final Notification notification;

  /// Converts the notification to a JSON map.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'jsonrpc': jsonrpc,
      'method': notification.method,
      'params': notification.params.toJson(),
    };
  }
}

/// Represents a successful JSON-RPC response.
class JsonRpcResponse implements JsonRpcMessage {
  JsonRpcResponse(this.jsonrpc, this.id, this.result);

  /// Creates a JSON-RPC response from a JSON map.
  factory JsonRpcResponse.fromJson(Map<String, dynamic> json) {
    return JsonRpcResponse(
      json['jsonrpc'] as String,
      json['id'] as RequestId,
      json['result'],
    );
  }

  final String jsonrpc;
  final RequestId id;
  final dynamic result;

  /// Converts the response to a JSON map.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{'jsonrpc': jsonrpc, 'id': id, 'result': result};
  }
}

/// Represents an error JSON-RPC response.
class JsonRpcError implements JsonRpcMessage {
  JsonRpcError(this.jsonrpc, this.id, this.error);

  /// Creates a JSON-RPC error from a JSON map.
  factory JsonRpcError.fromJson(Map<String, dynamic> json) {
    final errorJson = json['error'] as Map<String, dynamic>;

    return JsonRpcError(
      json['jsonrpc'] as String,
      json['id'] as RequestId?,
      JsonRpcErrorDetail(
        code: errorJson['code'] as int,
        message: errorJson['message'] as String,
        data: errorJson['data'],
      ),
    );
  }

  final String jsonrpc;
  final RequestId? id;
  final JsonRpcErrorDetail error;

  /// Converts the error to a JSON map.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'jsonrpc': jsonrpc,
      'id': id,
      'error': error.toJson(),
    };
  }
}

/// Detailed error information for JSON-RPC errors.
class JsonRpcErrorDetail {
  JsonRpcErrorDetail({required this.code, required this.message, this.data});

  final int code;
  final String message;
  final dynamic data;

  /// Converts the error detail to a JSON map.
  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{'code': code, 'message': message};

    if (data != null) {
      result['data'] = data;
    }

    return result;
  }
}

/// Represents an empty result for requests that don't return data.
class EmptyResult extends Result {}

/// Notification for cancelling a previous request.
class CancelledNotification extends Notification {
  CancelledNotification(RequestId requestId, {String? reason})
    : super(
        'cancelled',
        NotificationParams(
          additionalFields: {
            'requestId': requestId,
            if (reason != null) 'reason': reason,
          },
        ),
      );
}

/// Client capabilities for the MCP protocol.
class ClientCapabilities {
  ClientCapabilities({this.experimental, this.roots, this.sampling});

  /// Creates client capabilities from a JSON map.
  factory ClientCapabilities.fromJson(Map<String, dynamic> json) {
    return ClientCapabilities(
      experimental: json['experimental'] as Map<String, dynamic>?,
      roots:
          json['roots'] != null
              ? RootsCapabilities(
                listChanged:
                    (json['roots'] as Map<String, dynamic>)['listChanged']
                        as bool? ??
                    false,
              )
              : null,
      sampling: json['sampling'] != null ? SamplingCapabilities() : null,
    );
  }

  Map<String, dynamic>? experimental;
  RootsCapabilities? roots;
  SamplingCapabilities? sampling;

  /// Converts the client capabilities to a JSON map.
  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};

    if (experimental != null) {
      result['experimental'] = experimental;
    }

    if (roots != null) {
      result['roots'] = {'listChanged': roots!.listChanged};
    }

    if (sampling != null) {
      result['sampling'] = <String, dynamic>{};
    }

    return result;
  }
}

/// Capabilities related to root resources.
class RootsCapabilities {
  RootsCapabilities({this.listChanged = false});

  final bool listChanged;
}

/// Capabilities related to LLM sampling.
class SamplingCapabilities {
  SamplingCapabilities();
}

/// Server capabilities for the MCP protocol.
class ServerCapabilities {
  ServerCapabilities({
    this.experimental,
    this.logging = false,
    this.prompts,
    this.resources,
    this.tools,
  });

  /// Creates server capabilities from a JSON map.
  factory ServerCapabilities.fromJson(Map<String, dynamic> json) {
    return ServerCapabilities(
      experimental: json['experimental'] as Map<String, dynamic>?,
      logging: json['logging'] != null,
      prompts:
          json['prompts'] != null
              ? PromptCapabilities(
                listChanged:
                    (json['prompts'] as Map<String, dynamic>)['listChanged']
                        as bool? ??
                    false,
              )
              : null,
      resources:
          json['resources'] != null
              ? ResourceCapabilities(
                subscribe:
                    (json['resources'] as Map<String, dynamic>)['subscribe']
                        as bool? ??
                    false,
                listChanged:
                    (json['resources'] as Map<String, dynamic>)['listChanged']
                        as bool? ??
                    false,
              )
              : null,
      tools:
          json['tools'] != null
              ? ToolCapabilities(
                listChanged:
                    (json['tools'] as Map<String, dynamic>)['listChanged']
                        as bool? ??
                    false,
              )
              : null,
    );
  }

  Map<String, dynamic>? experimental;
  bool logging;
  PromptCapabilities? prompts;
  ResourceCapabilities? resources;
  ToolCapabilities? tools;

  /// Converts the server capabilities to a JSON map.
  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};

    if (experimental != null) {
      result['experimental'] = experimental;
    }

    if (logging) {
      result['logging'] = <String, dynamic>{};
    }

    if (prompts != null) {
      result['prompts'] = {'listChanged': prompts!.listChanged};
    }

    if (resources != null) {
      result['resources'] = {
        'subscribe': resources!.subscribe,
        'listChanged': resources!.listChanged,
      };
    }

    if (tools != null) {
      result['tools'] = {'listChanged': tools!.listChanged};
    }

    return result;
  }
}

/// Capabilities related to prompts.
class PromptCapabilities {
  PromptCapabilities({this.listChanged = false});

  final bool listChanged;
}

/// Capabilities related to resources.
class ResourceCapabilities {
  ResourceCapabilities({this.subscribe = false, this.listChanged = false});

  final bool subscribe;
  final bool listChanged;
}

/// Capabilities related to tools.
class ToolCapabilities {
  ToolCapabilities({this.listChanged = false});

  final bool listChanged;
}

/// Information about an MCP implementation.
class Implementation {
  Implementation({required this.name, required this.version});

  /// Creates implementation info from a JSON map.
  factory Implementation.fromJson(Map<String, dynamic> json) {
    return Implementation(
      name: json['name'] as String,
      version: json['version'] as String,
    );
  }

  final String name;
  final String version;

  /// Converts the implementation info to a JSON map.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{'name': name, 'version': version};
  }
}

/// Request for initializing the MCP protocol.
class InitializeRequest extends Request {
  InitializeRequest({
    required String protocolVersion,
    required ClientCapabilities capabilities,
    required Implementation clientInfo,
  }) : super('initialize', {
         'protocolVersion': protocolVersion,
         'capabilities': capabilities.toJson(),
         'clientInfo': clientInfo.toJson(),
       });

  /// Creates an initialize request from a JSON map.
  factory InitializeRequest.fromJson(Map<String, dynamic> json) {
    final params = json['params'] as Map<String, dynamic>;

    return InitializeRequest(
      protocolVersion: params['protocolVersion'] as String,
      capabilities: ClientCapabilities.fromJson(
        params['capabilities'] as Map<String, dynamic>,
      ),
      clientInfo: Implementation.fromJson(
        params['clientInfo'] as Map<String, dynamic>,
      ),
    );
  }
}

/// Result of the initialize request.
class InitializeResult extends Result {
  InitializeResult({
    required this.protocolVersion,
    required this.capabilities,
    required this.serverInfo,
    this.instructions,
    super.meta,
  });

  /// Creates an initialize result from a JSON map.
  factory InitializeResult.fromJson(Map<String, dynamic> json) {
    return InitializeResult(
      protocolVersion: json['protocolVersion'] as String,
      capabilities: ServerCapabilities.fromJson(
        json['capabilities'] as Map<String, dynamic>,
      ),
      serverInfo: Implementation.fromJson(
        json['serverInfo'] as Map<String, dynamic>,
      ),
      instructions: json['instructions'] as String?,
      meta: json['_meta'] as Map<String, dynamic>?,
    );
  }

  final String protocolVersion;
  final ServerCapabilities capabilities;
  final Implementation serverInfo;
  final String? instructions;

  @override
  Map<String, dynamic> toJson() {
    final result = super.toJson();

    result['protocolVersion'] = protocolVersion;
    result['capabilities'] = capabilities.toJson();
    result['serverInfo'] = serverInfo.toJson();

    if (instructions != null) {
      result['instructions'] = instructions;
    }

    return result;
  }
}

/// Notification sent after initialization is complete.
class InitializedNotification extends Notification {
  InitializedNotification() : super('initialized', NotificationParams());
}

/// Request for pinging the server.
class PingRequest extends Request {
  PingRequest() : super('ping', {});
}

/// Notification for reporting progress of a long-running operation.
class ProgressNotification extends Notification {
  ProgressNotification({
    required ProgressToken progressToken,
    required double progress,
    double? total,
  }) : super(
         'progress',
         NotificationParams(
           additionalFields: {
             'progressToken': progressToken,
             'progress': progress,
             if (total != null) 'total': total,
           },
         ),
       );
}

/// Base class for paginated requests.
class PaginatedRequest extends Request {
  PaginatedRequest(String method, {Cursor? cursor})
    : super(method, {if (cursor != null) 'cursor': cursor});
}

/// Base class for paginated results.
class PaginatedResult extends Result {
  PaginatedResult({this.nextCursor, super.meta});

  final Cursor? nextCursor;

  @override
  Map<String, dynamic> toJson() {
    final result = super.toJson();

    if (nextCursor != null) {
      result['nextCursor'] = nextCursor;
    }

    return result;
  }
}

// More type definitions would go here...
