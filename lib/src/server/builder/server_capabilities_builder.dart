/// Server capabilities builder implementation for the MCP protocol.
library;

import 'package:straw_mcp/src/mcp/types.dart';

/// Builder for constructing server capabilities.
///
/// This builder allows fluent construction of server capabilities
/// for MCP servers. It provides methods for enabling and configuring
/// different capability types like tools, resources, prompts, etc.
class ServerCapabilitiesBuilder {
  /// Experimental capabilities.
  dynamic experimental;

  /// Whether tool list changes are supported.
  bool _toolListChanged = false;

  /// Whether resource subscription is supported.
  bool _resourceSubscribe = false;

  /// Whether resource list changes are supported.
  bool _resourceListChanged = false;

  /// Whether prompt list changes are supported.
  bool _promptListChanged = false;

  /// Whether logging is enabled.
  bool _loggingEnabled = false;

  /// Enable tool capabilities with optional features.
  ///
  /// [listChanged] - Whether the server supports tool list change notifications.
  void tool({bool listChanged = false}) {
    _toolListChanged = listChanged;
  }

  /// Enable resource capabilities with optional features.
  ///
  /// [subscribe] - Whether the server supports resource subscriptions.
  /// [listChanged] - Whether the server supports resource list change notifications.
  void resource({bool subscribe = false, bool listChanged = false}) {
    _resourceSubscribe = subscribe;
    _resourceListChanged = listChanged;
  }

  /// Enable prompt capabilities with optional features.
  ///
  /// [listChanged] - Whether the server supports prompt list change notifications.
  void prompt({bool listChanged = false}) {
    _promptListChanged = listChanged;
  }

  /// Build server capabilities based on configured options.
  ServerCapabilities build() {
    final capabilities = ServerCapabilities(
      experimental: experimental,
      logging: _loggingEnabled,
    );

    // Configure tool capabilities if enabled
    if (_toolListChanged) {
      capabilities.tools = ToolCapabilities(listChanged: _toolListChanged);
    }

    // Configure resource capabilities if any resource features are enabled
    if (_resourceSubscribe || _resourceListChanged) {
      capabilities.resources = ResourceCapabilities(
        subscribe: _resourceSubscribe,
        listChanged: _resourceListChanged,
      );
    }

    // Configure prompt capabilities if enabled
    if (_promptListChanged) {
      capabilities.prompts = PromptCapabilities(
        listChanged: _promptListChanged,
      );
    }

    return capabilities;
  }
}
