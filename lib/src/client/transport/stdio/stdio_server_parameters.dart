/// サーバープロセスのパラメータを定義
///
/// このファイルでは、MCPサーバープロセスを起動するためのパラメータを定義します。
/// コマンド、引数、環境変数などの設定をカプセル化します。
library;

import 'package:straw_mcp/src/client/transport/stdio/process_handler.dart';

/// サーバープロセスのパラメータ
class StdioServerParameters {
  /// コンストラクタ
  /// - [command]: 実行するコマンド
  /// - [arguments]: コマンドライン引数
  /// - [environment]: 環境変数
  /// - [stderrHandler]: 標準エラー出力の処理方法
  /// - [workingDirectory]: 作業ディレクトリ
  const StdioServerParameters({
    required this.command,
    this.arguments,
    this.environment,
    this.stderrHandler,
    this.workingDirectory,
  });

  /// 実行するコマンド
  final String command;

  /// コマンドライン引数
  final List<String>? arguments;

  /// 環境変数
  final Map<String, String>? environment;

  /// 標準エラー出力の処理方法
  /// nullの場合、親プロセスの標準エラー出力が継承されます
  final ProcessHandler? stderrHandler;

  /// 作業ディレクトリ
  final String? workingDirectory;
}
