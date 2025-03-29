import 'package:straw_mcp/src/mcp/tools.dart';
import 'package:straw_mcp/src/server/server.dart';

/// Builder for constructing MCP tools with fluent API.
///
/// This builder allows for the simple creation of tool definitions
/// with a fluent, cascading API. It supports adding various parameter types
/// and configuring tool metadata.
class ToolBuilder {
  /// The name of the tool.
  String name = '';

  /// Optional description of the tool.
  String? description;

  /// Parameters for this tool.
  final List<ToolParameter> _parameters = [];

  /// The handler function for this tool.
  ToolHandlerFunction? handler;

  /// Add a number parameter to this tool.
  ///
  /// [name] - The name of the parameter.
  /// [required] - Whether this parameter is required.
  /// [description] - Optional description of the parameter.
  /// [defaultValue] - Optional default value for the parameter.
  /// [enumValues] - Optional list of allowed values for the parameter.
  void number({
    required String name,
    bool required = false,
    String? description,
    num? defaultValue,
    List<num>? enumValues,
  }) {
    _parameters.add(
      ToolParameter(
        name: name,
        type: 'number',
        required: required,
        description: description,
        defaultValue: defaultValue,
        enumValues: enumValues?.map((v) => v.toString()).toList(),
      ),
    );
  }

  /// Add a string parameter to this tool.
  ///
  /// [name] - The name of the parameter.
  /// [required] - Whether this parameter is required.
  /// [description] - Optional description of the parameter.
  /// [defaultValue] - Optional default value for the parameter.
  /// [enumValues] - Optional list of allowed values for the parameter.
  void string({
    required String name,
    bool required = false,
    String? description,
    String? defaultValue,
    List<String>? enumValues,
  }) {
    _parameters.add(
      ToolParameter(
        name: name,
        type: 'string',
        required: required,
        description: description,
        defaultValue: defaultValue,
        enumValues: enumValues,
      ),
    );
  }

  /// Add a boolean parameter to this tool.
  ///
  /// [name] - The name of the parameter.
  /// [required] - Whether this parameter is required.
  /// [description] - Optional description of the parameter.
  /// [defaultValue] - Optional default value for the parameter.
  void boolean({
    required String name,
    bool required = false,
    String? description,
    bool? defaultValue,
  }) {
    _parameters.add(
      ToolParameter(
        name: name,
        type: 'boolean',
        required: required,
        description: description,
        defaultValue: defaultValue,
      ),
    );
  }

  /// Add an array parameter to this tool.
  ///
  /// [name] - The name of the parameter.
  /// [required] - Whether this parameter is required.
  /// [description] - Optional description of the parameter.
  void array({
    required String name,
    bool required = false,
    String? description,
  }) {
    _parameters.add(
      ToolParameter(
        name: name,
        type: 'array',
        required: required,
        description: description,
      ),
    );
  }

  /// Add an object parameter to this tool.
  ///
  /// [name] - The name of the parameter.
  /// [required] - Whether this parameter is required.
  /// [description] - Optional description of the parameter.
  void object({
    required String name,
    bool required = false,
    String? description,
  }) {
    _parameters.add(
      ToolParameter(
        name: name,
        type: 'object',
        required: required,
        description: description,
      ),
    );
  }

  /// Build the tool with the configured options.
  ServerTool build() {
    if (name.isEmpty) {
      throw ArgumentError('Tool name is required');
    }
    
    if (handler == null) {
      throw ArgumentError('Tool handler is required');
    }
    
    final tool = Tool(
      name: name,
      description: description,
      inputSchema: _parameters,
    );
    return ServerTool(tool, handler!);
  }
}
