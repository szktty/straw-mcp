import 'package:straw_mcp/src/json/jsonable.dart';

/// Latest version of the MCP protocol.
const String latestProtocolVersion = '2024-11-05';

/// JSON-RPC version used by MCP.
const String jsonRpcVersion = '2.0';

/// Base class for all JSON-RPC messages in the MCP protocol.
abstract class JsonRpcMessage implements Jsonable {}

/// Type for request IDs, which can be strings or integers.
typedef RequestId = Object;

/// Type for progress tokens used in progress notifications.
typedef ProgressToken = Object;

/// Type for pagination cursors.
typedef Cursor = String;

/// Type for generic parameter maps.
typedef Params = Map<String, dynamic>;

/// Base class for all MCP requests.
class Request implements Jsonable {
  Request({
    required this.method,
    this.params = const {},
  });

  final String method;
  final Map<String, dynamic> params;

  /// Converts the request to JSON.
  @override
  Map<String, dynamic> toJson() {
    return {
      'method': method,
      'params': params,
    };
  }
}

/// Base class for all MCP notifications.
class Notification implements Jsonable {
  Notification({
    required this.method,
    this.params,
  });

  final String method;
  final dynamic params;

  /// Converts the notification to JSON.
  @override
  Map<String, dynamic> toJson() {
    return {
      'method': method,
      'params': params,
    };
  }
}

/// Base class for all MCP results.
class Result implements Jsonable {
  Result({this.meta});

  Map<String, dynamic>? meta;

  /// Converts the result to JSON.
  @override
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
  JsonRpcRequest({
    required this.jsonrpc,
    required this.id,
    required this.params,
    required this.request,
  });

  /// Creates a JSON-RPC request from a JSON map.
  factory JsonRpcRequest.fromJson(Map<String, dynamic> json) {
    final req = Request(
      method: json['method'] as String,
      params: json['params'] as Map<String, dynamic>? ?? {},
    );

    return JsonRpcRequest(
      jsonrpc: json['jsonrpc'] as String,
      id: json['id'] as RequestId,
      params: json['params'],
      request: req,
    );
  }

  final String jsonrpc;
  final RequestId id;
  final dynamic params;
  final Request request;

  /// Converts the request to a JSON map.
  @override
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
  JsonRpcNotification({
    required this.version,
    required this.method,
    this.params,
  });

  /// Creates a JSON-RPC notification from a JSON map.
  factory JsonRpcNotification.fromJson(Map<String, dynamic> json) {
    final method = json['method'] as String;
    final params = json['params'] as Map<String, dynamic>? ?? {};
    return JsonRpcNotification(
      version: json['jsonrpc'] as String,
      method: method,
      params: params,
    );
  }

  final String version;
  final String method;
  final dynamic params;

  /// Converts the notification to a JSON map.
  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'jsonrpc': version,
      'method': method,
      'params': params,
    };
  }
}

/// Represents a successful JSON-RPC response.
class JsonRpcResponse implements JsonRpcMessage {
  JsonRpcResponse({
    required this.jsonrpc,
    required this.id,
    required this.result,
  });

  /// Creates a JSON-RPC response from a JSON map.
  factory JsonRpcResponse.fromJson(Map<String, dynamic> json) {
    return JsonRpcResponse(
      jsonrpc: json['jsonrpc'] as String,
      id: json['id'] as RequestId,
      result: json['result'],
    );
  }

  final String jsonrpc;
  final RequestId id;
  final dynamic result;

  /// Converts the response to a JSON map.
  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{'jsonrpc': jsonrpc, 'id': id, 'result': result};
  }
}

/// Represents an error JSON-RPC response.
class JsonRpcError implements JsonRpcMessage {
  JsonRpcError({
    required this.jsonrpc,
    required this.id,
    required this.error,
  });

  /// Creates a JSON-RPC error from a JSON map.
  factory JsonRpcError.fromJson(Map<String, dynamic> json) {
    final errorJson = json['error'] as Map<String, dynamic>;

    return JsonRpcError(
      jsonrpc: json['jsonrpc'] as String,
      id: json['id'] as RequestId?,
      error: JsonRpcErrorDetail(
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
  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'jsonrpc': jsonrpc,
      'id': id,
      'error': error.toJson(),
    };
  }
}

/// Detailed error information for JSON-RPC errors.
class JsonRpcErrorDetail implements Jsonable {
  JsonRpcErrorDetail({required this.code, required this.message, this.data});

  final int code;
  final String message;
  final dynamic data;

  /// Converts the error detail to a JSON map.
  @override
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
        method: 'notifications/cancelled',
        params: {
          'requestId': requestId,
          if (reason != null) 'reason': reason,
        },
      );
}

/// Client capabilities for the MCP protocol.
class ClientCapabilities implements Jsonable {
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
  @override
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
class RootsCapabilities implements Jsonable {
  RootsCapabilities({this.listChanged = false});

  final bool listChanged;

  /// Converts the root capabilities to a JSON map.
  @override
  Map<String, dynamic> toJson() {
    return {'listChanged': listChanged};
  }
}

/// Capabilities related to LLM sampling.
class SamplingCapabilities implements Jsonable {
  SamplingCapabilities();
  
  /// Converts the sampling capabilities to a JSON map.
  @override
  Map<String, dynamic> toJson() {
    return {};
  }
}

/// Server capabilities for the MCP protocol.
class ServerCapabilities implements Jsonable {
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

  dynamic experimental;
  bool logging;
  PromptCapabilities? prompts;
  ResourceCapabilities? resources;
  ToolCapabilities? tools;

  /// Converts the server capabilities to a JSON map.
  @override
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
class PromptCapabilities implements Jsonable {
  PromptCapabilities({this.listChanged = false});

  final bool listChanged;

  /// Converts the prompt capabilities to a JSON map.
  @override
  Map<String, dynamic> toJson() {
    return {'listChanged': listChanged};
  }
}

/// Capabilities related to resources.
class ResourceCapabilities implements Jsonable {
  ResourceCapabilities({this.subscribe = false, this.listChanged = false});

  final bool subscribe;
  final bool listChanged;

  /// Converts the resource capabilities to a JSON map.
  @override
  Map<String, dynamic> toJson() {
    return {
      'subscribe': subscribe,
      'listChanged': listChanged,
    };
  }
}

/// Capabilities related to tools.
class ToolCapabilities implements Jsonable {
  ToolCapabilities({this.listChanged = false});

  final bool listChanged;

  /// Converts the tool capabilities to a JSON map.
  @override
  Map<String, dynamic> toJson() {
    return {'listChanged': listChanged};
  }
}

/// Information about an MCP implementation.
class Implementation implements Jsonable {
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
  @override
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
  }) : super(
         method: 'initialize',
         params: {
           'protocolVersion': protocolVersion,
           'capabilities': capabilities.toJson(),
           'clientInfo': clientInfo.toJson(),
         },
       );

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
  InitializedNotification() : super(
    method: 'notifications/initialized',
    params: null,
  );

  /// Creates an initialized notification from a JSON map.
  factory InitializedNotification.fromJson(Map<String, dynamic> json) {
    return InitializedNotification();
  }
}

/// Request for pinging the server.
class PingRequest extends Request {
  PingRequest() : super(
    method: 'ping',
    params: {},
  );

  /// Creates a ping request from a JSON map.
  factory PingRequest.fromJson(Map<String, dynamic> json) {
    return PingRequest();
  }
}

/// Notification for reporting progress of a long-running operation.
class ProgressNotification extends Notification {
  ProgressNotification({
    required ProgressToken progressToken,
    required double progress,
    double? total,
  }) : super(
         method: 'notifications/progress',
         params: {
           'progressToken': progressToken,
           'progress': progress,
           if (total != null) 'total': total,
         },
       );
}

/// Base class for paginated requests.
class PaginatedRequest extends Request {
  PaginatedRequest({
    required String method,
    Cursor? cursor,
  }) : super(
        method: method,
        params: cursor != null ? {'cursor': cursor} : {},
      );
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
