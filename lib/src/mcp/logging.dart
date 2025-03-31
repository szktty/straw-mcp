import 'package:straw_mcp/src/mcp/types.dart';

/// The severity of a log message.
///
/// These map to syslog message severities, as specified in RFC-5424:
/// https://datatracker.ietf.org/doc/html/rfc5424#section-6.2.1
enum LoggingLevel {
  /// Debug-level message.
  /// Level 7: For debugging information.
  debug,

  /// Informational message.
  /// Level 6: For general information.
  info,

  /// Notice message.
  /// Level 5: For normal but significant conditions.
  notice,

  /// Warning message.
  /// Level 4: For warning conditions.
  warning,

  /// Error message.
  /// Level 3: For error conditions.
  error,

  /// Critical message.
  /// Level 2: For critical conditions.
  critical,

  /// Alert message.
  /// Level 1: For conditions that require immediate action.
  alert,

  /// Emergency message.
  /// Level 0: For system is unusable conditions.
  emergency;

  /// Convert the logging level to a string representation.
  @override
  String toString() => name;

  /// Convert the logging level from a string representation.
  static LoggingLevel fromString(String name) {
    return LoggingLevel.values.firstWhere(
      (level) => level.name == name,
      orElse: () => LoggingLevel.info,
    );
  }

  /// Get the numeric value of the logging level (0-7).
  int get value {
    // In RFC-5424, emergency is 0 and debug is 7, which is the reverse
    // of the enum order, so we need to invert the index.
    return LoggingLevel.values.length - 1 - index;
  }

  /// Check if this level is more severe than or equal to the given level.
  bool isAtLeastAsSevereAs(LoggingLevel other) {
    return value <= other.value;
  }
}

/// A request from the client to the server, to enable or adjust logging.
class SetLevelRequest extends Request {
  /// Create a new logging level request.
  ///
  /// Args:
  ///   level: The logging level to set
  SetLevelRequest(LoggingLevel level)
    : super(method: 'logging/setLevel', params: {'level': level.name});

  /// Creates a logging level request from a JSON map.
  factory SetLevelRequest.fromJson(Map<String, dynamic> json) {
    final params = json['params'] as Map<String, dynamic>;
    return SetLevelRequest(LoggingLevel.fromString(params['level'] as String));
  }
}

/// Notification of a log message passed from server to client.
class LoggingMessageNotification extends Notification {
  /// Create a new logging message notification.
  ///
  /// Args:
  ///   level: The severity of this log message
  ///   data: The data to be logged, such as a string message or an object
  ///   logger: An optional name of the logger issuing this message
  LoggingMessageNotification({
    required LoggingLevel level,
    required dynamic data,
    String? logger,
  }) : super(method: 'notifications/message', params: {
         'level': level.name,
         'data': data,
         if (logger != null) 'logger': logger,
       });

  /// Creates a logging message notification from a JSON map.
  factory LoggingMessageNotification.fromJson(Map<String, dynamic> json) {
    final params = json['params'] as Map<String, dynamic>;
    return LoggingMessageNotification(
      level: LoggingLevel.fromString(params['level'] as String),
      data: params['data'],
      logger: params['logger'] as String?,
    );
  }

  /// Create a builder for a logging message notification.
  static LoggingMessageNotificationBuilder builder() {
    return LoggingMessageNotificationBuilder();
  }
}

/// Builder for creating logging message notifications.
class LoggingMessageNotificationBuilder {
  /// The severity of the log message.
  LoggingLevel? _level;

  /// The data to be logged.
  dynamic _data;

  /// The name of the logger issuing the message.
  String? _logger;

  /// Set the severity level of the log message.
  LoggingMessageNotificationBuilder level(LoggingLevel level) {
    _level = level;
    return this;
  }

  /// Set the data to be logged.
  LoggingMessageNotificationBuilder data(dynamic data) {
    _data = data;
    return this;
  }

  /// Set the name of the logger issuing the message.
  LoggingMessageNotificationBuilder logger(String logger) {
    _logger = logger;
    return this;
  }

  /// Build the logging message notification.
  LoggingMessageNotification build() {
    if (_level == null) {
      throw ArgumentError('Level must be specified');
    }
    if (_data == null) {
      throw ArgumentError('Data must be specified');
    }

    return LoggingMessageNotification(
      level: _level!,
      data: _data,
      logger: _logger,
    );
  }
}
