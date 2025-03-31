/// 標準入出力トランスポートのオプション定義
///
/// このファイルでは、標準入出力を使用したMCPクライアントトランスポートのオプション設定を
/// カプセル化するクラスを定義します。
library;

import 'dart:io';

import 'package:straw_mcp/src/client/transport/stdio/stdio_server_parameters.dart';
import 'package:straw_mcp/src/shared/logging/logging_options.dart';

/// 標準入出力トランスポートのオプション設定
class StdioClientTransportOptions {
  /// コンストラクタ
  const StdioClientTransportOptions({
    this.serverParameters,
    this.inputStream,
    this.outputSink,
    this.logging = const LoggingOptions(),
  });

  /// stdioを使用するためのコンビニエンスファクトリ
  ///
  /// 標準入出力ストリームを使用するトランスポートオプションを作成します。
  factory StdioClientTransportOptions.stdio({LoggingOptions? logging}) {
    return StdioClientTransportOptions(
      inputStream: stdin,
      outputSink: stdout,
      logging: logging ?? const LoggingOptions(),
    );
  }

  /// サーバープロセスのパラメータ
  /// このプロパティが設定されている場合、inputStreamとoutputSinkは無視される
  final StdioServerParameters? serverParameters;

  /// 入力ストリーム（デフォルトはstdin）
  /// serverParametersが設定されていない場合のみ使用
  final Stream<List<int>>? inputStream;

  /// 出力シンク（デフォルトはstdout）
  /// serverParametersが設定されていない場合のみ使用
  final IOSink? outputSink;

  /// ロギングオプション
  final LoggingOptions logging;
}
