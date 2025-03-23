import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

/// Enumeration representing server states
enum ServerState {
  /// Waiting for initial connection
  waiting,

  /// Connected
  connected,

  /// Reconnecting
  reconnecting,

  /// Terminating
  terminating,
}

/// API connection error exception
class ApiNotConnectedException implements Exception {
  final String message;

  ApiNotConnectedException(this.message);

  @override
  String toString() => message;
}

/// HTTP API client class
class ApiClient {
  /// Base URL of the API
  final String baseUrl;

  /// HTTP client
  final http.Client _client;

  /// Logger
  final Logger _logger;

  /// Server state
  ServerState _state = ServerState.waiting;

  /// Reconnect timer
  Timer? _reconnectTimer;

  /// Number of connection attempts
  int _reconnectAttempts = 0;

  /// Interval between connection attempts
  final Duration waitInterval;

  /// Maximum wait duration
  final Duration? maxWaitDuration;

  /// Start time
  final DateTime _startTime = DateTime.now();

  /// Last connected time
  DateTime? _lastConnectedTime;

  /// State notification stream
  final StreamController<ServerState> _stateController =
      StreamController<ServerState>.broadcast();

  /// State notification stream
  Stream<ServerState> get stateStream => _stateController.stream;

  /// Server state
  ServerState get state => _state;

  /// Connection status
  bool get isConnected => _state == ServerState.connected;

  /// Last connected time
  DateTime? get lastConnectedTime => _lastConnectedTime;

  /// Number of reconnection attempts
  int get reconnectAttempts => _reconnectAttempts;

  /// Constructor
  ApiClient({
    required this.baseUrl,
    Logger? logger,
    http.Client? client,
    this.waitInterval = const Duration(seconds: 5),
    this.maxWaitDuration,
  }) : _client = client ?? http.Client(),
       _logger = logger ?? Logger('ApiClient') {
    // Start connection attempts
    _attemptConnection();
  }

  /// Connection attempt method
  Future<void> _attemptConnection() async {
    if (_state == ServerState.terminating) return;

    _reconnectAttempts++;
    try {
      _logger.fine(
        'API connection attempt #$_reconnectAttempts: $baseUrl/ping',
      );

      // Call the ping API
      final response = await _client
          .get(Uri.parse('$baseUrl/ping'))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        // Connection successful
        final previousState = _state;
        _state = ServerState.connected;
        _lastConnectedTime = DateTime.now();

        // Notify if state has changed
        if (previousState != _state) {
          _stateController.add(_state);

          if (previousState == ServerState.waiting) {
            _logger.info(
              'Connected to MemoApp (attempts: $_reconnectAttempts)',
            );
          } else if (previousState == ServerState.reconnecting) {
            _logger.info('Reconnected to MemoApp');
          }
        }

        _reconnectAttempts = 0;
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
      } else {
        _scheduleReconnect('Invalid response: ${response.statusCode}');
      }
    } catch (e) {
      _scheduleReconnect('Connection error: $e');

      // Check maximum wait duration
      if (maxWaitDuration != null) {
        final elapsed = DateTime.now().difference(_startTime);
        if (elapsed > maxWaitDuration!) {
          _logger.severe(
            'Exceeded maximum wait duration (${maxWaitDuration!.inSeconds} seconds). Exiting.',
          );
          exit(1);
        }
      }
    }
  }

  /// Schedule reconnection
  void _scheduleReconnect(String reason) {
    // Update state
    final previousState = _state;
    if (_state != ServerState.waiting && _state != ServerState.reconnecting) {
      _state = ServerState.reconnecting;
    }

    // Notify if state has changed
    if (previousState != _state) {
      _stateController.add(_state);
    }

    // Log output
    if (_reconnectAttempts == 1) {
      _logger.warning('Cannot connect to MemoApp: $reason');
    } else {
      _logger.fine(
        'Cannot connect to MemoApp (attempts: $_reconnectAttempts): $reason',
      );
    }

    if (_reconnectAttempts % 5 == 0) {
      _logger.info('Waiting to connect to MemoApp...');
    }

    // Set reconnect timer
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(waitInterval, _attemptConnection);
  }

  /// Ping
  Future<bool> ping() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/ping'))
          .timeout(const Duration(seconds: 5));

      final isSuccess = response.statusCode == 200;

      if (isSuccess) {
        // Update state on success
        final previousState = _state;
        _state = ServerState.connected;
        _lastConnectedTime = DateTime.now();

        // Notify if state has changed
        if (previousState != _state) {
          _stateController.add(_state);

          if (previousState == ServerState.waiting) {
            _logger.info('Connected to MemoApp');
          } else if (previousState == ServerState.reconnecting) {
            _logger.info('Reconnected to MemoApp');
          }
        }
      } else if (_state == ServerState.connected) {
        // Switch to reconnecting mode if failed from connected state
        _state = ServerState.reconnecting;
        _stateController.add(_state);
        _logger.warning(
          'Disconnected from MemoApp: HTTP ${response.statusCode}',
        );
        _scheduleReconnect('Invalid response: ${response.statusCode}');
      }

      return isSuccess;
    } catch (e) {
      if (_state == ServerState.connected) {
        // Switch to reconnecting mode if error from connected state
        _state = ServerState.reconnecting;
        _stateController.add(_state);

        if (e is SocketException) {
          _logger.warning('Disconnected from MemoApp: Network error');
        } else if (e is TimeoutException) {
          _logger.warning('Disconnected from MemoApp: Timeout');
        } else {
          _logger.warning('Disconnected from MemoApp: $e');
        }

        _scheduleReconnect('Connection error: $e');
      }

      return false;
    }
  }

  /// Retrieve memo list
  Future<List<Map<String, dynamic>>> getMemos() async {
    // Connection check
    if (!isConnected) {
      // Attempt reconnection
      final reconnected = await ping();
      if (!reconnected) {
        throw ApiNotConnectedException(
          'Not connected to MemoApp (state: $_state). Please check if the app is running.',
        );
      }
    }

    try {
      _logger.fine('Retrieving memo list...');
      final response = await _client
          .get(Uri.parse('$baseUrl/memos'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        final message =
            'Failed to retrieve memo list: HTTP ${response.statusCode}';
        _logger.warning(message);

        try {
          final errorData = jsonDecode(response.body) as Map<String, dynamic>;
          if (errorData.containsKey('error')) {
            throw Exception('$message - ${errorData['error']}');
          }
        } catch (_) {}

        throw Exception(message);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final memos = (data['memos'] as List).cast<Map<String, dynamic>>();

      _logger.fine('Retrieved ${memos.length} memos');
      return memos;
    } catch (e) {
      String message = 'Failed to retrieve memo list';

      if (e is SocketException) {
        message = '$message: Network error';
        _state = ServerState.reconnecting;
        _stateController.add(_state);
        _scheduleReconnect('Network error');
      } else if (e is TimeoutException) {
        message = '$message: Timeout';
      } else if (e is FormatException) {
        message = '$message: Response parsing error';
      } else if (e is Exception) {
        message = '$message: ${e.toString()}';
      } else {
        message = '$message: $e';
      }

      _logger.warning(message);
      throw Exception(message);
    }
  }

  /// Create memo
  Future<Map<String, dynamic>> createMemo({
    required String title,
    required String content,
  }) async {
    // Connection check
    if (!isConnected) {
      // Attempt reconnection
      final reconnected = await ping();
      if (!reconnected) {
        throw ApiNotConnectedException(
          'Not connected to MemoApp (state: $_state). Please check if the app is running.',
        );
      }
    }

    try {
      _logger.fine('Creating memo: "$title"');
      final response = await _client
          .post(
            Uri.parse('$baseUrl/memos'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'title': title, 'content': content}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 201) {
        final message = 'Failed to create memo: HTTP ${response.statusCode}';
        _logger.warning(message);

        try {
          final errorData = jsonDecode(response.body) as Map<String, dynamic>;
          if (errorData.containsKey('error')) {
            throw Exception('$message - ${errorData['error']}');
          }
        } catch (_) {}

        throw Exception(message);
      }

      final memo = jsonDecode(response.body) as Map<String, dynamic>;
      _logger.fine('Created memo: ID ${memo['id']}');

      return memo;
    } catch (e) {
      String message = 'Failed to create memo';

      if (e is SocketException) {
        message = '$message: Network error';
        _state = ServerState.reconnecting;
        _stateController.add(_state);
        _scheduleReconnect('Network error');
      } else if (e is TimeoutException) {
        message = '$message: Timeout';
      } else if (e is FormatException) {
        message = '$message: Response parsing error';
      } else if (e is Exception) {
        message = '$message: ${e.toString()}';
      } else {
        message = '$message: $e';
      }

      _logger.warning(message);
      throw Exception(message);
    }
  }

  /// Delete memo
  Future<void> deleteMemo(String id) async {
    // Connection check
    if (!isConnected) {
      // Attempt reconnection
      final reconnected = await ping();
      if (!reconnected) {
        throw ApiNotConnectedException(
          'Not connected to MemoApp (state: $_state). Please check if the app is running.',
        );
      }
    }

    try {
      _logger.fine('Deleting memo: ID $id');
      final response = await _client
          .delete(Uri.parse('$baseUrl/memos/$id'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        final message = 'Failed to delete memo: HTTP ${response.statusCode}';
        _logger.warning(message);

        try {
          final errorData = jsonDecode(response.body) as Map<String, dynamic>;
          if (errorData.containsKey('error')) {
            throw Exception('$message - ${errorData['error']}');
          }
        } catch (_) {}

        throw Exception(message);
      }

      _logger.fine('Deleted memo: ID $id');
    } catch (e) {
      String message = 'Failed to delete memo';

      if (e is SocketException) {
        message = '$message: Network error';
        _state = ServerState.reconnecting;
        _stateController.add(_state);
        _scheduleReconnect('Network error');
      } else if (e is TimeoutException) {
        message = '$message: Timeout';
      } else if (e is FormatException) {
        message = '$message: Response parsing error';
      } else if (e is Exception) {
        message = '$message: ${e.toString()}';
      } else {
        message = '$message: $e';
      }

      _logger.warning(message);
      throw Exception(message);
    }
  }

  /// Clean up resources
  Future<void> close() async {
    try {
      _state = ServerState.terminating;
      _stateController.add(_state);

      _reconnectTimer?.cancel();
      _client.close();
      await _stateController.close();
      _logger.info('Closed API client');
    } catch (e) {
      _logger.severe('Error occurred while closing API client: $e');
    }
  }
}
