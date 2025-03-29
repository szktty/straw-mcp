/// Tool-related types and functions for the MCP protocol.
library;

import 'package:straw_mcp/src/mcp/contents.dart';
import 'package:straw_mcp/src/mcp/resources.dart';
import 'package:straw_mcp/src/mcp/types.dart';

/// Request for listing available tools.
class ListToolsRequest extends PaginatedRequest {
  ListToolsRequest({Cursor? cursor}) : super('tools/list', cursor: cursor);
}

/// Result of the list tools request.
class ListToolsResult extends PaginatedResult {
  ListToolsResult({required this.tools, super.nextCursor, super.meta});

  /// Creates a list tools result from a JSON map.
  factory ListToolsResult.fromJson(Map<String, dynamic> json) {
    return ListToolsResult(
      tools:
          (json['tools'] as List)
              .map((t) => Tool.fromJson(t as Map<String, dynamic>))
              .toList(),
      nextCursor: json['nextCursor'] as String?,
      meta: json['_meta'] as Map<String, dynamic>?,
    );
  }

  final List<Tool> tools;

  @override
  Map<String, dynamic> toJson() {
    final result = super.toJson();

    result['tools'] = tools.map((t) => t.toJson()).toList();

    return result;
  }
}

/// Request for calling a tool.
class CallToolRequest extends Request {
  CallToolRequest({required this.name, required this.arguments})
    : super('tools/call', {'name': name, 'arguments': arguments});

  final String name;
  final Map<String, dynamic> arguments;
}

// Content classes are now imported from 'contents.dart'

/// Result of the call tool request.
class CallToolResult extends Result {
  /// Creates a call tool result.
  ///
  /// - [content]: The content items that make up the result
  /// - [isError]: Whether the result represents an error
  /// - [meta]: Optional metadata for the result
  CallToolResult({required this.content, this.isError = false, super.meta});

  /// Creates a text tool result with the given text content.
  ///
  /// A convenience function for creating a successful tool result
  /// with a single text content item.
  factory CallToolResult.text(String text) {
    return CallToolResult(content: [TextContent(text: text)]);
  }

  /// Creates an error tool result with the given error message.
  ///
  /// A convenience function for creating an error tool result
  /// with a single text content item containing the error message.
  factory CallToolResult.error(String errorMessage) {
    return CallToolResult(
      content: [TextContent(text: errorMessage)],
      isError: true,
    );
  }

  /// Creates a call tool result from a JSON map.
  factory CallToolResult.fromJson(Map<String, dynamic> json) {
    return CallToolResult(
      content:
          ((json['content'] as List?) ?? [])
              .map((c) => Content.fromJson(c as Map<String, dynamic>))
              .toList(),
      isError: json['isError'] as bool? ?? false,
      meta: json['_meta'] as Map<String, dynamic>?,
    );
  }

  /// Content of the tool execution result.
  ///
  /// Can include text, images, or embedded resources.
  final List<Content> content;

  /// Indicates whether an error occurred during tool execution.
  ///
  /// When true, the content typically contains an error message.
  final bool isError;

  @override
  Map<String, dynamic> toJson() {
    final result = super.toJson();

    result['content'] = content.map((c) => c.toJson()).toList();

    if (isError) {
      result['isError'] = true;
    }

    return result;
  }
}

/// Notification indicating that the tool list has changed.
class ToolListChangedNotification extends Notification {
  ToolListChangedNotification()
    : super('notifications/tools/list_changed', null);
}

/// Represents a tool parameter.
class ToolParameter extends Annotated {
  /// Creates a new tool parameter.
  ///
  /// - [name]: The parameter name
  /// - [type]: The parameter type (e.g., 'string', 'number', 'boolean')
  /// - [required]: Whether the parameter is required
  /// - [description]: Optional description of the parameter
  /// - [enumValues]: Optional list of allowed values for the parameter
  /// - [defaultValue]: Optional default value for the parameter
  /// - [audience]: Optional audience annotation
  /// - [priority]: Optional priority annotation
  ToolParameter({
    required this.name,
    required this.type,
    this.required,
    this.description,
    this.enumValues,
    this.defaultValue,
    super.audience,
    super.priority,
  });

  /// Creates a tool parameter from a JSON map.
  factory ToolParameter.fromJson(Map<String, dynamic> json) {
    final annotated = Annotated.fromJson(
      json['annotations'] as Map<String, dynamic>?,
    );

    return ToolParameter(
      name: json['name'] as String,
      type: json['type'] as String,
      required: json['required'] as bool?,
      description: json['description'] as String?,
      enumValues:
          json['enum'] != null ? (json['enum'] as List).cast<String>() : null,
      defaultValue: json['default'],
      audience: annotated.audience,
      priority: annotated.priority,
    );
  }

  String name;
  String type;
  bool? required;
  String? description;
  List<String>? enumValues;
  dynamic defaultValue;

  /// Converts the tool parameter to a JSON map.
  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{'name': name, 'type': type};

    if (required ?? false) {
      result['required'] = true;
    }

    if (description != null) {
      result['description'] = description;
    }

    if (enumValues != null) {
      result['enum'] = enumValues;
    }

    if (defaultValue != null) {
      result['default'] = defaultValue;
    }

    final annotations = annotationsToJson();
    if (annotations != null) {
      result['annotations'] = annotations;
    }

    return result;
  }
}

/// Represents a tool in the MCP protocol.
class Tool extends Annotated {
  /// Creates a new tool.
  ///
  /// - [name]: The name of the tool
  /// - [description]: Optional description of the tool
  /// - [inputSchema]: Optional list of parameters the tool accepts
  /// - [audience]: Optional audience annotation
  /// - [priority]: Optional priority annotation
  Tool({
    required this.name,
    this.description,
    List<ToolParameter>? inputSchema,
    super.audience,
    super.priority,
  }) : inputSchema = inputSchema ?? [] {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(name)) {
      throw ArgumentError(
        "Tool name must match pattern '^[a-zA-Z0-9_-]{1,64}\$'. Got: $name",
      );
    }
  }

  /// Creates a tool from a JSON map.
  factory Tool.fromJson(Map<String, dynamic> json) {
    final annotated = Annotated.fromJson(
      json['annotations'] as Map<String, dynamic>?,
    );
    final params = <ToolParameter>[];

    if (json['inputSchema'] != null) {
      final inputSchema = json['inputSchema'] as Map<String, dynamic>;
      final properties =
          inputSchema['properties'] as Map<String, dynamic>? ?? {};
      final required =
          (inputSchema['required'] as List?)?.cast<String>() ?? <String>[];

      for (final entry in properties.entries) {
        final name = entry.key;
        final propSchema = entry.value as Map<String, dynamic>;

        params.add(
          ToolParameter(
            name: name,
            type: propSchema['type'] as String? ?? 'string',
            required: required.contains(name),
            description: propSchema['description'] as String?,
            enumValues:
                propSchema['enum'] != null
                    ? (propSchema['enum'] as List).cast<String>()
                    : null,
            defaultValue: propSchema['default'],
          ),
        );
      }
    }

    return Tool(
      name: json['name'] as String,
      description: json['description'] as String?,
      inputSchema: params,
      audience: annotated.audience,
      priority: annotated.priority,
    );
  }

  /// The name of the tool.
  String name;

  /// A human-readable description of the tool.
  String? description;

  /// The list of parameters that the tool accepts.
  List<ToolParameter> inputSchema;

  /// Converts the tool to a JSON map.
  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{'name': name};

    if (description != null) {
      result['description'] = description;
    }

    // JSON Schema for input parameters
    final properties = <String, dynamic>{};
    final required = <String>[];

    for (final param in inputSchema) {
      final propertySchema = <String, dynamic>{'type': param.type};

      if (param.description != null) {
        propertySchema['description'] = param.description;
      }

      if (param.enumValues != null) {
        propertySchema['enum'] = param.enumValues;
      }

      if (param.defaultValue != null) {
        propertySchema['default'] = param.defaultValue;
      }

      properties[param.name] = propertySchema;

      if (param.required ?? false) {
        required.add(param.name);
      }
    }

    final schema = <String, dynamic>{
      'type': 'object',
      'properties': properties,
    };

    if (required.isNotEmpty) {
      schema['required'] = required;
    }

    result['inputSchema'] = schema;

    final annotations = annotationsToJson();
    if (annotations != null) {
      result['annotations'] = annotations;
    }

    return result;
  }
}
