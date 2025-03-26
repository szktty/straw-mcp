/// Example of a simple MCP server implementation with SSE transport.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:straw_mcp/straw_mcp.dart';

/// Runs a simple MCP server with basic functionality exposed via SSE transport.
void main() async {
  // Configure logging
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    print('${record.time}: ${record.level.name}: ${record.message}');
  });

  final logger = Logger('SSE-Server');

  // Create a server instance
  final handler = ProtocolHandler('SimpleServer', '1.0.0', [
    withResourceCapabilities(subscribe: true, listChanged: true),
    withPromptCapabilities(listChanged: true),
    withToolCapabilities(listChanged: true),
    withLogging(),
    withInstructions(
      'This is a simple MCP server example using SSE transport.',
    ),
  ]);

  // Add a dynamic text resource that changes over time
  handler.addResource(
    Resource(
      uri: 'resource://example/hello',
      name: 'Hello Resource',
      description: 'A dynamic hello world resource that changes over time',
      mimeType: 'text/plain',
    ),
    (request) async {
      await Future.delayed(
        const Duration(milliseconds: 100),
      ); // Simulate async operation
      final timestamp = DateTime.now().toString();
      return [
        TextResourceContents(
          uri: 'resource://example/hello',
          text: 'Hello, World!\nTimestamp: $timestamp',
          mimeType: 'text/plain',
        ),
      ];
    },
  );

  // Add a binary resource example
  handler.addResource(
    Resource(
      uri: 'resource://example/binary',
      name: 'Binary Resource',
      description: 'A simple binary data resource',
      mimeType: 'application/octet-stream',
    ),
    (request) async {
      await Future.delayed(
        const Duration(milliseconds: 100),
      ); // Simulate async operation

      // Generate some random binary data
      final random = Random();
      final bytes = List<int>.generate(128, (_) => random.nextInt(256));
      final base64Data = base64Encode(bytes);

      return [
        BlobResourceContents(
          uri: 'resource://example/binary',
          blob: base64Data,
          mimeType: 'application/octet-stream',
        ),
      ];
    },
  );

  // Add multiple tools
  handler.addTool(
    newTool('echo', [
      withString('message', [required(), description('Message to echo')]),
    ]),
    (request) async {
      final args = request.params['arguments'] as Map<String, dynamic>;
      final message = args['message'] as String;

      await Future.delayed(
        const Duration(milliseconds: 100),
      ); // Simulate async operation

      logger.info('Executing echo tool with message: "$message"');
      return newToolResultText('Echo: $message');
    },
  );

  handler.addTool(
    newTool('calculate', [
      withNumber('a', [required(), description('First number')]),
      withNumber('b', [required(), description('Second number')]),
      withString('operation', [
        required(),
        description('Operation to perform (add, subtract, multiply, divide)'),
      ]),
    ]),
    (request) async {
      final args = request.params['arguments'] as Map<String, dynamic>;
      final a = args['a'] as num;
      final b = args['b'] as num;
      final operation = args['operation'] as String;

      await Future.delayed(
        const Duration(milliseconds: 100),
      ); // Simulate async operation

      logger.info('Executing calculate tool: $a $operation $b');

      try {
        double result;
        switch (operation.toLowerCase()) {
          case 'add':
            result = (a + b).toDouble();
          case 'subtract':
            result = (a - b).toDouble();
          case 'multiply':
            result = (a * b).toDouble();
          case 'divide':
            if (b == 0) {
              return newToolResultError('Cannot divide by zero');
            }
            result = a / b;
          default:
            return newToolResultError(
              'Unknown operation. Supported operations: add, subtract, multiply, divide',
            );
        }

        return newToolResultText('Result of $a $operation $b = $result');
      } catch (e) {
        logger.warning('Error in calculate tool: $e');
        return newToolResultError('Calculation error: $e');
      }
    },
  );

  // Add multiple prompts
  handler.addPrompt(
    Prompt(
      name: 'greet',
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
      final args = request.params['arguments'] as Map<String, dynamic>?;
      final name = args?['name'] as String? ?? 'Guest';

      logger.info('Generating greet prompt for name: $name');
      await Future.delayed(
        const Duration(milliseconds: 100),
      ); // Simulate async operation

      return GetPromptResult(
        title: 'A personalized greeting',
        messages: [
          PromptMessage(
            role: Role.assistant,
            content: TextContent(
              text:
                  'Hello, $name! Welcome to the MCP handler. How can I assist you today?',
            ),
          ),
        ],
      );
    },
  );

  handler.addPrompt(
    Prompt(
      name: 'code_review',
      description: 'A prompt for code review',
      arguments: [
        PromptArgument(
          name: 'code',
          description: 'Code to review',
          required: true,
        ),
        PromptArgument(
          name: 'language',
          description: 'Programming language',
          required: false,
        ),
      ],
    ),
    (request) async {
      final args = request.params['arguments'] as Map<String, dynamic>?;
      final code = args?['code'] as String? ?? '';
      final language = args?['language'] as String? ?? 'unknown';

      logger.info('Generating code review prompt for $language code');
      await Future.delayed(
        const Duration(milliseconds: 100),
      ); // Simulate async operation

      return GetPromptResult(
        title: 'Code review suggestions',
        messages: [
          PromptMessage(
            role: Role.user,
            content: TextContent(
              text:
                  'Please review this $language code:\n\n```$language\n$code\n```',
            ),
          ),
          PromptMessage(
            role: Role.assistant,
            content: TextContent(
              text:
                  'I will review your $language code. Here are my initial thoughts...',
            ),
          ),
        ],
      );
    },
  );

  // Periodically update resource to demonstrate notifications
  Timer.periodic(const Duration(seconds: 10), (_) {
    // Only send notification if we have subscriptions
    // In a real server, you would track subscriptions and only notify when needed
    logger.info('Sending resource update notification');

    // Send notification that the resource has changed
    try {
      handler.sendNotification(
        ResourceUpdatedNotification(uri: 'resource://example/hello'),
      );
      logger.info('Resource update notification sent');
    } catch (e) {
      logger.warning('Failed to send resource update notification: $e');
    }
  });

  // Start the HTTP server with SSE support
  final sseServer = serveSse(
    handler,
    options: SseServerOptions(host: 'localhost', port: 8888, logger: logger),
  );

  logger.info('Server started at http://localhost:8888');
  logger.info('Press Ctrl+C to stop the server');

  // Handle termination
  ProcessSignal.sigint.watch().listen((_) {
    logger.info('Shutting down handler...');
    sseServer.stop().then((_) {
      exit(0);
    });
  });

  await sseServer.start();
}
