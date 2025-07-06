#!/bin/bash
# 環境ステータス確認スクリプト

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

# PATHを設定
export PATH="$HOME/.local/bin:$PATH"

echo -e "${BLUE}=== AtCoder環境ステータス ===${NC}"
echo ""

# ツールのインストール状態
echo -e "${BLUE}[ツールのインストール状況]${NC}"
if command -v acc &> /dev/null; then
    ACC_VERSION=$(acc --version 2>&1 | head -n1 || echo "不明")
    echo -e "${GREEN}✓ atcoder-cli${NC} ($ACC_VERSION)"
else
    echo -e "${RED}✗ atcoder-cli${NC} - 未インストール"
fi

if command -v oj &> /dev/null; then
    OJ_VERSION=$(oj --version 2>/dev/null | head -n1 || echo "不明")
    echo -e "${GREEN}✓ online-judge-tools${NC} ($OJ_VERSION)"
else
    echo -e "${RED}✗ online-judge-tools${NC} - 未インストール"
fi

# コンパイラ確認
echo ""
echo -e "${BLUE}[コンパイラ]${NC}"
if command -v g++ &> /dev/null; then
    GCC_VERSION=$(g++ --version | head -n1)
    echo -e "${GREEN}✓ g++${NC} - $GCC_VERSION"
else
    echo -e "${RED}✗ g++${NC} - 未インストール"
fi

if command -v python &> /dev/null; then
    PYTHON_VERSION=$(python --version 2>&1)
    if echo "$PYTHON_VERSION" | grep -q "PyPy"; then
        echo -e "${GREEN}✓ python (PyPy)${NC} - $PYTHON_VERSION"
    else
        echo -e "${GREEN}✓ python${NC} - $PYTHON_VERSION"
    fi
elif command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    echo -e "${GREEN}✓ python3${NC} - $PYTHON_VERSION"
else
    echo -e "${RED}✗ python${NC} - 未インストール"
fi


# ログイン状態
echo ""
echo -e "${BLUE}[ログイン状態]${NC}"

# accログイン状態確認
ACC_LOGGED_IN=false
if command -v acc &> /dev/null; then
    if acc session &> /dev/null && acc session 2>/dev/null | grep -q "OK"; then
        echo -e "${GREEN}✓ acc${NC} - ログイン済み"
        ACC_LOGGED_IN=true
    else
        echo -e "${RED}✗ acc${NC} - 未ログイン"
    fi
else
    echo -e "${RED}✗ acc${NC} - 未インストール"
fi

# ojログイン状態確認
OJ_LOGGED_IN=false
if command -v oj &> /dev/null && oj login --check https://atcoder.jp/ &> /dev/null; then
    echo -e "${GREEN}✓ oj${NC} - ログイン済み"
    OJ_LOGGED_IN=true
else
    echo -e "${RED}✗ oj${NC} - 未ログイン"
fi

# ログインしていない場合の手動ログイン手順
if [ "$ACC_LOGGED_IN" = "false" ] || [ "$OJ_LOGGED_IN" = "false" ]; then
    echo ""
    echo -e "${YELLOW}[手動ログイン手順]${NC}"
    echo "1. ブラウザで https://atcoder.jp/login を開いてログイン"
    echo "2. 以下のコマンドを実行:"
    
    if [ "$ACC_LOGGED_IN" = "false" ]; then
        echo "   ${BLUE}acc login${NC}"
    fi
    
    if [ "$OJ_LOGGED_IN" = "false" ]; then
        echo "   ${BLUE}oj login https://atcoder.jp/${NC}"
    fi
    
    echo ""
    echo "3. ログイン完了後は ${BLUE}make status${NC} で確認"
fi

# プロジェクト情報
echo ""
echo -e "${BLUE}[プロジェクト情報]${NC}"
echo "プロジェクトルート: $PROJECT_ROOT"
echo "現在のディレクトリ: $(pwd)"

# コンテスト一覧
if [ -d "$PROJECT_ROOT/contests" ]; then
    CONTEST_COUNT=$(find "$PROJECT_ROOT/contests" -maxdepth 1 -type d | tail -n +2 | wc -l)
    echo "コンテスト総数: $CONTEST_COUNT"
    
    if [ "$CONTEST_COUNT" -gt 0 ]; then
        echo ""
        echo -e "${BLUE}[最近のコンテスト]${NC}"
        ls -ltd "$PROJECT_ROOT/contests"/*/ 2>/dev/null | head -5 | while read -r line; do
            echo "  $line"
        done
    fi
fi

# 提出履歴
SUBMISSION_LOG="$HOME/.ac-env/submissions/history.csv"
if [ -f "$SUBMISSION_LOG" ]; then
    echo ""
    echo -e "${BLUE}[最近の提出履歴]${NC}"
    tail -5 "$SUBMISSION_LOG" | while IFS=, read -r timestamp contest problem file; do
        echo "  $timestamp - $contest/$problem ($file)"
    done
fi

# ディスク使用量
echo ""
echo -e "${BLUE}[ディスク使用量]${NC}"
if [ -d "$PROJECT_ROOT/contests" ]; then
    DISK_USAGE=$(du -sh "$PROJECT_ROOT/contests" 2>/dev/null | cut -f1 || echo "計算できません")
    echo "コンテストフォルダ: $DISK_USAGE"
else
    echo "コンテストフォルダ: 未作成"
fi