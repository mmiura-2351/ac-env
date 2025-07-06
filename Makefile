# 競技プログラミング環境 Makefile

.PHONY: help install uninstall login login-simple new test submit template status clean config

# Makefileの絶対パスを取得
MAKEFILE_DIR := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))
SCRIPT_DIR := $(MAKEFILE_DIR)scripts

# =============================================================================
# デフォルトターゲット
# =============================================================================

help:
	@echo "競技プログラミング環境コマンド"
	@echo ""
	@echo "=== セットアップ ==="
	@echo "  make install              環境をセットアップ（不足している依存関係のみ）"
	@echo "  make uninstall            環境を削除"
	@echo ""
	@echo "=== 競技プログラミング ==="
	@echo "  make new abc300           新しいコンテストを作成"
	@echo "  make test [問題名]        テストを実行"
	@echo "  make submit [問題名]      問題を提出"
	@echo "  make template [言語]      テンプレートをコピー"
	@echo "  make status               現在の状態を表示（ログイン状態含む）"
	@echo ""
	@echo "=== 管理 ==="
	@echo "  make config               設定の表示"
	@echo "  make config キー 値       設定値の変更"
	@echo "  make clean                一時ファイルをクリーンアップ"

# =============================================================================
# セットアップ
# =============================================================================

# 環境セットアップ（不足している依存関係のみインストール）
install:
	@$(SCRIPT_DIR)/install.sh --skip-existing

# 環境のアンインストール
uninstall:
	@$(SCRIPT_DIR)/uninstall.sh

# =============================================================================
# 競技プログラミングワークフロー
# =============================================================================

# 新規コンテスト作成
new:
	@if [ -n "$(CONTEST)" ]; then \
		$(SCRIPT_DIR)/new-contest.sh $(CONTEST); \
	elif [ -n "$(word 1,$(filter-out $@,$(MAKECMDGOALS)))" ]; then \
		$(SCRIPT_DIR)/new-contest.sh $(word 1,$(filter-out $@,$(MAKECMDGOALS))); \
	else \
		echo "エラー: コンテスト名が必要です"; \
		echo "使い方: make new abc300"; \
		exit 1; \
	fi

# テスト実行
test:
	@$(SCRIPT_DIR)/test.sh $(filter-out $@,$(MAKECMDGOALS))

# 提出
submit:
	@$(SCRIPT_DIR)/submit.sh $(filter-out $@,$(MAKECMDGOALS))

# テンプレートコピー
template:
	@$(SCRIPT_DIR)/template.sh $(filter-out $@,$(MAKECMDGOALS))


# ステータス確認
status:
	@$(SCRIPT_DIR)/status.sh

# クリーンアップ
clean:
	@$(SCRIPT_DIR)/clean.sh $(filter-out $@,$(MAKECMDGOALS))

# 設定管理
config:
	@$(SCRIPT_DIR)/config.sh $(filter-out $@,$(MAKECMDGOALS))

# Makefileの引数を無視するためのダミーターゲット
%:
	@: