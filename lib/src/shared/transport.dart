/// Transport interface for MCP server implementations.
///
/// This file provides a common interface for all transport mechanisms used
/// in MCP server implementations, allowing for consistent handling of
/// connections regardless of the underlying protocol (stream, HTTP+SSE, etc).
library;

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:straw_mcp/src/json_rpc/message.dart';
import 'package:straw_mcp/src/mcp/types.dart';

/// MCP server transport interface.
///
/// All server transport implementations should implement this interface
/// to provide a consistent API for starting, closing, and sending messages.
abstract class Transport {
  /// Starts the transport and begins receiving messages.
  Future<void> start();

  /// Closes the transport and releases any resources.
  Future<void> close();

  /// Sends a JSON-RPC message to the client.
  Future<void> send(JsonRpcMessage message);

  /// Callback for when a message is received from the client.
  void Function(String message)? get onMessage;

  set onMessage(void Function(String message)? handler);

  /// Callback for when an error occurs in the transport.
  void Function(Object error)? get onError;

  set onError(void Function(Object error)? handler);

  /// Callback for when the transport is closed.
  void Function()? get onClose;

  set onClose(void Function()? handler);
}

/// Base implementation of the Transport interface.
///
/// Provides common functionality for all transport implementations,
/// particularly the callback handling.
abstract class TransportBase implements Transport {
  /// Message received callback.
  void Function(String message)? _onMessageHandler;

  /// Error callback.
  void Function(Object error)? _onErrorHandler;

  /// Close callback.
  void Function()? _onCloseHandler;

  @override
  void Function(String message)? get onMessage => _onMessageHandler;

  @override
  set onMessage(void Function(String message)? handler) {
    _onMessageHandler = handler;
  }

  @override
  void Function(Object error)? get onError => _onErrorHandler;

  @override
  set onError(void Function(Object error)? handler) {
    _onErrorHandler = handler;
  }

  @override
  void Function()? get onClose => _onCloseHandler;

  @override
  set onClose(void Function()? handler) {
    _onCloseHandler = handler;
  }

  /// Calls the message handler with the given message.
  @protected
  void handleMessage(String message) {
    _onMessageHandler?.call(message);
  }

  /// Calls the error handler with the given error.
  @protected
  void handleError(Object error) {
    _onErrorHandler?.call(error);
  }

  /// Calls the close handler.
  @protected
  void handleClose() {
    _onCloseHandler?.call();
  }
}
