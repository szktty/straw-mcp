/// ロギング機能を提供するmixin
///
/// このmixinはサーバーやトランスポートクラスにロギング機能を提供します。
/// LoggingOptionsを使用して設定を受け取り、ファイルログとロガーの両方に
/// メッセージを出力する機能を一元管理します。
library;

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' show dirname;
import 'package:straw_mcp/src/shared/logging/logging_options.dart';

/// @nodoc
/// ロギング機能を提供するmixin
mixin LoggingMixin {
  /// @nodoc
  /// ロギングオプション
  LoggingOptions get loggingOptions;

  /// @nodoc
  /// ロガー
  Logger? get logger => loggingOptions.logger;

  /// @nodoc
  /// ログファイルパス
  String? get logFilePath => loggingOptions.logFilePath;

  /// ログファイル出力用のIOSink
  IOSink? _logFile;

  /// ログファイルが初期化済みかどうか
  bool _logFileInitialized = false;

  /// @nodoc
  /// ログファイルの初期化
  ///
  /// ログファイルパスが指定されている場合、そのパスにファイルを開きます。
  /// 親ディレクトリが存在しない場合は作成します。
  void initializeLogFile() {
    if (_logFileInitialized || logFilePath == null) {
      return;
    }

    try {
      final logDir = Directory(dirname(logFilePath!));
      if (!logDir.existsSync()) {
        logDir.createSync(recursive: true);
      }
      final logFileObj = File(logFilePath!);
      _logFile = logFileObj.openWrite(mode: FileMode.append);
      log('Initialized log file at $logFilePath');
      _logFileInitialized = true;
    } on Exception catch (e) {
      logError('Failed to open log file at $logFilePath: $e');
    }
  }

  /// @nodoc
  /// エラーレベルのログを出力します
  ///
  /// ロガーとログファイル（設定されている場合）の両方に出力します。
  void logError(String message) {
    logger?.severe(message);
    _writeToLogFile('[ERROR] $message');
  }

  /// @nodoc
  /// 警告レベルのログを出力します
  ///
  /// ロガーとログファイル（設定されている場合）の両方に出力します。
  void logWarning(String message) {
    logger?.warning(message);
    _writeToLogFile('[WARNING] $message');
  }

  /// @nodoc
  /// 情報レベルのログを出力します
  ///
  /// ロガーとログファイル（設定されている場合）の両方に出力します。
  void log(String message) {
    logger?.info(message);
    _writeToLogFile('[INFO] $message');
  }

  /// @nodoc
  /// デバッグレベルのログを出力します
  ///
  /// ロガーとログファイル（設定されている場合）の両方に出力します。
  void logDebug(String message) {
    logger?.fine(message);
    _writeToLogFile('[DEBUG] $message');
  }

  /// @nodoc
  /// 情報レベルのログを出力します（logのエイリアス）
  ///
  /// Server クラスとの互換性のために提供
  void logInfo(String message) {
    log(message);
  }

  /// @nodoc
  /// ログファイルにメッセージを書き込みます
  ///
  /// ログファイルが設定されている場合のみ書き込みを行います。
  void _writeToLogFile(String message) {
    if (_logFile != null) {
      try {
        final timestamp = DateTime.now().toIso8601String();
        _logFile!.writeln('$timestamp $message');
      } on Exception catch (e) {
        // ログファイル書き込みのエラーを回避するために、ロガーだけに出力
        logger?.severe('Failed to write to log file: $e');
      }
    }
  }

  /// @nodoc
  /// ログファイルをフラッシュして閉じます
  ///
  /// ログファイルが開かれている場合のみ実行されます。
  Future<void> closeLogFile() async {
    if (_logFile != null) {
      try {
        await _logFile!.flush();
        await _logFile!.close();
        _logFile = null;
        logger?.info('Log file closed');
      } on Exception catch (e) {
        logger?.severe('Error closing log file: $e');
      }
    }
    _logFileInitialized = false;
  }
}
