# StrawMCP: MCP Dart SDK

A Dart implementation of the Model Context Protocol (MCP), enabling seamless integration between Dart/Flutter applications and LLM services.

**Note**: This SDK is currently experimental and under active development. APIs are subject to change.

## Supported Features

Currently, the following features are supported:

* MCP client functionality (sending requests to MCP servers)
* MCP server functionality (implementing a server in Dart applications)
* Tool registration and execution
* Resource management
* Prompt management
* stdio communication (communication via standard input/output)
* HTTP+SSE communication (basic implementation)

## Documentation for LLMs

`doc/llms-full.txt` contains the full documentation for LLMs using the MCP Dart SDK.

## Installation

Install the package with the following command:

```
dart pub add straw_mcp
```

Or add the following to your `pubspec.yaml`:

```yaml
dependencies:
  straw_mcp: ^0.5.0  # Specify the latest version
```

## Examples

For detailed examples, please refer to the `example/` directory.

## Quick Start

### Implementing an MCP Server

```dart
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:straw_mcp/straw_mcp.dart';

void main() async {
  // Set up logging
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    stderr.writeln('${record.level.name}: ${record.time}: ${record.message}');
  });

  final logger = Logger('ServerExample');

  // Create a server
  final server = ProtocolHandler(
    'example-server', 
    '1.0.0', 
    [
      withToolCapabilities(listChanged: true),
      withResourceCapabilities(subscribe: false, listChanged: true),
      withPromptCapabilities(listChanged: true),
      withLogging(),
      withInstructions('This is an example MCP server with tools, resources, and prompts.'),
    ],
    logger,
  );
  
  // Add a tool
  server.addTool(
    newTool('calculator', [
      withDescription('Simple calculator'),
      withNumber('a', [required(), description('First operand')]),
      withNumber('b', [required(), description('Second operand')]),
      withString('operation', [
        required(),
        description('Operation to perform'),
        enumValues(['add', 'subtract', 'multiply', 'divide']),
      ]),
    ]),
    (request) async {
      final args = request.params['arguments'] as Map<String, dynamic>;
      final a = (args['a'] as num).toDouble();
      final b = (args['b'] as num).toDouble();
      final operation = args['operation'] as String;
      
      double result;
      switch (operation) {
        case 'add':
          result = a + b;
          break;
        case 'subtract':
          result = a - b;
          break;
        case 'multiply':
          result = a * b;
          break;
        case 'divide':
          if (b == 0) {
            return newToolResultError('Cannot divide by zero');
          }
          result = a / b;
          break;
        default:
          return newToolResultError('Unknown operation: $operation');
      }
      
      return newToolResultText('Result: $result');
    },
  );
  
  // Add a resource
  server.addResource(
    Resource(
      uri: 'example://greeting',
      name: 'Greeting',
      description: 'A simple greeting message',
      mimeType: 'text/plain',
    ),
    (request) async {
      return [
        TextResourceContents(
          uri: 'example://greeting',
          text: 'Hello, world!',
          mimeType: 'text/plain',
        ),
      ];
    },
  );
  
  // Add a prompt
  server.addPrompt(
    Prompt(
      name: 'simple-greeting',
      description: 'A simple greeting prompt',
      arguments: [
        PromptArgument(
          name: 'name',
          description: 'Name to greet',
          required: true,
        ),
      ],
    ),
    (request) async {
      final args = request.params['arguments'] as Map<String, dynamic>? ?? {};
      final name = args['name'] as String? ?? 'World';
      
      return GetPromptResult(
        messages: [
          PromptMessage(
            role: Role.user,
            content: TextContent(
              text: 'Please provide a warm greeting to $name.',
            ),
          ),
        ],
      );
    },
  );
  
  logger.info('Starting MCP server...');
  
  // Start the server
  await serveStdio(
    server,
    options: StreamServerOptions.stdio(logger: Logger('StreamServer')),
  );
}
```

### Using an MCP Client

```dart
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:straw_mcp/straw_mcp.dart';

Future<void> main() async {
  // Set up logging
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    stderr.writeln('${record.level.name}: ${record.time}: ${record.message}');
  });

  final logger = Logger('ClientExample');
  
  // Create a client
  final client = StreamClient(
    options: StreamClientOptions.stdio(logger: Logger('StreamClient')),
  );
  
  try {
    // Connect to the server
    logger.info('Connecting to MCP server...');
    await client.connect();
    
    // Initialize
    final initResult = await client.initialize(
      InitializeRequest(
        protocolVersion: latestProtocolVersion,
        capabilities: ClientCapabilities(),
        clientInfo: Implementation(
          name: 'example-client', 
          version: '1.0.0',
        ),
      ),
    );
    
    logger.info('Connected to server: ${initResult.serverInfo.name} ${initResult.serverInfo.version}');
    if (initResult.instructions != null) {
      logger.info('Server instructions: ${initResult.instructions}');
    }
    
    // Register notification handler
    client.onNotification((notification) {
      final method = notification.notification.method;
      logger.info('Received notification: $method');
    });
    
    // Get available tools
    logger.info('Requesting tools...');
    final toolsResult = await client.listTools(ListToolsRequest());
    logger.info('Available tools: ${toolsResult.tools.map((t) => t.name).join(', ')}');
    
    // Call a tool
    if (toolsResult.tools.any((t) => t.name == 'calculator')) {
      logger.info('Calling calculator tool...');
      final callResult = await client.callTool(
        CallToolRequest(
          name: 'calculator',
          arguments: {
            'a': 5,
            'b': 3,
            'operation': 'add',
          },
        ),
      );
      
      // Display the result
      for (final content in callResult.content) {
        if (content is TextContent) {
          logger.info('Calculator result: ${content.text}');
        }
      }
    }
    
    // Get available resources
    logger.info('Requesting resources...');
    final resourcesResult = await client.listResources(ListResourcesRequest());
    logger.info('Available resources: ${resourcesResult.resources.map((r) => r.uri).join(', ')}');
    
    // Read a resource
    if (resourcesResult.resources.any((r) => r.uri == 'example://greeting')) {
      logger.info('Reading greeting resource...');
      final readResult = await client.readResource(
        ReadResourceRequest(uri: 'example://greeting'),
      );
      
      for (final content in readResult.contents) {
        if (content is TextResourceContents) {
          logger.info('Resource content: ${content.text}');
        }
      }
    }
    
    // Get available prompts
    logger.info('Requesting prompts...');
    final promptsResult = await client.listPrompts(ListPromptsRequest());
    logger.info('Available prompts: ${promptsResult.prompts.map((p) => p.name).join(', ')}');
    
    // Get a prompt
    if (promptsResult.prompts.any((p) => p.name == 'simple-greeting')) {
      logger.info('Getting simple-greeting prompt...');
      final promptResult = await client.getPrompt(
        GetPromptRequest(
          name: 'simple-greeting',
          arguments: {'name': 'John'},
        ),
      );
      
      for (final message in promptResult.messages) {
        if (message.content is TextContent) {
          logger.info('Prompt message: ${(message.content as TextContent).text}');
        }
      }
    }
    
    // Close the client
    logger.info('Closing connection...');
    await client.close();
    logger.info('Connection closed');
  } catch (e) {
    logger.severe('Error: $e');
  }
}
```

## License

Apache License 2.0