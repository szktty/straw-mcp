/// MCPクライアントのメッセージ関連機能を定義するインターフェース
///
/// このファイルでは、MCPクライアントが提供するメッセージ関連の機能を定義します。
/// これには、リソース、ツール、プロンプトなどのメッセージ操作に関連する高レベルAPIメソッドが含まれます。
/// 接続管理、初期化、通知ハンドリングなどのコア機能は含まれません。
library;

import 'dart:async';

import 'package:straw_mcp/src/mcp/prompts.dart';
import 'package:straw_mcp/src/mcp/resources.dart';
import 'package:straw_mcp/src/mcp/roots.dart';
import 'package:straw_mcp/src/mcp/sampling.dart';
import 'package:straw_mcp/src/mcp/tools.dart';
import 'package:straw_mcp/src/client/client.dart';

/// MCPクライアントのメッセージ関連機能を定義するインターフェース
///
/// このインターフェースは、リソース・ツール・プロンプトなどの
/// メッセージ操作に関連する高レベルAPIメソッドのみを定義します。
/// 接続管理、初期化、通知ハンドリングなどのコア機能は含みません。
abstract class ClientMessageSupport {
  /// 利用可能なリソースを取得する
  Future<ListResourcesResult> listResources([ListResourcesRequest? request]);

  /// 利用可能なリソーステンプレートを取得する
  Future<ListResourceTemplatesResult> listResourceTemplates([ListResourceTemplatesRequest? request]);

  /// 特定のリソースを読み取る
  Future<ReadResourceResult> readResource(ReadResourceRequest request);

  /// リソースの更新通知を購読する
  Future<void> subscribe(SubscribeRequest request);

  /// リソースの更新通知の購読を解除する
  Future<void> unsubscribe(UnsubscribeRequest request);

  /// 利用可能なプロンプトを取得する
  Future<ListPromptsResult> listPrompts([ListPromptsRequest? request]);

  /// 特定のプロンプトを取得する
  Future<GetPromptResult> getPrompt(GetPromptRequest request);

  /// 利用可能なツールを取得する
  Future<ListToolsResult> listTools([ListToolsRequest? request]);

  /// 特定のツールを呼び出す
  Future<CallToolResult> callTool(CallToolRequest request);

  /// 補完候補を取得する
  Future<CompleteResult> complete(CompleteRequest request);

  /// 利用可能なルートを取得する
  Future<ListRootsResult> listRoots([ListRootsRequest? request]);

  /// メッセージを作成する（LLMサンプリング）
  Future<CreateMessageResult> createMessage(CreateMessageRequest request);

  /// ルートリスト変更通知を送信する
  Future<void> rootsListChangedNotification();

  /// ロギングレベルを設定する
  Future<void> setLevel(SetLevelRequest request);
}

/// デフォルトのClientMessageSupportの実装
///
/// Clientインターフェースの実装クラスで使用するミックスイン
mixin ClientMessageSupportMixin implements ClientMessageSupport {
  /// クライアントリクエストを送信する抽象メソッド
  ///
  /// このメソッドは、このミックスインを使用するクラスで実装する必要があります。
  Future<T> sendRequest<T>(String method, Map<String, dynamic> params);

  @override
  Future<ListResourcesResult> listResources([ListResourcesRequest? request]) async {
    final actualRequest = request ?? ListResourcesRequest();
    final result = await sendRequest<Map<String, dynamic>>(
      'resources/list',
      actualRequest.params,
    );
    return ListResourcesResult.fromJson(result);
  }

  @override
  Future<ListResourceTemplatesResult> listResourceTemplates([ListResourceTemplatesRequest? request]) async {
    final actualRequest = request ?? ListResourceTemplatesRequest();
    final result = await sendRequest<Map<String, dynamic>>(
      'resources/templates/list',
      actualRequest.params,
    );
    return ListResourceTemplatesResult.fromJson(result);
  }

  @override
  Future<ReadResourceResult> readResource(ReadResourceRequest request) async {
    final result = await sendRequest<Map<String, dynamic>>(
      'resources/read',
      request.params,
    );
    return ReadResourceResult.fromJson(result);
  }

  @override
  Future<void> subscribe(SubscribeRequest request) async {
    await sendRequest<Map<String, dynamic>>(
      'resources/subscribe',
      request.params,
    );
  }

  @override
  Future<void> unsubscribe(UnsubscribeRequest request) async {
    await sendRequest<Map<String, dynamic>>(
      'resources/unsubscribe',
      request.params,
    );
  }

  @override
  Future<ListPromptsResult> listPrompts([ListPromptsRequest? request]) async {
    final actualRequest = request ?? ListPromptsRequest();
    final result = await sendRequest<Map<String, dynamic>>(
      'prompts/list',
      actualRequest.params,
    );
    return ListPromptsResult.fromJson(result);
  }

  @override
  Future<GetPromptResult> getPrompt(GetPromptRequest request) async {
    final result = await sendRequest<Map<String, dynamic>>(
      'prompts/get',
      request.params,
    );
    return GetPromptResult.fromJson(result);
  }

  @override
  Future<ListToolsResult> listTools([ListToolsRequest? request]) async {
    final actualRequest = request ?? ListToolsRequest();
    final result = await sendRequest<Map<String, dynamic>>(
      'tools/list',
      actualRequest.params,
    );
    return ListToolsResult.fromJson(result);
  }

  @override
  Future<CallToolResult> callTool(CallToolRequest request) async {
    final result = await sendRequest<Map<String, dynamic>>(
      'tools/call',
      request.params,
    );
    return CallToolResult.fromJson(result);
  }

  @override
  Future<CompleteResult> complete(CompleteRequest request) async {
    final result = await sendRequest<Map<String, dynamic>>(
      'completion/complete',
      request.params,
    );
    return CompleteResult.fromJson(result);
  }

  @override
  Future<ListRootsResult> listRoots([ListRootsRequest? request]) async {
    final actualRequest = request ?? ListRootsRequest();
    final result = await sendRequest<Map<String, dynamic>>(
      'roots/list',
      actualRequest.params,
    );
    return ListRootsResult.fromJson(result);
  }

  @override
  Future<CreateMessageResult> createMessage(CreateMessageRequest request) async {
    final result = await sendRequest<Map<String, dynamic>>(
      'sampling/createMessage',
      request.params,
    );
    return CreateMessageResult.fromJson(result);
  }

  @override
  Future<void> rootsListChangedNotification() async {
    await sendRequest<Map<String, dynamic>>(
      'notifications/roots/list_changed',
      {},
    );
  }

  @override
  Future<void> setLevel(SetLevelRequest request) async {
    await sendRequest<Map<String, dynamic>>(
      'logging/setLevel',
      request.params,
    );
  }
}
