/// HTTP+SSEを使用したMCPクライアントトランスポート
///
/// このファイルでは、HTTP+SSE（Server-Sent Events）を使用したMCPクライアントトランスポートを実装します。
/// リクエストはHTTP POSTで送信し、サーバーからの通知はSSEで受信します。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:straw_mcp/src/client/transport/client_transport.dart';
import 'package:straw_mcp/src/client/transport/sse/event_source.dart';
import 'package:straw_mcp/src/client/transport/sse/sse_client_transport_options.dart';
import 'package:straw_mcp/src/json_rpc/codec.dart';
import 'package:straw_mcp/src/json_rpc/message.dart';
import 'package:straw_mcp/src/mcp/types.dart';

/// HTTP+SSEを使用したMCPトランスポート
class SseClientTransport extends ClientTransportBase {
  /// コンストラクタ
  ///
  /// - [baseUrl]: MCPサーバーのベースURL
  /// - [options]: トランスポートオプション
  SseClientTransport(
    String baseUrl, {
    SseClientTransportOptions options = const SseClientTransportOptions(),
  })  : _baseUrl = baseUrl,
        _options = options,
        _httpClient = options.httpClient ?? http.Client(),
        _clientId = options.clientId ??
            'client-${DateTime.now().millisecondsSinceEpoch}',
        _sessionId = options.sessionId ??
            'session-${DateTime.now().millisecondsSinceEpoch}',
        super(logging: options.logging);

  /// サーバーのベースURL
  final String _baseUrl;

  /// トランスポートオプション
  final SseClientTransportOptions _options;

  /// HTTPクライアント
  final http.Client _httpClient;

  /// クライアントID
  final String _clientId;

  /// セッションID
  final String _sessionId;

  /// JSON-RPCコーデック
  final JsonRpcCodec _codec = JsonRpcCodec();

  /// SSEイベントソース
  EventSource? _eventSource;

  /// イベントタイムアウトタイマー
  Timer? _eventTimeoutTimer;

  /// 接続試行回数
  int _connectionAttempts = 0;

  /// 再接続フラグ
  bool _shouldReconnect = true;

  /// 接続コンプリータ
  Completer<void>? _connectionCompleter;

  @override
  Future<void> start() async {
    if (isRunning) {
      return;
    }

    log('SSEトランスポートを開始します');
    isRunning = true;
    _shouldReconnect = true;
    _connectionAttempts = 0;

    try {
      await _connectSse();
      log('SSEトランスポートが正常に開始されました');
    } catch (e) {
      log('SSEトランスポートの開始に失敗しました: $e');
      handleError(e);

      // 初期接続に失敗した場合も、再接続を試みるために isRunning はtrueのままにする
      if (_shouldReconnect && isRunning) {
        _scheduleReconnect();
      }
    }
  }

  /// SSEエンドポイントに接続します
  Future<void> _connectSse() async {
    if (!isRunning) {
      return;
    }

    _connectionAttempts++;
    _connectionCompleter = Completer<void>();

    try {
      log('SSEエンドポイントに接続します: $_baseUrl/sse (試行回数: $_connectionAttempts)');

      // 専用のHTTPクライアントを作成
      final httpClient = io.HttpClient()
        ..connectionTimeout = _options.connectionTimeout;

      final request = await httpClient.getUrl(Uri.parse('$_baseUrl/sse'));

      // ヘッダーを追加
      request.headers.add('Accept', 'text/event-stream');
      request.headers.add('Cache-Control', 'no-cache');
      request.headers.add('X-Client-ID', _clientId);
      request.headers.add('X-Session-ID', _sessionId);

      // カスタムヘッダーの追加
      if (_options.headers != null) {
        _options.headers!.forEach((name, value) {
          request.headers.add(name, value);
        });
      }

      // 接続タイムアウトを設定
      final responseCompleter = Completer<io.HttpClientResponse>();
      final connectionTimeoutTimer = Timer(_options.connectionTimeout, () {
        if (!responseCompleter.isCompleted) {
          responseCompleter.completeError(
            TimeoutException(
              '接続タイムアウト: ${_options.connectionTimeout.inSeconds}秒経過',
              _options.connectionTimeout,
            ),
          );
        }
      });

      // リクエストを送信
      final response = await request.close().then((r) {
        if (!responseCompleter.isCompleted) {
          responseCompleter.complete(r);
        }
        return r;
      }).catchError((Object error) {
        if (!responseCompleter.isCompleted) {
          responseCompleter.completeError(error);
        }

        handleError(error);
        throw error;
      });

      // タイムアウトタイマーをキャンセル
      connectionTimeoutTimer.cancel();

      if (response.statusCode != 200) {
        httpClient.close();
        throw Exception(
          'SSEエンドポイントへの接続に失敗しました: HTTP ${response.statusCode}',
        );
      }

      // レスポンスを行に変換
      final lines = parseSseLines(response);

      // イベントソースを作成
      _eventSource = EventSource(lines);

      // イベントタイムアウトタイマーを開始
      _resetEventTimeoutTimer();

      // イベントを監視
      _eventSource!.events.listen(
        (event) {
          // イベントを受信したらタイムアウトタイマーをリセット
          _resetEventTimeoutTimer();

          try {
            // ハートビートイベントを無視
            if (event.event == null && event.data.isEmpty) {
              return;
            }

            // JSONメッセージをパース
            final jsonMap = json.decode(event.data) as Map<String, dynamic>;
            final message = _codec.decodeNotification(jsonMap);

            // メッセージをハンドラーに通知
            handleMessage(message);
          } catch (e) {
            log('SSEイベント処理エラー: $e');
            handleError(e);
          }
        },
        onDone: () {
          log('サーバーによってSSE接続が閉じられました');
          _cleanup();

          // 必要に応じて再接続
          if (_shouldReconnect && isRunning) {
            _scheduleReconnect();
          } else {
            handleClose();
          }
        },
        onError: (Object e) {
          log('SSE接続エラー: $e');

          _cleanup();
          handleError(e);

          // 必要に応じて再接続
          if (_shouldReconnect && isRunning) {
            _scheduleReconnect();
          } else {
            handleClose();
          }
        },
      );

      log('SSE接続が正常に確立されました');

      // 接続の成功をマーク
      if (!_connectionCompleter!.isCompleted) {
        _connectionCompleter!.complete();
      }

      // 接続試行回数をリセット
      _connectionAttempts = 0;
    } catch (e) {
      log('SSE接続の確立中にエラーが発生しました: $e');

      // リソースをクリーンアップ
      _cleanup();

      // コンプリータをエラーで完了
      if (!_connectionCompleter!.isCompleted) {
        _connectionCompleter!.completeError(e);
      }

      // エラーを伝播
      rethrow;
    }

    return _connectionCompleter!.future;
  }

  /// イベントタイムアウトタイマーをリセットします
  void _resetEventTimeoutTimer() {
    _eventTimeoutTimer?.cancel();
    _eventTimeoutTimer = Timer(_options.eventTimeout, () {
      log('SSEイベントタイムアウト: ${_options.eventTimeout.inSeconds}秒経過');

      // 現在の接続を閉じて再接続を試みる
      _cleanup();

      // エラーを通知
      handleError(TimeoutException(
        'イベントタイムアウト',
        _options.eventTimeout,
      ));

      // 必要に応じて再接続
      if (_shouldReconnect && isRunning) {
        _scheduleReconnect();
      }
    });
  }

  /// 再接続を予定します
  void _scheduleReconnect() {
    if (!isRunning) {
      return;
    }

    // 指数バックオフによる遅延を計算
    final delay = Duration(
      milliseconds: _options.retryInterval.inMilliseconds *
          (1 << _connectionAttempts.clamp(0, 10)),
    );

    log('再接続試行($_connectionAttempts)を${delay.inSeconds}秒後に予定します');

    // 再接続をスケジュール
    Future<void>.delayed(delay, () {
      if (!isRunning || !_shouldReconnect) {
        return;
      }

      _connectSse().catchError((Object error) {
        log('再接続試行に失敗しました: $error');

        // 最大再試行回数に達した場合は諦める
        if (_connectionAttempts >= _options.maxRetries) {
          log('最大再接続試行回数に達しました、諦めます');
          _shouldReconnect = false;
          handleClose();
        } else if (isRunning && _shouldReconnect) {
          // それ以外の場合は、再度試行
          _scheduleReconnect();
        }
      });
    });
  }

  /// リソースをクリーンアップします
  void _cleanup() {
    // タイマーをキャンセル
    _eventTimeoutTimer?.cancel();
    _eventTimeoutTimer = null;

    // イベントソースをクローズ
    _eventSource?.close();
    _eventSource = null;
  }

  @override
  Future<void> send(JsonRpcMessage message) async {
    if (!isRunning) {
      await start();
    }

    try {
      // メッセージをエンコード
      final jsonMap = _encodeMessage(message);
      final jsonData = json.encode(jsonMap);

      // ヘッダーを構築
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'X-Client-ID': _clientId,
        'X-Session-ID': _sessionId,
      };

      if (_options.headers != null) {
        headers.addAll(_options.headers!);
      }

      // メッセージの送信を再試行
      http.Response? response;
      Exception? lastError;

      for (var i = 0; i < _options.maxRetries; i++) {
        try {
          response = await _httpClient
              .post(
                Uri.parse('$_baseUrl/jsonrpc'),
                headers: headers,
                body: jsonData,
              )
              .timeout(_options.requestTimeout);

          // 成功した場合は再試行ループを終了
          if (response.statusCode == 200 || response.statusCode == 204) {
            break;
          }

          log('HTTPエラー: ${response.statusCode} - ${response.body}');
          lastError = Exception('HTTPエラー: ${response.statusCode}');
        } on Object catch (e) {
          log('リクエストエラー (試行 ${i + 1}/${_options.maxRetries}): $e');
          lastError = e is Exception ? e : Exception(e.toString());

          // 最後の試行でなければ再試行前に待機
          if (i < _options.maxRetries - 1) {
            await Future<void>.delayed(_options.retryInterval);
          }
        }
      }

      // すべての再試行後も有効なレスポンスがない場合
      if (response == null ||
          (response.statusCode != 200 && response.statusCode != 204)) {
        throw lastError ??
            Exception('${_options.maxRetries}回の試行後もメッセージの送信に失敗しました');
      }

      // レスポンスが通知または内容がない場合、処理完了
      if (response.statusCode == 204 || response.body.isEmpty) {
        return;
      }

      // それ以外の場合は、レスポンスを処理
      try {
        final jsonResponse = json.decode(response.body) as Map<String, dynamic>;

        // エラーかどうかチェック
        if (jsonResponse.containsKey('error')) {
          log('エラーレスポンスを受信しました: ${jsonResponse['error']}');
          handleError(Exception('サーバーからのエラー: ${jsonResponse['error']}'));
          return;
        }

        // レスポンスを処理
        if (jsonResponse.containsKey('result')) {
          // リクエストに対するレスポンス
          final messageResponse = _codec.decodeResponse(jsonResponse);
          handleMessage(messageResponse);
        }
      } catch (e) {
        log('レスポンスのデコードエラー: $e');
        handleError(e);
      }
    } catch (e) {
      log('メッセージ送信エラー: $e');
      handleError(e);
      rethrow;
    }
  }

  /// 送信用にメッセージをエンコードします
  Map<String, dynamic> _encodeMessage(JsonRpcMessage message) {
    if (message is JsonRpcRequest) {
      return _codec.encodeRequest(message);
    } else if (message is JsonRpcNotification) {
      return _codec.encodeNotification(message);
    } else if (message is JsonRpcResponse) {
      return _codec.encodeResponse(message);
    } else if (message is JsonRpcError) {
      return _codec.encodeResponse(message);
    } else {
      throw Exception('不明なメッセージタイプ: ${message.runtimeType}');
    }
  }

  @override
  Future<void> close() async {
    if (!isRunning) {
      return;
    }

    log('SSEクライアントトランスポートをクローズします');
    isRunning = false;
    _shouldReconnect = false;

    // タイマーとリソースをクリーンアップ
    _cleanup();

    // HTTPクライアントをクローズ
    _httpClient.close();

    // 基底クラスのcloseを呼び出し
    await super.close();
    
    log('SSEクライアントトランスポートが正常にクローズされました');
  }
}
