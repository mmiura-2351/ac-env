#!/bin/bash
# コンフィグ管理スクリプト

set -euo pipefail

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# スクリプトのディレクトリ
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_ROOT/config.json"

# 使用方法表示
show_usage() {
    echo "使い方:"
    echo "  $0              # 全設定を表示"
    echo "  $0 <キー>        # 特定の設定値を取得"
    echo "  $0 <キー> <値>   # 設定値を変更"
    echo ""
    echo "利用可能なキー:"
    echo "  default_language      - デフォルトプログラミング言語 (cpp/python)"
    echo "  test_timeout          - テスト実行タイムアウト（ミリ秒）"
    echo "  parallel_tests        - 並列テスト実行の有効化 (true/false)"
    echo "  auto_submit_confirm   - 提出前の確認表示 (true/false)"
    echo "  editor                - デフォルトエディタコマンド"
    echo "  言語設定は config.json の supported_languages セクションで行います"
    echo "  test_dir_name         - テストディレクトリ名"
    echo "  submission_backup     - 提出バックアップの有効化 (true/false)"
    echo "  clean_keep_days       - 古い提出履歴の保持日数"
    echo "  color_output          - カラー出力の有効化 (true/false)"
}

# JSONから値を取得
get_config() {
    local key="$1"
    if command -v jq &> /dev/null; then
        jq -r ".$key // empty" "$CONFIG_FILE" 2>/dev/null || echo ""
    else
        # jqがない場合は簡易的なgrep/sed処理
        grep "\"$key\"" "$CONFIG_FILE" | sed -E 's/.*"'"$key"'"\s*:\s*"?([^",}]*)"?.*/\1/' | head -1
    fi
}

# JSONに値を設定
set_config() {
    local key="$1"
    local value="$2"
    
    # 値の型を判定
    if [[ "$value" =~ ^[0-9]+$ ]]; then
        # 数値
        json_value="$value"
    elif [[ "$value" == "true" || "$value" == "false" ]]; then
        # ブール値
        json_value="$value"
    elif [[ "$value" == "[]" || "$value" =~ ^\[.*\]$ ]]; then
        # 配列
        json_value="$value"
    else
        # 文字列
        json_value="\"$value\""
    fi
    
    if command -v jq &> /dev/null; then
        # jqを使用
        local tmp_file=$(mktemp)
        jq ".$key = $json_value" "$CONFIG_FILE" > "$tmp_file" && mv "$tmp_file" "$CONFIG_FILE"
        echo -e "${GREEN}✓ Set $key = $value${NC}"
    else
        echo -e "${RED}Error: jq is required to modify config. Please install jq.${NC}"
        echo "You can manually edit: $CONFIG_FILE"
        exit 1
    fi
}

# 全設定を表示
show_all_config() {
    echo -e "${BLUE}=== 現在の設定 ===${NC}"
    echo ""
    
    if command -v jq &> /dev/null; then
        jq -r 'to_entries | .[] | "\(.key): \(.value)"' "$CONFIG_FILE" | while IFS=: read -r key value; do
            # supported_languagesの場合は言語名のみ表示
            if [ "$key" = "supported_languages" ]; then
                local langs=$(jq -r '.supported_languages | keys | join(", ")' "$CONFIG_FILE")
                printf "${GREEN}%-24s${NC}:  %s\n" "$key" "$langs"
            else
                printf "${GREEN}%-24s${NC}:  %s\n" "$key" "$value"
            fi
        done
    else
        cat "$CONFIG_FILE"
    fi
    
    echo ""
    echo -e "${BLUE}設定ファイル: $CONFIG_FILE${NC}"
}

# 設定検証
validate_config() {
    local key="$1"
    local value="$2"
    
    case "$key" in
        default_language)
            # 設定ファイルを読み込んで対応言語をチェック
            if command -v jq &> /dev/null && [ -f "$CONFIG_FILE" ]; then
                local supported_langs
                supported_langs=$(jq -r '.supported_languages | keys[]' "$CONFIG_FILE" 2>/dev/null | tr '\n' ' ')
                if [[ ! " $supported_langs " =~ " $value " ]]; then
                    echo -e "${RED}エラー: 無効な言語です。対応言語: $supported_langs${NC}"
                    exit 1
                fi
            else
                # フォールバック（jqがない場合）
                if [[ ! "$value" =~ ^(cpp|python)$ ]]; then
                    echo -e "${RED}エラー: 無効な言語です。cpp または python を指定してください${NC}"
                    exit 1
                fi
            fi
            ;;
        test_timeout)
            if ! [[ "$value" =~ ^[0-9]+$ ]] || [ "$value" -lt 100 ] || [ "$value" -gt 30000 ]; then
                echo -e "${RED}エラー: 無効なタイムアウト値です。100〜30000ミリ秒の間で指定してください${NC}"
                exit 1
            fi
            ;;
        parallel_tests|auto_submit_confirm|submission_backup|color_output)
            if [[ ! "$value" =~ ^(true|false)$ ]]; then
                echo -e "${RED}エラー: 無効なブール値です。true または false を指定してください${NC}"
                exit 1
            fi
            ;;
        clean_keep_days)
            if ! [[ "$value" =~ ^[0-9]+$ ]] || [ "$value" -lt 1 ] || [ "$value" -gt 365 ]; then
                echo -e "${RED}エラー: 無効な日数です。1〜365日の間で指定してください${NC}"
                exit 1
            fi
            ;;
    esac
}

# メイン処理
main() {
    # コンフィグファイルが存在しない場合は作成
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}設定ファイルが見つかりません。デフォルト設定を作成中...${NC}"
        cat > "$CONFIG_FILE" << 'EOF'
{
  "default_language": "python",
  "default_template_dir": "templates",
  "test_timeout": 2000,
  "parallel_tests": false,
  "auto_submit_confirm": true,
  "editor": "",
  "cpp_flags": "-std=c++17 -O2 -Wall -Wextra",
  "python_command": "python3",
  "rust_flags": "-O",
  "test_dir_name": "test",
  "submission_backup": true,
  "submission_backup_dir": "~/.ac-env/submissions",
  "debug_patterns": ["debug", "DEBUG", "cout.*<<.*endl.*//.*debug"],
  "clean_keep_days": 30,
  "color_output": true
}
EOF
        echo -e "${GREEN}デフォルト設定を作成しました${NC}"
    fi
    
    case $# in
        0)
            # 引数なし: 全設定表示
            show_all_config
            ;;
        1)
            if [ "$1" == "help" ] || [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
                show_usage
            else
                # 1引数: 値を取得
                local value=$(get_config "$1")
                if [ -n "$value" ]; then
                    echo "$value"
                else
                    echo -e "${RED}エラー: 不明なキー: $1${NC}"
                    exit 1
                fi
            fi
            ;;
        2)
            # 2引数: 値を設定
            validate_config "$1" "$2"
            set_config "$1" "$2"
            ;;
        *)
            show_usage
            exit 1
            ;;
    esac
}

main "$@"