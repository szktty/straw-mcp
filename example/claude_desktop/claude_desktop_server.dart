/// Claude Desktop MCP Server Example
///
/// This example demonstrates how to create a MCP server that can be used with
/// Claude Desktop. It provides various tools for text manipulation, calculations,
/// and utility functions.
///
/// Usage:
///   dart run example/claude_desktop/claude_desktop_server.dart
///
/// Then in Claude Desktop, configure the server path to point to this script.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:logging/logging.dart';
import 'package:straw_mcp/straw_mcp.dart';

/// Main entry point for the Claude Desktop MCP server
void main() async {
  // Configure logging to stderr
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    stderr.writeln('${record.level.name}: ${record.time}: ${record.message}');
  });

  final logger = Logger('ClaudeDesktopServer');

  // Create the MCP server with appropriate capabilities
  final handler = ProtocolHandler('Dart MCP Claude Desktop Server', '0.1.0', [
    withToolCapabilities(listChanged: true),
    withResourceCapabilities(subscribe: true, listChanged: true),
    withPromptCapabilities(listChanged: false),
    withLogging(),
    withInstructions(
      'This server provides text manipulation, calculation, and utility tools.',
    ),
  ]);

  // Register tools
  _registerTextTools(handler);
  _registerMathTools(handler);
  _registerUtilityTools(handler);

  // Add resources if needed
  _registerResources(handler);

  logger.info('Starting Claude Desktop MCP server (stdio)...');

  // Get execution file path and create logs in the same directory
  final scriptPath = Platform.script.toFilePath();
  final scriptDir = File(scriptPath).parent.path;
  final logDir = Directory('$scriptDir/logs');
  if (!logDir.existsSync()) {
    try {
      logDir.createSync(recursive: true);
      logger.info('Created log directory: ${logDir.path}');
    } catch (e) {
      logger.warning('Failed to create log directory: $e');
      // Continue execution even if an exception occurs
    }
  }

  // Generate log file path
  String logFilePath;
  try {
    if (logDir.existsSync()) {
      logFilePath =
          '${logDir.path}/mcp_server_${DateTime.now().millisecondsSinceEpoch}.log';
      logger.info('Log file: $logFilePath');
    } else {
      logFilePath = '';
      logger.warning(
        'Log file will not be created because log directory does not exist.',
      );
    }
  } on Exception catch (e) {
    logFilePath = '';
    logger.warning('Error occurred while generating log file path: $e');
  }

  // Create wrapper log file for response logging
  IOSink? responseLogFile;
  if (logFilePath.isNotEmpty) {
    try {
      final responseLogFilePath =
          '${logDir.path}/responses_${DateTime.now().millisecondsSinceEpoch}.log';
      responseLogFile = File(
        responseLogFilePath,
      ).openWrite(mode: FileMode.append);
      logger.info('Response log file: $responseLogFilePath');
    } catch (e) {
      logger.warning('Failed to create response log file: $e');
    }
  }

  // Set up notification listener and log response contents
  handler.notifications.listen((notification) {
    if (responseLogFile != null) {
      try {
        final timestamp = DateTime.now().toIso8601String();
        final method = notification.method;
        responseLogFile.writeln('$timestamp NOTIFICATION: $method');
      } catch (e) {
        logger.warning('Failed to log notification: $e');
      }
    }
  });

  // Provide MCP server via stdio
  try {
    // Interceptor for response logs
    final logStdout = _LoggingIOSink(stdout, (String data) {
      if (responseLogFile != null) {
        try {
          // Parse and record content if it's JSON data
          if (data.trim().startsWith('{') && data.contains('"jsonrpc"')) {
            final jsonMap = json.decode(data) as Map<String, dynamic>;
            final timestamp = DateTime.now().toIso8601String();

            // Determine the type of response
            if (jsonMap.containsKey('error')) {
              // For error responses
              final error = jsonMap['error'];
              responseLogFile.writeln(
                '$timestamp RESPONSE ERROR: Code: ${error['code']}, Message: ${error['message']}',
              );
            } else if (jsonMap.containsKey('result')) {
              // For successful responses
              final result = jsonMap['result'];

              // For tool call results
              if (result is Map &&
                  result.containsKey('type') &&
                  result.containsKey('content')) {
                final type = result['type'];
                final content = result['content'];

                responseLogFile.writeln(
                  '$timestamp RESPONSE RESULT: Type: $type',
                );
                responseLogFile.writeln(
                  '$timestamp RESPONSE CONTENT: $content',
                );
              }
              // For resource contents
              else if (result is Map && result.containsKey('contents')) {
                final contents = result['contents'];
                if (contents is List && contents.isNotEmpty) {
                  for (var i = 0; i < contents.length; i++) {
                    final content = contents[i];
                    if (content is Map && content.containsKey('text')) {
                      responseLogFile.writeln(
                        '$timestamp RESPONSE RESOURCE CONTENT[$i]: ${content['text']}',
                      );
                    }
                  }
                }
              }
              // For other results
              else {
                // Record only basic information in the log
                final resultStr = json.encode(result);
                responseLogFile.writeln(
                  '$timestamp RESPONSE RESULT: ${resultStr.length > 1000 ? "${resultStr.substring(0, 1000)}..." : resultStr}',
                );
              }
            }
          } else {
            // Record non-JSON data as is
            final timestamp = DateTime.now().toIso8601String();
            responseLogFile.writeln('$timestamp OUTPUT: $data');
          }
        } catch (e) {
          final timestamp = DateTime.now().toIso8601String();
          responseLogFile.writeln(
            '$timestamp ERROR: Failed to log response: $e',
          );
        }
      }
    });

    await serveStdio(
      handler,
      options: StreamServerOptions.stdio(
        logger: Logger('StreamServer'),
        logFilePath: logFilePath.isNotEmpty ? logFilePath : null,
      ),
    );
  } catch (e) {
    logger.severe('Error occurred while starting MCP server: $e');
    stderr.writeln('ERROR: $e');
    exit(1);
  } finally {
    // Close response log file
    await responseLogFile?.flush();
    await responseLogFile?.close();
  }
}

/// Wrapper for IOSink to record logs
class _LoggingIOSink implements IOSink {
  _LoggingIOSink(this._sink, this._logCallback);

  final IOSink _sink;
  final void Function(String) _logCallback;

  @override
  void add(List<int> data) {
    _sink.add(data);
  }

  @override
  void write(Object? obj) {
    final str = obj.toString();
    _logCallback(str);
    _sink.write(obj);
  }

  @override
  void writeAll(Iterable objects, [String separator = '']) {
    final str = objects.join(separator);
    _logCallback(str);
    _sink.writeAll(objects, separator);
  }

  @override
  void writeCharCode(int charCode) {
    final str = String.fromCharCode(charCode);
    _logCallback(str);
    _sink.writeCharCode(charCode);
  }

  @override
  void writeln([Object? obj = '']) {
    final str = obj.toString();
    _logCallback(str);
    _sink.writeln(obj);
  }

  @override
  Future addStream(Stream<List<int>> stream) => _sink.addStream(stream);

  @override
  Future close() => _sink.close();

  @override
  Future flush() => _sink.flush();

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _sink.addError(error, stackTrace);

  @override
  Future get done => _sink.done;

  @override
  Encoding get encoding => _sink.encoding;

  @override
  set encoding(Encoding encoding) => _sink.encoding = encoding;
}

/// Register text manipulation tools
void _registerTextTools(ProtocolHandler handler) {
  // Text Count tool
  handler.addTool(
    newTool('text_count', [
      withString('text', [required(), description('Text to analyze')]),
    ]),
    (request) async {
      final text = request.params['arguments']['text'] as String;
      final words =
          text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      final chars = text.length;
      final charsNoSpaces = text.replaceAll(RegExp(r'\s+'), '').length;
      final lines = text.split('\n').length;

      return newToolResultText(
        'Text statistics:\n'
        '- Words: $words\n'
        '- Characters (with spaces): $chars\n'
        '- Characters (without spaces): $charsNoSpaces\n'
        '- Lines: $lines',
      );
    },
  );

  // Text Format tool
  handler.addTool(
    newTool('text_format', [
      withString('text', [required(), description('Text to format')]),
      withString('format', [
        required(),
        description('Format type: uppercase, lowercase, titlecase, etc.'),
        enumValues(['uppercase', 'lowercase', 'titlecase', 'sentence', 'trim']),
      ]),
    ]),
    (request) async {
      final text = request.params['arguments']['text'] as String;
      final format = request.params['arguments']['format'] as String;

      switch (format) {
        case 'uppercase':
          return newToolResultText(text.toUpperCase());
        case 'lowercase':
          return newToolResultText(text.toLowerCase());
        case 'titlecase':
          return newToolResultText(_toTitleCase(text));
        case 'sentence':
          return newToolResultText(_toSentenceCase(text));
        case 'trim':
          return newToolResultText(text.trim());
        default:
          return newToolResultError('Unknown format: $format');
      }
    },
  );

  // Text Split tool
  handler.addTool(
    newTool('text_split', [
      withString('text', [required(), description('Text to split')]),
      withString('delimiter', [
        required(),
        description('Delimiter to split by'),
      ]),
    ]),
    (request) async {
      final text = request.params['arguments']['text'] as String;
      final delimiter = request.params['arguments']['delimiter'] as String;
      final parts = text.split(delimiter);

      return newToolResultText(
        'Split into ${parts.length} parts:\n\n${parts.asMap().entries.map((e) => '${e.key + 1}: ${e.value}').join('\n\n')}',
      );
    },
  );
}

/// Register mathematical calculation tools
void _registerMathTools(ProtocolHandler handler) {
  // Calculator tool
  handler.addTool(
    newTool('calculator', [
      withString('expression', [
        required(),
        description('Mathematical expression to evaluate'),
      ]),
    ]),
    (request) async {
      try {
        final expression = request.params['arguments']['expression'] as String;

        // Simple calculator implementation
        // In a real app, you'd want to use a proper math expression parser
        // This is just a basic example that evaluates basic expressions
        final result = _evaluateExpression(expression);

        return newToolResultText('Result: $result');
      } catch (e) {
        return newToolResultError('Error evaluating expression: $e');
      }
    },
  );

  // Statistics tool
  handler.addTool(
    newTool('statistics', [
      withString('numbers', [
        required(),
        description('Comma-separated list of numbers'),
      ]),
    ]),
    (request) async {
      try {
        final numbersStr = request.params['arguments']['numbers'] as String;
        final numbers =
            numbersStr.split(',').map((s) => double.parse(s.trim())).toList();

        if (numbers.isEmpty) {
          return newToolResultError('No numbers provided');
        }

        final mean = numbers.reduce((a, b) => a + b) / numbers.length;

        // Sort for median
        numbers.sort();
        final median =
            numbers.length % 2 == 0
                ? (numbers[numbers.length ~/ 2 - 1] +
                        numbers[numbers.length ~/ 2]) /
                    2
                : numbers[numbers.length ~/ 2];

        // Calculate standard deviation
        final variance =
            numbers.map((n) => math.pow(n - mean, 2)).reduce((a, b) => a + b) /
            numbers.length;
        final stdDev = math.sqrt(variance);

        final min = numbers.first;
        final max = numbers.last;

        return newToolResultText(
          'Statistical analysis:\n'
          '- Count: ${numbers.length}\n'
          '- Sum: ${numbers.reduce((a, b) => a + b)}\n'
          '- Mean: $mean\n'
          '- Median: $median\n'
          '- Min: $min\n'
          '- Max: $max\n'
          '- Range: ${max - min}\n'
          '- Standard Deviation: $stdDev',
        );
      } catch (e) {
        return newToolResultError('Error analyzing numbers: $e');
      }
    },
  );
}

/// Register utility tools
void _registerUtilityTools(ProtocolHandler handler) {
  // Date and Time tool
  handler.addTool(
    newTool('date_time', [
      withString('format', [
        description('Date format (optional)'),
        enumValues(['iso', 'readable', 'unix']),
      ]),
    ]),
    (request) async {
      final args = request.params['arguments'] as Map<String, dynamic>;
      final format = args['format'] as String? ?? 'readable';
      final now = DateTime.now();

      switch (format) {
        case 'iso':
          return newToolResultText(now.toIso8601String());
        case 'unix':
          return newToolResultText('${now.millisecondsSinceEpoch ~/ 1000}');
        case 'readable':
        default:
          return newToolResultText(
            'Current date and time:\n'
            '- Date: ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}\n'
            '- Time: ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}\n'
            '- Timezone: ${now.timeZoneName} (UTC${now.timeZoneOffset.isNegative ? '' : '+'}${now.timeZoneOffset.inHours}:${(now.timeZoneOffset.inMinutes % 60).abs().toString().padLeft(2, '0')})',
          );
      }
    },
  );

  // Random Generator tool
  handler.addTool(
    newTool('random_generator', [
      withString('type', [
        required(),
        description('Type of random value to generate'),
        enumValues(['number', 'uuid', 'string']),
      ]),
      withNumber('min', [description('Minimum value for number generation')]),
      withNumber('max', [description('Maximum value for number generation')]),
      withNumber('length', [description('Length for string generation')]),
    ]),
    (request) async {
      final args = request.params['arguments'] as Map<String, dynamic>;
      final type = args['type'] as String;
      final random = math.Random();

      switch (type) {
        case 'number':
          final min = (args['min'] as num?)?.toInt() ?? 1;
          final max = (args['max'] as num?)?.toInt() ?? 100;

          if (min >= max) {
            return newToolResultError(
              'Minimum value must be less than maximum value',
            );
          }

          final randomNumber = min + random.nextInt(max - min + 1);
          return newToolResultText('Random number: $randomNumber');

        case 'uuid':
          final uuid = _generateUuid();
          return newToolResultText('Random UUID: $uuid');

        case 'string':
          final length = (args['length'] as num?)?.toInt() ?? 10;

          if (length <= 0 || length > 1000) {
            return newToolResultError('Length must be between 1 and 1000');
          }

          const chars =
              'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
          final randomString = String.fromCharCodes(
            List.generate(
              length,
              (_) => chars.codeUnitAt(random.nextInt(chars.length)),
            ),
          );

          return newToolResultText('Random string: $randomString');

        default:
          return newToolResultError('Unknown random type: $type');
      }
    },
  );

  // JSON tools
  handler.addTool(
    newTool('json_tools', [
      withString('operation', [
        required(),
        description('JSON operation to perform'),
        enumValues(['format', 'validate', 'query']),
      ]),
      withString('json', [required(), description('JSON data to process')]),
      withString('path', [description('JSON path for query operation')]),
    ]),
    (request) async {
      try {
        final args = request.params['arguments'] as Map<String, dynamic>;
        final operation = args['operation'] as String;
        final jsonStr = args['json'] as String;

        switch (operation) {
          case 'format':
            final decoded = json.decode(jsonStr);
            final formatted = const JsonEncoder.withIndent(
              '  ',
            ).convert(decoded);
            return newToolResultText('Formatted JSON:\n\n$formatted');

          case 'validate':
            // Just try to parse it
            json.decode(jsonStr);
            return newToolResultText('JSON is valid.');

          case 'query':
            final path = args['path'] as String?;
            if (path == null || path.isEmpty) {
              return newToolResultError('Path is required for query operation');
            }

            final decoded = json.decode(jsonStr);
            final result = _queryJson(decoded, path);

            if (result is Map || result is List) {
              return newToolResultText(
                'Query result:\n\n${const JsonEncoder.withIndent('  ').convert(result)}',
              );
            } else {
              return newToolResultText('Query result: $result');
            }

          default:
            return newToolResultError('Unknown JSON operation: $operation');
        }
      } catch (e) {
        return newToolResultError('Error processing JSON: $e');
      }
    },
  );
}

/// Register resources
void _registerResources(ProtocolHandler handler) {
  // System info resource
  handler.addResource(
    Resource(
      uri: 'resource://system/info',
      name: 'System Information',
      description: 'Information about the system',
      mimeType: 'text/plain',
    ),
    (request) async {
      final systemInfo = [
        'System Information:',
        '- Operating System: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
        '- Dart Version: ${Platform.version}',
        '- Number of Processors: ${Platform.numberOfProcessors}',
        '- Hostname: ${Platform.localHostname}',
        '- Path Separator: ${Platform.pathSeparator}',
        '- Environment Variables: ${Platform.environment.length} variables',
      ].join('\n');

      return [
        TextResourceContents(
          uri: request.params['uri'] as String,
          text: systemInfo,
          mimeType: 'text/plain',
        ),
      ];
    },
  );
}

// Utility functions

/// Convert text to title case
String _toTitleCase(String text) {
  if (text.isEmpty) return text;

  return text
      .split(' ')
      .map((word) {
        if (word.isEmpty) return word;
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      })
      .join(' ');
}

/// Convert text to sentence case
String _toSentenceCase(String text) {
  if (text.isEmpty) return text;

  return text
      .split('. ')
      .map((sentence) {
        if (sentence.isEmpty) return sentence;
        return sentence[0].toUpperCase() + sentence.substring(1).toLowerCase();
      })
      .join('. ');
}

/// Very basic expression evaluator
/// Note: This is a simplified implementation for demo purposes only
double _evaluateExpression(String expression) {
  // Remove all whitespace
  expression = expression.replaceAll(RegExp(r'\s+'), '');

  // Handle parentheses first
  final parenRegex = RegExp(r'\(([^()]+)\)');
  while (expression.contains('(')) {
    expression = expression.replaceAllMapped(parenRegex, (match) {
      final subExpr = match.group(1)!;
      return _evaluateExpression(subExpr).toString();
    });
  }

  // Evaluate multiplication and division
  final mulDivRegex = RegExp(r'(\d+\.?\d*)([\*\/])(\d+\.?\d*)');
  while (expression.contains('*') || expression.contains('/')) {
    expression = expression.replaceAllMapped(mulDivRegex, (match) {
      final a = double.parse(match.group(1)!);
      final op = match.group(2)!;
      final b = double.parse(match.group(3)!);

      if (op == '*') return (a * b).toString();
      if (op == '/') {
        if (b == 0) throw Exception('Division by zero');
        return (a / b).toString();
      }

      throw Exception('Unknown operator: $op');
    });
  }

  // Evaluate addition and subtraction
  final addSubRegex = RegExp(r'(\d+\.?\d*)([\+\-])(\d+\.?\d*)');
  while (expression.contains('+') || expression.contains('-', 1)) {
    expression = expression.replaceAllMapped(addSubRegex, (match) {
      final a = double.parse(match.group(1)!);
      final op = match.group(2)!;
      final b = double.parse(match.group(3)!);

      if (op == '+') return (a + b).toString();
      if (op == '-') return (a - b).toString();

      throw Exception('Unknown operator: $op');
    });
  }

  return double.parse(expression);
}

/// Generate a UUID v4
String _generateUuid() {
  final random = math.Random();
  const hexDigits = '0123456789abcdef';
  final result = List<String>.filled(36, '');

  for (var i = 0; i < 36; i++) {
    final hexPos = random.nextInt(16);
    result[i] = hexDigits[hexPos];
  }

  // UUID v4 format adjustments
  result[14] = '4'; // version 4
  result[19] =
      hexDigits[(int.parse(result[19], radix: 16) & 0x3) | 0x8]; // variant

  // Add hyphens
  result[8] = result[13] = result[18] = result[23] = '-';

  return result.join();
}

/// Simple JSON query function using dot notation
/// e.g. "users.0.name" to get the name of the first user
dynamic _queryJson(dynamic json, String path) {
  final parts = path.split('.');
  dynamic current = json;

  for (final part in parts) {
    if (current is List) {
      final index = int.tryParse(part);
      if (index == null || index < 0 || index >= current.length) {
        throw Exception('Invalid array index: $part');
      }
      current = current[index];
    } else if (current is Map) {
      if (!current.containsKey(part)) {
        throw Exception('Key not found: $part');
      }
      current = current[part];
    } else {
      throw Exception('Cannot navigate beyond scalar value');
    }
  }

  return current;
}
