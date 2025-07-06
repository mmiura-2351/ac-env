#!/bin/bash
# Step 5: online-judge-tools インストール
# PyPy環境にonline-judge-toolsをインストール

set -euo pipefail

# ライブラリ読み込み
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"
# shellcheck source=../lib/logger.sh
source "$SCRIPT_DIR/../lib/logger.sh"

# =============================================================================
# online-judge-tools インストール関数
# =============================================================================

# 既存のonline-judge-toolsをチェック
check_existing_oj() {
    log_progress "既存のonline-judge-toolsをチェック中"
    
    if command_exists "oj"; then
        local oj_path
        oj_path=$(command -v oj)
        log_success "online-judge-toolsが既にインストールされています: $oj_path"
        
        # バージョン確認
        if oj --version >/dev/null 2>&1; then
            local version
            version=$(oj --version 2>/dev/null | head -1 || echo "不明")
            log_info "バージョン: $version"
        fi
        
        return 0
    else
        log_info "online-judge-toolsが見つかりません"
        return 1
    fi
}

# Python環境をチェック
check_python_environment() {
    log_progress "Python環境をチェック中"
    
    # PyPyチェック
    local pypy_python="$PYPY_DIR/bin/pypy3"
    if executable_exists "$pypy_python"; then
        local version
        version=$("$pypy_python" --version 2>&1)
        log_success "PyPy環境: $version"
        
        # pipが利用可能か確認
        if "$pypy_python" -m pip --version >/dev/null 2>&1; then
            local pip_version
            pip_version=$("$pypy_python" -m pip --version | head -1)
            log_success "pip: $pip_version"
        else
            log_error "PyPy環境にpipが見つかりません"
            return 1
        fi
        
        return 0
    fi
    
    # システムPythonチェック
    if command_exists "python"; then
        local version
        version=$(python --version 2>&1)
        log_info "システムPython: $version"
        
        if python -m pip --version >/dev/null 2>&1; then
            log_success "システムPythonのpipが利用可能です"
            return 0
        else
            log_warn "システムPythonでpipが利用できません"
        fi
    fi
    
    log_error "適切なPython環境が見つかりません"
    return 1
}

# PyPy環境にonline-judge-toolsをインストール
install_oj_pypy() {
    local pypy_python="$PYPY_DIR/bin/pypy3"
    
    log_progress "PyPy環境にonline-judge-toolsをインストール中"
    
    # pipの更新
    log_progress "pipを更新中"
    if ! "$pypy_python" -m pip install --upgrade pip; then
        log_warn "pipの更新に失敗しました（継続します）"
    fi
    
    # 必要な依存関係をインストール
    log_progress "必要な依存関係をインストール中"
    if ! "$pypy_python" -m pip install lxml beautifulsoup4; then
        log_warn "依存関係のインストールで一部失敗しました（継続します）"
    fi
    
    # online-judge-toolsインストール
    log_progress "online-judge-toolsをインストール中"
    if ! "$pypy_python" -m pip install online-judge-tools; then
        log_error "online-judge-toolsのインストールに失敗しました"
        return 1
    fi
    
    # HTML parser の問題を修正
    local utils_file="$PYPY_DIR/lib/pypy3.10/site-packages/onlinejudge/_implementation/utils.py"
    if [ -f "$utils_file" ]; then
        log_progress "HTML parserを修正中"
        sed -i "s/HTML_PARSER = 'lxml'/HTML_PARSER = 'html.parser'/" "$utils_file" 2>/dev/null || true
    fi
    
    log_success "PyPy環境へのonline-judge-toolsインストールが完了しました"
}

# システムPython環境にonline-judge-toolsをインストール
install_oj_system() {
    log_progress "システムPython環境にonline-judge-toolsをインストール中"
    
    # pipの確認
    local pip_cmd=""
    if command_exists "pip3"; then
        pip_cmd="pip3"
    elif command_exists "pip"; then
        pip_cmd="pip"
    elif python -m pip --version >/dev/null 2>&1; then
        pip_cmd="python -m pip"
    else
        log_error "pipが見つかりません"
        return 1
    fi
    
    # 必要な依存関係をインストール
    log_progress "必要な依存関係をインストール中 ($pip_cmd)"
    if ! eval "$pip_cmd install lxml beautifulsoup4"; then
        log_warn "依存関係のインストールで一部失敗しました（継続します）"
    fi
    
    # online-judge-toolsインストール
    log_progress "online-judge-toolsをインストール中 ($pip_cmd)"
    if ! eval "$pip_cmd install online-judge-tools"; then
        log_error "online-judge-toolsのインストールに失敗しました"
        return 1
    fi
    
    log_success "システムPython環境へのonline-judge-toolsインストールが完了しました"
}

# インストール先を決定してインストール
install_online_judge_tools() {
    local pypy_python="$PYPY_DIR/bin/pypy3"
    
    # PyPy環境を優先
    if executable_exists "$pypy_python"; then
        install_oj_pypy
    else
        install_oj_system
    fi
}

# インストール確認
verify_oj_installation() {
    log_progress "online-judge-toolsのインストールを確認中"
    
    # PyPy環境での確認
    local pypy_python="$PYPY_DIR/bin/pypy3"
    local pypy_oj="$PYPY_DIR/bin/oj"
    
    if executable_exists "$pypy_python" && file_exists "$pypy_oj"; then
        log_success "PyPy環境のoj実行ファイル確認: $pypy_oj"
        
        # バージョン確認
        if "$pypy_oj" --version >/dev/null 2>&1; then
            local version
            version=$("$pypy_oj" --version 2>/dev/null | head -1 || echo "不明")
            log_success "PyPy環境のojバージョン: $version"
        fi
        
        return 0
    fi
    
    # システム環境での確認
    if command_exists "oj"; then
        local oj_path
        oj_path=$(command -v oj)
        log_success "システム環境のoj実行ファイル確認: $oj_path"
        
        if oj --version >/dev/null 2>&1; then
            local version
            version=$(oj --version 2>/dev/null | head -1 || echo "不明")
            log_success "システム環境のojバージョン: $version"
        fi
        
        return 0
    fi
    
    log_error "ojコマンドが見つかりません"
    return 1
}

# シンボリックリンクをセットアップ
setup_oj_symlink() {
    log_progress "ojコマンドのシンボリックリンクをセットアップ中"
    
    local pypy_oj="$PYPY_DIR/bin/oj"
    local link_path="$LOCAL_BIN/oj"
    
    # PyPy環境のojを優先
    if file_exists "$pypy_oj"; then
        if safe_symlink "$pypy_oj" "$link_path"; then
            log_success "ojコマンドのシンボリックリンクを作成: $link_path -> $pypy_oj"
            return 0
        fi
    fi
    
    # システム環境のojがある場合
    if command_exists "oj"; then
        local oj_path
        oj_path=$(command -v oj)
        log_info "システム環境のojが利用可能です: $oj_path"
        return 0
    fi
    
    log_warn "ojコマンドのシンボリックリンク作成に失敗しました"
    return 1
}

# 最終確認（ojコマンドが実行可能か）
test_oj_command() {
    log_progress "ojコマンドの動作確認中"
    
    # PATHを一時的に更新
    export PATH="$LOCAL_BIN:$PATH"
    
    if command_exists "oj"; then
        local oj_path
        oj_path=$(command -v oj)
        log_success "ojコマンドが利用可能です: $oj_path"
        
        # バージョン表示テスト
        if oj --version >/dev/null 2>&1; then
            local version
            version=$(oj --version 2>/dev/null | head -1 || echo "不明")
            log_success "バージョン確認: $version"
        else
            log_warn "バージョン確認でエラーが発生しました"
        fi
        
        # 簡単な機能テスト
        if oj --help >/dev/null 2>&1; then
            log_success "基本機能が正常に動作しています"
        else
            log_warn "基本機能でエラーが発生しました"
        fi
        
        return 0
    else
        log_error "ojコマンドが利用できません"
        log_info "PATHの設定を確認してください"
        return 1
    fi
}

# online-judge-toolsの設定確認
check_oj_config() {
    log_progress "online-judge-toolsの設定を確認中"
    
    # PATHを更新
    export PATH="$LOCAL_BIN:$PATH"
    
    if command_exists "oj"; then
        log_info "online-judge-toolsの使用を開始するには、以下を実行してください:"
        log_info "  oj login https://atcoder.jp/"
        log_info "  oj --help  # 使用方法の確認"
    fi
}

# =============================================================================
# メイン処理
# =============================================================================

main() {
    log_step "Step 5: online-judge-tools インストール"
    
    # 既存のonline-judge-toolsチェック
    if check_existing_oj; then
        log_info "適切なonline-judge-toolsが既に利用可能です"
        log_info "スキップして次のステップに進みます"
        return 0
    fi
    
    # Python環境チェック
    if ! check_python_environment; then
        log_error "Python環境が整っていません"
        return 1
    fi
    
    # online-judge-toolsインストール
    if ! install_online_judge_tools; then
        log_error "online-judge-toolsのインストールに失敗しました"
        return 1
    fi
    
    # インストール確認
    if ! verify_oj_installation; then
        log_error "online-judge-toolsのインストール確認に失敗しました"
        return 1
    fi
    
    # シンボリックリンクセットアップ
    setup_oj_symlink
    
    # 動作確認
    if ! test_oj_command; then
        log_warn "ojコマンドの動作確認で問題が発生しました"
        log_info "PATH設定後に利用可能になる予定です"
    fi
    
    # 設定案内
    check_oj_config
    
    log_success "online-judge-toolsのインストールが完了しました"
    return 0
}

# スクリプトが直接実行された場合のみmainを呼び出し
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi