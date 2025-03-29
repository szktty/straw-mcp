/// Server Builder pattern implementation for the MCP protocol.
///
/// This file provides builder patterns for creating and configuring MCP servers
/// in a fluent and declarative way.
library;

import 'package:straw_mcp/src/mcp/resources.dart';
import 'package:straw_mcp/src/mcp/prompts.dart';
import 'package:straw_mcp/src/mcp/tools.dart';
import 'package:straw_mcp/src/mcp/types.dart';
import 'package:straw_mcp/src/server/builder/prompt_builder.dart';
import 'package:straw_mcp/src/server/builder/resource_builder.dart';
import 'package:straw_mcp/src/server/builder/server_capabilities_builder.dart';
import 'package:straw_mcp/src/server/builder/tool_builder.dart';
import 'package:straw_mcp/src/server/server.dart';
import 'package:logging/logging.dart';

/// Server builder for creating and configuring MCP servers.
///
/// Usage example:
/// ```dart
/// final server = Server.build(
///   (b) => b
///     ..name = 'example-server'
///     ..version = 'v1.0.0'
///     ..capabilities((c) => c
///       ..tool(listChanged: true)
///       ..resource(subscribe: true, listChanged: true)
///       ..prompt(listChanged: true))
///     ..logging()
///     ..instructions = 'This is a sample MCP server.'
///     ..tool(
///       (t) => t
///         ..name = 'echo'
///         ..description = 'Echo the input'
///         ..string(
///           name: 'message',
///           required: true,
///           description: 'Message to echo back'
///         )
///         ..handler = (request) async {
///           final message = request.arguments['message'] as String;
///           return ToolResult.text('Echo: $message');
///         },
///     ),
/// );
/// ```
class ServerBuilder {
  /// The name of the server.
  String? name;

  /// The version of the server.
  String? version;

  /// Whether to enforce strict capabilities.
  bool enforceStrictCapabilities = false;

  /// Instructions for the server.
  String? instructions;

  /// Optional logger for the server.
  Logger? logger;

  /// The capabilities builder for this server.
  final ServerCapabilitiesBuilder _capabilitiesBuilder =
      ServerCapabilitiesBuilder();

  /// Whether logging is enabled for this server.
  bool _loggingEnabled = false;

  /// The tools to register with this server.
  final List<ServerTool> _tools = [];

  /// The resources to register with this server.
  final List<_ResourceEntry> _resources = [];

  /// The resource templates to register with this server.
  final List<_ResourceTemplateEntry> _resourceTemplates = [];

  /// The prompts to register with this server.
  final List<_PromptEntry> _prompts = [];

  /// Configure server capabilities using a builder.
  void capabilities(void Function(ServerCapabilitiesBuilder) updates) {
    updates(_capabilitiesBuilder);
  }

  /// Enable logging for this server.
  void logging() {
    _loggingEnabled = true;
  }

  /// Add a tool to this server using a builder.
  void tool(void Function(ToolBuilder) updates) {
    final builder = ToolBuilder();
    updates(builder);
    _tools.add(builder.build());
  }

  /// Add a resource to this server using a builder.
  void resource(void Function(ResourceBuilder) updates) {
    final builder = ResourceBuilder();
    updates(builder);
    _resources.add(_ResourceEntry(builder.build(), builder.handler!));
  }

  /// Add a resource template to this server using a builder.
  void resourceTemplate(void Function(ResourceTemplateBuilder) updates) {
    final builder = ResourceTemplateBuilder();
    updates(builder);
    _resourceTemplates.add(
      _ResourceTemplateEntry(builder.build(), builder.handler!),
    );
  }

  /// Add a prompt to this server using a builder.
  void prompt(void Function(PromptBuilder) updates) {
    final builder = PromptBuilder();
    updates(builder);
    _prompts.add(_PromptEntry(builder.build(), builder.handler!));
  }

  /// Build the server with all configured options.
  Server build() {
    // Check that required properties are set
    if (name == null || name!.isEmpty) {
      throw ArgumentError('Server name is required');
    }
    if (version == null || version!.isEmpty) {
      throw ArgumentError('Server version is required');
    }

    // Build server options
    final options = ServerOptions(
      capabilities: _capabilitiesBuilder.build(),
      enforceStrictCapabilities: enforceStrictCapabilities,
      instructions: instructions,
    );

    // If logging is enabled, enable it in capabilities
    if (_loggingEnabled) {
      options.capabilities?.logging = true;
    }

    // Create the server
    final server = Server(name: name!, version: version!, options: options);

    // Add all configured elements
    for (final tool in _tools) {
      server.addTool(tool.tool, tool.handler);
    }

    for (final entry in _resources) {
      server.addResource(entry.resource, entry.handler);
    }

    for (final entry in _resourceTemplates) {
      server.addResourceTemplate(entry.template, entry.handler);
    }

    for (final entry in _prompts) {
      server.addPrompt(entry.prompt, entry.handler);
    }

    return server;
  }
}

/// Internal class for storing resources and their handlers.
class _ResourceEntry {
  _ResourceEntry(this.resource, this.handler);

  final Resource resource;
  final ResourceHandlerFunction handler;
}

/// Internal class for storing resource templates and their handlers.
class _ResourceTemplateEntry {
  _ResourceTemplateEntry(this.template, this.handler);

  final ResourceTemplate template;
  final ResourceTemplateHandlerFunction handler;
}

/// Internal class for storing prompts and their handlers.
class _PromptEntry {
  _PromptEntry(this.prompt, this.handler);

  final Prompt prompt;
  final PromptHandlerFunction handler;
}
