#!/bin/bash
# 新規コンテスト作成スクリプト

set -euo pipefail

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# 引数チェック
if [ $# -eq 0 ]; then
    echo -e "${RED}エラー: コンテスト名が必要です${NC}"
    echo "使い方: $0 <コンテスト名>"
    exit 1
fi

CONTEST="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONTESTS_DIR="$PROJECT_ROOT/contests"

# contestsディレクトリ作成
mkdir -p "$CONTESTS_DIR"

echo -e "${BLUE}コンテスト作成中: $CONTEST${NC}"

# コンテスト作成（テストケースダウンロードはスキップ、すべての問題を選択）
cd "$CONTESTS_DIR"
acc new "$CONTEST" --no-tests --choice all

# 作成されたディレクトリに移動
if [ -d "$CONTEST" ]; then
    cd "$CONTEST"
    
    # 各問題のテストケースを自動取得
    for problem in */; do
        if [ -d "$problem" ]; then
            problem_name="${problem%/}"
            echo -e "${BLUE}問題 $problem_name のテストケースを取得中${NC}"
            cd "$problem"
            
            # テストケースをダウンロード（明示的にtestディレクトリを指定）
            url="https://atcoder.jp/contests/$CONTEST/tasks/${CONTEST}_${problem_name}"
            if oj download "$url" -d test 2>/dev/null; then
                echo -e "${GREEN}✓ 問題 $problem_name のテストケースをダウンロードしました${NC}"
            else
                echo -e "${RED}✗ 問題 $problem_name のテストケースダウンロードに失敗しました${NC}"
            fi
            
            # Makefileへのシンボリックリンクを作成
            if [ ! -e "Makefile" ]; then
                ln -s ../../../Makefile Makefile
                echo -e "${GREEN}✓ 問題 $problem_name にMakefileのリンクを作成しました${NC}"
            fi
            
            cd ..
        fi
    done
    
    echo -e "${GREEN}コンテスト $CONTEST が正常に作成されました！${NC}"
    echo -e "${GREEN}場所: $CONTESTS_DIR/$CONTEST${NC}"
else
    echo -e "${RED}エラー: コンテストディレクトリの作成に失敗しました${NC}"
    exit 1
fi