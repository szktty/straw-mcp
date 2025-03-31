/// JSON-RPC message handling for the MCP protocol.
library;

import 'package:straw_mcp/src/mcp/errors.dart';
import 'package:straw_mcp/src/mcp/types.dart';

/// Creates a JSON-RPC request message.
JsonRpcRequest createRequest({
  required String method,
  required dynamic params,
  required RequestId id,
}) {
  return JsonRpcRequest(
    jsonrpc: jsonRpcVersion,
    id: id,
    params: params,
    request: Request(
      method: method,
      params: params is Map<String, dynamic> ? params : {},
    ),
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
JsonRpcResponse createResponse({
  required RequestId id,
  required dynamic result,
}) {
  return JsonRpcResponse(
    jsonrpc: jsonRpcVersion,
    id: id,
    result: result,
  );
}

/// Creates a JSON-RPC error response message.
JsonRpcError createErrorResponse({
  required RequestId? id,
  required int code,
  required String message,
  dynamic data,
}) {
  return JsonRpcError(
    jsonrpc: jsonRpcVersion,
    id: id,
    error: JsonRpcErrorDetail(code: code, message: message, data: data),
  );
}

/// Creates a standard parse error response.
JsonRpcError createParseError(RequestId? id, [String? message]) {
  return createErrorResponse(
    id: id,
    code: McpErrorCode.parseError,
    message: message ?? 'Parse error',
  );
}

/// Creates a standard invalid request error response.
JsonRpcError createInvalidRequestError(RequestId? id, [String? message]) {
  return createErrorResponse(
    id: id,
    code: McpErrorCode.invalidRequest,
    message: message ?? 'Invalid request',
  );
}

/// Creates a standard method not found error response.
JsonRpcError createMethodNotFoundError(RequestId? id, [String? message]) {
  return createErrorResponse(
    id: id,
    code: McpErrorCode.methodNotFound,
    message: message ?? 'Method not found',
  );
}

/// Creates a standard invalid params error response.
JsonRpcError createInvalidParamsError(RequestId? id, [String? message]) {
  return createErrorResponse(
    id: id,
    code: McpErrorCode.invalidParams,
    message: message ?? 'Invalid params',
  );
}

/// Creates a standard internal error response.
JsonRpcError createInternalError(RequestId? id, [String? message]) {
  return createErrorResponse(
    id: id,
    code: McpErrorCode.internalError,
    message: message ?? 'Internal error',
  );
}
