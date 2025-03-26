import 'package:straw_mcp/src/mcp/contents.dart';
import 'package:straw_mcp/src/mcp/tools.dart';
import 'package:straw_mcp/src/mcp/types.dart';
import 'package:test/test.dart';

// ignore_for_file: avoid_print, avoid_dynamic_calls

void main() {
  group('Tool Definition Tests', () {
    test('Tool class correctly generates inputSchema', () {
      final tool = Tool(
        name: 'calculator',
        description: 'Calculator function',
        inputSchema: [
          ToolParameter(name: 'a', type: 'number', required: true),
          ToolParameter(name: 'b', type: 'number', required: true),
          ToolParameter(name: 'operation', type: 'string', required: true),
        ],
      );

      final json = tool.toJson();

      expect(json['name'], equals('calculator'));
      expect(json['description'], equals('Calculator function'));
      expect(json['inputSchema'], isNotNull);
      expect(json['inputSchema']['type'], equals('object'));
      expect(json['inputSchema']['properties'], isA<Map>());
      expect(json['inputSchema']['properties']['a'], isA<Map>());
      expect(json['inputSchema']['properties']['a']['type'], equals('number'));
      expect(json['inputSchema']['required'], contains('a'));
      expect(json['inputSchema']['required'], contains('b'));
      expect(json['inputSchema']['required'], contains('operation'));
    });

    test('ToolParameter toJson implementation is correct', () {
      final param = ToolParameter(
        name: 'count',
        type: 'number',
        required: true,
        description: 'Number of items',
        enumValues: ['1', '2', '3'],
        defaultValue: 1,
      );

      final json = param.toJson();

      expect(json['name'], equals('count'));
      expect(json['type'], equals('number'));
      expect(json['required'], isTrue);
      expect(json['description'], equals('Number of items'));
      expect(json['enum'], equals(['1', '2', '3']));
      expect(json['default'], equals(1));
    });

    test('newTool function correctly generates a tool', () {
      final tool = newTool('searcher', [
        withDescription('Search function'),
        withString('query', [required(), description('Search keyword')]),
        withNumber('limit', [description('Result limit'), defaultValue(10)]),
        withBoolean('exact', [
          description('Exact match search'),
          defaultValue(false),
        ]),
      ]);

      expect(tool.name, equals('searcher'));
      expect(tool.description, equals('Search function'));
      expect(tool.inputSchema.length, equals(3));

      final queryParam = tool.inputSchema.firstWhere((p) => p.name == 'query');
      expect(queryParam.type, equals('string'));
      expect(queryParam.required, isTrue);

      final limitParam = tool.inputSchema.firstWhere((p) => p.name == 'limit');
      expect(limitParam.type, equals('number'));
      expect(limitParam.defaultValue, equals(10));

      final json = tool.toJson();
      expect(
        json['inputSchema']['properties']['exact']['type'],
        equals('boolean'),
      );
      expect(
        json['inputSchema']['properties']['exact']['default'],
        equals(false),
      );
    });

    test('Tool.fromJson correctly restores a tool', () {
      final originalTool = Tool(
        name: 'translator',
        description: 'Translation function',
        inputSchema: [
          ToolParameter(
            name: 'text',
            type: 'string',
            required: true,
            description: 'Text to translate',
          ),
          ToolParameter(
            name: 'source',
            type: 'string',
            required: false,
            description: 'Source language',
          ),
          ToolParameter(
            name: 'target',
            type: 'string',
            required: true,
            description: 'Target language',
          ),
        ],
      );

      final json = originalTool.toJson();
      final restoredTool = Tool.fromJson(json);

      expect(restoredTool.name, equals(originalTool.name));
      expect(restoredTool.description, equals(originalTool.description));
      expect(
        restoredTool.inputSchema.length,
        equals(originalTool.inputSchema.length),
      );

      final textParam = restoredTool.inputSchema.firstWhere(
        (p) => p.name == 'text',
      );
      expect(textParam.type, equals('string'));
      expect(textParam.required, isTrue);

      final sourceParam = restoredTool.inputSchema.firstWhere(
        (p) => p.name == 'source',
      );
      expect(sourceParam.required, isFalse);
    });
  });

  group('Tool Execution Result Tests', () {
    test('CallToolResult correctly handles content as an array', () {
      final result = CallToolResult(
        content: [
          TextContent(text: 'Test result'),
          TextContent(text: 'Additional information'),
        ],
      );

      final json = result.toJson();

      expect(json['content'], isA<List>());
      expect(json['content'].length, equals(2));
      expect(json['content'][0]['type'], equals('text'));
      expect(json['content'][0]['text'], equals('Test result'));
      expect(json['content'][1]['text'], equals('Additional information'));
      expect(
        json.containsKey('isError'),
        isFalse,
      ); // isError is not included by default
    });

    test('CallToolResult.fromJson correctly restores results', () {
      final jsonData = {
        'content': [
          {'type': 'text', 'text': 'Calculation result: 42'},
          {'type': 'text', 'text': 'Processing completed'},
        ],
        'isError': false,
      };

      final result = CallToolResult.fromJson(jsonData);

      expect(result.content.length, equals(2));
      expect(result.content[0], isA<TextContent>());
      expect(
        (result.content[0] as TextContent).text,
        equals('Calculation result: 42'),
      );
      expect(result.isError, isFalse);
    });

    test('Error results are correctly generated', () {
      final result = CallToolResult(
        content: [TextContent(text: 'An error occurred')],
        isError: true,
      );

      final json = result.toJson();

      expect(json['isError'], isTrue);
      expect(json['content'][0]['text'], equals('An error occurred'));
    });

    test('newToolResultText function correctly generates results', () {
      final result = newToolResultText('Test result');

      expect(result.content.length, equals(1));
      expect(result.content[0], isA<TextContent>());
      expect((result.content[0] as TextContent).text, equals('Test result'));
      expect(result.isError, isFalse);
    });

    test('newToolResultError function correctly generates error results', () {
      final result = newToolResultError('Error message');

      expect(result.content.length, equals(1));
      expect(result.content[0], isA<TextContent>());
      expect((result.content[0] as TextContent).text, equals('Error message'));
      expect(result.isError, isTrue);
    });
  });

  group('Composite Tests', () {
    test('Tool call request-response flow', () {
      // Create a tool call request
      final request = CallToolRequest(
        name: 'calculator',
        arguments: {'a': 5, 'b': 3, 'operation': 'add'},
      );

      // Check the request JSON
      expect(request.method, equals('tools/call'));
      expect(request.name, equals('calculator'));
      expect(request.params['arguments'], isA<Map>());
      expect(request.params['arguments']['a'], equals(5));
      expect(request.params['arguments']['b'], equals(3));

      // Convert to JsonRpc request
      final jsonRpcRequest = JsonRpcRequest('2.0', 1, request.params, request);

      // Simulate server-side processing
      final result = CallToolResult(content: [TextContent(text: '8')]);

      // Convert to JsonRpc response
      final jsonRpcResponse = JsonRpcResponse('2.0', 1, result.toJson());

      // Check response JSON format
      final responseJson = jsonRpcResponse.toJson();
      expect(responseJson['jsonrpc'], equals('2.0'));
      expect(responseJson['id'], equals(1));
      expect(responseJson['result']['content'][0]['type'], equals('text'));
      expect(responseJson['result']['content'][0]['text'], equals('8'));
    });

    test('Tool results containing various content types', () {
      // Generate results containing multiple content types
      final result = CallToolResult(
        content: [
          TextContent(text: 'Text result'),
          ImageContent(data: 'base64data', mimeType: 'image/png'),
          // Add EmbeddedResource if needed
        ],
      );

      final json = result.toJson();

      expect(json['content'].length, equals(2));
      expect(json['content'][0]['type'], equals('text'));
      expect(json['content'][1]['type'], equals('image'));
      expect(json['content'][1]['data'], equals('base64data'));
      expect(json['content'][1]['mimeType'], equals('image/png'));
    });

    test('Verification of ListToolsResult implementation', () {
      final tools = [
        Tool(name: 'tool1', description: 'Tool 1'),
        Tool(name: 'tool2', description: 'Tool 2'),
      ];

      final result = ListToolsResult(tools: tools);
      final json = result.toJson();

      expect(json['tools'], isA<List>());
      expect(json['tools'].length, equals(2));
      expect(json['tools'][0]['name'], equals('tool1'));
      expect(json['tools'][1]['name'], equals('tool2'));

      final restored = ListToolsResult.fromJson(json);
      expect(restored.tools.length, equals(2));
      expect(restored.tools[0].name, equals('tool1'));
      expect(restored.tools[1].name, equals('tool2'));
    });
  });
}
