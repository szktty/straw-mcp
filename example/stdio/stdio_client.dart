/// Example of a standard input/output MCP client.
///
/// This example demonstrates how to create and run an MCP client that
/// communicates via standard input and output streams.
///
/// This can be used to connect to the stream_server_example by piping:
/// dart run example/stdio/stream_server_example.dart | dart run example/stdio/stdio_client_example.dart
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

  final logger = Logger('StreamClientExample');

  // Create an MCP client that communicates via stdio
  final client = StreamClient(
    options: StreamClientOptions.stdio(logger: Logger('StreamClient')),
  );

  try {
    // Connect to the server
    logger.info('Connecting to MCP server...');

    // Initialize the connection
    final initResult = await client.initialize(
      InitializeRequest(
        clientInfo: Implementation(
          name: 'Dart MCP Example Client',
          version: '0.1.0',
        ),
        protocolVersion: latestProtocolVersion,
        capabilities: ClientCapabilities(),
      ),
    );

    logger.info(
      'Connected to server: ${initResult.serverInfo.name} ${initResult.serverInfo.version}',
    );
    logger.info('Server capabilities: ${initResult.capabilities}');
    if (initResult.instructions != null) {
      logger.info('Server instructions: ${initResult.instructions}');
    }

    // List available tools
    logger.info('Requesting available tools...');
    final toolsResult = await client.listTools(ListToolsRequest());

    if (toolsResult.tools.isEmpty) {
      logger.warning('No tools available');
    } else {
      logger.info('Available tools:');
      for (final tool in toolsResult.tools) {
        logger.info(' - ${tool.name}');
      }

      // Try calling the echo tool if available
      final echoTool =
          toolsResult.tools.where((t) => t.name == 'echo').firstOrNull;
      if (echoTool != null) {
        logger.info('Calling echo tool...');
        final echoResult = await client.callTool(
          CallToolRequest(
            name: 'echo',
            arguments: {'message': 'Hello from Dart MCP client!'},
          ),
        );
        logger.info('Echo result: ${echoResult.content}');
      }

      // Try calling the add tool if available
      final addTool =
          toolsResult.tools.where((t) => t.name == 'add').firstOrNull;
      if (addTool != null) {
        logger.info('Calling add tool...');
        final addResult = await client.callTool(
          CallToolRequest(name: 'add', arguments: {'a': 40, 'b': 2}),
        );
        logger.info('Add result: ${addResult.content}');
      }
    }

    // Close the connection
    await client.close();
    logger.info('Connection closed');
  } catch (e) {
    logger.severe('Error: $e');
  } finally {
    exit(0);
  }
}
