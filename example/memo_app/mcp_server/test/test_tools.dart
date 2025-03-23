// MemoApp MCPサーバーのツールをテストするクライアント

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

import 'package:logging/logging.dart';
import 'package:straw_mcp/straw_mcp.dart';
import 'package:test/test.dart';

/// Test API (Mock Server)
class MockApiServer {
  HttpServer? _server;
  final int port;
  final Logger logger = Logger('MockApiServer');

  // Holds created memos
  final List<Map<String, dynamic>> _memos = [];

  MockApiServer({this.port = 8888});

  /// Start the server
  Future<void> start() async {
    logger.info('Starting mock API server (port: $port)...');

    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    logger.info('Server started: http://localhost:$port');

    _server!.listen((HttpRequest request) async {
      logger.fine('Request: ${request.method} ${request.uri.path}');

      final pathSegments = request.uri.pathSegments;

      // Add CORS headers
      request.response.headers.add('Access-Control-Allow-Origin', '*');
      request.response.headers.add(
        'Access-Control-Allow-Methods',
        'GET, POST, DELETE, OPTIONS',
      );
      request.response.headers.add(
        'Access-Control-Allow-Headers',
        'Origin, Content-Type',
      );

      // Handle OPTIONS request
      if (request.method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.ok;
        await request.response.close();
        return;
      }

      switch (request.method) {
        case 'GET':
          if (pathSegments.isEmpty || pathSegments.last == 'api') {
            // Root path
            request.response.statusCode = HttpStatus.ok;
            request.response.write('MemoApp API Mock Server');
          } else if (pathSegments.contains('ping')) {
            // ping endpoint
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode({
                'status': 'ok',
                'timestamp': DateTime.now().toIso8601String(),
              }),
            );
          } else if (pathSegments.contains('memos')) {
            if (pathSegments.length > 2) {
              // Get individual memo
              final id = pathSegments.last;
              final memo = _memos.firstWhere(
                (m) => m['id'] == id,
                orElse: () => {},
              );

              if (memo.isEmpty) {
                request.response.statusCode = HttpStatus.notFound;
                request.response.headers.contentType = ContentType.json;
                request.response.write(
                  jsonEncode({'error': 'Memo not found', 'id': id}),
                );
              } else {
                request.response.statusCode = HttpStatus.ok;
                request.response.headers.contentType = ContentType.json;
                request.response.write(jsonEncode(memo));
              }
            } else {
              // Get memo list
              request.response.statusCode = HttpStatus.ok;
              request.response.headers.contentType = ContentType.json;
              request.response.write(
                jsonEncode({'memos': _memos, 'count': _memos.length}),
              );
            }
          } else {
            // Unknown path
            request.response.statusCode = HttpStatus.notFound;
            request.response.write('Not Found');
          }
          break;

        case 'POST':
          if (pathSegments.contains('memos')) {
            // Create memo
            final body = await utf8.decoder.bind(request).join();
            final data = jsonDecode(body) as Map<String, dynamic>;
            final title = data['title'] as String?;
            final content = data['content'] as String?;

            if (title == null || title.isEmpty) {
              request.response.statusCode = HttpStatus.badRequest;
              request.response.headers.contentType = ContentType.json;
              request.response.write(jsonEncode({'error': 'タイトルは必須です'}));
            } else {
              final memo = {
                'id': _generateId(),
                'title': title,
                'content': content ?? '',
                'createdAt': DateTime.now().toIso8601String(),
              };

              _memos.add(memo);

              request.response.statusCode = HttpStatus.created;
              request.response.headers.contentType = ContentType.json;
              request.response.write(jsonEncode(memo));
            }
          } else {
            // 不明なパス
            request.response.statusCode = HttpStatus.notFound;
            request.response.write('Not Found');
          }
          break;
        case 'DELETE':
          if (pathSegments.contains('memos') && pathSegments.length > 2) {
            // Delete memo
            final id = pathSegments.last;
            final index = _memos.indexWhere((m) => m['id'] == id);

            if (index < 0) {
              request.response.statusCode = HttpStatus.notFound;
              request.response.headers.contentType = ContentType.json;
              request.response.write(
                jsonEncode({'error': 'Memo not found', 'id': id}),
              );
            } else {
              _memos.removeAt(index);

              request.response.statusCode = HttpStatus.ok;
              request.response.headers.contentType = ContentType.json;
              request.response.write(
                jsonEncode({'id': id, 'status': 'deleted'}),
              );
            }
          } else {
            // Unknown path
            request.response.statusCode = HttpStatus.notFound;
            request.response.write('Not Found');
          }
          break;

        default:
          // Unsupported method
          request.response.statusCode = HttpStatus.methodNotAllowed;
          request.response.write('Method Not Allowed');
      }

      await request.response.close();
    });
  }

  /// Stop the server
  Future<void> stop() async {
    logger.info('Stopping mock API server...');
    await _server?.close();
    logger.info('Server stopped');
  }

  /// Generate unique ID
  String _generateId() {
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    final prefix = 'memo-';
    return '$prefix$random';
  }
}

/// Class to debug MCP communication
class DebugClient {
  final Logger logger = Logger('McpDebugClient');
  final int apiPort;

  Process? _mcpProcess;
  Client? _mcpClient;
  IOSink? _debugLogSink;

  DebugClient({this.apiPort = 8888});

  /// Initialize log file
  void initLogFile(String path) {
    try {
      final file = File(path);
      _debugLogSink = file.openWrite(mode: FileMode.append);

      try {
        _debugLogSink?.writeln(
          '=== MCP Test Session Start (${DateTime.now()}) ===',
        );
      } catch (e) {
        logger.warning('Initial log write error: $e');
      }
    } catch (e) {
      logger.severe('Failed to open log file: $e');
      _debugLogSink = null; // Disable logging if failed
    }
  }

  /// Write to log file
  void _logToFile(String message) {
    try {
      _debugLogSink?.writeln('${DateTime.now().toIso8601String()}: $message');
    } catch (e) {
      logger.warning('Log file write error: $e');
    }
  }

  /// Start MCP server process
  Future<void> startServer(String serverPath) async {
    logger.info('Starting MCP server...');

    final apiUrl = 'http://localhost:$apiPort/api';
    logger.info('API URL: $apiUrl');

    // Start server process
    _mcpProcess = await Process.start('dart', [
      serverPath,
      '--api-url=$apiUrl',
      '--log-level=fine',
    ]);

    logger.info('Server process started: PID ${_mcpProcess!.pid}');

    // Monitor error output
    _mcpProcess!.stderr.transform(utf8.decoder).listen((data) {
      for (final line in data.split('\n')) {
        if (line.trim().isNotEmpty) {
          logger.info('Server log: $line');
          _logToFile('SERVER LOG: $line');
        }
      }
    });

    // Prepare to read standard output
    final stdoutController = StreamController<List<int>>();
    _mcpProcess!.stdout.listen((data) {
      stdoutController.sink.add(data);

      // Log raw data for debugging
      final decoded = utf8.decode(data, allowMalformed: true);
      for (final line in decoded.split('\n')) {
        if (line.trim().isNotEmpty) {
          _logToFile('SERVER OUTPUT: ${line.replaceAll('\r', '\\r')}');
        }
      }
    });

    // Create client
    _mcpClient = StreamClient(
      options: StreamClientOptions(
        outputSink: IOSink(_mcpProcess!.stdin),
        inputStream: stdoutController.stream,
      ),
    );

    // Client connection is no longer needed
    logger.info('MCP client connection complete');

    // Initialization request
    logger.info('Initializing MCP server...');
    final initResult = await _mcpClient!.initialize(
      InitializeRequest(
        protocolVersion: '2024-11-05',
        capabilities: ClientCapabilities(roots: null, sampling: null),
        clientInfo: Implementation(name: 'mcp-test-client', version: '1.0.0'),
      ),
    );

    logger.info(
      'Initialization complete: ${initResult.serverInfo.name} ${initResult.serverInfo.version}',
    );
    _logToFile('Server name: ${initResult.serverInfo.name}');
    _logToFile('Version: ${initResult.serverInfo.version}');
    _logToFile('Capabilities: ${json.encode(initResult.capabilities)}');

    // Wait for server initialization
    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// Retrieve the list of tools
  Future<List<Tool>> getTools() async {
    if (_mcpClient == null) {
      throw Exception('MCP client is not initialized');
    }

    logger.info('Retrieving tool list...');

    try {
      final result = await _mcpClient!.listTools(ListToolsRequest());

      for (final tool in result.tools) {
        try {
          _logToFile('Tool: ${tool.name}');
          _logToFile('  Description: ${tool.description ?? "None"}');
          try {
            final schema = tool.toJson()['inputSchema'];
            _logToFile(
              '  Schema: ${schema != null ? json.encode(schema) : "None"}',
            );
          } catch (e) {
            _logToFile('  Failed to retrieve schema: $e');
          }
        } catch (e) {
          logger.warning('Error logging tool information: $e');
        }
      }

      return result.tools;
    } catch (e, stackTrace) {
      logger.severe('Error retrieving tool list: $e');
      logger.fine('Stack trace: $stackTrace');
      _logToFile('Failed to retrieve tool list: $e');

      // Return an empty list
      return [];
    }
  }

  /// Call a tool
  Future<CallToolResult> callTool(
    String name,
    Map<String, dynamic> args,
  ) async {
    if (_mcpClient == null) {
      throw Exception('MCP client is not initialized');
    }

    logger.info('Calling tool: $name, Arguments: $args');
    _logToFile('Calling tool: $name');
    _logToFile('Arguments: ${json.encode(args)}');

    try {
      final result = await _mcpClient!.callTool(
        CallToolRequest(name: name, arguments: args),
      );

      _logToFile('Tool result:');
      if (result.isError == true) {
        _logToFile('  Error: true');
      }

      if (result.content.isNotEmpty) {
        for (final content in result.content) {
          if (content is TextContent) {
            _logToFile('  Text: ${content.text}');
          } else {
            _logToFile('  Other content: ${content.runtimeType}');
          }
        }
      } else {
        _logToFile('  No result');
      }

      return result;
    } catch (e, stackTrace) {
      logger.severe('Error calling tool: $e');
      logger.fine('Stack trace: $stackTrace');
      _logToFile('Error calling tool: $e');
      _logToFile('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Retrieve the list of resources
  Future<List<Resource>> getResources() async {
    if (_mcpClient == null) {
      throw Exception('MCP client is not initialized');
    }

    logger.info('Retrieving resource list...');
    final result = await _mcpClient!.listResources(ListResourcesRequest());

    for (final resource in result.resources) {
      _logToFile('Resource: ${resource.uri}');
      _logToFile('  Name: ${resource.name}');
      _logToFile('  Description: ${resource.description ?? "None"}');
      _logToFile('  MIME type: ${resource.mimeType ?? "Unknown"}');
    }

    return result.resources;
  }

  /// Read a resource
  Future<ReadResourceResult> readResource(String uri) async {
    if (_mcpClient == null) {
      throw Exception('MCP client is not initialized');
    }

    logger.info('Reading resource: $uri');
    _logToFile('Reading resource: $uri');

    try {
      final result = await _mcpClient!.readResource(
        ReadResourceRequest(uri: uri),
      );

      _logToFile('Resource content:');
      for (final content in result.contents) {
        _logToFile('  URI: ${content.uri}');
        _logToFile('  MIME type: ${content.mimeType ?? "Unknown"}');

        if (content is TextResourceContents) {
          final text = content.text;
          _logToFile(
            '  Text: ${text.length > 200 ? "${text.substring(0, 200)}..." : text}',
          );
        } else if (content is BlobResourceContents) {
          _logToFile('  Binary data: ${content.blob.length} bytes');
        }
      }

      return result;
    } catch (e, stackTrace) {
      logger.severe('Error reading resource: $e');
      logger.fine('Stack trace: $stackTrace');
      _logToFile('Error reading resource: $e');
      _logToFile('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Clean up resources
  Future<void> cleanup() async {
    logger.info('Cleaning up...');

    try {
      if (_mcpClient != null) {
        await _mcpClient!.close();
        logger.info('Closed MCP client');
      }
    } catch (e) {
      logger.warning('Error closing MCP client: $e');
    }

    try {
      if (_mcpProcess != null) {
        _mcpProcess!.kill();
        logger.info('Terminated MCP server process');
      }
    } catch (e) {
      logger.warning('Error terminating MCP server process: $e');
    }

    try {
      if (_debugLogSink != null) {
        try {
          _debugLogSink!.writeln(
            '=== MCP Test Session End (${DateTime.now()}) ===',
          );
        } catch (e) {
          logger.warning('Log write error: $e');
        }

        try {
          await _debugLogSink!.close();
        } catch (e) {
          logger.warning('Log file close error: $e');
        }
        _debugLogSink = null;
      }
    } catch (e) {
      logger.warning('Log file management error: $e');
    }
  }
}

/// Main test function
void main() async {
  // Logger settings
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  final logger = Logger('ToolsTest');

  // Mock API server
  final apiServer = MockApiServer();

  // MCP debug client
  final mcpClient = DebugClient(apiPort: apiServer.port);

  // Get the path to the current script and build the path to the server script
  final currentScriptPath = Platform.script.toFilePath();
  // Get the directory of the current script (test directory)
  final testDir = Directory(path.dirname(currentScriptPath));
  // Navigate to the bin directory (../bin from test directory)
  final serverPath = path.join(testDir.parent.path, 'bin', 'mcp_server.dart');
  
  print('Using server path: $serverPath');

  // Path to the log file
  final logPath = 'mcp_tools_test_${DateTime.now().millisecondsSinceEpoch}.log';

  try {
    // Set up log file
    mcpClient.initLogFile(logPath);

    // Start mock API server
    await apiServer.start();

    // Test group
    group('MemoMCP Tool Tests', () {
      // Setup
      setUpAll(() async {
        // Start MCP server
        await mcpClient.startServer(serverPath);

        // Wait for confirmation of startup
        await Future.delayed(const Duration(seconds: 1));
      });

      // Cleanup
      tearDownAll(() async {
        // Clean up resources
        await mcpClient.cleanup();
        await apiServer.stop();
      });

      // Test: Retrieve tool list
      test('Can retrieve tool list', () async {
        final tools = await mcpClient.getTools();

        expect(tools, isNotEmpty);
        expect(
          tools.map((t) => t.name),
          containsAll(['create-memo', 'list-memos', 'delete-memo']),
        );
      });

      // Test: Retrieve resource list
      test('Can retrieve resource list', () async {
        final resources = await mcpClient.getResources();

        expect(resources, isNotEmpty);
        expect(resources.map((r) => r.uri), contains('memo://list'));
      });

      // Test: create-memo tool
      test('Can create memo with create-memo', () async {
        final result = await mcpClient.callTool('create-memo', {
          'title': 'Test Memo',
          'content': 'This is a test memo.',
        });

        expect(result.isError, isFalse); // No error
        expect(result.content, isNotEmpty);

        if (result.content.isNotEmpty && result.content.first is TextContent) {
          final text = (result.content.first as TextContent).text;
          expect(text, contains('Memo created'));
          expect(text, contains('Test Memo'));
          expect(text, contains('ID:'));
        } else {
          fail('No text content found');
        }
      });

      // Test: list-memos tool
      test('Can retrieve memo list with list-memos', () async {
        final result = await mcpClient.callTool('list-memos', {});

        expect(result.isError, isFalse); // No error
        expect(result.content, isNotEmpty);

        if (result.content.isNotEmpty && result.content.first is TextContent) {
          final text = (result.content.first as TextContent).text;
          expect(text, contains('Memo List'));
          expect(text, contains('Test Memo'));
        } else {
          fail('No text content found');
        }
      });

      // Test: Read resource
      test('Can read memo://list resource', () async {
        final result = await mcpClient.readResource('memo://list');

        expect(result.contents, isNotEmpty);

        if (result.contents.isNotEmpty &&
            result.contents.first is TextResourceContents) {
          final text = (result.contents.first as TextResourceContents).text;
          expect(text, contains('# Memo List'));
          expect(text, contains('Test Memo'));
        } else {
          fail('No text content found');
        }
      });

      // Test: delete-memo tool (ID required)
      test('Can delete memo with delete-memo', () async {
        // First, retrieve ID with list-memos
        final listResult = await mcpClient.callTool('list-memos', {});

        expect(listResult.content, isNotEmpty);

        String? memoId;
        if (listResult.content.isNotEmpty &&
            listResult.content.first is TextContent) {
          final text = (listResult.content.first as TextContent).text;
          final match = RegExp(r'ID: ([a-zA-Z0-9-]+)').firstMatch(text);

          if (match != null && match.groupCount >= 1) {
            memoId = match.group(1);
          }
        }

        expect(memoId, isNotNull, reason: 'Failed to retrieve memo ID');

        if (memoId != null) {
          final result = await mcpClient.callTool('delete-memo', {
            'id': memoId,
          });

          expect(result.isError, isFalse); // No error
          expect(result.content, isNotEmpty);

          if (result.content.isNotEmpty &&
              result.content.first is TextContent) {
            final text = (result.content.first as TextContent).text;
            expect(text, contains('Memo deleted'));
            expect(text, contains('ID: $memoId'));
          } else {
            fail('No text content found');
          }
        }
      });
    });
  } catch (e, stackTrace) {
    logger.severe('Error occurred during test execution: $e');
    logger.fine('Stack trace: $stackTrace');

    // Attempt cleanup
    try {
      await mcpClient.cleanup();
    } catch (cleanupError) {
      logger.warning('Secondary error during cleanup: $cleanupError');
    }

    try {
      await apiServer.stop();
    } catch (stopError) {
      logger.warning('Error stopping server: $stopError');
    }

    rethrow;
  }
}
