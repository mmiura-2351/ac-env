#!/bin/bash
# テスト実行スクリプト

set -euo pipefail

# 設定読み込み
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/config-loader.sh"

# デフォルト設定
PROBLEM="${1:-}"
TEST_DIR_NAME=$(get_config "test_dir_name" "test")

# メインファイルを探す（言語固有の関数は削除し、共通関数を使用）
# find_main_file関数はconfig-loader.shに移動済み

# テスト実行
run_test() {
    local main_file
    main_file=$(find_main_file) || {
        echo -e "${RED}エラー: メインファイルが見つかりません${NC}"
        echo -e "${YELLOW}対応する拡張子のファイルを探しています${NC}"
        exit 1
    }
    
    # ファイルから言語を自動判定
    local language
    language=$(detect_language_from_file "$main_file") || {
        echo -e "${RED}エラー: ファイル拡張子から言語を判定できません: $main_file${NC}"
        echo -e "${BLUE}対応言語:${NC} $(get_supported_languages)"
        exit 1
    }
    
    # 言語サポートチェック
    if ! is_language_supported "$language"; then
        echo -e "${RED}エラー: サポートされていない言語です: $language${NC}"
        echo -e "${BLUE}対応言語:${NC} $(get_supported_languages)"
        exit 1
    fi
    
    local compile_cmd
    compile_cmd=$(get_language_command "$language" "$main_file")
    
    echo -e "${BLUE}テスト実行: $main_file (言語: $language)${NC}"
    echo -e "${BLUE}コマンド: $compile_cmd${NC}"
    
    local timeout=$(get_config "test_timeout" "2000")
    
    if [ -d "$TEST_DIR_NAME" ]; then
        oj test -c "$compile_cmd" -d "$TEST_DIR_NAME/" -t "$timeout"
    elif [ -d "test" ]; then
        oj test -c "$compile_cmd" -d test/ -t "$timeout"
    elif [ -d "tests" ]; then
        oj test -c "$compile_cmd" -d tests/ -t "$timeout"
    else
        echo -e "${RED}エラー: テストディレクトリが見つかりません${NC}"
        echo -e "${YELLOW}'$TEST_DIR_NAME'、'test'、または'tests'ディレクトリを探しています${NC}"
        exit 1
    fi
}

# メイン処理
if [ -z "$PROBLEM" ]; then
    # 現在のディレクトリでテスト
    if [ -d "test" ] || [ -d "tests" ]; then
        echo -e "${BLUE}現在のディレクトリでテストを実行${NC}"
        run_test
    else
        echo -e "${RED}エラー: 問題ディレクトリではありません${NC}"
        exit 1
    fi
else
    # 指定された問題ディレクトリでテスト
    if [ -d "$PROBLEM" ]; then
        echo -e "${BLUE}問題 $PROBLEM のテストを実行${NC}"
        cd "$PROBLEM"
        run_test
    else
        echo -e "${RED}エラー: 問題ディレクトリ '$PROBLEM' が見つかりません${NC}"
        exit 1
    fi
fi