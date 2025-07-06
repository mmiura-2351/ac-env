#!/bin/bash
# 競技プログラミング環境セットアップ - PATH管理ライブラリ
# PATH設定とシンボリックリンク管理

# 依存関係
if [ -z "${PROJECT_ROOT:-}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # shellcheck source=./common.sh
    source "$SCRIPT_DIR/common.sh"
    # shellcheck source=./logger.sh
    source "$SCRIPT_DIR/logger.sh"
fi

# =============================================================================
# PATH管理設定
# =============================================================================

readonly SHELL_RC_MARKER="# === ac-env PATH settings ==="

# =============================================================================
# シェル設定ファイル検出
# =============================================================================

# シェル設定ファイルを検出
detect_shell_rc() {
    local shell_rc=""
    
    # 現在のシェルに基づいて決定
    if [ -n "${BASH_VERSION:-}" ]; then
        shell_rc="$HOME/.bashrc"
    elif [ -n "${ZSH_VERSION:-}" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        shell_rc="$HOME/.bashrc"
    elif [ -f "$HOME/.zshrc" ]; then
        shell_rc="$HOME/.zshrc"
    fi
    
    echo "$shell_rc"
}

# =============================================================================
# PATH管理関数
# =============================================================================

# 基本PATHを構築
build_base_path() {
    local npm_prefix
    npm_prefix=$(get_npm_prefix)
    
    echo "$LOCAL_BIN:/usr/local/bin:$npm_prefix/bin"
}

# 現在のセッションでPATHを設定
set_current_path() {
    local base_path
    base_path=$(build_base_path)
    
    export PATH="$base_path:$PATH"
    log_debug "現在のセッションPATH: $PATH"
}

# シェル設定ファイルにPATH設定を追加
add_path_to_shell_rc() {
    local shell_rc
    shell_rc=$(detect_shell_rc)
    
    if [ -z "$shell_rc" ]; then
        log_warn "シェル設定ファイルが見つかりません"
        return 1
    fi
    
    # 既に設定されているかチェック
    if [ -f "$shell_rc" ] && grep -q "$SHELL_RC_MARKER" "$shell_rc"; then
        log_debug "PATH設定は既に$shell_rcに存在します"
        return 0
    fi
    
    # PATH設定を追加
    {
        echo ""
        echo "$SHELL_RC_MARKER"
        echo "# 競技プログラミング環境のPATH設定"
        echo "if [ -d \"\$HOME/.local/bin\" ]; then"
        echo "    NPM_PREFIX=\$(npm config get prefix 2>/dev/null || echo \"/usr/local\")"
        echo "    export PATH=\"\$HOME/.local/bin:/usr/local/bin:\$NPM_PREFIX/bin:\$PATH\""
        echo "fi"
        echo "$SHELL_RC_MARKER"
    } >> "$shell_rc"
    
    log_success "PATH設定を$shell_rcに追加しました"
    return 0
}

# =============================================================================
# シンボリックリンク管理
# =============================================================================

# accコマンドのシンボリックリンク作成
setup_acc_symlink() {
    local npm_prefix
    npm_prefix=$(get_npm_prefix)
    local acc_path="$npm_prefix/bin/acc"
    local link_path="$LOCAL_BIN/acc"
    
    if safe_symlink "$acc_path" "$link_path"; then
        log_success "accコマンドのシンボリックリンクを作成: $link_path"
        return 0
    else
        log_warn "accコマンドが見つかりません: $acc_path"
        return 1
    fi
}

# ojコマンドのシンボリックリンク作成
setup_oj_symlink() {
    local oj_path="$PYPY_DIR/bin/oj"
    local link_path="$LOCAL_BIN/oj"
    
    if safe_symlink "$oj_path" "$link_path"; then
        log_success "ojコマンドのシンボリックリンクを作成: $link_path"
        return 0
    else
        log_warn "ojコマンドが見つかりません: $oj_path"
        return 1
    fi
}

# pythonコマンドのシンボリックリンク作成
setup_python_symlink() {
    local python_path="$PYPY_DIR/bin/pypy3"
    local link_path="$LOCAL_BIN/python"
    
    if safe_symlink "$python_path" "$link_path"; then
        log_success "pythonコマンドのシンボリックリンクを作成: $link_path"
        return 0
    else
        log_warn "PyPyが見つかりません: $python_path"
        return 1
    fi
}

# 全てのシンボリックリンクを設定
setup_all_symlinks() {
    log_step "シンボリックリンクを設定中"
    
    ensure_dir "$LOCAL_BIN"
    
    # python (PyPy)
    setup_python_symlink
    
    # acc (AtCoder CLI)
    setup_acc_symlink
    
    # oj (online-judge-tools)
    setup_oj_symlink
}

# =============================================================================
# PATH完全セットアップ
# =============================================================================

# PATH設定の完全セットアップ
setup_path_complete() {
    log_step "PATH設定をセットアップ中"
    
    # 現在のセッションでPATH設定
    set_current_path
    
    # シェル設定ファイルにPATH追加
    add_path_to_shell_rc
    
    # シンボリックリンク設定
    setup_all_symlinks
    
    log_success "PATH設定が完了しました"
}

# =============================================================================
# PATH検証
# =============================================================================

# コマンドの利用可能性をチェック
check_command_availability() {
    local commands=("python" "acc" "oj" "g++" "jq")
    local all_ok=true
    
    log_step "コマンドの利用可能性を確認中"
    
    for cmd in "${commands[@]}"; do
        if command_exists "$cmd"; then
            local cmd_path
            cmd_path=$(command -v "$cmd")
            log_success "$cmd: $cmd_path"
        else
            log_warn "$cmd: 見つかりません"
            all_ok=false
        fi
    done
    
    if [ "$all_ok" = "true" ]; then
        log_success "すべてのコマンドが利用可能です"
        return 0
    else
        log_warn "一部のコマンドが利用できません"
        return 1
    fi
}

# PATH設定の詳細表示
show_path_info() {
    log_step "現在のPATH設定"
    
    echo "PATH環境変数:"
    echo "$PATH" | tr ':' '\n' | head -10
    
    echo ""
    echo "重要なディレクトリ:"
    echo "  LOCAL_BIN: $LOCAL_BIN"
    echo "  NPM_PREFIX: $(get_npm_prefix)"
    echo "  PYPY_DIR: $PYPY_DIR"
    
    echo ""
    echo "シンボリックリンク:"
    ls -la "$LOCAL_BIN"/ 2>/dev/null | grep -E "(acc|oj|python)" || echo "  (シンボリックリンクなし)"
}