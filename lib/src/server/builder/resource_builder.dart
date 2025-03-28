/// Resource builder implementation for the MCP protocol.
library;

import 'package:straw_mcp/src/mcp/resources.dart';
import 'package:straw_mcp/src/mcp/types.dart';
import 'package:straw_mcp/src/server/server.dart';

/// Builder for constructing MCP resources with fluent API.
///
/// This builder allows for the simple creation of resource definitions
/// with a fluent, cascading API.
class ResourceBuilder {
  /// The URI of the resource.
  String uri = '';

  /// The name of the resource.
  String name = '';

  /// Optional description of the resource.
  String? description;

  /// Optional MIME type of the resource.
  String? mimeType;

  /// Optional size of the resource in bytes.
  int? size;

  /// The handler function for this resource.
  ResourceHandlerFunction? handler;

  /// Build a resource object with the configured properties.
  Resource build() {
    if (uri.isEmpty) {
      throw ArgumentError('Resource URI is required');
    }
    
    if (name.isEmpty) {
      throw ArgumentError('Resource name is required');
    }
    
    if (handler == null) {
      throw ArgumentError('Resource handler is required');
    }
    
    return Resource(
      uri: uri,
      name: name,
      description: description,
      mimeType: mimeType,
      size: size,
    );
  }
}

/// Builder for constructing MCP resource templates with fluent API.
///
/// This builder allows for the simple creation of resource template definitions
/// with a fluent, cascading API.
class ResourceTemplateBuilder {
  /// The URI template pattern.
  String uriTemplate = '';

  /// The name of the resource template.
  String name = '';

  /// Optional description of the resource template.
  String? description;

  /// Optional MIME type of resources matching this template.
  String? mimeType;

  /// The handler function for this resource template.
  ResourceTemplateHandlerFunction? handler;

  /// Build a resource template object with the configured properties.
  ResourceTemplate build() {
    if (uriTemplate.isEmpty) {
      throw ArgumentError('Resource template URI template is required');
    }
    
    if (name.isEmpty) {
      throw ArgumentError('Resource template name is required');
    }
    
    if (handler == null) {
      throw ArgumentError('Resource template handler is required');
    }
    
    return ResourceTemplate(
      uriTemplate: uriTemplate,
      name: name,
      description: description,
      mimeType: mimeType,
    );
  }
}
