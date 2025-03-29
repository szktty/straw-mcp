import 'package:straw_mcp/straw_mcp.dart';

import 'api_client.dart';

/// Implementation of MemoApp resources
class MemoResources {
  /// API client
  final ApiClient apiClient;

  /// Constructor
  MemoResources(this.apiClient);

  /// Register resources
  void register(Server server) {
    // memo://list resource
    server.addResource(
      Resource(
        uri: 'memo://list',
        name: 'Memo List',
        description: 'Displays a list of saved memos',
        mimeType: 'text/plain',
      ),
      _handleMemoListResource,
    );
  }

  /// Generate message for waiting state
  String _getWaitingStateContent() {
    final now = DateTime.now();
    final startTime = now.subtract(
      Duration(
        seconds: apiClient.reconnectAttempts * apiClient.waitInterval.inSeconds,
      ),
    );
    final elapsedMinutes = now.difference(startTime).inMinutes;

    final buffer = StringBuffer();
    buffer.writeln('# Waiting for MemoApp connection');
    buffer.writeln();
    buffer.writeln(
      'Currently waiting for connection to MemoApp. Please check if the app is running.',
    );
    buffer.writeln();
    buffer.writeln('**Connection state:** ${apiClient.state}');
    buffer.writeln(
      '**Connection attempts:** ${apiClient.reconnectAttempts} times',
    );

    if (elapsedMinutes > 0) {
      buffer.writeln('**Waiting time:** About $elapsedMinutes minutes');
    }

    buffer.writeln();
    buffer.writeln(
      'The connection will be established automatically when MemoApp starts.',
    );
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();
    buffer.writeln(
      'Next connection attempt in: within ${apiClient.waitInterval.inSeconds} seconds',
    );

    if (apiClient.maxWaitDuration != null) {
      final remainingTime =
          apiClient.maxWaitDuration! - now.difference(startTime);
      if (remainingTime.isNegative) {
        buffer.writeln('Exceeded maximum wait time. Will exit soon.');
      } else {
        final remainingMinutes = remainingTime.inMinutes;
        final remainingSeconds = remainingTime.inSeconds % 60;
        buffer.writeln(
          'Time remaining until maximum wait time: $remainingMinutes minutes $remainingSeconds seconds',
        );
      }
    }

    return buffer.toString();
  }

  /// memo://list resource handler
  Future<List<ResourceContents>> _handleMemoListResource(
    ReadResourceRequest request,
  ) async {
    try {
      // Check connection state
      if (apiClient.state != ServerState.connected) {
        // Return dummy resource displaying waiting information
        return [
          TextResourceContents(
            uri: 'memo://list',
            text: _getWaitingStateContent(),
            mimeType: 'text/plain',
          ),
        ];
      }

      final memos = await apiClient.getMemos();

      final buffer = StringBuffer('# Memo List\n\n');

      for (int i = 0; i < memos.length; i++) {
        final memo = memos[i];
        buffer.writeln('${i + 1}. ${memo['title']}');
        buffer.writeln('   ID: ${memo['id']}');
        buffer.writeln('   Created at: ${memo['createdAt']}');
        buffer.writeln();
      }

      buffer.writeln('There are a total of ${memos.length} memos.');

      return [
        TextResourceContents(
          uri: 'memo://list',
          text: buffer.toString(),
          mimeType: 'text/plain',
        ),
      ];
    } catch (e) {
      // Display waiting message in case of ApiNotConnectedException
      if (e is ApiNotConnectedException) {
        return [
          TextResourceContents(
            uri: 'memo://list',
            text: _getWaitingStateContent(),
            mimeType: 'text/plain',
          ),
        ];
      }

      // Display error message for other errors
      return [
        TextResourceContents(
          uri: 'memo://list',
          text: 'Failed to retrieve memo list: $e',
          mimeType: 'text/plain',
        ),
      ];
    }
  }
}
