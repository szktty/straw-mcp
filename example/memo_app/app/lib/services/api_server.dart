import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:memo_app/services/memo_service.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

/// Class that provides an HTTP API server
class ApiServer {
  /// Constructor
  ApiServer({required this.memoService, this.port = 8888});

  /// Server port
  final int port;

  /// Memo service
  final MemoService memoService;

  /// Last time a ping was received
  DateTime? _lastPingTime;

  /// HTTP Server
  HttpServer? _server;

  /// Start the server
  Future<void> start() async {
    // Create router
    final router = Router();

    // Ping endpoint
    router.get('/api/ping', _handlePing);

    // Get memo list
    router.get('/api/memos', _handleGetMemos);

    // Get specific memo
    router.get('/api/memos/<id>', _handleGetMemo);

    // Create memo
    router.post('/api/memos', _handleCreateMemo);

    // Delete memo
    router.delete('/api/memos/<id>', _handleDeleteMemo);

    // Middleware settings
    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_corsMiddleware())
        .addHandler(router.call);

    // Start server
    _server = await serve(handler, InternetAddress.loopbackIPv4, port);
    print('API server started: http://localhost:$port');
  }

  /// Stop the server
  Future<void> stop() async {
    await _server?.close();
    _server = null;
    print('API server stopped');
  }

  /// Get the last time a ping was received
  DateTime? get lastPingTime => _lastPingTime;

  // Handler implementations

  /// Ping handler
  Response _handlePing(Request request) {
    _lastPingTime = DateTime.now();
    return Response.ok(
      jsonEncode({
        'status': 'ok',
        'timestamp': DateTime.now().toIso8601String(),
      }),
      headers: {'content-type': 'application/json'},
    );
  }

  /// Memo list retrieval handler
  Response _handleGetMemos(Request request) {
    final memos = memoService.getMemos();
    return Response.ok(
      jsonEncode({
        'memos': memos.map((memo) => memo.toJson()).toList(),
        'count': memos.length,
      }),
      headers: {'content-type': 'application/json'},
    );
  }

  /// Specific memo retrieval handler
  Response _handleGetMemo(Request request, String id) {
    try {
      final memo = memoService.getMemo(id);
      return Response.ok(
        jsonEncode(memo.toJson()),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.notFound(
        jsonEncode({'error': 'Memo not found', 'id': id}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  /// Memo creation handler
  Future<Response> _handleCreateMemo(Request request) async {
    try {
      final jsonString = await request.readAsString();
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;

      if (!jsonMap.containsKey('title') ||
          jsonMap['title'].toString().isEmpty) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Title is required'}),
          headers: {'content-type': 'application/json'},
        );
      }

      final memo = memoService.createMemo(
        title: jsonMap['title'] as String,
        content: jsonMap['content'] as String? ?? '',
      );

      return Response(
        201,
        body: jsonEncode(memo.toJson()),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'An internal error occurred: $e'}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  /// Memo deletion handler
  Response _handleDeleteMemo(Request request, String id) {
    try {
      memoService.deleteMemo(id);
      return Response.ok(
        jsonEncode({'id': id, 'status': 'deleted'}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.notFound(
        jsonEncode({'error': 'Memo not found', 'id': id}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  /// CORS middleware
  Middleware _corsMiddleware() {
    return (Handler handler) {
      return (Request request) async {
        final response = await handler(request);
        return response.change(
          headers: {
            ...response.headers,
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Origin, Content-Type',
          },
        );
      };
    };
  }
}
