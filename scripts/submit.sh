#!/bin/bash
# 提出スクリプト

set -euo pipefail

# 設定読み込み
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/config-loader.sh"

# PATHを設定
export PATH="$HOME/.local/bin:$PATH"

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

# テスト実行
run_tests() {
    local file="$1"
    
    echo -e "${BLUE}提出前にテストを実行中...${NC}"
    
    # テストディレクトリの確認
    local test_dir=""
    if [ -d "test" ]; then
        test_dir="test"
    elif [ -d "tests" ]; then
        test_dir="tests"
    else
        echo -e "${RED}✗ テストディレクトリが見つかりません${NC}"
        return 1
    fi
    
    # ファイルから言語を自動判定
    local language
    language=$(detect_language_from_file "$file") || {
        echo -e "${RED}エラー: ファイル拡張子から言語を判定できません: $file${NC}"
        return 1
    }
    
    # 言語サポートチェック
    if ! is_language_supported "$language"; then
        echo -e "${RED}エラー: サポートされていない言語です: $language${NC}"
        return 1
    fi
    
    local compile_cmd
    compile_cmd=$(get_language_command "$language" "$file")
    local timeout=$(get_config "test_timeout" "2000")
    
    echo -e "${BLUE}テスト実行: $file (言語: $language)${NC}"
    
    # テスト実行
    if oj test -c "$compile_cmd" -d "$test_dir/" -t "$timeout" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ すべてのテストが成功しました${NC}"
        return 0
    else
        echo -e "${RED}✗ テストが失敗しました${NC}"
        echo -e "${YELLOW}提出前にテストを修正してください${NC}"
        return 1
    fi
}


# 提出準備
prepare_submission() {
    local file="$1"
    
    echo -e "${BLUE}提出準備中: $file${NC}"
    
    # 現在のディレクトリから問題URLを構築
    local contest=$(basename "$(dirname "$(pwd)")")
    local problem=$(basename "$(pwd)")
    local task_name="${contest}_${problem}"
    local submit_url="https://atcoder.jp/contests/$contest/submit?taskScreenName=$task_name"
    local problem_url="https://atcoder.jp/contests/$contest/tasks/$task_name"
    
    echo -e "${GREEN}✓ 提出準備が完了しました${NC}"
    echo ""
    echo -e "${BLUE}=== 提出情報 ===${NC}"
    echo -e "${BLUE}コンテスト: $contest${NC}"
    echo -e "${BLUE}問題: $problem${NC}"
    echo -e "${BLUE}ファイル: $file${NC}"
    echo ""
    
    echo ""
    echo -e "${BLUE}=== 手動提出手順 ===${NC}"
    echo -e "${BLUE}1. ブラウザで以下のURLを開いてください:${NC}"
    echo -e "${GREEN}   $submit_url${NC}"
    echo -e "${BLUE}2. 問題「$problem」を選択${NC}"
    echo -e "${BLUE}3. 言語を選択${NC}"
    echo -e "${BLUE}4. コードをコピー&ペースト: $file${NC}"
    echo -e "${BLUE}5. 提出ボタンをクリック${NC}"
    echo ""
    echo -e "${BLUE}問題ページ: $problem_url${NC}"
    
    # バックアップを作成
    backup_submission "$file"
}

# 提出バックアップ
backup_submission() {
    local file="$1"
    
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
        echo -e "${GREEN}✓ 提出バックアップを保存しました${NC}"
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
        
        echo -e "${BLUE}現在のディレクトリから提出準備${NC}"
        
        # 提出前チェック
        pre_submit_check "$main_file"
        
        # テスト実行
        if ! run_tests "$main_file"; then
            echo -e "${RED}テストが失敗したため提出を中止します${NC}"
            exit 1
        fi
        
        # 提出確認
        confirm_submit
        
        # 提出準備（URLコピーと案内）
        prepare_submission "$main_file"
        
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
            
            echo -e "${BLUE}問題 $PROBLEM の提出準備${NC}"
            
            # 提出前チェック
            pre_submit_check "$main_file"
            
            # テスト実行
            if ! run_tests "$main_file"; then
                echo -e "${RED}テストが失敗したため提出を中止します${NC}"
                exit 1
            fi
            
            # 提出確認
            confirm_submit
            
            # 提出準備（URLコピーと案内）
            prepare_submission "$main_file"
            
        else
            echo -e "${RED}エラー: 問題ディレクトリ '$PROBLEM' が見つかりません${NC}"
            exit 1
        fi
    fi
}

main