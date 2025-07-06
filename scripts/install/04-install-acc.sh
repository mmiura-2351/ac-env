#!/bin/bash
# Step 4: AtCoder CLI インストール
# npm経由でatcoder-cliをインストール

set -euo pipefail

# ライブラリ読み込み
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"
# shellcheck source=../lib/logger.sh
source "$SCRIPT_DIR/../lib/logger.sh"

# =============================================================================
# AtCoder CLI インストール関数
# =============================================================================

# 既存のAtCoder CLIをチェック
check_existing_acc() {
    log_progress "既存のAtCoder CLIをチェック中"
    
    if command_exists "acc"; then
        local acc_path
        acc_path=$(command -v acc)
        log_success "AtCoder CLIが既にインストールされています: $acc_path"
        
        # バージョン確認
        if acc --version >/dev/null 2>&1; then
            local version
            version=$(acc --version 2>/dev/null || echo "不明")
            log_info "バージョン: $version"
        fi
        
        return 0
    else
        log_info "AtCoder CLIが見つかりません"
        return 1
    fi
}

# npm環境をチェック
check_npm_environment() {
    log_progress "npm環境をチェック中"
    
    if ! command_exists "npm"; then
        log_error "npmが見つかりません"
        log_info "Node.jsをインストールしてください: https://nodejs.org/"
        return 1
    fi
    
    local npm_version
    npm_version=$(npm --version)
    log_success "npm $npm_version"
    
    # npmグローバルプレフィックス確認
    local npm_prefix
    npm_prefix=$(get_npm_prefix)
    log_info "npmグローバルプレフィックス: $npm_prefix"
    
    # グローバルインストール権限チェック
    if [ ! -w "$npm_prefix" ] && [ "$npm_prefix" = "/usr/local" ]; then
        log_warn "グローバルインストールには管理者権限が必要な場合があります"
    fi
    
    return 0
}

# AtCoder CLIをインストール
install_atcoder_cli() {
    log_progress "AtCoder CLIをインストール中"
    
    # npmでグローバルインストール
    if ! npm install -g atcoder-cli; then
        log_error "AtCoder CLIのインストールに失敗しました"
        log_info "以下を試してください:"
        log_info "1. 管理者権限で実行: sudo npm install -g atcoder-cli"
        log_info "2. npmの設定変更: npm config set prefix ~/.npm-global"
        return 1
    fi
    
    log_success "AtCoder CLIのインストールが完了しました"
}

# インストール確認
verify_acc_installation() {
    log_progress "AtCoder CLIのインストールを確認中"
    
    local npm_prefix
    npm_prefix=$(get_npm_prefix)
    local acc_path="$npm_prefix/bin/acc"
    
    # インストール先確認
    if file_exists "$acc_path"; then
        log_success "AtCoder CLI実行ファイル確認: $acc_path"
    else
        log_error "AtCoder CLI実行ファイルが見つかりません: $acc_path"
        return 1
    fi
    
    # npmリストで確認
    if npm list -g atcoder-cli >/dev/null 2>&1; then
        local version
        version=$(npm list -g atcoder-cli | grep atcoder-cli | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        log_success "AtCoder CLI パッケージ確認: v$version"
    else
        log_warn "npmリストでAtCoder CLIが見つかりません"
    fi
    
    return 0
}

# シンボリックリンクをセットアップ
setup_acc_symlink() {
    log_progress "accコマンドのシンボリックリンクをセットアップ中"
    
    local npm_prefix
    npm_prefix=$(get_npm_prefix)
    local acc_path="$npm_prefix/bin/acc"
    local link_path="$LOCAL_BIN/acc"
    
    if safe_symlink "$acc_path" "$link_path"; then
        log_success "accコマンドのシンボリックリンクを作成: $link_path"
    else
        log_warn "accコマンドのシンボリックリンク作成に失敗しました"
        log_info "手動でPATHに追加してください: $npm_prefix/bin"
    fi
}

# 最終確認（accコマンドが実行可能か）
test_acc_command() {
    log_progress "accコマンドの動作確認中"
    
    # PATHを一時的に更新
    local npm_prefix
    npm_prefix=$(get_npm_prefix)
    export PATH="$LOCAL_BIN:$npm_prefix/bin:$PATH"
    
    if command_exists "acc"; then
        local acc_path
        acc_path=$(command -v acc)
        log_success "accコマンドが利用可能です: $acc_path"
        
        # バージョン表示テスト
        if acc --version >/dev/null 2>&1; then
            local version
            version=$(acc --version 2>/dev/null || echo "不明")
            log_success "バージョン確認: $version"
        else
            log_warn "バージョン確認でエラーが発生しました"
        fi
        
        return 0
    else
        log_error "accコマンドが利用できません"
        log_info "PATHの設定を確認してください"
        return 1
    fi
}

# AtCoder CLIの設定確認
check_acc_config() {
    log_progress "AtCoder CLIの設定を確認中"
    
    # PATHを更新
    local npm_prefix
    npm_prefix=$(get_npm_prefix)
    export PATH="$LOCAL_BIN:$npm_prefix/bin:$PATH"
    
    if command_exists "acc"; then
        # セッション確認（ログイン状態の確認）
        log_info "AtCoder CLIの使用を開始するには、以下を実行してください:"
        log_info "  acc login"
        log_info "  acc session"
    fi
}

# =============================================================================
# メイン処理
# =============================================================================

main() {
    log_step "Step 4: AtCoder CLI インストール"
    
    # 既存のAtCoder CLIチェック
    if check_existing_acc; then
        log_info "適切なAtCoder CLIが既に利用可能です"
        log_info "スキップして次のステップに進みます"
        return 0
    fi
    
    # npm環境チェック
    if ! check_npm_environment; then
        log_error "npm環境が整っていません"
        return 1
    fi
    
    # AtCoder CLIインストール
    if ! install_atcoder_cli; then
        log_error "AtCoder CLIのインストールに失敗しました"
        return 1
    fi
    
    # インストール確認
    if ! verify_acc_installation; then
        log_error "AtCoder CLIのインストール確認に失敗しました"
        return 1
    fi
    
    # シンボリックリンクセットアップ
    setup_acc_symlink
    
    # 動作確認
    if ! test_acc_command; then
        log_warn "accコマンドの動作確認で問題が発生しました"
        log_info "PATH設定後に利用可能になる予定です"
    fi
    
    # 設定案内
    check_acc_config
    
    log_success "AtCoder CLIのインストールが完了しました"
    return 0
}

# スクリプトが直接実行された場合のみmainを呼び出し
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi