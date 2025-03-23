/// Content-related types shared between prompts and tools.
library;

import 'package:straw_mcp/src/mcp/resources.dart';

/// Base class for content in messages.
abstract class Content extends Annotated {
  Content({super.audience, super.priority});

  /// The type of content.
  String get type;

  /// Converts the content to a JSON map.
  Map<String, dynamic> toJson();

  /// Creates content from a JSON map.
  static Content fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;

    switch (type) {
      case 'text':
        return TextContent.fromJson(json);
      case 'image':
        return ImageContent.fromJson(json);
      case 'resource':
        return EmbeddedResource.fromJson(json);
      default:
        throw FormatException('Unknown content type: $type');
    }
  }
}

/// Represents text content.
class TextContent extends Content {
  TextContent({required this.text, super.audience, super.priority});

  /// Creates text content from a JSON map.
  factory TextContent.fromJson(Map<String, dynamic> json) {
    final annotated = Annotated.fromJson(
      json['annotations'] as Map<String, dynamic>?,
    );

    return TextContent(
      text: json['text'] as String,
      audience: annotated.audience,
      priority: annotated.priority,
    );
  }

  @override
  final String type = 'text';

  final String text;

  @override
  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{'type': type, 'text': text};

    final annotations = annotationsToJson();
    if (annotations != null) {
      result['annotations'] = annotations;
    }

    return result;
  }
}

/// Creates new text content.
TextContent newTextContent(String text) {
  return TextContent(text: text);
}

/// Represents image content.
class ImageContent extends Content {
  ImageContent({
    required this.data,
    required this.mimeType,
    super.audience,
    super.priority,
  });

  /// Creates image content from a JSON map.
  factory ImageContent.fromJson(Map<String, dynamic> json) {
    final annotated = Annotated.fromJson(
      json['annotations'] as Map<String, dynamic>?,
    );

    return ImageContent(
      data: json['data'] as String,
      mimeType: json['mimeType'] as String,
      audience: annotated.audience,
      priority: annotated.priority,
    );
  }

  @override
  final String type = 'image';

  final String data;
  final String mimeType;

  @override
  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{
      'type': type,
      'data': data,
      'mimeType': mimeType,
    };

    final annotations = annotationsToJson();
    if (annotations != null) {
      result['annotations'] = annotations;
    }

    return result;
  }
}

/// Represents an embedded resource.
class EmbeddedResource extends Content {
  EmbeddedResource({required this.resource, super.audience, super.priority});

  /// Creates an embedded resource from a JSON map.
  factory EmbeddedResource.fromJson(Map<String, dynamic> json) {
    final annotated = Annotated.fromJson(
      json['annotations'] as Map<String, dynamic>?,
    );

    return EmbeddedResource(
      resource: resourceContentsFromJson(
        json['resource'] as Map<String, dynamic>,
      ),
      audience: annotated.audience,
      priority: annotated.priority,
    );
  }

  @override
  final String type = 'resource';

  final ResourceContents resource;

  @override
  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{
      'type': type,
      'resource': resource.toJson(),
    };

    final annotations = annotationsToJson();
    if (annotations != null) {
      result['annotations'] = annotations;
    }

    return result;
  }
}

/// Creates a new embedded resource.
EmbeddedResource newEmbeddedResource(ResourceContents resource) {
  return EmbeddedResource(resource: resource);
}

/// Helper function to create content from JSON.
Content contentFromJson(Map<String, dynamic> json) {
  return Content.fromJson(json);
}
