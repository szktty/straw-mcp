import 'package:logging/logging.dart';

/// ロギング関連のオプションを提供するクラス
class LoggingOptions {
  /// Creates a new set of logging options.
  ///
  /// - [logger]: Optional logger for error messages
  /// - [logFilePath]: Optional path to a log file for recording server events
  const LoggingOptions({this.logger, this.logFilePath});

  /// Logger for error messages.
  final Logger? logger;

  /// Path to log file (optional)
  final String? logFilePath;
}
