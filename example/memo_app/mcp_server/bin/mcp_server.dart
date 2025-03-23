#!/usr/bin/env dart

import 'dart:io';

import 'package:mcp_server/mcp_server.dart';

/// Main entry point
void main(List<String> args) async {
  try {
    // Parse arguments
    final parsedArgs = parseArgs(args);
    final apiUrl = parsedArgs['api-url'] as String;
    final logLevel = parseLogLevel(parsedArgs['log-level'] as String);
    final pingInterval = Duration(
      seconds: int.parse(parsedArgs['ping-interval'] as String),
    );
    final waitInterval = Duration(
      seconds: int.parse(parsedArgs['wait-interval'] as String),
    );

    // Maximum wait time
    final maxWaitSec = int.parse(parsedArgs['max-wait'] as String);
    Duration? maxWaitDuration;
    if (maxWaitSec > 0) {
      maxWaitDuration = Duration(seconds: maxWaitSec);
    }

    // Run server (including serving via standard input/output)
    await runServer(
      apiUrl: apiUrl,
      logLevel: logLevel,
      pingInterval: pingInterval,
      waitInterval: waitInterval,
      maxWaitDuration: maxWaitDuration,
    );

    // This point is not reached (server terminates internally when it detects standard input/output termination)
  } catch (e, stackTrace) {
    stderr.writeln('An error occurred: $e');
    stderr.writeln(stackTrace);
    exit(1);
  }
}
