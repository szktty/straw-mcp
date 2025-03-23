/// Example of a simple MCP client implementation using SSE transport.
library;

import 'package:logging/logging.dart';
import 'package:straw_mcp/straw_mcp.dart';

/// Runs a simple MCP client that connects to a local server using SSE.
void main() async {
  // Configure logging
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.message}');
  });

  // Create client options
  final options = SseClientOptions(
    logger: Logger('SseClient'),
    connectionTimeout: const Duration(seconds: 10),
    eventTimeout: const Duration(minutes: 2),
    maxRetries: 3,
  );

  // Create a client instance
  final client = SseClient('http://localhost:8888', options: options);

  try {
    // Connect to the server
    print('Connecting to server...');
    await client.connect();

    // Initialize connection
    print('Initializing connection...');
    final initResult = await client.initialize(
      InitializeRequest(
        clientInfo: Implementation(name: 'SimpleClient', version: '1.0.0'),
        protocolVersion: latestProtocolVersion,
        capabilities: ClientCapabilities(),
      ),
    );

    print(
      'Connected to server: ${initResult.serverInfo.name} ${initResult.serverInfo.version}',
    );
    print('Protocol version: ${initResult.protocolVersion}');

    if (initResult.instructions != null) {
      print('Server instructions: ${initResult.instructions}');
    }

    // Setup notification handler
    client.onNotification((notification) {
      print('\nReceived notification: ${notification.notification.method}');
    });

    // List resources
    print('\nListing resources...');
    final resourcesResult = await client.listResources(ListResourcesRequest());
    for (final resource in resourcesResult.resources) {
      print('  - ${resource.name}: ${resource.uri}');
    }

    // Read a resource
    if (resourcesResult.resources.isNotEmpty) {
      final resourceUri = resourcesResult.resources.first.uri;
      print('\nReading resource: $resourceUri');
      final readResult = await client.readResource(
        ReadResourceRequest(uri: resourceUri),
      );

      for (final content in readResult.contents) {
        if (content is TextResourceContents) {
          print('  Content: ${content.text}');
        } else if (content is BlobResourceContents) {
          print(
            '  Binary content: ${content.mimeType} (${content.blob.length} bytes)',
          );
        }
      }

      // Subscribe to resource if subscription is supported
      try {
        print('\nSubscribing to resource: $resourceUri');
        await client.subscribe(SubscribeRequest(uri: resourceUri));
        print('Successfully subscribed to resource');
        print('(Resource changes will be shown via notifications)');
      } catch (e) {
        print('  Resource subscription not supported: $e');
      }
    }

    // List tools
    print('\nListing tools...');
    final toolsResult = await client.listTools(ListToolsRequest());
    for (final tool in toolsResult.tools) {
      print('  - ${tool.name}: ${tool.description ?? "(No description)"}');
    }

    // Call a tool
    if (toolsResult.tools.isNotEmpty) {
      final toolName = toolsResult.tools.first.name;
      print('\nCalling tool: $toolName');
      final toolResult = await client.callTool(
        CallToolRequest(
          name: toolName,
          arguments: {'message': 'Hello from SSE client!'},
        ),
      );

      print('  Tool result:');
      for (final content in toolResult.content) {
        if (content is TextContent) {
          print('    ${content.text}');
        } else if (content is ImageContent) {
          print(
            '    Image content: ${content.mimeType} (${content.data.length} bytes)',
          );
        } else if (content is EmbeddedResource) {
          print('    Embedded resource: ${content.resource.uri}');
        }
      }

      if (toolResult.isError == true) {
        print('  Tool execution returned an error');
      }
    }

    // List prompts
    print('\nListing prompts...');
    final promptsResult = await client.listPrompts(ListPromptsRequest());
    for (final prompt in promptsResult.prompts) {
      print('  - ${prompt.name}: ${prompt.description ?? "(No description)"}');

      if (prompt.arguments != null && prompt.arguments!.isNotEmpty) {
        print('    Arguments:');
        for (final arg in prompt.arguments!) {
          print(
            '      ${arg.name}: ${arg.description ?? "(No description)"}' +
                (arg.required == true ? ' (required)' : ''),
          );
        }
      }
    }

    // Get a prompt
    if (promptsResult.prompts.isNotEmpty) {
      final promptName = promptsResult.prompts.first.name;
      print('\nGetting prompt: $promptName');
      final promptResult = await client.getPrompt(
        GetPromptRequest(name: promptName, arguments: {'name': 'User'}),
      );

      print('  Prompt title: ${promptResult.title}');
      print('  Messages:');
      for (final message in promptResult.messages) {
        final role = message.role;
        print('    $role:');

        if (message.content is TextContent) {
          print('      ${(message.content as TextContent).text}');
        } else if (message.content is ImageContent) {
          print(
            '      Image content: ${(message.content as ImageContent).mimeType}',
          );
        } else if (message.content is EmbeddedResource) {
          final resource = (message.content as EmbeddedResource).resource;
          print('      Embedded resource: ${resource.uri}');
          if (resource is TextResourceContents) {
            print(
              '        ${resource.text.substring(0, min(50, resource.text.length))}...',
            );
          }
        }
      }
    }

    // Ping the server
    print('\nPinging server...');
    await client.ping();
    print('Server responded to ping');

    // Close the connection
    print('\nClosing connection...');
    await client.close();
    print('Connection closed');
  } catch (e, stackTrace) {
    print('Error: $e');
    print('Stack trace: $stackTrace');
    await client.close();
  }
}

/// Returns the minimum of two integers.
int min(int a, int b) => a < b ? a : b;
