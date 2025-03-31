/// クライアントオプションのクラス定義
///
/// このファイルでは、MCPクライアントの設定オプションを定義します。
/// クライアントの振る舞いをカスタマイズするための様々な設定を提供します。
library;

import 'package:straw_mcp/src/mcp/types.dart';
import 'package:straw_mcp/src/shared/logging/logging_options.dart';

/// クライアントオプションクラス
///
/// このクラスは、クライアントの振る舞いをカスタマイズするためのオプションを提供します。
class ClientOptions {
  /// コンストラクタ
  const ClientOptions({
    this.capabilities,
    this.enforceStrictCapabilities = false,
    this.requestTimeout = const Duration(seconds: 30),
    this.connectTimeout = const Duration(seconds: 10),
    this.logging = const LoggingOptions(),
  });

  /// クライアント機能
  ///
  /// クライアントがサポートする機能を指定します。
  /// nullの場合、デフォルトの機能セットが使用されます。
  final ClientCapabilities? capabilities;

  /// 厳格な機能チェックを強制するかどうか
  ///
  /// trueの場合、サーバーが必要な機能をサポートしていない場合に
  /// 例外をスローします。
  final bool enforceStrictCapabilities;

  /// リクエストタイムアウト
  ///
  /// リクエストがこの時間内に完了しない場合、タイムアウトエラーが発生します。
  final Duration requestTimeout;

  /// 接続タイムアウト
  ///
  /// 接続がこの時間内に確立されない場合、タイムアウトエラーが発生します。
  final Duration connectTimeout;

  /// ロギングオプション
  ///
  /// クライアントのロギング動作を設定します。
  final LoggingOptions logging;

  /// デフォルトの機能セットを持つ新しいオプションを作成します
  factory ClientOptions.defaultOptions() {
    return ClientOptions(
      capabilities: ClientCapabilities(),
    );
  }
  
  /// このオプションの値をベースに新しいオプションを作成します
  ///
  /// 指定されたパラメータのみが上書きされ、他のパラメータは現在の値が保持されます。
  ClientOptions copyWith({
    ClientCapabilities? capabilities,
    bool? enforceStrictCapabilities,
    Duration? requestTimeout,
    Duration? connectTimeout,
    LoggingOptions? logging,
  }) {
    return ClientOptions(
      capabilities: capabilities ?? this.capabilities,
      enforceStrictCapabilities: enforceStrictCapabilities ?? this.enforceStrictCapabilities,
      requestTimeout: requestTimeout ?? this.requestTimeout,
      connectTimeout: connectTimeout ?? this.connectTimeout,
      logging: logging ?? this.logging,
    );
  }
}
