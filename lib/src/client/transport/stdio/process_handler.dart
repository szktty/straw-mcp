import 'dart:async';
import 'dart:io';

/// 標準エラー出力の処理方法を定義する抽象クラス
sealed class ProcessHandler {
  /// 内部コンストラクタ
  const ProcessHandler();

  /// プロセス起動モードを使用するハンドラーを作成
  ///
  /// [mode]: プロセス起動モードを指定
  static ProcessHandler startMode(ProcessStartMode mode) =>
      StartModeProcessHandler(mode);

  /// ストリームシンクを使用するハンドラーを作成
  ///
  /// [sink]: 出力先のストリームシンクを指定
  static ProcessHandler stream(StreamSink<List<int>> sink) =>
      StreamProcessHandler(sink);

  /// ファイルディスクリプタを使用するハンドラーを作成
  ///
  /// [fd]: ファイルディスクリプタ番号を指定
  static ProcessHandler fileDescriptor(int fd) =>
      FileDescriptorProcessHandler(fd);
}

/// プロセス起動モードを使った標準エラー出力処理
class StartModeProcessHandler extends ProcessHandler {
  /// コンストラクタ
  /// - [mode]: プロセス起動モード
  const StartModeProcessHandler(this.mode);

  /// プロセス起動モード
  final ProcessStartMode mode;
}

/// ストリームシンクを使った標準エラー出力処理
class StreamProcessHandler extends ProcessHandler {
  /// コンストラクタ
  /// - [sink]: 出力先のストリームシンク
  const StreamProcessHandler(this.sink);

  /// 出力先のストリームシンク
  final StreamSink<List<int>> sink;
}

/// ファイルディスクリプタを使った標準エラー出力処理
class FileDescriptorProcessHandler extends ProcessHandler {
  /// コンストラクタ
  /// - [fd]: ファイルディスクリプタ番号
  const FileDescriptorProcessHandler(this.fd);

  /// ファイルディスクリプタ番号
  final int fd;
}
