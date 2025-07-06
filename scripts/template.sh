#!/bin/bash
# テンプレートコピースクリプト

set -euo pipefail

# 設定読み込み
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/lib/config-loader.sh"

# デフォルト言語
DEFAULT_LANG=$(get_config "default_language" "python")
LANG="${1:-$DEFAULT_LANG}"

# 言語サポートチェック
if ! is_language_supported "$LANG"; then
    echo -e "${RED}エラー: サポートされていない言語です: $LANG${NC}"
    echo -e "${BLUE}対応言語:${NC} $(get_supported_languages)"
    exit 1
fi

# テンプレートディレクトリ
TEMPLATE_DIR_NAME=$(get_config "default_template_dir" "templates")
TEMPLATES_DIR="$PROJECT_ROOT/$TEMPLATE_DIR_NAME"

# 言語設定から値を取得
TEMPLATE_FILE="$TEMPLATES_DIR/$LANG/$(get_language_config "$LANG" "template_file")"
OUTPUT_FILE="$(get_language_config "$LANG" "main_file")"

# テンプレートディレクトリ作成（なければ）
mkdir -p "$(dirname "$TEMPLATE_FILE")"

# テンプレートファイルが存在しない場合は作成
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo -e "${YELLOW}テンプレートが見つかりません。デフォルトテンプレートを作成中...${NC}"
    
    case "$LANG" in
        cpp)
            cat > "$TEMPLATE_FILE" << 'EOF'
#include <bits/stdc++.h>
using namespace std;

int main() {
    ios::sync_with_stdio(false);
    cin.tie(nullptr);
    
    
    
    return 0;
}
EOF
            ;;
        python)
            cat > "$TEMPLATE_FILE" << 'EOF'
import sys
input = sys.stdin.readline

def main():
    pass

if __name__ == "__main__":
    main()
EOF
            ;;
        *)
            echo -e "${RED}エラー: $LANG のデフォルトテンプレートが利用できません${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}デフォルトテンプレートを作成しました: $TEMPLATE_FILE${NC}"
fi

# 既存ファイルチェック
if [ -f "$OUTPUT_FILE" ]; then
    echo -e "${YELLOW}警告: $OUTPUT_FILE は既に存在します${NC}"
    echo -n "上書きしますか？ (y/n): "
    read -r response
    if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
        echo -e "${RED}キャンセルしました${NC}"
        exit 0
    fi
fi

# テンプレートコピー
cp "$TEMPLATE_FILE" "$OUTPUT_FILE"
echo -e "${GREEN}✓ テンプレートをコピーしました: $OUTPUT_FILE${NC}"

# エディタで開くかどうか
CONFIGURED_EDITOR=$(get_config "editor" "")
EDITOR_CMD="${EDITOR:-$CONFIGURED_EDITOR}"

if [ -n "$EDITOR_CMD" ]; then
    echo -n "エディタで開きますか？ (y/n): "
    read -r response
    if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
        $EDITOR_CMD "$OUTPUT_FILE"
    fi
fi