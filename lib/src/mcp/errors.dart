import 'dart:convert';

/// Model Context Protocol の標準エラーコード
///
/// JSON-RPC 2.0仕様に準拠したエラーコードです。
/// https://www.jsonrpc.org/specification
class McpErrorCode {
  /// JSON解析エラー: -32700
  ///
  /// 無効なJSONでパーサーエラーが発生した場合
  static const int parseError = -32700;

  /// 無効なリクエスト: -32600
  ///
  /// JSONは有効だが、リクエストオブジェクトとして無効な場合
  static const int invalidRequest = -32600;

  /// メソッドが見つからない: -32601
  ///
  /// メソッドが存在しない場合
  static const int methodNotFound = -32601;

  /// 無効なパラメータ: -32602
  ///
  /// メソッドのパラメータが無効な場合
  static const int invalidParams = -32602;

  /// 内部エラー: -32603
  ///
  /// 内部的なJSON-RPCエラーが発生した場合
  static const int internalError = -32603;

  /// サーバーアプリケーション固有エラー
  ///
  /// -32768～-32000の範囲のJSONRPC定義予約エラー
  static const int serverErrorStart = -32099;
  static const int serverErrorEnd = -32000;

  /// プロトコルエラー: -32001
  ///
  /// MCPプロトコルレベルのエラーが発生した場合
  static const int protocolError = -32001;

  /// 通知処理エラー: -32002
  ///
  /// MCPの通知処理に関するエラーが発生した場合
  static const int notificationError = -32002;

  /// 機能エラー: -32003
  ///
  /// MCPサーバーまたはクライアントの機能に関連するエラーが発生した場合
  static const int capabilityError = -32003;

  /// ツール実行エラー: -32004
  ///
  /// ツールの実行中にエラーが発生した場合
  static const int toolExecutionError = -32004;

  /// リソースエラー: -32005
  ///
  /// リソースアクセスに関するエラーが発生した場合
  static const int resourceError = -32005;

  /// プロンプトエラー: -32006
  ///
  /// プロンプト処理に関するエラーが発生した場合
  static const int promptError = -32006;

  /// 接続エラー: -32007
  ///
  /// 接続に関するエラーが発生した場合
  static const int connectionError = -32007;

  /// タイムアウトエラー: -32008
  ///
  /// 操作がタイムアウトした場合
  static const int timeoutError = -32008;

  /// サンプリングエラー: -32009
  ///
  /// LLMサンプリングに関するエラーが発生した場合
  static const int samplingError = -32009;

  /// ルートエラー: -32010
  ///
  /// ルート操作に関するエラーが発生した場合
  static const int rootsError = -32010;
}

/// MCP固有のエラークラス
class McpError extends Error {
  /// コンストラクタ
  ///
  /// - [code]: エラーコード
  /// - [message]: エラーメッセージ
  /// - [data]: 追加のエラーデータ（オプション）
  /// - [cause]: エラーの原因となった例外（オプション）
  McpError({required this.code, required this.message, this.data, this.cause});

  /// エラーコード
  final int code;

  /// エラーメッセージ
  final String message;

  /// 追加のエラーデータ
  final dynamic data;

  /// エラーの原因となった例外
  final Object? cause;

  /// エラーコードから標準メッセージを取得する
  static String _getDefaultMessage(int code) {
    switch (code) {
      case McpErrorCode.parseError:
        return 'Parse error';
      case McpErrorCode.invalidRequest:
        return 'Invalid request';
      case McpErrorCode.methodNotFound:
        return 'Method not found';
      case McpErrorCode.invalidParams:
        return 'Invalid params';
      case McpErrorCode.internalError:
        return 'Internal error';
      case McpErrorCode.protocolError:
        return 'Protocol error';
      case McpErrorCode.notificationError:
        return 'Notification error';
      case McpErrorCode.capabilityError:
        return 'Capability error';
      case McpErrorCode.toolExecutionError:
        return 'Tool execution error';
      case McpErrorCode.resourceError:
        return 'Resource error';
      case McpErrorCode.promptError:
        return 'Prompt error';
      case McpErrorCode.connectionError:
        return 'Connection error';
      case McpErrorCode.timeoutError:
        return 'Timeout error';
      case McpErrorCode.samplingError:
        return 'Sampling error';
      case McpErrorCode.rootsError:
        return 'Roots error';
      default:
        if (code >= McpErrorCode.serverErrorStart &&
            code <= McpErrorCode.serverErrorEnd) {
          return 'Server error';
        }
        return 'Unknown error';
    }
  }

  /// パースエラーを作成する
  static McpError parseError(String message, [dynamic data, Object? cause]) {
    return McpError(
      code: McpErrorCode.parseError,
      message: message,
      data: data,
      cause: cause,
    );
  }

  /// 無効なリクエストエラーを作成する
  static McpError invalidRequest(
    String message, [
    dynamic data,
    Object? cause,
  ]) {
    return McpError(
      code: McpErrorCode.invalidRequest,
      message: message,
      data: data,
      cause: cause,
    );
  }

  /// メソッド未発見エラーを作成する
  static McpError methodNotFound(
    String message, [
    dynamic data,
    Object? cause,
  ]) {
    return McpError(
      code: McpErrorCode.methodNotFound,
      message: message,
      data: data,
      cause: cause,
    );
  }

  /// 無効なパラメータエラーを作成する
  static McpError invalidParams(String message, [dynamic data, Object? cause]) {
    return McpError(
      code: McpErrorCode.invalidParams,
      message: message,
      data: data,
      cause: cause,
    );
  }

  /// 内部エラーを作成する
  static McpError internalError(String message, [dynamic data, Object? cause]) {
    return McpError(
      code: McpErrorCode.internalError,
      message: message,
      data: data,
      cause: cause,
    );
  }

  /// プロトコルエラーを作成する
  static McpError protocolError(String message, [dynamic data, Object? cause]) {
    return McpError(
      code: McpErrorCode.protocolError,
      message: message,
      data: data,
      cause: cause,
    );
  }

  /// 通知処理エラーを作成する
  static McpError notificationError(
    String message, [
    dynamic data,
    Object? cause,
  ]) {
    return McpError(
      code: McpErrorCode.notificationError,
      message: message,
      data: data,
      cause: cause,
    );
  }

  /// 機能エラーを作成する
  static McpError capabilityError(
    String message, [
    dynamic data,
    Object? cause,
  ]) {
    return McpError(
      code: McpErrorCode.capabilityError,
      message: message,
      data: data,
      cause: cause,
    );
  }

  /// ツール実行エラーを作成する
  static McpError toolExecutionError(
    String message, [
    dynamic data,
    Object? cause,
  ]) {
    return McpError(
      code: McpErrorCode.toolExecutionError,
      message: message,
      data: data,
      cause: cause,
    );
  }

  /// リソースエラーを作成する
  static McpError resourceError(String message, [dynamic data, Object? cause]) {
    return McpError(
      code: McpErrorCode.resourceError,
      message: message,
      data: data,
      cause: cause,
    );
  }

  /// プロンプトエラーを作成する
  static McpError promptError(String message, [dynamic data, Object? cause]) {
    return McpError(
      code: McpErrorCode.promptError,
      message: message,
      data: data,
      cause: cause,
    );
  }

  /// 接続エラーを作成する
  static McpError connectionError(
    String message, [
    dynamic data,
    Object? cause,
  ]) {
    return McpError(
      code: McpErrorCode.connectionError,
      message: message,
      data: data,
      cause: cause,
    );
  }

  /// タイムアウトエラーを作成する
  static McpError timeoutError(String message, [dynamic data, Object? cause]) {
    return McpError(
      code: McpErrorCode.timeoutError,
      message: message,
      data: data,
      cause: cause,
    );
  }

  /// サンプリングエラーを作成する
  static McpError samplingError(String message, [dynamic data, Object? cause]) {
    return McpError(
      code: McpErrorCode.samplingError,
      message: message,
      data: data,
      cause: cause,
    );
  }

  /// ルートエラーを作成する
  static McpError rootsError(String message, [dynamic data, Object? cause]) {
    return McpError(
      code: McpErrorCode.rootsError,
      message: message,
      data: data,
      cause: cause,
    );
  }

  /// エラーコードとメッセージからMcpErrorを作成する
  static McpError fromCode(
    int code, [
    String? message,
    dynamic data,
    Object? cause,
  ]) {
    return McpError(
      code: code,
      message: message ?? _getDefaultMessage(code),
      data: data,
      cause: cause,
    );
  }

  /// JSON-RPCエラーマップからMcpErrorを作成する
  static McpError fromJsonRpcError(Map<String, dynamic> errorMap) {
    final errorObj = errorMap['error'] as Map<String, dynamic>;
    return McpError(
      code: errorObj['code'] as int,
      message: errorObj['message'] as String,
      data: errorObj['data'],
    );
  }

  /// JSON-RPCエラーマップを作成する
  Map<String, dynamic> toJsonRpcError(dynamic id) {
    final Map<String, dynamic> error = {'code': code, 'message': message};

    if (data != null) {
      error['data'] = data;
    }

    return {'jsonrpc': '2.0', 'id': id, 'error': error};
  }

  @override
  String toString() {
    final buffer = StringBuffer('McpError: ($code) $message');

    if (data != null) {
      try {
        final dataStr = data is String ? data : jsonEncode(data);
        buffer.write('\nData: $dataStr');
      } catch (e) {
        buffer.write('\nData: $data');
      }
    }

    if (cause != null) {
      buffer.write('\nCause: $cause');
    }

    return buffer.toString();
  }
}
