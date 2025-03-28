/// Example of an MCP echo server and client in a single file.
///
/// This example demonstrates how to create and run both an MCP server and client
/// in the same application. The server provides simple echo functionality, and
/// the client connects to it.
///
/// ## How to run
///
/// ```bash
/// # Run both server and client together (default)
/// dart run example.dart
///
/// # Run server only
/// dart run example.dart --server
///
/// # Run client only (requires a running server)
/// dart run example.dart --client
/// ```
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:straw_mcp/straw_mcp.dart';

/// Entry point that provides a choice between running the client, server, or both.
void main(List<String> args) async {
  if (args.contains('--server')) {
    // Run the server only
    await runServer();
  } else if (args.contains('--client')) {
    // Run the client only
    await runClient();
  } else {
    // Run both server and client
    print('Running both server and client together');
    await runBoth();
  }
}

/// Runs only the MCP echo server.
Future<void> runServer() async {
  print('Starting echo server...');

  final server = createEchoServer();

  // Create a stdio transport
  final transport = StdioServerTransport();

  // Start the server with the transport
  print('Starting server with stdio transport...');
  await server.start(transport);

  // Keep the server running
  print('Server running, waiting for requests...');
  // This will keep running until the transport is closed
}

/// Runs only the MCP client.
Future<void> runClient() async {
  print('Starting echo client...');

  final client = StreamClient(options: StreamClientOptions.stdio());

  try {
    await connectAndUseEchoTool(client);
  } catch (e) {
    print('Error: $e');
  } finally {
    await client.close();
    print('Client closed');
    exit(0);
  }
}

/// Runs both the server and client, with the client connecting to the server.
Future<void> runBoth() async {
  print('Starting echo server and client...');

  // Start the server as a separate process
  print('Launching server process...');
  final serverProcess = await Process.start(
    Platform.executable, // Use the current Dart executable
    [
      Platform.script.toFilePath(), // This script itself
      '--server', // Tell it to run in server mode
    ],
  );

  // Log server output to stderr
  serverProcess.stderr.transform(utf8.decoder).listen(stderr.write);

  // Give the server a moment to start up
  await Future<void>.delayed(Duration(milliseconds: 500));

  print('Server launched, starting client...');

  // Create a client that connects to the server process
  final client = StreamClient(
    options: StreamClientOptions(
      stream: serverProcess.stdout,
      sink: serverProcess.stdin,
    ),
  );

  try {
    await connectAndUseEchoTool(client);
  } catch (e) {
    print('Error: $e');
  } finally {
    await client.close();
    print('Client closed');

    // Close the server process
    serverProcess.kill();
    await serverProcess.exitCode;
    exit(0);
  }
}

/// Creates and returns an MCP server with echo functionality using Builder pattern.
Server createEchoServer() {
  return Server.build(
    (b) =>
        b
          ..name = 'MCP Echo Server'
          ..version = '1.0.0'
          ..capabilities(
            (c) =>
                c
                  ..tool(listChanged: true)
                  ..resource(subscribe: false, listChanged: true)
                  ..prompt(listChanged: true),
          )
          ..logging()
          ..instructions =
              'This is a simple MCP echo server that demonstrates basic functionality.'
          ..tool(
            (t) =>
                t
                  ..name = 'echo'
                  ..description = 'Echoes back a message.'
                  ..string(
                    name: 'message',
                    required: true,
                    description: 'Message to echo back',
                  )
                  ..handler = (request) async {
                    try {
                      final message = request.arguments['message'] as String;
                      print('Received echo request: "$message"');
                      return CallToolResult.text('Echo: $message');
                    } catch (e) {
                      print('Error in echo tool: $e');
                      return CallToolResult.error(
                        'Error processing echo request: $e',
                      );
                    }
                  },
          ),
  );
}

/// Common client logic to connect and use the echo tool.
Future<void> connectAndUseEchoTool(StreamClient client) async {
  print('Connecting to server...');

  // Initialize the connection
  final initResult = await client.initialize(
    InitializeRequest(
      clientInfo: Implementation(
        name: 'Dart MCP Echo Client',
        version: '1.0.0',
      ),
      protocolVersion: latestProtocolVersion,
      capabilities: ClientCapabilities(),
    ),
  );

  // Connect to the transport first
  await client.connect();

  print(
    'Connected to server: ${initResult.serverInfo.name} ${initResult.serverInfo.version}',
  );

  // List available tools
  print('Requesting available tools...');
  final toolsResult = await client.listTools(ListToolsRequest());

  print('Available tools: ${toolsResult.tools.map((t) => t.name).join(', ')}');

  // Try calling the echo tool
  final echoTool = toolsResult.tools.where((t) => t.name == 'echo').firstOrNull;

  if (echoTool != null) {
    print('Calling echo tool...');

    // Call the echo tool multiple times with different messages
    for (final message in [
      'Hello, MCP!',
      'Echo test message',
      'Final echo test',
    ]) {
      final echoResult = await client.callTool(
        CallToolRequest(name: 'echo', arguments: {'message': message}),
      );

      // Display the result
      final resultText =
          echoResult.content.firstWhere(
                (c) => c is TextContent,
                orElse: () => TextContent(text: 'No text response'),
              )
              as TextContent;

      print('Echo result: ${resultText.text}');

      // Brief pause between calls
      await Future.delayed(Duration(milliseconds: 300));
    }
  } else {
    print('Echo tool not found');
  }

  print('Echo client operations completed successfully');
}
