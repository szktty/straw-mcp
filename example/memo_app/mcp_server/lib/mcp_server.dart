/// MCP Server Library
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:logging/logging.dart';
import 'package:straw_mcp/straw_mcp.dart';

import 'src/api_client.dart';
import 'src/resources.dart';
import 'src/tools.dart';

/// Build and run an MCP server (served via standard input/output)
///
/// This function builds the server and serves it via standard input/output.
/// There is no need to call `serveStdio` separately.
Future<void> runServer({
  required String apiUrl,
  Level logLevel = Level.INFO,
  Duration pingInterval = const Duration(seconds: 30),
  Duration waitInterval = const Duration(seconds: 5),
  Duration? maxWaitDuration,
}) async {
  // Logger configuration
  Logger.root.level = logLevel;
  Logger.root.onRecord.listen((record) {
    stderr.writeln('${record.time}: ${record.level.name}: ${record.message}');
  });

  final logger = Logger('MemoMCP');
  logger.info('Starting the server...');
  logger.info('API endpoint: $apiUrl');

  if (maxWaitDuration != null) {
    logger.info('Maximum wait time: ${maxWaitDuration.inSeconds} seconds');
  } else {
    logger.info('Maximum wait time: unlimited');
  }

  // Create MCP server
  final handler = ProtocolHandler('memo-mcp', '1.0.0', [
    withToolCapabilities(listChanged: true),
    withResourceCapabilities(subscribe: false, listChanged: true),
    withLogging(),
    withInstructions(
      'This MCP server provides integration with the memo application.',
    ),
  ]);

  // Initialize API client (with wait mode support)
  final apiClient = ApiClient(
    baseUrl: apiUrl,
    logger: logger,
    waitInterval: waitInterval,
    maxWaitDuration: maxWaitDuration,
  );

  // Send initial message as log notification
  handler.logInfo(
    'MemoMCP server started. Attempting to connect to MemoApp...',
  );

  // Register tools and resources
  final tools = MemoTools(apiClient);
  tools.register(handler);

  final resources = MemoResources(apiClient);
  resources.register(handler);

  // Periodic connection check (after connection is established)
  Timer? pingTimer;

  apiClient.stateStream.listen((state) {
    if (state == ServerState.connected) {
      // Start ping timer when connection is established
      pingTimer?.cancel();
      pingTimer = Timer.periodic(pingInterval, (_) async {
        try {
          await apiClient.ping();
        } catch (e) {
          logger.warning('Error during periodic connection check: $e');
        }
      });
    } else if (state == ServerState.terminating) {
      // Stop timer when terminating
      pingTimer?.cancel();
    }
  });

  // Start the server
  logger.info('MCP server ready');

  // MCP protocol communication via standard input/output (custom implementation here)
  try {
    // Function to process JSON-RPC messages
    Future<void> handleJsonRpcMessage(String line) async {
      try {
        // Process message
        final response = await handler.handleMessage(line);
        if (response != null) {
          // If there's a response, write it to standard output
          stdout.writeln(response);
          await stdout.flush();
        }
      } catch (e, stackTrace) {
        logger.severe(
          'Error while processing JSON-RPC message: $e\n$stackTrace',
        );
      }
    }

    // Process each line of standard input asynchronously
    // Use LineSplitter to process line by line
    final stdinLines = stdin
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    // Use Completer to detect termination
    final completer = Completer<void>();

    // Subscription for standard input processing
    StreamSubscription<String>? subscription;

    subscription = stdinLines.listen(
      // Process when receiving data
      (line) async {
        try {
          await handleJsonRpcMessage(line);
        } catch (e) {
          logger.severe('Error while processing line: $e');
        }
      },
      // Process on error
      onError: (e, stackTrace) {
        logger.severe('Error while reading standard input: $e\n$stackTrace');
        if (!completer.isCompleted) {
          completer.completeError(e, stackTrace);
        }
      },
      // Process on completion
      onDone: () {
        logger.info('Standard input closed (client may have terminated)');
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      // Process on cancel
      cancelOnError: false,
    );

    // Set up termination handling
    completer.future
        .then((_) async {
          logger.info(
            'Shutting down the server because standard input was closed',
          );

          // Clean up resources
          subscription?.cancel();
          pingTimer?.cancel();

          // Close the API client
          await apiClient.close();

          // Close the server
          handler.close();

          // Terminate the process (with a slight delay to allow remaining processing to complete)
          Timer(const Duration(seconds: 1), () {
            logger.info('Terminating the process');
            exit(0);
          });
        })
        .catchError((e, stackTrace) {
          logger.severe(
            'Shutting down the server due to error: $e\n$stackTrace',
          );

          // Clean up resources
          subscription?.cancel();
          pingTimer?.cancel();
          apiClient.close();
          handler.close();

          // Terminate the process
          exit(1);
        });

    // Do not block the main thread
    // The server continues to run in the background
    logger.info('MCP communication started (via standard input/output)');
  } catch (e, stackTrace) {
    logger.severe('Error while starting server: $e\n$stackTrace');

    // Clean up resources
    pingTimer?.cancel();
    await apiClient.close();
    handler.close();

    // Re-throw exception
    rethrow;
  }
}

/// コマンドライン引数をパース
ArgResults parseArgs(List<String> args) {
  final parser =
      ArgParser()
        ..addOption(
          'api-url',
          abbr: 'a',
          help: 'MemoAppのAPIエンドポイントURL',
          defaultsTo: 'http://localhost:8888/api',
        )
        ..addOption(
          'log-level',
          abbr: 'l',
          help:
              'ログレベル (all, finest, finer, fine, config, info, warning, severe, shout, off)',
          defaultsTo: 'info',
        )
        ..addOption(
          'ping-interval',
          abbr: 'p',
          help: 'APIサーバーへのping間隔（秒）',
          defaultsTo: '30',
        )
        ..addOption(
          'wait-interval',
          abbr: 'w',
          help: '接続試行間隔（秒）',
          defaultsTo: '5',
        )
        ..addOption(
          'max-wait',
          abbr: 'm',
          help: '最大待機時間（秒）。0は無制限',
          defaultsTo: '0',
        )
        ..addFlag('help', abbr: 'h', help: 'ヘルプを表示', negatable: false);

  try {
    final results = parser.parse(args);
    if (results['help'] as bool) {
      stdout.writeln('MemoMCP - メモアプリMCPサーバー');
      stdout.writeln('');
      stdout.writeln('使用方法: memo_mcp [options]');
      stdout.writeln('');
      stdout.writeln(parser.usage);
      exit(0);
    }
    return results;
  } catch (e) {
    stderr.writeln('引数のパースに失敗しました: $e');
    stderr.writeln('');
    stderr.writeln(parser.usage);
    exit(1);
  }
}

/// ログレベル文字列をLevelに変換
Level parseLogLevel(String levelStr) {
  switch (levelStr.toLowerCase()) {
    case 'all':
      return Level.ALL;
    case 'finest':
      return Level.FINEST;
    case 'finer':
      return Level.FINER;
    case 'fine':
      return Level.FINE;
    case 'config':
      return Level.CONFIG;
    case 'info':
      return Level.INFO;
    case 'warning':
      return Level.WARNING;
    case 'severe':
      return Level.SEVERE;
    case 'shout':
      return Level.SHOUT;
    case 'off':
      return Level.OFF;
    default:
      return Level.INFO;
  }
}
