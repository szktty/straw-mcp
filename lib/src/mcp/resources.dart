import 'package:straw_mcp/src/mcp/types.dart';

/// Request for listing available resources.
class ListResourcesRequest extends PaginatedRequest {
  ListResourcesRequest({Cursor? cursor})
    : super('resources/list', cursor: cursor);
}

/// Result of the list resources request.
class ListResourcesResult extends PaginatedResult {
  ListResourcesResult({required this.resources, super.nextCursor, super.meta});

  /// Creates a list resources result from a JSON map.
  factory ListResourcesResult.fromJson(Map<String, dynamic> json) {
    return ListResourcesResult(
      resources:
          (json['resources'] as List)
              .map((r) => Resource.fromJson(r as Map<String, dynamic>))
              .toList(),
      nextCursor: json['nextCursor'] as String?,
      meta: json['_meta'] as Map<String, dynamic>?,
    );
  }

  final List<Resource> resources;

  @override
  Map<String, dynamic> toJson() {
    final result = super.toJson();

    result['resources'] = resources.map((r) => r.toJson()).toList();

    return result;
  }
}

/// Request for listing available resource templates.
class ListResourceTemplatesRequest extends PaginatedRequest {
  ListResourceTemplatesRequest({Cursor? cursor})
    : super('resources/templates/list', cursor: cursor);
}

/// Result of the list resource templates request.
class ListResourceTemplatesResult extends PaginatedResult {
  ListResourceTemplatesResult({
    required this.resourceTemplates,
    super.nextCursor,
    super.meta,
  });

  /// Creates a list resource templates result from a JSON map.
  factory ListResourceTemplatesResult.fromJson(Map<String, dynamic> json) {
    return ListResourceTemplatesResult(
      resourceTemplates:
          (json['resourceTemplates'] as List)
              .map((t) => ResourceTemplate.fromJson(t as Map<String, dynamic>))
              .toList(),
      nextCursor: json['nextCursor'] as String?,
      meta: json['_meta'] as Map<String, dynamic>?,
    );
  }

  final List<ResourceTemplate> resourceTemplates;

  @override
  Map<String, dynamic> toJson() {
    final result = super.toJson();

    result['resourceTemplates'] =
        resourceTemplates.map((t) => t.toJson()).toList();

    return result;
  }
}

/// Request for reading a specific resource.
class ReadResourceRequest extends Request {
  ReadResourceRequest({required String uri, Map<String, dynamic>? arguments})
    : super('resources/read', {
        'uri': uri,
        if (arguments != null) 'arguments': arguments,
      });
}

/// Result of the read resource request.
class ReadResourceResult extends Result {
  ReadResourceResult({required this.contents, super.meta});

  /// Creates a read resource result from a JSON map.
  factory ReadResourceResult.fromJson(Map<String, dynamic> json) {
    return ReadResourceResult(
      contents:
          (json['contents'] as List)
              .map((c) => resourceContentsFromJson(c as Map<String, dynamic>))
              .toList(),
      meta: json['_meta'] as Map<String, dynamic>?,
    );
  }

  final List<ResourceContents> contents;

  @override
  Map<String, dynamic> toJson() {
    final result = super.toJson();

    result['contents'] = contents.map((c) => c.toJson()).toList();

    return result;
  }
}

/// Notification indicating that the resource list has changed.
class ResourceListChangedNotification extends Notification {
  ResourceListChangedNotification()
    : super('notifications/resources/list_changed', null);
}

/// Request for subscribing to resource updates.
class SubscribeRequest extends Request {
  SubscribeRequest({required String uri})
    : super('resources/subscribe', {'uri': uri});
}

/// Request for unsubscribing from resource updates.
class UnsubscribeRequest extends Request {
  UnsubscribeRequest({required String uri})
    : super('resources/unsubscribe', {'uri': uri});
}

/// Notification indicating that a resource has been updated.
class ResourceUpdatedNotification extends Notification {
  ResourceUpdatedNotification({required String uri})
    : super('notifications/resources/updated', {'uri': uri});
}

/// Base class for annotated objects in the MCP protocol.
class Annotated {
  /// Creates an annotated object.
  Annotated({this.audience, this.priority});

  /// Creates annotations from a JSON map.
  factory Annotated.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return Annotated();
    }

    List<Role>? audience;
    if (json['audience'] != null) {
      audience =
          (json['audience'] as List)
              .map((a) => roleFromString(a as String))
              .toList();
    }

    return Annotated(audience: audience, priority: json['priority'] as double?);
  }

  /// The intended audience for the object.
  final List<Role>? audience;

  /// The priority of the object.
  final double? priority;

  /// Converts annotations to a JSON map.
  Map<String, dynamic>? annotationsToJson() {
    if (audience == null && priority == null) {
      return null;
    }

    final result = <String, dynamic>{};

    if (audience != null) {
      result['audience'] = audience!.map((r) => r.toString()).toList();
    }

    if (priority != null) {
      result['priority'] = priority;
    }

    return result;
  }
}

/// Represents a resource in the MCP protocol.
class Resource extends Annotated {
  Resource({
    required this.uri,
    required this.name,
    this.description,
    this.mimeType,
    this.size,
    super.audience,
    super.priority,
  });

  /// Creates a resource from a JSON map.
  factory Resource.fromJson(Map<String, dynamic> json) {
    final annotated = Annotated.fromJson(
      json['annotations'] as Map<String, dynamic>?,
    );

    return Resource(
      uri: json['uri'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      mimeType: json['mimeType'] as String?,
      size: json['size'] as int?,
      audience: annotated.audience,
      priority: annotated.priority,
    );
  }

  final String uri;
  final String name;
  final String? description;
  final String? mimeType;
  final int? size;

  /// Converts the resource to a JSON map.
  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{'uri': uri, 'name': name};

    if (description != null) {
      result['description'] = description;
    }

    if (mimeType != null) {
      result['mimeType'] = mimeType;
    }

    if (size != null) {
      result['size'] = size;
    }

    final annotations = annotationsToJson();
    if (annotations != null) {
      result['annotations'] = annotations;
    }

    return result;
  }
}

/// Represents a resource template in the MCP protocol.
class ResourceTemplate extends Annotated {
  ResourceTemplate({
    required this.uriTemplate,
    required this.name,
    this.description,
    this.mimeType,
    super.audience,
    super.priority,
  });

  /// Creates a resource template from a JSON map.
  factory ResourceTemplate.fromJson(Map<String, dynamic> json) {
    final annotated = Annotated.fromJson(
      json['annotations'] as Map<String, dynamic>?,
    );

    return ResourceTemplate(
      uriTemplate: json['uriTemplate'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      mimeType: json['mimeType'] as String?,
      audience: annotated.audience,
      priority: annotated.priority,
    );
  }

  final String uriTemplate;
  final String name;
  final String? description;
  final String? mimeType;

  /// Converts the resource template to a JSON map.
  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{'uriTemplate': uriTemplate, 'name': name};

    if (description != null) {
      result['description'] = description;
    }

    if (mimeType != null) {
      result['mimeType'] = mimeType;
    }

    final annotations = annotationsToJson();
    if (annotations != null) {
      result['annotations'] = annotations;
    }

    return result;
  }
}

/// Interface for resource contents.
abstract class ResourceContents {
  /// Creates resource contents from a JSON map.
  factory ResourceContents.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('text')) {
      return TextResourceContents.fromJson(json);
    } else if (json.containsKey('blob')) {
      return BlobResourceContents.fromJson(json);
    } else {
      throw const FormatException('Unknown resource contents type');
    }
  }

  String get uri;

  String? get mimeType;

  /// Converts the resource contents to a JSON map.
  Map<String, dynamic> toJson();
}

/// Represents text-based resource contents.
class TextResourceContents implements ResourceContents {
  TextResourceContents({required this.uri, required this.text, this.mimeType});

  /// Creates text resource contents from a JSON map.
  factory TextResourceContents.fromJson(Map<String, dynamic> json) {
    return TextResourceContents(
      uri: json['uri'] as String,
      text: json['text'] as String,
      mimeType: json['mimeType'] as String?,
    );
  }

  @override
  final String uri;

  @override
  final String? mimeType;

  final String text;

  @override
  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{'uri': uri, 'text': text};

    if (mimeType != null) {
      result['mimeType'] = mimeType;
    }

    return result;
  }
}

/// Represents binary resource contents.
class BlobResourceContents implements ResourceContents {
  /// Creates blob resource contents.
  BlobResourceContents({required this.uri, required this.blob, this.mimeType});

  /// Creates blob resource contents from a JSON map.
  factory BlobResourceContents.fromJson(Map<String, dynamic> json) {
    return BlobResourceContents(
      uri: json['uri'] as String,
      blob: json['blob'] as String,
      mimeType: json['mimeType'] as String?,
    );
  }

  @override
  final String uri;

  @override
  final String? mimeType;

  final String blob;

  @override
  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{'uri': uri, 'blob': blob};

    if (mimeType != null) {
      result['mimeType'] = mimeType;
    }

    return result;
  }
}

/// Creates a resource contents instance from a JSON map.
ResourceContents resourceContentsFromJson(Map<String, dynamic> json) {
  if (json.containsKey('text')) {
    return TextResourceContents.fromJson(json);
  } else if (json.containsKey('blob')) {
    return BlobResourceContents.fromJson(json);
  } else {
    throw const FormatException('Unknown resource contents type');
  }
}

/// LLM interaction roles.
enum Role { system, user, assistant, function, tool }

/// Converts a role enum to a string.
String roleToString(Role role) {
  return role.toString().split('.').last;
}

/// Creates a role enum from a string.
Role roleFromString(String roleStr) {
  switch (roleStr) {
    case 'system':
      return Role.system;
    case 'user':
      return Role.user;
    case 'assistant':
      return Role.assistant;
    case 'function':
      return Role.function;
    case 'tool':
      return Role.tool;
    default:
      throw ArgumentError('Unknown role: $roleStr');
  }
}
