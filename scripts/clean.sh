#!/bin/bash
# クリーンアップスクリプト

set -euo pipefail

# 設定読み込み
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/config-loader.sh"

PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONTESTS_DIR="$PROJECT_ROOT/contests"

# コマンド引数の処理
DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        --dry-run|--dryrun|-n)
            DRY_RUN=true
            ;;
    esac
done

# 設定値取得
KEEP_DAYS=$(get_config "clean_keep_days" "30")
BACKUP_DIR=$(expand_path "$(get_config "submission_backup_dir" "~/.ac-env/submissions")")

echo -e "${BLUE}=== クリーンアップスクリプト ===${NC}"

# 削除対象をカウント
count_files() {
    local pattern="$1"
    find "$CONTESTS_DIR" -name "$pattern" -type f 2>/dev/null | wc -l
}

# ファイル削除
remove_files() {
    local pattern="$1"
    local description="$2"
    local count=$(count_files "$pattern")
    
    if [ "$count" -gt 0 ]; then
        echo -e "${YELLOW}$description ファイルが $count 個見つかりました${NC}"
        
        if [ "$DRY_RUN" = "true" ]; then
            echo "  (dry-run) 削除対象:"
            find "$CONTESTS_DIR" -name "$pattern" -type f 2>/dev/null | head -10
            if [ "$count" -gt 10 ]; then
                echo "  ... 他 $((count - 10)) 個"
            fi
        else
            find "$CONTESTS_DIR" -name "$pattern" -type f -delete 2>/dev/null
            echo -e "${GREEN}  ✓ $count 個のファイルを削除しました${NC}"
        fi
    else
        echo -e "${GREEN}$description ファイルは見つかりませんでした${NC}"
    fi
}

# メイン処理
main() {
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${YELLOW}DRY-RUNモードで実行中${NC}"
        echo ""
    fi
    
    # コンパイル済みファイル
    echo -e "${BLUE}[コンパイル済みファイル]${NC}"
    remove_files "a.out" "コンパイル済みバイナリ"
    remove_files "*.exe" "Windows実行ファイル"
    remove_files "*.o" "オブジェクト"
    
    # エディタのバックアップファイル
    echo ""
    echo -e "${BLUE}[エディタバックアップファイル]${NC}"
    remove_files "*~" "バックアップ"
    remove_files "*.swp" "vimスワップ"
    remove_files ".*.swp" "隠しvimスワップ"
    
    # キャッシュクリア
    echo ""
    echo -e "${BLUE}[キャッシュディレクトリ]${NC}"
    
    # online-judge-toolsのキャッシュ
    OJ_CACHE="$HOME/.cache/online-judge-tools"
    if [ -d "$OJ_CACHE" ]; then
        CACHE_SIZE=$(du -sh "$OJ_CACHE" 2>/dev/null | cut -f1)
        echo -e "${YELLOW}online-judge-toolsキャッシュ: $CACHE_SIZE${NC}"
        
        if [ "$DRY_RUN" != "true" ]; then
            echo -n "キャッシュをクリアしますか？ (y/n): "
            read -r response
            if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
                rm -rf "$OJ_CACHE"
                echo -e "${GREEN}  ✓ キャッシュがクリアされました${NC}"
            fi
        else
            echo "  (dry-run) キャッシュをクリアします"
        fi
    else
        echo -e "${GREEN}ojキャッシュは見つかりませんでした${NC}"
    fi
    
    # 古い提出履歴
    echo ""
    echo -e "${BLUE}[古い提出履歴]${NC}"
    if [ -d "$BACKUP_DIR" ]; then
        OLD_SUBMISSIONS=$(find "$BACKUP_DIR" -name "*.cpp" -o -name "*.py" -o -name "*.rs" -mtime "+$KEEP_DAYS" 2>/dev/null | wc -l)
        if [ "$OLD_SUBMISSIONS" -gt 0 ]; then
            echo -e "${YELLOW}$KEEP_DAYS 日より古い提出履歴が $OLD_SUBMISSIONS 個見つかりました${NC}"
            
            if [ "$DRY_RUN" != "true" ]; then
                echo -n "古い提出履歴を削除しますか？ (y/n): "
                read -r response
                if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
                    find "$BACKUP_DIR" -name "*.cpp" -o -name "*.py" -o -name "*.rs" -mtime "+$KEEP_DAYS" -delete 2>/dev/null
                    echo -e "${GREEN}  ✓ 古い提出履歴を削除しました${NC}"
                fi
            else
                echo "  (dry-run) 古い提出履歴を削除します"
            fi
        else
            echo -e "${GREEN}古い提出履歴は見つかりませんでした${NC}"
        fi
    fi
    
    # サマリー
    echo ""
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${YELLOW}Dry-run が完了しました。実際にクリーンアップするには DRY_RUN=true なしで実行してください。${NC}"
    else
        echo -e "${GREEN}クリーンアップが完了しました！${NC}"
    fi
}

main "$@"