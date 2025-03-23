// Sample of a simple MCP server implementation
// File to be launched as an external process during testing

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:straw_mcp/src/mcp/contents.dart';
import 'package:straw_mcp/src/mcp/tools.dart';
import 'package:straw_mcp/src/server/protocol_handler.dart';
import 'package:straw_mcp/src/server/stream_server.dart';

// ignore_for_file: avoid_print, avoid_dynamic_calls

void main() async {
  // Logger configuration
  hierarchicalLoggingEnabled = true;
  final logger = Logger('TestServer')..level = Level.ALL;

  Logger.root.onRecord.listen((record) {
    stderr.writeln('${record.time}: ${record.level.name}: ${record.message}');
  });

  // Create server
  final handler =
      ProtocolHandler('test-server', '1.0.0')
        // Register a tool for testing
        ..addTool(
          Tool(
            name: 'echo',
            description: 'Echo back the input',
            parameters: [
              ToolParameter(
                name: 'message',
                type: 'string',
                required: true,
                description: 'Message to echo',
              ),
            ],
          ),
          (request) async {
            final message = request.params['arguments']['message'] as String;
            return CallToolResult(
              content: [TextContent(text: 'Echo: $message')],
            );
          },
        )
        ..addTool(
          Tool(
            name: 'add',
            description: 'Add two numbers',
            parameters: [
              ToolParameter(name: 'a', type: 'number', required: true),
              ToolParameter(name: 'b', type: 'number', required: true),
            ],
          ),
          (request) async {
            final a = (request.params['arguments']['a'] as num).toDouble();
            final b = (request.params['arguments']['b'] as num).toDouble();
            return CallToolResult(content: [TextContent(text: '${a + b}')]);
          },
        );

  // Configure StreamServerOptions
  final options = StreamServerOptions.stdio(
    logger: logger,
    logFilePath: 'test_server.log',
  );

  // Start the server
  await serveStdio(handler, options: options);
}
