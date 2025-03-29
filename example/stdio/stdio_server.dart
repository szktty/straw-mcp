/// Example of a standard input/output MCP server.
///
/// This example demonstrates how to create and run an MCP server that
/// communicates via standard input and output streams.
library;

import 'dart:io';
import 'package:logging/logging.dart';
import 'package:straw_mcp/straw_mcp.dart';

void main() async {
  // Set up logging
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    stderr.writeln('${record.level.name}: ${record.time}: ${record.message}');
  });

  final logger = Logger('StreamServerExample');

  // Create a basic MCP server with some tools
  final handler =
      Server('MCP Example Server', '0.1.0', [
          withToolCapabilities(listChanged: true),
          withResourceCapabilities(subscribe: true, listChanged: true),
          withPromptCapabilities(listChanged: true),
          withLogging(),
          withInstructions(
            'This is a simple MCP server example that communicates via stdio.',
          ),
        ])
        ..addTool(
          newTool('echo', [
            withDescription('Echoes back a message.'),
            withString('message', [
              required(),
              description('Message to echo back'),
            ]),
          ]),
          (request) async {
            final message = request.params['arguments']['message'] as String;
            return newToolResultText('Echo: $message');
          },
        )
        ..addTool(
          newTool('add', [
            withDescription('Adds two numbers together.'),
            withNumber('a', [required(), description('First number')]),
            withNumber('b', [required(), description('Second number')]),
          ]),
          (request) async {
            final a = (request.params['arguments']['a'] as num).toDouble();
            final b = (request.params['arguments']['b'] as num).toDouble();
            return newToolResultText('Result: ${a + b}');
          },
        );

  logger.info('Starting MCP server (stdio)...');

  // Serve the MCP server via stdio
  await serveStdio(
    handler,
    options: StreamServerTransportOptions.stdio(logger: Logger('StreamServer')),
  );
}
