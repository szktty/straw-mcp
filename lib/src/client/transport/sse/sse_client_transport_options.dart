/// HTTP+SSEトランスポートのオプション定義
///
/// このファイルでは、HTTP+SSEを使用したMCPクライアントトランスポートのオプション設定を
/// カプセル化するクラスを定義します。
library;

import 'package:http/http.dart' as http;
import 'package:straw_mcp/src/shared/logging/logging_options.dart';

/// HTTP+SSEトランスポートのオプション設定
class SseClientTransportOptions {
  /// コンストラクタ
  const SseClientTransportOptions({
    this.headers,
    this.connectionTimeout = const Duration(seconds: 30),
    this.eventTimeout = const Duration(minutes: 5),
    this.requestTimeout = const Duration(seconds: 30),
    this.httpClient,
    this.clientId,
    this.sessionId,
    this.maxRetries = 3,
    this.retryInterval = const Duration(seconds: 3),
    this.logging = const LoggingOptions(),
  });

  /// 追加のHTTPヘッダー
  final Map<String, String>? headers;

  /// 接続タイムアウト
  final Duration connectionTimeout;

  /// イベントタイムアウト
  final Duration eventTimeout;

  /// HTTPリクエストタイムアウト
  final Duration requestTimeout;

  /// HTTPクライアント
  final http.Client? httpClient;

  /// クライアントID
  final String? clientId;

  /// セッションID
  final String? sessionId;

  /// 最大リトライ回数
  final int maxRetries;

  /// リトライ間隔
  final Duration retryInterval;

  /// ロギングオプション
  final LoggingOptions logging;
}
