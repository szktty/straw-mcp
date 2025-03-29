/// Standard input/output transport implementation for the MCP protocol.
///
/// This file provides an implementation of an MCP server that communicates
/// via standard input/output streams.
library;

import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:straw_mcp/src/server/stream_server_transport.dart';
import 'package:straw_mcp/src/shared/logging/logging_options.dart';
import 'package:straw_mcp/src/shared/transport.dart';

/// MCP server implementation that communicates via standard input/output streams.
///
/// This class extends [StreamServerTransport] to provide specific functionality
/// for stdio-based communication, including signal handling for graceful shutdown.
class StdioServerTransport extends StreamServerTransport {
  /// Creates a new stdio-based MCP server.
  ///
  /// - [logging]: Optional logging configuration for the transport
  StdioServerTransport({LoggingOptions logging = const LoggingOptions()})
    : super(
        options: StreamServerTransportOptions(
          stream: stdin.asBroadcastStream(),
          sink: stdout,
          logging: logging,
        ),
      );

  /// Subscriptions for process signals.
  StreamSubscription<ProcessSignal>? _sigintSubscription;
  StreamSubscription<ProcessSignal>? _sigtermSubscription;

  @override
  Future<void> flushOutput() async {
    await stdout.flush();
  }

  @override
  Future<void> start() async {
    // スーパークラスのstartメソッドを呼び出し
    await super.start();

    // シグナルハンドラーのセットアップ
    _setupSignalHandlers();
  }

  /// Sets up signal handlers for SIGINT and SIGTERM.
  ///
  /// This allows the server to gracefully shutdown when the process
  /// receives termination signals.
  void _setupSignalHandlers() {
    final log = logger ?? Logger('StdioServerTransport');

    // SIGINTハンドラー (Ctrl+C)
    _sigintSubscription = ProcessSignal.sigint.watch().listen((_) async {
      log.info('Received SIGINT, shutting down');
      try {
        await _cleanupAndExit(0);
      } catch (e) {
        log.severe('Error during SIGINT shutdown: $e');
        exit(1);
      }
    });

    // SIGTERMハンドラー
    _sigtermSubscription = ProcessSignal.sigterm.watch().listen((_) async {
      log.info('Received SIGTERM, shutting down');
      try {
        await _cleanupAndExit(0);
      } catch (e) {
        log.severe('Error during SIGTERM shutdown: $e');
        exit(1);
      }
    });

    this.log('Signal handlers set up');
  }

  /// Performs cleanup and exits the process.
  ///
  /// - [exitCode]: The exit code to use
  Future<void> _cleanupAndExit(int exitCode) async {
    // シグナルサブスクリプションをキャンセル
    await _sigintSubscription?.cancel();
    await _sigtermSubscription?.cancel();

    // トランスポートを閉じる
    await close();

    // プロセスを終了
    exit(exitCode);
  }

  @override
  Future<void> close() async {
    if (!isRunning) {
      return;
    }

    log('Closing stdio transport');

    // シグナルサブスクリプションをキャンセル
    await _sigintSubscription?.cancel();
    _sigintSubscription = null;

    await _sigtermSubscription?.cancel();
    _sigtermSubscription = null;

    // スーパークラスのcloseを呼び出す
    await super.close();
  }
}
