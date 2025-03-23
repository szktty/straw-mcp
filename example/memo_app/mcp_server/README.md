# MemoMCP サーバー

MemoAppとClaude Desktopを連携するためのMCPサーバーです。

## 機能

- メモの作成、一覧取得、削除などの操作をClaude Desktopから実行できるようにします
- MemoAppとの連携によって、AIアシスタントがメモ管理をサポートします

## 提供ツール

本サーバーは以下のツールを提供します：

- **create-memo**: 新規メモを作成します
- **list-memos**: 保存されているメモの一覧を取得します
- **delete-memo**: 指定されたIDのメモを削除します

## 提供リソース

本サーバーは以下のリソースを提供します：

- **memo://list**: メモ一覧（テキスト形式）

## 使い方

### 前提条件

- Dart SDK (3.7.0以上)
- MemoApp（APIエンドポイントが利用可能な状態）
- Claude Desktop（MCP機能対応版）

### インストール

```bash
# 依存関係のインストール
dart pub get
```

### 実行

```bash
# 開発モードで実行
dart bin/mcp_server.dart --api-url=http://localhost:8888/api

# または Makefile を使用
make run API_URL=http://localhost:8888/api
```

### ビルド

```bash
# 実行可能ファイルにコンパイル
make build

# 実行
make start API_URL=http://localhost:8888/api
```

## Claude Desktopとの連携

Claude Desktopの設定ファイル（`claude_desktop_config.json`）を編集し、以下のように追加します：

```json
{
  "mcpServers": {
    "memo": {
      "command": "/absolute/path/to/memo_mcp",
      "args": ["--api-url=http://localhost:8888/api"]
    }
  }
}
```

設定ファイルの場所：
- macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Windows: `%APPDATA%\Claude\claude_desktop_config.json`

## テスト

MCPサーバーのテストには以下のコマンドを使用できます：

```bash
# 単体テストを実行
make test

# ツールテストを実行（モックAPIサーバーを使用）
make test-tools

# 対話的な手動テストを実行
make manual-test
```

### 手動テスト

`make manual-test` コマンドは対話的なテストインターフェースを提供します。
このツールを使用して、MCPサーバーのツールとリソースを手動でテストできます。

主な機能：

1. メモ一覧の取得
2. 新規メモの作成
3. メモの削除
4. リソースの読み取り
5. ツール・リソース一覧の取得

テスト結果は自動的にログファイルに保存されます。

### ツールテスト

`make test-tools` コマンドは、自動化されたテストを実行します。
このテストでは、モックAPIサーバーを使用して、MCPサーバーのツールとリソースが正しく機能することを検証します。

## コマンドラインオプション

```
使用方法: memo_mcp [options]

オプション:
  -a, --api-url=<URL>          MemoAppのAPIエンドポイントURL
                               (デフォルト: http://localhost:8888/api)
  -l, --log-level=<レベル>      ログレベル
                               (デフォルト: info)
  -p, --ping-interval=<秒>      APIサーバーへのping間隔
                               (デフォルト: 30)
  -h, --help                   ヘルプを表示
```

## トラブルシューティング

### APIサーバーに接続できない

MemoAppが起動しており、APIエンドポイントが正しく設定されていることを確認してください。
デフォルトでは `http://localhost:8888/api` に接続を試みます。

### Claude Desktopで認識されない

Claude Desktopの設定ファイルが正しく設定されていることを確認してください。
特に、絶対パスが正しく指定されていることを確認します。

### ツールの呼び出しでエラーが発生する

手動テストツール (`make manual-test`) を使用して、ツールの動作を確認してください。
詳細なエラーメッセージとログが生成されます。
