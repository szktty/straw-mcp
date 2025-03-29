/// Sampling-related types and functions for the MCP protocol.
library;

import 'package:straw_mcp/src/mcp/contents.dart';
import 'package:straw_mcp/src/mcp/resources.dart';
import 'package:straw_mcp/src/mcp/types.dart';

/// Request for sampling from an LLM via the client.
class CreateMessageRequest extends Request {
  CreateMessageRequest({
    required this.messages,
    this.modelPreferences,
    this.systemPrompt,
    this.includeContext,
    this.temperature,
    required this.maxTokens,
    this.stopSequences,
    this.metadata,
  }) : super('sampling/createMessage', {
          'messages': messages.map((m) => m.toJson()).toList(),
          if (modelPreferences != null)
            'modelPreferences': modelPreferences.toJson(),
          if (systemPrompt != null) 'systemPrompt': systemPrompt,
          if (includeContext != null) 'includeContext': includeContext,
          if (temperature != null) 'temperature': temperature,
          'maxTokens': maxTokens,
          if (stopSequences != null) 'stopSequences': stopSequences,
          if (metadata != null) 'metadata': metadata,
        });

  final List<SamplingMessage> messages;
  final ModelPreferences? modelPreferences;
  final String? systemPrompt;
  final String? includeContext; // 'none', 'thisServer', or 'allServers'
  final double? temperature;
  final int maxTokens;
  final List<String>? stopSequences;
  final Map<String, dynamic>? metadata;
}

/// Model preferences for sampling requests.
class ModelPreferences {
  ModelPreferences({
    this.hints,
    this.costPriority,
    this.speedPriority,
    this.intelligencePriority,
  });

  final List<ModelHint>? hints;
  final double? costPriority;
  final double? speedPriority;
  final double? intelligencePriority;

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};

    if (hints != null && hints!.isNotEmpty) {
      result['hints'] = hints!.map((h) => h.toJson()).toList();
    }

    if (costPriority != null) {
      result['costPriority'] = costPriority;
    }

    if (speedPriority != null) {
      result['speedPriority'] = speedPriority;
    }

    if (intelligencePriority != null) {
      result['intelligencePriority'] = intelligencePriority;
    }

    return result;
  }
}

/// Model hint for guiding client model selection.
class ModelHint {
  ModelHint({this.name});

  factory ModelHint.of(String name) {
    return ModelHint(name: name);
  }

  final String? name;

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};

    if (name != null) {
      result['name'] = name;
    }

    return result;
  }
}

/// Message for use in sampling requests and results.
class SamplingMessage {
  SamplingMessage({required this.role, required this.content});

  factory SamplingMessage.fromJson(Map<String, dynamic> json) {
    return SamplingMessage(
      role: roleFromString(json['role'] as String),
      content: contentFromJson(json['content'] as Map<String, dynamic>),
    );
  }

  final Role role;
  final Content content;

  Map<String, dynamic> toJson() {
    return {
      'role': roleToString(role),
      'content': content.toJson(),
    };
  }
}

/// Result of a sampling request.
class CreateMessageResult extends Result implements SamplingMessage {
  CreateMessageResult({
    required this.model,
    this.stopReason,
    required this.role,
    required this.content,
    super.meta,
  });

  factory CreateMessageResult.fromJson(Map<String, dynamic> json) {
    return CreateMessageResult(
      model: json['model'] as String,
      stopReason: json['stopReason'] as String?,
      role: roleFromString(json['role'] as String),
      content: contentFromJson(json['content'] as Map<String, dynamic>),
      meta: json['_meta'] as Map<String, dynamic>?,
    );
  }

  final String model;
  final String? stopReason;
  @override
  final Role role;
  @override
  final Content content;

  @override
  Map<String, dynamic> toJson() {
    final result = super.toJson();

    result['model'] = model;
    if (stopReason != null) {
      result['stopReason'] = stopReason;
    }
    result['role'] = roleToString(role);
    result['content'] = content.toJson();

    return result;
  }
}
