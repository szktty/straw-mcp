/// 標準入出力を使用したMCPクライアントトランスポート
///
/// このファイルでは、標準入出力またはサブプロセスとの通信を使用したMCPクライアントトランスポートを実装します。
/// 直接stdioストリームを使用する方法と、サブプロセスを起動して通信する方法の両方をサポートします。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:straw_mcp/src/client/transport/client_transport.dart';
import 'package:straw_mcp/src/client/transport/stdio/process_handler.dart';
import 'package:straw_mcp/src/client/transport/stdio/stdio_client_transport_options.dart';
import 'package:straw_mcp/src/client/transport/stdio/stdio_server_parameters.dart';
import 'package:straw_mcp/src/json_rpc/codec.dart';
import 'package:straw_mcp/src/json_rpc/message.dart';
import 'package:straw_mcp/src/shared/stdio_buffer.dart';

/// 標準入出力を使用したMCPトランスポート
class StdioClientTransport extends ClientTransportBase {
  /// コンストラクタ
  ///
  /// - [options]: トランスポートオプション
  StdioClientTransport({
    StdioClientTransportOptions options = const StdioClientTransportOptions(),
  }) : _options = options,
       super(logging: options.logging);

  /// トランスポートオプション
  final StdioClientTransportOptions _options;

  /// サブプロセスのハンドル（サーバーパラメータを使用している場合）
  io.Process? _process;

  /// 入力ストリーム
  Stream<List<int>>? _inputStream;

  /// 出力シンク
  io.IOSink? _outputSink;

  /// 入力ストリーム購読
  StreamSubscription<String>? _inputSubscription;

  /// JSON-RPCコーデック
  final JsonRpcCodec _codec = JsonRpcCodec();

  /// StdioBufferを使った行ベースの入力処理
  StdioBuffer? _buffer;

  @override
  Future<void> start() async {
    if (isRunning) {
      return;
    }

    log('トランスポートを開始します');
    isRunning = true;

    try {
      // サーバーパラメータが指定されている場合はプロセスを起動
      if (_options.serverParameters != null) {
        await _startProcess();
      } else {
        await _setupDirectStreams();
      }

      // 入力ストリームを監視
      await _setupInputProcessing();

      log('トランスポートが正常に開始されました');
    } catch (e) {
      isRunning = false;
      log('トランスポートの開始に失敗しました: $e');
      handleError(e);
      rethrow;
    }
  }

  /// サブプロセスを起動して接続します
  Future<void> _startProcess() async {
    final params = _options.serverParameters!;

    log(
      'サーバープロセスを起動します: ${params.command} ${params.arguments?.join(' ') ?? ''}',
    );

    try {
      // stderrHandlerの設定に基づいてプロセス起動オプションを決定
      final stderrHandler = params.stderrHandler;

      if (stderrHandler is StartModeProcessHandler) {
        // ProcessStartModeを使用してプロセスを起動
        _process = await io.Process.start(
          params.command,
          params.arguments ?? [],
          environment: params.environment,
          workingDirectory: params.workingDirectory,
          mode: stderrHandler.mode,
        );
      } else {
        // デフォルトモードでプロセスを起動
        _process = await io.Process.start(
          params.command,
          params.arguments ?? [],
          environment: params.environment,
          workingDirectory: params.workingDirectory,
        );

        // 起動後にstderrの処理を設定
        if (stderrHandler is StreamProcessHandler) {
          _process!.stderr.listen((data) {
            stderrHandler.sink.add(data);
          });
        } else if (stderrHandler is FileDescriptorProcessHandler) {
          // ファイルディスクリプタへのリダイレクトは現在サポートされていません
          // 代わりにログに出力
          log('警告: ファイルディスクリプタへのstderrリダイレクトは現在サポートされていません');
          _process!.stderr.listen((data) {
            final message = utf8.decode(data);
            log('サーバーstderr: $message');
          });
        } else {
          // デフォルトでは、標準エラー出力をログに記録
          _process!.stderr.listen((data) {
            final message = utf8.decode(data);
            log('サーバーstderr: $message');
          });
        }
      }

      _inputStream = _process!.stdout;
      _outputSink = _process!.stdin;

      log('サーバープロセスが起動しました (PID: ${_process!.pid})');
    } catch (e) {
      log('サーバープロセスの起動に失敗しました: $e');
      rethrow;
    }
  }

  /// 直接指定されたストリームを設定します
  Future<void> _setupDirectStreams() async {
    log('直接ストリームを使用します');

    _inputStream = _options.inputStream ?? io.stdin;
    _outputSink = _options.outputSink ?? io.stdout;
  }

  /// 入力ストリームの処理を設定します
  Future<void> _setupInputProcessing() async {
    if (_inputStream == null) {
      throw StateError('入力ストリームが設定されていません');
    }

    // StdioBufferを使用してデコードを行う
    _buffer = StdioBuffer(_inputStream!);

    // メッセージの監視を開始
    _inputSubscription = _buffer!.lines.listen(
      _processInput,
      onDone: () {
        log('入力ストリームが終了しました');
        close();
      },
      onError: (Object e) {
        log('入力ストリームでエラーが発生しました: $e');
        handleError(e);
        close();
      },
    );
  }

  /// 入力行を処理します
  void _processInput(String line) {
    if (!isRunning) {
      return;
    }

    try {
      final jsonData = json.decode(line) as Map<String, dynamic>;
      final message = _codec.decode(jsonData);
      handleMessage(message);
    } catch (e) {
      log('入力の処理に失敗しました: $e');
      handleError(e);
    }
  }

  @override
  Future<void> send(JsonRpcMessage message) async {
    if (!isRunning) {
      await start();
    }

    if (_outputSink == null) {
      throw StateError('出力シンクが設定されていません');
    }

    try {
      final jsonData = _codec.encode(message);
      final line = json.encode(jsonData);
      _outputSink!.writeln(line);
      await _outputSink!.flush();
    } catch (e) {
      log('メッセージの送信に失敗しました: $e');
      handleError(e);
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    if (!isRunning) {
      return;
    }

    log('トランスポートをクローズします');
    isRunning = false;

    try {
      // 入力ストリームの購読をキャンセル
      await _inputSubscription?.cancel();
      _inputSubscription = null;

      // バッファをクローズ
      await _buffer?.close();
      _buffer = null;

      // プロセスが起動されていた場合はシャットダウン
      if (_process != null) {
        log('サーバープロセスをシャットダウンします (PID: ${_process!.pid})');

        // 出力シンクをクローズ
        _outputSink?.close();

        // graceful期間が経過したらプロセスを強制終了
        const gracePeriod = Duration(seconds: 5);
        Timer(gracePeriod, () {
          try {
            if (!_process!.kill()) {
              log('サーバープロセスの強制終了に失敗しました (PID: ${_process!.pid})');
            }
          } catch (e) {
            log('サーバープロセスの強制終了中にエラーが発生しました: $e');
          }
        });

        // プロセスの終了を待つ
        await _process!.exitCode.timeout(
          gracePeriod,
          onTimeout: () {
            log('サーバープロセスの終了待機がタイムアウトしました');
            return -1;
          },
        );

        _process = null;
      } else if (_outputSink != null && _outputSink != io.stdout) {
        // 標準出力以外の出力シンクであればクローズ
        await _outputSink!.close();
      }

      _inputStream = null;
      _outputSink = null;

      // 基底クラスのcloseを呼び出し
      await super.close();

      log('トランスポートのクローズが完了しました');
    } catch (e) {
      log('トランスポートのクローズ中にエラーが発生しました: $e');
      handleError(e);

      // エラーが発生しても基底クラスのcloseを呼び出し
      await super.close();

      rethrow;
    }
  }

  /// stdioトランスポートのファクトリコンビニエンスメソッド
  ///
  /// 標準入出力を使用するシンプルなトランスポートを作成します。
  static StdioClientTransport stdio({LoggingOptions? logging}) {
    return StdioClientTransport(
      options: StdioClientTransportOptions.stdio(logging: logging),
    );
  }
}
