#!/bin/bash
# Step 1: 依存関係チェック
# 必要なツールとシステム要件をチェック

set -euo pipefail

# ライブラリ読み込み
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"
# shellcheck source=../lib/logger.sh
source "$SCRIPT_DIR/../lib/logger.sh"

# =============================================================================
# 依存関係チェック関数
# =============================================================================

# 必須コマンドチェック
check_required_commands() {
    local required_commands=("curl" "tar" "git")
    local missing_commands=()
    
    log_progress "必須コマンドをチェック中"
    
    for cmd in "${required_commands[@]}"; do
        if command_exists "$cmd"; then
            log_debug "$cmd: 利用可能"
        else
            missing_commands+=("$cmd")
            log_warn "$cmd: 見つかりません"
        fi
    done
    
    if [ ${#missing_commands[@]} -gt 0 ]; then
        log_error "以下の必須コマンドが見つかりません: ${missing_commands[*]}"
        log_info "インストール方法:"
        case "$(detect_os)" in
            linux)
                log_info "  Ubuntu/Debian: sudo apt-get install ${missing_commands[*]}"
                log_info "  CentOS/RHEL: sudo yum install ${missing_commands[*]}"
                ;;
            macos)
                log_info "  macOS: brew install ${missing_commands[*]}"
                ;;
        esac
        return 1
    fi
    
    log_success "必須コマンドが揃っています"
    return 0
}

# Node.js/npm チェック
check_nodejs() {
    log_progress "Node.js/npmをチェック中"
    
    if ! command_exists "node"; then
        log_warn "Node.jsが見つかりません"
        log_info "Node.jsをインストールしてください: https://nodejs.org/"
        return 1
    fi
    
    if ! command_exists "npm"; then
        log_warn "npmが見つかりません"
        return 1
    fi
    
    local node_version
    node_version=$(node --version | sed 's/^v//')
    local npm_version
    npm_version=$(npm --version)
    
    log_success "Node.js $node_version, npm $npm_version"
    
    # Node.js バージョンチェック（14以上推奨）
    if version_gte "$node_version" "14.0"; then
        log_success "Node.jsバージョンは要件を満たしています"
    else
        log_warn "Node.js 14.0以上を推奨します（現在: $node_version）"
    fi
    
    return 0
}

# git チェック
check_git() {
    log_progress "Gitをチェック中"
    
    if ! command_exists "git"; then
        log_warn "Gitが見つかりません"
        return 1
    fi
    
    local git_version
    git_version=$(git --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    log_success "Git $git_version"
    
    # Git 2.25以上推奨
    if version_gte "$git_version" "2.25"; then
        log_success "Gitバージョンは要件を満たしています"
    else
        log_warn "Git 2.25以上を推奨します（現在: $git_version）"
    fi
    
    return 0
}

# jq チェック（オプション）
check_jq() {
    log_progress "jqをチェック中"
    
    if command_exists "jq"; then
        local jq_version
        jq_version=$(jq --version | sed 's/^jq-//')
        log_success "jq $jq_version"
    else
        log_warn "jqが見つかりません（推奨ツール）"
        log_info "設定管理を向上させるため、jqのインストールを推奨します"
        case "$(detect_os)" in
            linux)
                log_info "  Ubuntu/Debian: sudo apt-get install jq"
                log_info "  CentOS/RHEL: sudo yum install jq"
                ;;
            macos)
                log_info "  macOS: brew install jq"
                ;;
        esac
    fi
}

# システム要件チェック
check_system_requirements() {
    log_progress "システム要件をチェック中"
    
    local os_type
    os_type=$(detect_os)
    log_info "OS: $os_type"
    
    # ディスク容量チェック（最低500MB）
    local available_space
    available_space=$(df "$HOME" | tail -1 | awk '{print $4}')
    local required_space=500000  # 500MB in KB
    
    if [ "$available_space" -gt "$required_space" ]; then
        log_success "十分なディスク容量があります"
    else
        log_warn "ディスク容量が不足している可能性があります"
    fi
    
    # ネットワーク接続チェック
    if curl -s --max-time 5 https://www.google.com > /dev/null; then
        log_success "インターネット接続が利用可能です"
    else
        log_warn "インターネット接続を確認してください"
    fi
}

# 既存のインストールチェック
check_existing_installation() {
    log_progress "既存のインストールをチェック中"
    
    local existing_items=()
    
    # PyPy
    if [ -d "$PYPY_DIR" ]; then
        existing_items+=("PyPy ($PYPY_DIR)")
    fi
    
    # AtCoder CLI
    if command_exists "acc"; then
        existing_items+=("AtCoder CLI")
    fi
    
    # online-judge-tools
    if command_exists "oj"; then
        existing_items+=("online-judge-tools")
    fi
    
    if [ ${#existing_items[@]} -gt 0 ]; then
        log_warn "以下が既にインストールされています:"
        for item in "${existing_items[@]}"; do
            log_info "  - $item"
        done
        log_info "継続すると既存のインストールが更新される可能性があります"
    else
        log_success "クリーンな環境です"
    fi
}

# =============================================================================
# メイン処理
# =============================================================================

main() {
    log_step "Step 1: 依存関係チェック"
    
    local all_checks_passed=true
    
    # 必須チェック
    if ! check_required_commands; then
        all_checks_passed=false
    fi
    
    if ! check_nodejs; then
        all_checks_passed=false
    fi
    
    if ! check_git; then
        all_checks_passed=false
    fi
    
    # オプションチェック
    check_jq
    check_system_requirements
    check_existing_installation
    
    # 結果判定
    if [ "$all_checks_passed" = "true" ]; then
        log_success "すべての依存関係チェックが完了しました"
        return 0
    else
        log_error "一部の依存関係が満たされていません"
        log_info "不足している依存関係をインストールしてから再実行してください"
        return 1
    fi
}

# スクリプトが直接実行された場合のみmainを呼び出し
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi