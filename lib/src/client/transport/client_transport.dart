/// Clientトランスポートインターフェース
///
/// このファイルでは、MCPクライアントが使用するトランスポート層のインターフェースを定義します。
/// サーバー側の[Transport]インターフェースと似ていますが、クライアント側のニーズに合わせて
/// いくつかの違いがあります。
library;

import 'dart:async';

import 'package:straw_mcp/src/json_rpc/message.dart';
import 'package:straw_mcp/src/mcp/types.dart';
import 'package:straw_mcp/src/shared/logging/logging_mixin.dart';
import 'package:straw_mcp/src/shared/logging/logging_options.dart';

/// MCPクライアントトランスポートインターフェース
///
/// すべてのクライアントトランスポート実装はこのインターフェースを実装して、
/// 起動、終了、メッセージ送信のための一貫したAPIを提供する必要があります。
abstract class ClientTransport {
  /// トランスポートを開始し、メッセージの受信を開始します。
  Future<void> start();

  /// トランスポートを閉じて、リソースを解放します。
  Future<void> close();

  /// JSON-RPCメッセージをサーバーに送信します。
  Future<void> send(JsonRpcMessage message);

  /// サーバーからメッセージを受信した時のコールバック。
  void Function(JsonRpcMessage message)? get onMessage;

  set onMessage(void Function(JsonRpcMessage message)? handler);

  /// トランスポートでエラーが発生した時のコールバック。
  void Function(Object error)? get onError;

  set onError(void Function(Object error)? handler);

  /// トランスポートが閉じられた時のコールバック。
  void Function()? get onClose;

  set onClose(void Function()? handler);
}

/// クライアントトランスポートの基本実装
///
/// すべてのクライアントトランスポート実装の基底クラスとして、
/// 共通機能、特にコールバック処理とロギング機能を提供します。
abstract class ClientTransportBase
    with LoggingMixin
    implements ClientTransport {
  /// ロギング機能を持つ新しいトランスポートベースを作成します。
  ClientTransportBase({this.logging = const LoggingOptions()}) {
    initializeLogFile();
  }

  /// メッセージ受信コールバック
  void Function(JsonRpcMessage message)? _onMessageHandler;

  /// エラーコールバック
  void Function(Object error)? _onErrorHandler;

  /// クローズコールバック
  void Function()? _onCloseHandler;

  /// このトランスポートのロギングオプション
  @override
  final LoggingOptions logging;

  /// トランスポートが実行中かどうか
  bool _isRunning = false;

  @override
  void Function(JsonRpcMessage message)? get onMessage => _onMessageHandler;

  @override
  set onMessage(void Function(JsonRpcMessage message)? handler) {
    _onMessageHandler = handler;
  }

  @override
  void Function(Object error)? get onError => _onErrorHandler;

  @override
  set onError(void Function(Object error)? handler) {
    _onErrorHandler = handler;
  }

  @override
  void Function()? get onClose => _onCloseHandler;

  @override
  set onClose(void Function()? handler) {
    _onCloseHandler = handler;
  }

  /// 指定されたメッセージでメッセージハンドラを呼び出します。
  void handleMessage(JsonRpcMessage message) {
    _onMessageHandler?.call(message);
  }

  /// 指定されたエラーでエラーハンドラを呼び出します。
  void handleError(Object error) {
    _onErrorHandler?.call(error);
  }

  /// クローズハンドラを呼び出します。
  void handleClose() {
    _onCloseHandler?.call();
  }

  /// ログファイルの閉じる処理を含むcloseの基本実装。
  @override
  Future<void> close() async {
    if (!_isRunning) {
      return;
    }

    _isRunning = false;
    log('トランスポートを終了します');

    // ログファイルを閉じる
    await closeLogFile();

    // トランスポートが閉じられたことを通知
    handleClose();
  }

  /// トランスポートが現在実行中かどうかを取得します。
  bool get isRunning => _isRunning;

  /// トランスポートの実行状態を設定します。
  ///
  /// これはサブクラスからのみ呼び出されるべきです。
  set isRunning(bool value) {
    _isRunning = value;
  }
}
