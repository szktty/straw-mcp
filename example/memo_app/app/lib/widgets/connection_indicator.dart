import 'package:flutter/material.dart';
import 'package:memo_app/screens/home_screen.dart';
import 'package:signals/signals_flutter.dart';

/// MCP server connection status indicator
class ConnectionIndicator extends StatelessWidget {
  /// Constructor
  const ConnectionIndicator({required this.connectionStatus, super.key});

  /// Connection status
  final Signal<ConnectionStatus> connectionStatus;

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final status = connectionStatus.value;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color:
              status == ConnectionStatus.connected
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              status == ConnectionStatus.connected
                  ? Icons.check_circle
                  : Icons.error_outline,
              size: 16,
              color:
                  status == ConnectionStatus.connected
                      ? Colors.green
                      : Colors.red,
            ),
            const SizedBox(width: 4),
            Text(
              status == ConnectionStatus.connected
                  ? 'MCP Connected'
                  : 'MCP Disconnected',
              style: TextStyle(
                fontSize: 12,
                color:
                    status == ConnectionStatus.connected
                        ? Colors.green
                        : Colors.red,
              ),
            ),
          ],
        ),
      );
    });
  }
}
