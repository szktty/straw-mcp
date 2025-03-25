/// Prompt-related types and functions for the MCP protocol.
library;

import 'package:straw_mcp/src/mcp/contents.dart';
import 'package:straw_mcp/src/mcp/resources.dart';
import 'package:straw_mcp/src/mcp/types.dart';

/// Request for listing available prompts.
class ListPromptsRequest extends PaginatedRequest {
  ListPromptsRequest({Cursor? cursor}) : super('prompts/list', cursor: cursor);
}

/// Result of the list prompts request.
class ListPromptsResult extends PaginatedResult {
  ListPromptsResult({required this.prompts, super.nextCursor, super.meta});

  /// Creates a list prompts result from a JSON map.
  factory ListPromptsResult.fromJson(Map<String, dynamic> json) {
    return ListPromptsResult(
      prompts:
          (json['prompts'] as List)
              .map((p) => Prompt.fromJson(p as Map<String, dynamic>))
              .toList(),
      nextCursor: json['nextCursor'] as String?,
      meta: json['_meta'] as Map<String, dynamic>?,
    );
  }

  final List<Prompt> prompts;

  @override
  Map<String, dynamic> toJson() {
    final result = super.toJson();

    result['prompts'] = prompts.map((p) => p.toJson()).toList();

    return result;
  }
}

/// Request for getting a specific prompt.
class GetPromptRequest extends Request {
  GetPromptRequest({required String name, Map<String, dynamic>? arguments})
    : super('prompts/get', {
        'name': name,
        if (arguments != null) 'arguments': arguments,
      });
}

/// Result of the get prompt request.
class GetPromptResult extends Result {
  GetPromptResult({required this.title, required this.messages, super.meta});

  /// Creates a get prompt result from a JSON map.
  factory GetPromptResult.fromJson(Map<String, dynamic> json) {
    return GetPromptResult(
      title: json['title'] as String,
      messages:
          (json['messages'] as List)
              .map((m) => PromptMessage.fromJson(m as Map<String, dynamic>))
              .toList(),
      meta: json['_meta'] as Map<String, dynamic>?,
    );
  }

  final String title;
  final List<PromptMessage> messages;

  @override
  Map<String, dynamic> toJson() {
    final result = super.toJson();

    result['title'] = title;
    result['messages'] = messages.map((m) => m.toJson()).toList();

    return result;
  }
}

/// Creates a new get prompt result.
GetPromptResult newGetPromptResult(String title, List<PromptMessage> messages) {
  return GetPromptResult(title: title, messages: messages);
}

/// Notification indicating that the prompt list has changed.
class PromptListChangedNotification extends Notification {
  PromptListChangedNotification()
    : super('notifications/prompts/list_changed', null);
}

/// Represents a prompt in the MCP protocol.
class Prompt extends Annotated {
  Prompt({
    required this.name,
    this.description,
    List<PromptArgument>? arguments,
    super.audience,
    super.priority,
  }) : arguments = arguments ?? [];

  /// Creates a prompt from a JSON map.
  factory Prompt.fromJson(Map<String, dynamic> json) {
    final annotated = Annotated.fromJson(
      json['annotations'] as Map<String, dynamic>?,
    );

    return Prompt(
      name: json['name'] as String,
      description: json['description'] as String?,
      arguments:
          json['arguments'] != null
              ? (json['arguments'] as List)
                  .map(
                    (a) => PromptArgument.fromJson(a as Map<String, dynamic>),
                  )
                  .toList()
              : [],
      audience: annotated.audience,
      priority: annotated.priority,
    );
  }

  String name;
  String? description;
  List<PromptArgument> arguments;

  /// Converts the prompt to a JSON map.
  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{'name': name};

    if (description != null) {
      result['description'] = description;
    }

    if (arguments.isNotEmpty) {
      result['arguments'] = arguments.map((a) => a.toJson()).toList();
    }

    final annotations = annotationsToJson();
    if (annotations != null) {
      result['annotations'] = annotations;
    }

    return result;
  }
}

/// Represents a prompt argument.
class PromptArgument extends Annotated {
  PromptArgument({
    required this.name,
    this.description,
    this.required,
    super.audience,
    super.priority,
  });

  /// Creates a prompt argument from a JSON map.
  factory PromptArgument.fromJson(Map<String, dynamic> json) {
    final annotated = Annotated.fromJson(
      json['annotations'] as Map<String, dynamic>?,
    );

    return PromptArgument(
      name: json['name'] as String,
      description: json['description'] as String?,
      required: json['required'] as bool?,
      audience: annotated.audience,
      priority: annotated.priority,
    );
  }

  String name;
  String? description;
  bool? required;

  /// Converts the prompt argument to a JSON map.
  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{'name': name};

    if (description != null) {
      result['description'] = description;
    }

    if (required != null && required!) {
      result['required'] = true;
    }

    final annotations = annotationsToJson();
    if (annotations != null) {
      result['annotations'] = annotations;
    }

    return result;
  }
}

/// Represents a message in a prompt.
class PromptMessage extends Annotated {
  PromptMessage({
    required this.role,
    required this.content,
    super.audience,
    super.priority,
  });

  /// Creates a prompt message from a JSON map.
  factory PromptMessage.fromJson(Map<String, dynamic> json) {
    final annotated = Annotated.fromJson(
      json['annotations'] as Map<String, dynamic>?,
    );

    return PromptMessage(
      role: roleFromString(json['role'] as String),
      content: contentFromJson(json['content'] as Map<String, dynamic>),
      audience: annotated.audience,
      priority: annotated.priority,
    );
  }

  final Role role;
  final Content content;

  /// Converts the prompt message to a JSON map.
  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{
      'role': roleToString(role),
      'content': content.toJson(),
    };

    final annotations = annotationsToJson();
    if (annotations != null) {
      result['annotations'] = annotations;
    }

    return result;
  }
}

/// Creates a new prompt message with text content.
PromptMessage newPromptMessage(Role role, Content content) {
  return PromptMessage(role: role, content: content);
}

// Content classes are now imported from 'contents.dart'

/// Function type for prompt options.
typedef PromptOption = void Function(Prompt prompt);

/// Function type for prompt argument options.
typedef ArgumentOption = void Function(PromptArgument argument);

/// Creates a new prompt with the given options.
Prompt newPrompt(String name, [List<PromptOption> options = const []]) {
  final prompt = Prompt(name: name);

  for (final option in options) {
    option(prompt);
  }

  return prompt;
}

/// Adds a description to a prompt.
PromptOption withPromptDescription(String description) {
  return (Prompt prompt) {
    prompt.description = description;
  };
}

/// Adds an argument to a prompt.
PromptOption withArgument(
  String name, [
  List<ArgumentOption> options = const [],
]) {
  return (Prompt prompt) {
    final argument = PromptArgument(name: name);

    for (final option in options) {
      option(argument);
    }

    prompt.arguments.add(argument);
  };
}

/// Adds a description to a prompt argument.
ArgumentOption argumentDescription(String description) {
  return (PromptArgument argument) {
    argument.description = description;
  };
}

/// Sets a prompt argument as required.
ArgumentOption requiredArgument() {
  return (PromptArgument argument) {
    argument.required = true;
  };
}
