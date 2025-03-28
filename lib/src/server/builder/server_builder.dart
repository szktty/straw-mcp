/// Server builder pattern entry point for the MCP protocol.
///
/// This file provides the main entry point for using the Server Builder pattern
/// with the MCP protocol. It extends the Server class with a factory method
/// that uses the builder pattern for creating configured instances.
library;

import 'package:straw_mcp/src/server/server.dart';
import 'builder.dart';

/// Extension to add builder pattern functionality to the Server class.
extension ServerBuilderExtension on Server {
  /// Creates a new server using the builder pattern.
  ///
  /// This static factory method uses the ServerBuilder to create and configure
  /// an MCP server with a fluent, declarative API.
  ///
  /// Example:
  /// ```dart
  /// final server = Server.build(
  ///   (b) => b
  ///     ..name = 'example-server'
  ///     ..version = '1.0.0'
  ///     ..logging()
  ///     ..tool(
  ///       (t) => t
  ///         ..name = 'calculator'
  ///         ..description = 'Simple calculator'
  ///         ..number(name: 'a', required: true)
  ///         ..number(name: 'b', required: true)
  ///         ..string(
  ///           name: 'operation',
  ///           required: true,
  ///           enumValues: ['add', 'subtract', 'multiply', 'divide']
  ///         )
  ///         ..handler = (request) async {
  ///           // Calculator implementation
  ///         },
  ///     ),
  /// );
  /// ```
  ///
  /// [updates] - A function that configures the server builder with the desired options.
  static Server build(void Function(ServerBuilder) updates) {
    final builder = ServerBuilder();
    updates(builder);
    return builder.build();
  }
}
