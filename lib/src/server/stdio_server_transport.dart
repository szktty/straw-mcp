/// Standard input/output server implementation for the MCP protocol.
///
/// This file provides an implementation of an MCP server that communicates
/// via standard input/output streams, suitable for command-line applications
/// and integration with other processes.
library;

import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:straw_mcp/src/server/server.dart';
import 'package:straw_mcp/src/server/stream_server_transport.dart';

/// MCP server implementation that communicates via standard input/output.
class StdioServerTransport extends StreamServerTransport {
  /// Creates a new stdio-based MCP server.
  ///
  /// This is a specialized server transport that uses standard input/output
  /// for communication, and includes signal handling for graceful shutdown.
  ///
  /// - [server]: The MCP server to wrap
  /// - [logger]: Optional logger for error messages
  /// - [contextFunction]: Optional function to customize client context
  /// - [logFilePath]: Optional path to a log file for recording server events
  StdioServerTransport(
    Server server, {
    Logger? logger,
    StreamServerTransportContextFunction? contextFunction,
    String? logFilePath,
  }) : super(
         server,
         options: StreamServerTransportOptions.stdio(
           logger: logger,
           contextFunction: contextFunction,
           logFilePath: logFilePath,
         ),
       );

  @override
  IOSink get sink => stdout;

  @override
  Future<void> start() async {
    // シャットダウン処理のセットアップ
    final shutdownCompleter = Completer<void>();
    final log = logger ?? Logger('StdioServerTransport');

    // stdinのクローズを検出するためのリスナー
    final stdinSubscription = stream.listen(
      (_) {
        // データ処理はStreamServerTransportに任せる
      },
      onDone: () async {
        log.info('stdin stream closed, shutting down');
        try {
          await server.close();
          await close();

          if (!shutdownCompleter.isCompleted) {
            shutdownCompleter.complete();
          }
        } catch (e) {
          log.severe('Error during shutdown: $e');
          if (!shutdownCompleter.isCompleted) {
            shutdownCompleter.completeError(e);
          }
        }
      },
      onError: (Object error) {
        log.severe('Error on stdin: $error');
        if (!shutdownCompleter.isCompleted) {
          shutdownCompleter.completeError(error);
        }
      },
    );

    // シグナルハンドラーのセットアップ
    StreamSubscription<ProcessSignal>? sigintSubscription;
    StreamSubscription<ProcessSignal>? sigtermSubscription;

    sigintSubscription = ProcessSignal.sigint.watch().listen((_) async {
      log.info('Received SIGINT, shutting down');
      try {
        await server.close();
        await close();
        await sigintSubscription?.cancel();
        await sigtermSubscription?.cancel();
        exit(0);
      } catch (e) {
        log.severe('Error during SIGINT shutdown: $e');
        exit(1);
      }
    });

    sigtermSubscription = ProcessSignal.sigterm.watch().listen((_) async {
      log.info('Received SIGTERM, shutting down');
      try {
        await server.close();
        await close();
        await sigintSubscription?.cancel();
        await sigtermSubscription?.cancel();
        exit(0);
      } on Exception catch (e) {
        log.severe('Error during SIGTERM shutdown: $e');
        exit(1);
      }
    });

    // サーバーの状態を監視
    server.closeState.listen((isClosed) {
      if (isClosed && !shutdownCompleter.isCompleted) {
        log.info('Server requested shutdown');
        shutdownCompleter.complete();
      }
    });

    // スーパークラスのstart()を呼び出し（元々のlisten()に相当）
    await super.start();

    // シャットダウンが完了するまで待機
    await shutdownCompleter.future;

    // リソースの解放
    try {
      await sigintSubscription.cancel();
      await sigtermSubscription.cancel();
      await stdinSubscription.cancel();

      // 最終的な終了ログ
      log.info('MCP server completely shut down');
    } catch (e) {
      log.severe('Error during final cleanup: $e');
    }
  }

  @override
  Future<void> flushOutput() async {
    await stdout.flush();
  }
}
