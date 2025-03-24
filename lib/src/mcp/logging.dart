/// Logging-related types and functions for the MCP protocol.
library;

import 'package:straw_mcp/src/client/client.dart' show LoggingLevel;
import 'package:straw_mcp/src/mcp/types.dart';

/// Notification of a log message from server to client.
///
/// This notification is used to send log messages from the server to the client.
/// The severity of the message is specified by the [level] property.
class LoggingMessageNotification extends Notification {
  /// Creates a new logging message notification.
  ///
  /// - [level]: The severity level of the log message
  /// - [data]: The data to be logged (can be any JSON-serializable value)
  /// - [logger]: Optional name of the logger issuing this message
  LoggingMessageNotification({
    required LoggingLevel level,
    required Object data,
    String? logger,
  }) : super(
         'notifications/message',
         NotificationParams(
           additionalFields: {
             'level': level.toString(),
             'data': data,
             if (logger != null) 'logger': logger,
           },
         ),
       );
}
