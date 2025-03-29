/// Prompt builder implementation for the MCP protocol.
library;

import 'package:straw_mcp/src/mcp/prompts.dart';
import 'package:straw_mcp/src/mcp/types.dart';
import 'package:straw_mcp/src/server/server.dart';

/// Builder for constructing MCP prompts with fluent API.
///
/// This builder allows for the simple creation of prompt definitions
/// with a fluent, cascading API. It supports adding arguments and
/// configuring prompt metadata.
class PromptBuilder {
  /// The name of the prompt.
  String name = '';

  /// Optional description of the prompt.
  String? description;

  /// Arguments for this prompt.
  final List<PromptArgument> _arguments = [];

  /// The handler function for this prompt.
  PromptHandlerFunction? handler;

  /// Add an argument to this prompt.
  ///
  /// [name] - The name of the argument.
  /// [description] - Optional description of the argument.
  /// [required] - Whether this argument is required.
  void argument({
    required String name,
    String? description,
    bool required = false,
  }) {
    _arguments.add(
      PromptArgument(name: name, description: description, required: required),
    );
  }

  /// Set multiple arguments at once, replacing any existing arguments.
  ///
  /// [args] - List of prompt arguments to set.
  set arguments(List<PromptArgument> args) {
    _arguments.clear();
    _arguments.addAll(args);
  }

  /// Build a prompt object with the configured properties.
  Prompt build() {
    if (name.isEmpty) {
      throw ArgumentError('Prompt name is required');
    }
    
    if (handler == null) {
      throw ArgumentError('Prompt handler is required');
    }
    
    return Prompt(name: name, description: description, arguments: _arguments);
  }
}
