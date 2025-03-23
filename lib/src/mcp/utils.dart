/// Utility functions for the MCP protocol.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:straw_mcp/src/mcp/contents.dart';
import 'package:straw_mcp/src/mcp/resources.dart';
import 'package:straw_mcp/src/mcp/tools.dart';

/// Encodes binary data as base64.
String encodeBase64(Uint8List data) {
  return base64Encode(data);
}

/// Decodes base64 data to binary.
Uint8List decodeBase64(String base64Data) {
  return base64Decode(base64Data);
}

/// Creates a text resource contents from a string.
TextResourceContents textResourceContents(
  String uri,
  String text, {
  String? mimeType,
}) {
  return TextResourceContents(uri: uri, text: text, mimeType: mimeType);
}

/// Creates a blob resource contents from binary data.
BlobResourceContents blobResourceContents(
  String uri,
  Uint8List data, {
  String? mimeType,
}) {
  return BlobResourceContents(
    uri: uri,
    blob: encodeBase64(data),
    mimeType: mimeType,
  );
}

/// Creates a text tool result with the given message.
CallToolResult textToolResult(String message) {
  return CallToolResult(content: [TextContent(text: message)]);
}

/// Creates an error tool result with the given error message.
CallToolResult errorToolResult(String errorMessage) {
  return CallToolResult(
    content: [TextContent(text: errorMessage)],
    isError: true,
  );
}

/// Creates a JSON tool result with the given data.
CallToolResult jsonToolResult(Map<String, dynamic> data) {
  return CallToolResult(content: [TextContent(text: json.encode(data))]);
}

/// Creates a number tool result with the given value.
CallToolResult numberToolResult(num value) {
  return CallToolResult(content: [TextContent(text: value.toString())]);
}

/// Creates a boolean tool result with the given value.
CallToolResult booleanToolResult({required bool value}) {
  return CallToolResult(content: [TextContent(text: value.toString())]);
}

/// Simple URI template matching for resource templates.
///
/// This is a simplified implementation and doesn't support the full RFC 6570.
bool matchesUriTemplate(String uri, String template, {bool strict = true}) {
  // Convert template to a regex pattern
  final pattern = template
      // Escape regex special characters
      .replaceAllMapped(
        RegExp(r'[\\^$*+?.()|[\]{}]'),
        (match) => '\\${match.group(0)}',
      )
      // Replace {name} with ([^/]+)
      .replaceAllMapped(RegExp(r'\{([^}]+)\}'), (match) => '([^/]+)');

  final regex = RegExp('^$pattern\$');
  return regex.hasMatch(uri);
}

/// Extracts variables from a URI based on a template.
///
/// This is a simplified implementation and doesn't support the full RFC 6570.
Map<String, String> extractUriVariables(String uri, String template) {
  final variables = <String, String>{};

  // Extract variable names
  final varNames = <String>[];
  final varMatches = RegExp(r'\{([^}]+)\}').allMatches(template);

  for (final match in varMatches) {
    varNames.add(match.group(1)!);
  }

  // Convert template to a regex pattern with capture groups
  final pattern = template
      // Escape regex special characters
      .replaceAllMapped(
        RegExp(r'[\\^$*+?.()|[\]{}]'),
        (match) => '\\${match.group(0)}',
      )
      // Replace {name} with ([^/]+)
      .replaceAllMapped(RegExp(r'\{([^}]+)\}'), (match) => '([^/]+)');

  final regex = RegExp('^$pattern\$');
  final match = regex.firstMatch(uri);

  if (match != null) {
    for (var i = 0; i < varNames.length; i++) {
      // Groups are 1-indexed in the match result
      variables[varNames[i]] = match.group(i + 1)!;
    }
  }

  return variables;
}
