import 'package:straw_mcp/straw_mcp.dart';

import 'api_client.dart';

/// Implementation of MemoApp tools
class MemoTools {
  /// API client
  final ApiClient apiClient;

  /// Constructor
  MemoTools(this.apiClient);

  /// Register tools
  void register(ProtocolHandler handler) {
    // create-memo tool
    handler.addTool(
      newTool('create-memo', [
        withDescription('Creates a new memo'),
        withString('title', [required(), description('Title of the memo')]),
        withString('content', [description('Content of the memo')]),
      ]),
      _handleCreateMemo,
    );

    // list-memos tool
    handler.addTool(
      newTool('list-memos', [
        withDescription('Retrieves a list of saved memos'),
      ]),
      _handleListMemos,
    );

    // delete-memo tool
    handler.addTool(
      newTool('delete-memo', [
        withDescription('Deletes a memo with the specified ID'),
        withString('id', [required(), description('ID of the memo to delete')]),
      ]),
      _handleDeleteMemo,
    );

    // Monitor API client state changes
    apiClient.stateStream.listen((state) {
      if (state == ServerState.connected) {
        handler.logInfo('Connected to MemoApp');
      } else if (state == ServerState.reconnecting) {
        handler.logWarning(
          'Disconnected from MemoApp. Attempting to reconnect...',
        );
      } else if (state == ServerState.waiting) {
        if (apiClient.reconnectAttempts > 1 &&
            apiClient.reconnectAttempts % 5 == 0) {
          handler.logInfo(
            'Waiting for connection to MemoApp (attempts: ${apiClient.reconnectAttempts})',
          );
        }
      }
    });
  }

  /// Generate error message for waiting state
  String _getWaitingStateMessage() {
    return '''
Waiting for connection to MemoApp (attempts: ${apiClient.reconnectAttempts})

MemoApp may not be running. Please start the app and try again.
Automatic reconnection attempts will continue until the connection is established.
''';
  }

  /// create-memo tool handler
  Future<CallToolResult> _handleCreateMemo(CallToolRequest request) async {
    try {
      // Check connection state
      if (apiClient.state != ServerState.connected) {
        return newToolResultError(_getWaitingStateMessage());
      }

      final args = request.params['arguments'] as Map<String, dynamic>;
      final title = args['title'] as String;
      final content = args['content'] as String? ?? '';

      final memo = await apiClient.createMemo(title: title, content: content);

      return newToolResultText('''
Memo created:
Title: ${memo['title']}
ID: ${memo['id']}
''');
    } catch (e) {
      if (e is ApiNotConnectedException) {
        return newToolResultError(_getWaitingStateMessage());
      }
      return newToolResultError('Failed to create memo: $e');
    }
  }

  /// list-memos tool handler
  Future<CallToolResult> _handleListMemos(CallToolRequest request) async {
    try {
      // Check connection state
      if (apiClient.state != ServerState.connected) {
        return newToolResultError(_getWaitingStateMessage());
      }

      final memos = await apiClient.getMemos();

      if (memos.isEmpty) {
        return newToolResultText('No memos found.');
      }

      final buffer = StringBuffer('Memo list:\n');

      for (final memo in memos) {
        buffer.writeln('- ${memo['title']} (ID: ${memo['id']})');
      }

      buffer.writeln('\nTotal ${memos.length} memos found.');

      return newToolResultText(buffer.toString());
    } catch (e) {
      if (e is ApiNotConnectedException) {
        return newToolResultError(_getWaitingStateMessage());
      }
      return newToolResultError('Failed to retrieve memo list: $e');
    }
  }

  /// delete-memo tool handler
  Future<CallToolResult> _handleDeleteMemo(CallToolRequest request) async {
    try {
      // Check connection state
      if (apiClient.state != ServerState.connected) {
        return newToolResultError(_getWaitingStateMessage());
      }

      final args = request.params['arguments'] as Map<String, dynamic>;
      final id = args['id'] as String;

      await apiClient.deleteMemo(id);

      return newToolResultText('''
Memo deleted:
ID: $id
''');
    } catch (e) {
      if (e is ApiNotConnectedException) {
        return newToolResultError(_getWaitingStateMessage());
      }
      return newToolResultError('Failed to delete memo: $e');
    }
  }
}
