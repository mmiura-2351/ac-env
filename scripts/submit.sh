#!/bin/bash
# 提出スクリプト

set -euo pipefail

# 設定読み込み
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/config-loader.sh"

# 引数処理
PROBLEM=""
FORCE=false

for arg in "$@"; do
    case "$arg" in
        --force|-f)
            FORCE=true
            ;;
        *)
            if [ -z "$PROBLEM" ]; then
                PROBLEM="$arg"
            fi
            ;;
    esac
done

AUTO_CONFIRM=$(get_config "auto_submit_confirm" "true")
BACKUP_ENABLED=$(get_config "submission_backup" "true")
BACKUP_DIR=$(expand_path "$(get_config "submission_backup_dir" "~/.ac-env/submissions")")

# メインファイルを探す（言語固有の関数は削除し、共通関数を使用）
# find_main_file関数はconfig-loader.shに移動済み

# 提出前チェック
pre_submit_check() {
    local file="$1"
    
    echo -e "${BLUE}提出前チェック:${NC}"
    
    # ファイルサイズチェック
    local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    echo -e "  ファイルサイズ: $size バイト"
    
    # デバッグコードチェック
    local has_debug=false
    while IFS= read -r pattern; do
        if grep -E "$pattern" "$file" > /dev/null; then
            echo -e "${YELLOW}  ⚠ 警告: デバッグコードが検出されました (パターン: $pattern)${NC}"
            has_debug=true
        fi
    done < <(get_config_array "debug_patterns")
    
    if [ "$has_debug" = false ]; then
        echo -e "${GREEN}  ✓ デバッグコードは検出されませんでした${NC}"
    fi
    
    # TODOチェック
    if grep -E "(TODO|FIXME|XXX)" "$file" > /dev/null; then
        echo -e "${YELLOW}  ⚠ 警告: TODO/FIXMEが見つかりました${NC}"
    else
        echo -e "${GREEN}  ✓ TODO/FIXMEは見つかりませんでした${NC}"
    fi
    
    echo ""
}

# 提出確認
confirm_submit() {
    if [ "$FORCE" != "true" ] && [ "$AUTO_CONFIRM" == "true" ]; then
        echo -e "${YELLOW}本当に提出しますか？ (y/n)${NC}"
        read -r response
        if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
            echo -e "${RED}提出がキャンセルされました${NC}"
            exit 0
        fi
    fi
}

# 提出実行
do_submit() {
    local file="$1"
    
    echo -e "${BLUE}提出中: $file${NC}"
    
    if acc submit "$file"; then
        echo -e "${GREEN}✓ 提出が成功しました！${NC}"
        
        if [ "$BACKUP_ENABLED" == "true" ]; then
            # 提出履歴を記録
            mkdir -p "$BACKUP_DIR"
            local timestamp=$(date +"%Y%m%d_%H%M%S")
            local contest=$(basename "$(dirname "$(pwd)")")
            local problem=$(basename "$(pwd)")
            
            # ログファイルに記録
            echo "$timestamp,$contest,$problem,$file" >> "$BACKUP_DIR/history.csv"
            
            # 提出したコードをバックアップ
            cp "$file" "$BACKUP_DIR/${timestamp}_${contest}_${problem}_${file}"
        fi
        
    else
        echo -e "${RED}✗ 提出に失敗しました${NC}"
        exit 1
    fi
}

# メイン処理
main() {
    if [ -z "$PROBLEM" ]; then
        # 現在のディレクトリから提出
        local main_file
        main_file=$(find_main_file) || {
            echo -e "${RED}エラー: メインファイルが見つかりません${NC}"
            echo -e "${YELLOW}対応する拡張子のファイルを探しています${NC}"
            exit 1
        }
        
        echo -e "${BLUE}現在のディレクトリから提出${NC}"
        pre_submit_check "$main_file"
        confirm_submit
        do_submit "$main_file"
        
    else
        # 指定された問題ディレクトリから提出
        if [ -d "$PROBLEM" ]; then
            cd "$PROBLEM"
            
            local main_file
            main_file=$(find_main_file) || {
                echo -e "${RED}エラー: $PROBLEM にメインファイルが見つかりません${NC}"
                echo -e "${YELLOW}対応する拡張子のファイルを探しています${NC}"
                exit 1
            }
            
            echo -e "${BLUE}問題 $PROBLEM を提出${NC}"
            pre_submit_check "$main_file"
            confirm_submit
            do_submit "$main_file"
            
        else
            echo -e "${RED}エラー: 問題ディレクトリ '$PROBLEM' が見つかりません${NC}"
            exit 1
        fi
    fi
}

main