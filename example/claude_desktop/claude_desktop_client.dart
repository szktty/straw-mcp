/// Client implementation for testing MCP server for Claude Desktop
library;

import 'dart:io';
import 'package:straw_mcp/straw_mcp.dart';

/// Run an interactive MCP client
void main() async {
  const port = 8888;
  const url = 'http://localhost:$port';

  print('Connecting to Claude Desktop MCP server...');
  print('Server URL: $url');

  // Create client instance
  final client = SseClient(url);

  try {
    // Initialize connection
    final initResult = await client.initialize(
      InitializeRequest(
        clientInfo: Implementation(
          name: 'ClaudeDesktopTestClient',
          version: '1.0.0',
        ),
        protocolVersion: '1.0',
        capabilities: ClientCapabilities(),
      ),
    );

    print('\nConnection successful!');
    print(
      'Server name: ${initResult.serverInfo.name} ${initResult.serverInfo.version}',
    );
    print('Protocol version: ${initResult.protocolVersion}');

    if (initResult.instructions != null) {
      print('\nServer description:');
      print('${initResult.instructions}');
    }

    // List available tools
    final toolsResult = await client.listTools(ListToolsRequest());
    print('\nAvailable tools:');
    for (final tool in toolsResult.tools) {
      print('- ${tool.name}');
    }

    // Test each tool
    print('\n\n==== Tool Testing ====');

    // Test calculator tool
    print('\nTesting calculator tool:');
    final calcResult = await client.callTool(
      CallToolRequest(
        name: 'calculate',
        arguments: {'expression': '2 * (3 + 4)'},
      ),
    );
    print(calcResult.content);

    // Test date/time tool
    print('\nTesting date/time tool:');
    final dateResult = await client.callTool(
      CallToolRequest(name: 'getCurrentDateTime', arguments: {}),
    );
    print(dateResult.content);

    // Test unit conversion tool
    print('\nTesting unit conversion tool:');
    final convResult = await client.callTool(
      CallToolRequest(
        name: 'convertUnit',
        arguments: {
          'value': 100,
          'fromUnit': 'cm',
          'toUnit': 'm',
          'type': 'length',
        },
      ),
    );
    print(convResult.content);

    // Test weather tool
    print('\nTesting weather tool:');
    final weatherResult = await client.callTool(
      CallToolRequest(name: 'getWeather', arguments: {'city': 'Tokyo'}),
    );
    print(weatherResult.content);

    // Test memo functionality
    print('\nTesting memo functionality:');

    // Save memo
    print('Saving memo:');
    final saveResult = await client.callTool(
      CallToolRequest(
        name: 'saveMemo',
        arguments: {
          'id': 'test-memo',
          'content': 'This is a test memo.\nTesting MCP server functionality.',
        },
      ),
    );
    print(saveResult.content);

    // Get memo list
    print('\nRetrieving memo list:');
    final listResult = await client.callTool(
      CallToolRequest(name: 'listMemos', arguments: {}),
    );
    print(listResult.content);

    // Get memo content
    print('\nRetrieving memo content:');
    final getMemoResult = await client.callTool(
      CallToolRequest(name: 'getMemo', arguments: {'id': 'test-memo'}),
    );
    print(getMemoResult.content);

    // Test resources
    print('\n\n==== Resource Testing ====');

    // List available resources
    final resourcesResult = await client.listResources(ListResourcesRequest());
    print('\nAvailable resources:');
    for (final resource in resourcesResult.resources) {
      print('- ${resource.name}: ${resource.uri}');
    }

    // Read current time resource
    print('\nReading current time resource:');
    final timeResourceResult = await client.readResource(
      ReadResourceRequest(uri: 'resource://claude/current-time'),
    );

    for (final content in timeResourceResult.contents) {
      if (content is TextResourceContents) {
        print('Time: ${content.text}');
      }
    }

    // Read memo resource
    print('\nReading memo resource:');
    final memoResourceResult = await client.readResource(
      ReadResourceRequest(uri: 'resource://claude/memo/test-memo'),
    );

    for (final content in memoResourceResult.contents) {
      if (content is TextResourceContents) {
        print('Memo content:\n${content.text}');
      }
    }

    // Test prompts
    print('\n\n==== Prompt Testing ====');

    // List available prompts
    final promptsResult = await client.listPrompts(ListPromptsRequest());
    print('\nAvailable prompts:');
    for (final prompt in promptsResult.prompts) {
      print('- ${prompt.name}: ${prompt.description}');
    }

    // Test greeting prompt
    print('\nTesting greeting prompt:');
    final promptResult = await client.getPrompt(
      GetPromptRequest(name: 'greeting', arguments: {'name': 'Test User'}),
    );

    print('Title: ${promptResult.title}');
    for (final message in promptResult.messages) {
      if (message.content is TextContent) {
        print('Message:\n${(message.content as TextContent).text}');
      }
    }

    // Close connection
    print('\n\nTest completed. Closing connection...');
    await client.close();
    print('Finished.');
  } catch (e) {
    print('An error occurred: $e');
    await client.close();
    exit(1);
  }
}
