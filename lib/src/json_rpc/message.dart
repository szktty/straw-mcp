/// JSON-RPC message handling for the MCP protocol.
library;

import 'package:straw_mcp/src/mcp/types.dart';

/// Creates a JSON-RPC request message.
JsonRpcRequest createRequest(String method, dynamic params, RequestId id) {
  return JsonRpcRequest(
    jsonRpcVersion,
    id,
    params,
    Request(method, params is Map<String, dynamic> ? params : {}),
  );
}

/// Creates a JSON-RPC notification message.
JsonRpcNotification createNotification(
  String method,
  Map<String, dynamic> params,
) {
  return JsonRpcNotification(
    version: jsonRpcVersion,
    method: method,
    params: params,
  );
}

/// Creates a JSON-RPC success response message.
JsonRpcResponse createResponse(RequestId id, dynamic result) {
  return JsonRpcResponse(jsonRpcVersion, id, result);
}

/// Creates a JSON-RPC error response message.
JsonRpcError createErrorResponse(
  RequestId? id,
  int code,
  String message, [
  dynamic data,
]) {
  return JsonRpcError(
    jsonRpcVersion,
    id,
    JsonRpcErrorDetail(code: code, message: message, data: data),
  );
}

/// Creates a standard parse error response.
JsonRpcError createParseError(RequestId? id, [String? message]) {
  return createErrorResponse(id, parseError, message ?? 'Parse error');
}

/// Creates a standard invalid request error response.
JsonRpcError createInvalidRequestError(RequestId? id, [String? message]) {
  return createErrorResponse(id, invalidRequest, message ?? 'Invalid request');
}

/// Creates a standard method not found error response.
JsonRpcError createMethodNotFoundError(RequestId? id, [String? message]) {
  return createErrorResponse(id, methodNotFound, message ?? 'Method not found');
}

/// Creates a standard invalid params error response.
JsonRpcError createInvalidParamsError(RequestId? id, [String? message]) {
  return createErrorResponse(id, invalidParams, message ?? 'Invalid params');
}

/// Creates a standard internal error response.
JsonRpcError createInternalError(RequestId? id, [String? message]) {
  return createErrorResponse(id, internalError, message ?? 'Internal error');
}
