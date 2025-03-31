/// MCPクライアントの実装
///
/// このファイルでは、MCPクライアントの完全な実装を提供します。
/// Model Context Protocol (MCP)のクライアント機能を使用するための主要なAPIを定義します。
library;

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:straw_mcp/src/client/message/client_message_support.dart';
import 'package:straw_mcp/src/client/options/client_options.dart';
import 'package:straw_mcp/src/client/transport/client_transport.dart';
import 'package:straw_mcp/src/json_rpc/codec.dart';
import 'package:straw_mcp/src/json_rpc/message.dart';
import 'package:straw_mcp/src/mcp/completion.dart';
import 'package:straw_mcp/src/mcp/errors.dart';
import 'package:straw_mcp/src/mcp/prompts.dart';
import 'package:straw_mcp/src/mcp/resources.dart';
import 'package:straw_mcp/src/mcp/roots.dart';
import 'package:straw_mcp/src/mcp/sampling.dart';
import 'package:straw_mcp/src/mcp/tools.dart';
import 'package:straw_mcp/src/mcp/types.dart';
import 'package:straw_mcp/src/shared/logging/logging_options.dart';

/// MCPクライアント
///
/// Model Context Protocol (MCP)クライアントの主要なクラスです。
/// リソース、ツール、プロンプトなどのMCP機能へのアクセスを提供します。
class Client implements ClientMessageSupport {
  /// コンストラクタ
  ///
  /// - [clientInfo]: クライアント情報（名前とバージョン）
  /// - [options]: クライアントオプション
  /// - [samplingHandler]: サンプリングハンドラ（オプション）
  Client(
    this.clientInfo, {
    this.options = const ClientOptions(),
    this.samplingHandler,
  }) : _logger = options.logging.logger ?? Logger('McpClient');

  /// クライアント情報
  final Implementation clientInfo;

  /// クライアントオプション
  final ClientOptions options;

  /// サンプリングハンドラ
  final Future<CreateMessageResult> Function(CreateMessageRequest)?
  samplingHandler;

  /// ロガー
  final Logger _logger;

  /// JSON-RPCコーデック
  final JsonRpcCodec _codec = JsonRpcCodec();

  /// クライアントトランスポート
  ClientTransport? _transport;

  /// 現在のリクエストID
  int _nextId = 1;

  /// コントローラーマップ（リクエストID → Completer）
  final Map<dynamic, Completer<dynamic>> _responseCompleters = {};

  /// 接続済みフラグ
  bool _isConnected = false;

  /// 初期化済みフラグ
  bool _isInitialized = false;

  /// 遅延初期化フラグ
  bool _lazyInitCalled = false;

  /// サーバー情報
  Implementation? _serverInfo;

  /// サーバー機能
  ServerCapabilities? _serverCapabilities;

  /// 通知コントローラー
  final StreamController<JsonRpcNotification> _notificationController =
      StreamController<JsonRpcNotification>.broadcast();

  /// ログメッセージを出力
  void _log(String message, [Object? error, StackTrace? stackTrace]) {
    if (error != null) {
      _logger.severe(message, error, stackTrace);
    } else {
      _logger.info(message);
    }
  }

  /// トランスポートに接続する
  Future<void> connect(ClientTransport transport) async {
    if (_isConnected) {
      _log('すでにトランスポートに接続済みです');
      return;
    }

    _log('トランスポートに接続します');
    _transport = transport;

    // トランスポートのコールバックを設定
    _transport!.onMessage = _handleMessage;
    _transport!.onError = _handleError;
    _transport!.onClose = _handleClose;

    try {
      // トランスポートを開始
      await _transport!.start();
      _isConnected = true;
      _log('トランスポートへの接続が確立されました');
    } catch (e, stackTrace) {
      _log('トランスポートへの接続に失敗しました', e, stackTrace);
      _transport = null;
      rethrow;
    }
  }

  /// メッセージハンドラー
  void _handleMessage(JsonRpcMessage message) {
    try {
      if (message is JsonRpcNotification) {
        // 通知を処理
        _notificationController.add(message);
      } else if (message is JsonRpcResponse) {
        // レスポンスを処理
        final completer = _responseCompleters[message.id];
        if (completer != null) {
          _responseCompleters.remove(message.id);
          completer.complete(message.result);
        } else {
          _log('不明なIDのレスポンスを受信しました: ${message.id}');
        }
      } else if (message is JsonRpcError) {
        // エラーを処理
        final completer = _responseCompleters[message.id];
        if (completer != null) {
          _responseCompleters.remove(message.id);
          completer.completeError(
            McpError(
              code: message.error.code,
              message: message.error.message,
              data: message.error.data,
            ),
          );
        } else {
          _log('不明なIDのエラーを受信しました: ${message.id}');
        }
      } else {
        _log('未知のメッセージタイプを受信しました: ${message.runtimeType}');
      }
    } catch (e, stackTrace) {
      _log('メッセージの処理中にエラーが発生しました', e, stackTrace);
    }
  }

  /// エラーハンドラー
  void _handleError(Object error, [StackTrace? stackTrace]) {
    _log('トランスポートでエラーが発生しました', error, stackTrace);
    // 保留中のすべてのリクエストをエラーで完了
    for (final completer in _responseCompleters.values) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    }
    _responseCompleters.clear();
  }

  /// クローズハンドラー
  void _handleClose() {
    _log('トランスポートが閉じられました');
    _isConnected = false;
    _isInitialized = false;

    // 保留中のすべてのリクエストをエラーで完了
    for (final completer in _responseCompleters.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          McpError(
            code: McpErrorCode.internalError,
            message: 'トランスポートが閉じられました',
          ),
        );
      }
    }
    _responseCompleters.clear();
  }

  /// リクエストを送信する共通メソッド
  Future<T> _sendRequest<T, R>(
    String method,
    Map<String, dynamic>? params,
    T Function(R) resultConverter,
  ) async {
    _ensureConnected();

    final id = _nextId++;
    final request = JsonRpcRequest(id: id, method: method, params: params);
    final completer = Completer<dynamic>();
    _responseCompleters[id] = completer;

    try {
      final timeoutDuration = options.requestTimeout;
      await _transport!.send(request);

      // タイムアウト付きで応答を待機
      final result = await completer.future.timeout(
        timeoutDuration,
        onTimeout: () {
          _responseCompleters.remove(id);
          throw McpError(
            code: McpErrorCode.timeoutError,
            message: 'リクエストがタイムアウトしました: $method',
          );
        },
      );

      return resultConverter(result as R);
    } catch (e) {
      _responseCompleters.remove(id);
      if (e is McpError) {
        rethrow;
      }
      throw McpError(
        code: McpErrorCode.internalError,
        message: 'リクエスト中にエラーが発生しました: $method',
        data: e,
      );
    }
  }

  /// 通知を送信する共通メソッド
  Future<void> _sendNotification(
    String method,
    Map<String, dynamic>? params,
  ) async {
    _ensureConnected();

    final notification = JsonRpcNotification(method: method, params: params);
    try {
      await _transport!.send(notification);
    } catch (e, stackTrace) {
      _log('通知の送信中にエラーが発生しました: $method', e, stackTrace);
      rethrow;
    }
  }

  /// 接続状態を確認
  void _ensureConnected() {
    if (_transport == null || !_isConnected) {
      throw McpError(
        code: McpErrorCode.connectionError,
        message: 'トランスポートに接続されていません',
      );
    }
  }

  /// 初期化状態を確認
  void _ensureInitialized() {
    _ensureConnected();
    if (!_isInitialized) {
      throw McpError(
        code: McpErrorCode.protocolError,
        message: 'クライアントが初期化されていません',
      );
    }
  }

  /// 遅延初期化
  ///
  /// リクエストが最初に送信される前に、必要に応じて初期化を行います。
  /// すでに初期化されている場合は何もしません。
  Future<void> _ensureLazyInitialized() async {
    if (_lazyInitCalled || _isInitialized) {
      return;
    }

    _lazyInitCalled = true;
    await initialize();
  }

  /// サーバーに初期化リクエストを送信する
  Future<InitializeResult> initialize([InitializeRequest? request]) async {
    if (_isInitialized) {
      _log('すでに初期化済みです');
      return InitializeResult(
        protocolVersion:
            _serverCapabilities?.protocolVersion ?? LATEST_PROTOCOL_VERSION,
        capabilities: _serverCapabilities!,
        serverInfo: _serverInfo!,
      );
    }

    request ??= InitializeRequest(
      protocolVersion: LATEST_PROTOCOL_VERSION,
      capabilities: options.capabilities ?? ClientCapabilities(),
      clientInfo: clientInfo,
    );

    try {
      final result = await _sendRequest<InitializeResult, Map<String, dynamic>>(
        'initialize',
        request.toJson(),
        (json) => InitializeResult.fromJson(json),
      );

      // プロトコルバージョンの互換性をチェック
      final serverVersion = result.protocolVersion;
      if (serverVersion != LATEST_PROTOCOL_VERSION &&
          options.enforceStrictProtocolVersion) {
        throw McpError(
          code: McpErrorCode.protocolError,
          message: 'サーバーのプロトコルバージョン $serverVersion には対応していません',
        );
      }

      // 初期化完了通知を送信
      await _sendNotification('notifications/initialized', null);

      // サーバー情報を保存
      _serverInfo = result.serverInfo;
      _serverCapabilities = result.capabilities;
      _isInitialized = true;

      _log(
        '初期化が完了しました: ${result.serverInfo.name} ${result.serverInfo.version}',
      );
      return result;
    } catch (e) {
      _log('初期化に失敗しました', e);
      rethrow;
    }
  }

  /// サーバーが生きているか確認する
  Future<void> ping() async {
    _ensureConnected();

    try {
      await _sendRequest<void, void>('ping', null, (_) => null);
      _log('pingに成功しました');
    } catch (e) {
      _log('pingに失敗しました', e);
      rethrow;
    }
  }

  /// クライアント接続を閉じる
  Future<void> close() async {
    if (_transport != null) {
      _log('クライアントを閉じています');
      try {
        await _transport!.close();
      } catch (e, stackTrace) {
        _log('トランスポートを閉じる際にエラーが発生しました', e, stackTrace);
      } finally {
        _isConnected = false;
        _isInitialized = false;
        _transport = null;
        await _notificationController.close();
      }
    }
  }

  /// サーバーからの通知を処理するハンドラを登録する
  void onNotification(void Function(JsonRpcNotification notification) handler) {
    _notificationController.stream.listen(handler);
  }

  /// リクエストをキャンセルする
  ///
  /// 指定されたリクエストIDに対応するリクエストをキャンセルします。
  /// サーバーにキャンセル通知を送信し、対応するCompleterをエラーで完了させます。
  Future<void> cancelRequest(dynamic requestId, {String? reason}) async {
    if (_transport == null || !_isConnected) {
      return;
    }

    final completer = _responseCompleters[requestId];
    if (completer != null) {
      // 通知を送信
      await sendNotification('notifications/cancelled', {
        'requestId': requestId,
        if (reason != null) 'reason': reason,
      });

      // Completerをキャンセル
      if (!completer.isCompleted) {
        completer.completeError(
          McpError(
            code: McpErrorCode.connectionError,
            message: reason ?? 'リクエストがキャンセルされました',
          ),
        );
      }

      // マップから削除
      _responseCompleters.remove(requestId);
    }
  }

  /// 保留中のすべてのリクエストをキャンセルする
  ///
  /// 現在保留中のすべてのリクエストをキャンセルします。
  /// サーバーにすべてのキャンセル通知を送信し、対応するCompleterをエラーで完了させます。
  Future<void> cancelAllRequests({String? reason}) async {
    if (_transport == null || !_isConnected || _responseCompleters.isEmpty) {
      return;
    }

    // すべてのリクエストIDをコピー
    final requestIds = List<dynamic>.from(_responseCompleters.keys);

    // 各リクエストをキャンセル
    for (final requestId in requestIds) {
      await cancelRequest(requestId, reason: reason);
    }
  }

  // ClientMessageSupport インターフェースの実装

  /// ClientMessageSupport に必要なサーバー機能プロパティの実装
  ServerCapabilities? get serverCapabilities => _serverCapabilities;

  /// ClientMessageSupport に必要なリクエスト送信メソッドの実装
  Future<T> sendRequest<T, R>(
    String method,
    Map<String, dynamic>? params,
    T Function(R) resultConverter,
  ) async {
    await _ensureLazyInitialized();
    _ensureInitialized();
    return _sendRequest<T, R>(method, params, resultConverter);
  }

  /// ClientMessageSupport に必要な通知送信メソッドの実装
  Future<void> sendNotification(
    String method,
    Map<String, dynamic>? params,
  ) async {
    await _ensureLazyInitialized();
    _ensureInitialized();
    return _sendNotification(method, params);
  }

  /// 利用可能なリソースを取得する
  @override
  Future<ListResourcesResult> listResources([
    ListResourcesRequest? request,
  ]) async {
    await _ensureLazyInitialized();

    _checkCapability('resources', serverCapabilities?.resources);

    request ??= ListResourcesRequest();
    return sendRequest<ListResourcesResult, Map<String, dynamic>>(
      'resources/list',
      request.toJson(),
      (json) => ListResourcesResult.fromJson(json),
    );
  }

  /// 利用可能なリソーステンプレートを取得する
  @override
  Future<ListResourceTemplatesResult> listResourceTemplates([
    ListResourceTemplatesRequest? request,
  ]) async {
    await _ensureLazyInitialized();

    _checkCapability('resources', serverCapabilities?.resources);

    request ??= ListResourceTemplatesRequest();
    return sendRequest<ListResourceTemplatesResult, Map<String, dynamic>>(
      'resources/templates/list',
      request.toJson(),
      (json) => ListResourceTemplatesResult.fromJson(json),
    );
  }

  /// 特定のリソースを読み取る
  @override
  Future<ReadResourceResult> readResource(ReadResourceRequest request) async {
    await _ensureLazyInitialized();

    _checkCapability('resources', serverCapabilities?.resources);

    return sendRequest<ReadResourceResult, Map<String, dynamic>>(
      'resources/read',
      request.toJson(),
      (json) => ReadResourceResult.fromJson(json),
    );
  }

  /// リソースの更新通知を購読する
  @override
  Future<void> subscribe(SubscribeRequest request) async {
    await _ensureLazyInitialized();

    _checkCapability(
      'resources.subscribe',
      serverCapabilities?.resources?.subscribe,
    );

    return sendRequest<void, void>(
      'resources/subscribe',
      request.toJson(),
      (_) => null,
    );
  }

  /// リソースの更新通知の購読を解除する
  @override
  Future<void> unsubscribe(UnsubscribeRequest request) async {
    await _ensureLazyInitialized();

    _checkCapability(
      'resources.subscribe',
      serverCapabilities?.resources?.subscribe,
    );

    return sendRequest<void, void>(
      'resources/unsubscribe',
      request.toJson(),
      (_) => null,
    );
  }

  /// 利用可能なプロンプトを取得する
  @override
  Future<ListPromptsResult> listPrompts([ListPromptsRequest? request]) async {
    await _ensureLazyInitialized();

    _checkCapability('prompts', serverCapabilities?.prompts);

    request ??= ListPromptsRequest();
    return sendRequest<ListPromptsResult, Map<String, dynamic>>(
      'prompts/list',
      request.toJson(),
      (json) => ListPromptsResult.fromJson(json),
    );
  }

  /// 特定のプロンプトを取得する
  @override
  Future<GetPromptResult> getPrompt(GetPromptRequest request) async {
    await _ensureLazyInitialized();

    _checkCapability('prompts', serverCapabilities?.prompts);

    return sendRequest<GetPromptResult, Map<String, dynamic>>(
      'prompts/get',
      request.toJson(),
      (json) => GetPromptResult.fromJson(json),
    );
  }

  /// 利用可能なツールを取得する
  @override
  Future<ListToolsResult> listTools([ListToolsRequest? request]) async {
    await _ensureLazyInitialized();

    _checkCapability('tools', serverCapabilities?.tools);

    request ??= ListToolsRequest();
    return sendRequest<ListToolsResult, Map<String, dynamic>>(
      'tools/list',
      request.toJson(),
      (json) => ListToolsResult.fromJson(json),
    );
  }

  /// 特定のツールを呼び出す
  @override
  Future<CallToolResult> callTool(CallToolRequest request) async {
    await _ensureLazyInitialized();

    _checkCapability('tools', serverCapabilities?.tools);

    return sendRequest<CallToolResult, Map<String, dynamic>>(
      'tools/call',
      request.toJson(),
      (json) => CallToolResult.fromJson(json),
    );
  }

  /// ロギングレベルを設定する
  Future<void> setLoggingLevel(LoggingLevel level) async {
    await _ensureLazyInitialized();

    _checkCapability('logging', serverCapabilities?.logging);

    return sendRequest<void, void>('logging/setLevel', {
      'level': level.name,
    }, (_) => null);
  }

  /// 補完候補を取得する
  @override
  Future<CompleteResult> complete(CompleteRequest request) async {
    await _ensureLazyInitialized();

    return sendRequest<CompleteResult, Map<String, dynamic>>(
      'completion/complete',
      request.toJson(),
      (json) => CompleteResult.fromJson(json),
    );
  }

  /// 利用可能なルートを取得する
  @override
  Future<ListRootsResult> listRoots([ListRootsRequest? request]) async {
    await _ensureLazyInitialized();

    request ??= ListRootsRequest();
    return sendRequest<ListRootsResult, Map<String, dynamic>>(
      'roots/list',
      request.toJson(),
      (json) => ListRootsResult.fromJson(json),
    );
  }

  /// メッセージを作成する（LLMサンプリング）
  @override
  Future<CreateMessageResult> createMessage(
    CreateMessageRequest request,
  ) async {
    await _ensureLazyInitialized();

    // カスタムサンプリングハンドラが設定されている場合は、それを使用する
    if (samplingHandler != null) {
      return samplingHandler!(request);
    }

    return sendRequest<CreateMessageResult, Map<String, dynamic>>((
      'sampling/createMessage',
      request.toJson(),
      (json) => CreateMessageResult.fromJson(json),
    );
  }

  /// ルートリスト変更通知を送信する
  @override
  Future<void> rootsListChangedNotification() async {
    await _ensureLazyInitialized();

    return sendNotification('notifications/roots/list_changed', null);
  }

  /// 機能が利用可能かチェック
  void _checkCapability(String feature, dynamic capability) {
    if (serverCapabilities == null) {
      throw McpError(
        code: McpErrorCode.protocolError,
        message: 'サーバー機能が初期化されていません',
      );
    }

    if (capability == null) {
      throw McpError(
        code: McpErrorCode.capabilityError,
        message: 'サーバーは $feature 機能をサポートしていません',
      );
    }
  }

  /// ビルダーパターンを使用してクライアントを構築
  static Client build(void Function(ClientBuilder builder) updates) {
    final builder = ClientBuilder();
    updates(builder);
    return builder._build();
  }
}

/// MCPクライアントのビルダークラス
///
/// クライアントのビルダーパターンを提供し、流暢なAPIでクライアントを構築できるようにします。
class ClientBuilder {
  /// クライアント名（必須）
  String? name;

  /// クライアントバージョン（必須）
  String? version;

  /// クライアント機能設定用のビルダー
  final _capabilitiesBuilder = ClientCapabilitiesBuilder();

  /// 通知ハンドラー
  void Function(JsonRpcNotification)? notificationHandler;

  /// サンプリングハンドラー
  Future<CreateMessageResult> Function(CreateMessageRequest)? samplingHandler;

  /// リクエストタイムアウト
  Duration requestTimeout = Duration(seconds: 30);

  /// プロトコルバージョン互換性の厳格チェック
  bool enforceStrictProtocolVersion = false;

  /// ロガー
  Logger? logger;

  /// 機能設定のためのメソッド
  void capabilities(void Function(ClientCapabilitiesBuilder) updates) {
    updates(_capabilitiesBuilder);
  }

  /// クライアントの構築
  Client _build() {
    // 必須プロパティのチェック
    if (name == null) {
      throw ArgumentError('Client name must be specified');
    }
    if (version == null) {
      throw ArgumentError('Client version must be specified');
    }

    // ロギングオプションの作成
    final loggingOptions = LoggingOptions(logger: logger);

    // クライアントオプションの作成
    final options = ClientOptions(
      capabilities: _capabilitiesBuilder._build(),
      requestTimeout: requestTimeout,
      logging: loggingOptions,
      enforceStrictProtocolVersion: enforceStrictProtocolVersion,
    );

    // クライアントオブジェクトを構築
    final client = Client(
      Implementation(name: name!, version: version!),
      options: options,
      samplingHandler: samplingHandler,
    );

    // 通知ハンドラーの設定
    if (notificationHandler != null) {
      client.onNotification(notificationHandler!);
    }

    return client;
  }
}

/// クライアント機能のビルダー
class ClientCapabilitiesBuilder {
  RootsCapabilitiesBuilder? _rootsBuilder;
  bool _samplingEnabled = false;
  Map<String, dynamic>? experimental;

  /// ルート機能の設定
  void roots({bool enabled = true, bool listChanged = false}) {
    if (enabled) {
      _rootsBuilder = RootsCapabilitiesBuilder()..listChanged = listChanged;
    } else {
      _rootsBuilder = null;
    }
  }

  /// サンプリング機能の設定
  void sampling({bool enabled = true}) {
    _samplingEnabled = enabled;
  }

  // 機能オブジェクトの構築
  ClientCapabilities _build() {
    return ClientCapabilities(
      roots: _rootsBuilder?._build(),
      sampling: _samplingEnabled ? SamplingCapabilities() : null,
      experimental: experimental,
    );
  }
}

/// ルート機能のビルダー
class RootsCapabilitiesBuilder {
  /// リスト変更通知のサポート
  bool listChanged = false;

  /// ルート機能オブジェクトを構築
  RootsCapabilities _build() {
    return RootsCapabilities(listChanged: listChanged);
  }
}
