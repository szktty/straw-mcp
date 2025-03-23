# MemoMCP サーバー用 Makefile

# 変数
DART = dart
OUTPUT_DIR = bin
OUTPUT_NAME = memo_mcp
SOURCE = bin/mcp_server.dart
API_URL = http://localhost:8888/api
LOG_LEVEL = info
PING_INTERVAL = 30

# ビルドコマンド
.PHONY: all
all: build

# 依存関係の更新
.PHONY: deps
deps:
	@echo "依存関係を更新しています..."
	@$(DART) pub get

# デバッグ実行
.PHONY: run
run: deps
	@echo "開発モードで実行しています..."
	@$(DART) $(SOURCE) --api-url=$(API_URL) --log-level=$(LOG_LEVEL) --ping-interval=$(PING_INTERVAL)

# 実行可能ファイルにコンパイル
.PHONY: build
build: deps
	@echo "実行可能ファイルをビルドしています..."
	@mkdir -p $(OUTPUT_DIR)
	@$(DART) compile exe $(SOURCE) -o $(OUTPUT_DIR)/$(OUTPUT_NAME)
	@chmod +x $(OUTPUT_DIR)/$(OUTPUT_NAME)
	@echo "ビルド完了: $(OUTPUT_DIR)/$(OUTPUT_NAME)"

# コンパイル済みファイルを実行
.PHONY: start
start: build
	@echo "コンパイル済みファイルを実行しています..."
	@$(OUTPUT_DIR)/$(OUTPUT_NAME) --api-url=$(API_URL) --log-level=$(LOG_LEVEL) --ping-interval=$(PING_INTERVAL)

# テスト実行
.PHONY: test
test: deps
	@echo "テストを実行しています..."
	@$(DART) test

# ツールテストを実行
.PHONY: test-tools
test-tools: deps
	@echo "ツールテストを実行しています..."
	@$(DART) test test/test_tools.dart

# 手動テストを実行
.PHONY: manual-test
manual-test: deps
	@echo "手動テストを実行しています..."
	@$(DART) run test/manual_test.dart

# クリーンアップ
.PHONY: clean
clean:
	@echo "ビルドファイルを削除しています..."
	@rm -f $(OUTPUT_DIR)/$(OUTPUT_NAME)

# ヘルプ
.PHONY: help
help:
	@echo "利用可能なコマンド:"
	@echo "  make deps                  - 依存関係を更新"
	@echo "  make run                   - 開発モードで実行"
	@echo "  make build                 - 実行可能ファイルをビルド"
	@echo "  make start                 - コンパイル済みファイルを実行"
	@echo "  make test                  - テストを実行"
	@echo "  make test-tools             - ツールテストを実行"
	@echo "  make manual-test            - 手動テストを実行"
	@echo "  make clean                 - ビルドファイルを削除"
	@echo ""
	@echo "環境変数:"
	@echo "  API_URL=<URL>             - APIエンドポイントURL (デフォルト: $(API_URL))"
	@echo "  LOG_LEVEL=<レベル>        - ログレベル (デフォルト: $(LOG_LEVEL))"
	@echo "  PING_INTERVAL=<秒>        - ping間隔 (デフォルト: $(PING_INTERVAL))"
	@echo ""
	@echo "例:"
	@echo "  make build API_URL=http://localhost:3000/api"
	@echo "  make start LOG_LEVEL=debug"
