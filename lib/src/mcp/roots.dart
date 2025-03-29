/// Root-related types and functions for the MCP protocol.
library;

import 'package:straw_mcp/src/mcp/types.dart';

/// Request for listing available roots.
class ListRootsRequest extends Request {
  ListRootsRequest() : super('roots/list', {});
}

/// Result of the list roots request.
class ListRootsResult extends Result {
  ListRootsResult({required this.roots, super.meta});

  /// Creates a list roots result from a JSON map.
  factory ListRootsResult.fromJson(Map<String, dynamic> json) {
    return ListRootsResult(
      roots:
          (json['roots'] as List)
              .map((r) => Root.fromJson(r as Map<String, dynamic>))
              .toList(),
      meta: json['_meta'] as Map<String, dynamic>?,
    );
  }

  final List<Root> roots;

  @override
  Map<String, dynamic> toJson() {
    final result = super.toJson();

    result['roots'] = roots.map((r) => r.toJson()).toList();

    return result;
  }
}

/// Represents a root in the MCP protocol.
class Root {
  Root({required this.uri, this.name});

  /// Creates a root from a JSON map.
  factory Root.fromJson(Map<String, dynamic> json) {
    return Root(
      uri: json['uri'] as String,
      name: json['name'] as String?,
    );
  }

  final String uri;
  final String? name;

  /// Converts the root to a JSON map.
  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{'uri': uri};

    if (name != null) {
      result['name'] = name;
    }

    return result;
  }
}

/// Notification indicating that the root list has changed.
class RootsListChangedNotification extends Notification {
  RootsListChangedNotification()
    : super('notifications/roots/list_changed', null);
}
