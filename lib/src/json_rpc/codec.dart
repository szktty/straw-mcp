/// JSON-RPC codec for encoding and decoding MCP messages.
library;

import 'package:straw_mcp/src/mcp/types.dart';

/// Handles encoding and decoding of JSON-RPC messages for the MCP protocol.
class JsonRpcCodec {
  /// Encodes a JSON-RPC request to a JSON-serializable map.
  Map<String, dynamic> encodeRequest(JsonRpcRequest request) {
    return request.toJson();
  }

  /// Encodes a JSON-RPC notification to a JSON-serializable map.
  Map<String, dynamic> encodeNotification(JsonRpcNotification notification) {
    return notification.toJson();
  }

  /// Encodes a JSON-RPC response to a JSON-serializable map.
  Map<String, dynamic> encodeResponse(JsonRpcMessage response) {
    if (response is JsonRpcResponse) {
      return response.toJson();
    } else if (response is JsonRpcError) {
      return response.toJson();
    } else {
      throw ArgumentError('Unknown response type: ${response.runtimeType}');
    }
  }

  /// Decodes a JSON-serializable map to a JSON-RPC message.
  JsonRpcMessage decodeMessage(Map<String, dynamic> json) {
    final jsonrpc = json['jsonrpc'] as String?;

    if (jsonrpc != jsonRpcVersion) {
      throw FormatException('Invalid JSON-RPC version: $jsonrpc');
    }

    if (json.containsKey('method')) {
      if (json.containsKey('id')) {
        return JsonRpcRequest.fromJson(json);
      } else {
        return JsonRpcNotification.fromJson(json);
      }
    } else if (json.containsKey('result')) {
      return JsonRpcResponse.fromJson(json);
    } else if (json.containsKey('error')) {
      return JsonRpcError.fromJson(json);
    }

    throw const FormatException('Invalid JSON-RPC message');
  }

  /// Decodes a JSON-serializable map to a JSON-RPC request.
  JsonRpcRequest decodeRequest(Map<String, dynamic> json) {
    final message = decodeMessage(json);

    if (message is JsonRpcRequest) {
      return message;
    } else {
      throw const FormatException('Not a JSON-RPC request');
    }
  }

  /// Decodes a JSON-serializable map to a JSON-RPC notification.
  JsonRpcNotification decodeNotification(Map<String, dynamic> json) {
    final message = decodeMessage(json);

    if (message is JsonRpcNotification) {
      return message;
    } else {
      throw const FormatException('Not a JSON-RPC notification');
    }
  }

  /// Decodes a JSON-serializable map to a JSON-RPC response or error.
  JsonRpcMessage decodeResponse(Map<String, dynamic> json) {
    final message = decodeMessage(json);

    if (message is JsonRpcResponse || message is JsonRpcError) {
      return message;
    } else {
      throw const FormatException('Not a JSON-RPC response or error');
    }
  }
}
