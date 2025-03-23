import 'dart:async';

import 'package:flutter/material.dart';
import 'package:memo_app/screens/home_screen.dart';
import 'package:memo_app/services/api_server.dart';
import 'package:memo_app/services/memo_service.dart';
import 'package:signals/signals.dart';

/// Application entry point
void main() {
  runApp(const MyApp());
}

/// Application root widget
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  /// Memo service
  late final MemoService _memoService;

  /// API server
  late final ApiServer _apiServer;

  /// Connection status with MCP server
  final connectionStatus = signal<ConnectionStatus>(
    ConnectionStatus.disconnected,
  );

  /// Connection check timer
  Timer? _connectionTimer;

  @override
  void initState() {
    super.initState();

    // Initialize services
    _memoService = MemoService();
    _apiServer = ApiServer(memoService: _memoService);

    // Create sample data
    _createSampleData();

    // Start server
    _startServer();

    // Periodic connection status check
    _connectionTimer = Timer.periodic(
      const Duration(seconds: 5),
      _checkConnection,
    );
  }

  @override
  void dispose() {
    _connectionTimer?.cancel();
    _apiServer.stop();
    super.dispose();
  }

  /// Create sample data
  void _createSampleData() {
    _memoService.createMemo(
      title: 'Sample Memo 1',
      content: 'This is a sample memo. Try editing it.',
    );

    _memoService.createMemo(
      title: 'Integration procedure with Claude Desktop',
      content: '''
1. Open Claude Desktop settings file
2. Add MemoMCP to mcpServers section
3. Specify executable file path as command
4. Restart Claude Desktop
5. Check connection status with MCP server from this app
''',
    );
  }

  /// Start server
  Future<void> _startServer() async {
    try {
      await _apiServer.start();
      connectionStatus.value = ConnectionStatus.disconnected;
    } catch (e) {
      print('Failed to start API server: $e');
    }
  }

  /// Check connection status
  void _checkConnection(Timer timer) {
    final lastPing = _apiServer.lastPingTime;
    if (lastPing == null) {
      connectionStatus.value = ConnectionStatus.disconnected;
      return;
    }

    final elapsed = DateTime.now().difference(lastPing);
    if (elapsed.inSeconds > 60) {
      connectionStatus.value = ConnectionStatus.disconnected;
    } else {
      connectionStatus.value = ConnectionStatus.connected;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MemoApp',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: HomeScreen(
        memoService: _memoService,
        connectionStatus: connectionStatus,
      ),
    );
  }
}
