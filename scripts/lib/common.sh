#!/bin/bash
# 競技プログラミング環境セットアップ - 共通ライブラリ
# 共通変数・関数・設定値を定義

set -euo pipefail

# =============================================================================
# 定数定義
# =============================================================================

readonly LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$(dirname "$LIB_DIR")")"
readonly INSTALL_DIR="$HOME/.ac-env"
readonly LOCAL_BIN="$HOME/.local/bin"
readonly CONFIG_FILE="$PROJECT_ROOT/config.json"

# PyPy設定
readonly PYPY_VERSION="3.10-v7.3.12"
readonly PYPY_DIR="$INSTALL_DIR/pypy3.10"

# カラー定義
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# =============================================================================
# 共通関数
# =============================================================================

# OS検出
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

# コマンド存在チェック
command_exists() {
    command -v "$1" &> /dev/null
}

# ディレクトリ作成（存在しない場合）
ensure_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
    fi
}

# ファイル存在確認
file_exists() {
    [ -f "$1" ]
}

# 実行可能ファイル確認
executable_exists() {
    [ -x "$1" ]
}

# シンボリックリンク作成（安全）
safe_symlink() {
    local target="$1"
    local link="$2"
    
    if [ -f "$target" ]; then
        ensure_dir "$(dirname "$link")"
        ln -sf "$target" "$link"
        return 0
    else
        return 1
    fi
}

# npm グローバルプレフィックス取得
get_npm_prefix() {
    npm config get prefix 2>/dev/null || echo "/usr/local"
}

# バージョン比較（major.minor形式）
version_gte() {
    local version="$1"
    local required="$2"
    
    local v_major v_minor r_major r_minor
    IFS='.' read -r v_major v_minor <<< "$version"
    IFS='.' read -r r_major r_minor <<< "$required"
    
    # 数値部分のみを抽出（例: "43.0" → "43"）
    v_major="${v_major//[^0-9]/}"
    v_minor="${v_minor//[^0-9]/}"
    r_major="${r_major//[^0-9]/}"
    r_minor="${r_minor//[^0-9]/}"
    
    [ "${v_major:-0}" -gt "${r_major:-0}" ] || \
    ([ "${v_major:-0}" -eq "${r_major:-0}" ] && [ "${v_minor:-0}" -ge "${r_minor:-0}" ])
}

# エラーでスクリプト終了
die() {
    echo -e "${RED}エラー: $1${NC}" >&2
    exit 1
}

# 警告メッセージ
warn() {
    echo -e "${YELLOW}警告: $1${NC}" >&2
}

# 情報メッセージ
info() {
    echo -e "${BLUE}$1${NC}"
}

# 成功メッセージ
success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# ステップヘッダー
step_header() {
    echo ""
    echo -e "${CYAN}=== $1 ===${NC}"
}

# 進行状況表示
progress() {
    echo -e "${BLUE}  → $1${NC}"
}

# 確認プロンプト
confirm() {
    local message="$1"
    local default="${2:-n}"
    
    echo -n "$message (y/n) [${default}]: "
    read -r response
    response="${response:-$default}"
    
    [[ "$response" =~ ^[Yy]$ ]]
}

# =============================================================================
# 初期化
# =============================================================================

# 必要なディレクトリを作成
init_common() {
    ensure_dir "$INSTALL_DIR"
    ensure_dir "$LOCAL_BIN"
    
    # 環境変数をエクスポート
    export INSTALL_DIR LOCAL_BIN PROJECT_ROOT CONFIG_FILE
    export PYPY_VERSION PYPY_DIR
}

# 初期化実行
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    # sourceされた場合のみ初期化
    init_common
fi