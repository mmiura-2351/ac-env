#!/bin/bash
# Step 6: PATH設定
# 全てのツールが利用可能になるようにPATHを設定

set -euo pipefail

# ライブラリ読み込み
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"
# shellcheck source=../lib/logger.sh
source "$SCRIPT_DIR/../lib/logger.sh"
# shellcheck source=../lib/path-manager.sh
source "$SCRIPT_DIR/../lib/path-manager.sh"

# =============================================================================
# PATH設定関数
# =============================================================================

# 現在のPATH状況を表示
show_current_path_status() {
    log_progress "現在のPATH状況を確認中"
    
    log_info "現在のPATH:"
    echo "$PATH" | tr ':' '\n' | head -5 | while read -r dir; do
        if [ -d "$dir" ]; then
            log_info "  ✓ $dir"
        else
            log_info "  ✗ $dir (存在しない)"
        fi
    done
    
    if [ "$(echo "$PATH" | tr ':' '\n' | wc -l)" -gt 5 ]; then
        log_info "  ... (他 $(($(echo "$PATH" | tr ':' '\n' | wc -l) - 5)) 個)"
    fi
}

# 重要なディレクトリの存在確認
check_important_directories() {
    log_progress "重要なディレクトリの存在確認中"
    
    local dirs=(
        "$LOCAL_BIN"
        "/usr/local/bin"
        "$(get_npm_prefix)/bin"
    )
    
    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            log_success "$dir: 存在"
        else
            log_warn "$dir: 存在しない"
            if [ "$dir" = "$LOCAL_BIN" ]; then
                ensure_dir "$dir"
                log_info "$dir を作成しました"
            fi
        fi
    done
}

# 実行可能ファイルの存在確認
check_executable_files() {
    log_progress "実行可能ファイルの存在確認中"
    
    local executables=(
        "python:$PYPY_DIR/bin/pypy3"
        "acc:$(get_npm_prefix)/bin/acc"
        "oj:$PYPY_DIR/bin/oj"
    )
    
    for entry in "${executables[@]}"; do
        local name="${entry%:*}"
        local path="${entry#*:}"
        
        if executable_exists "$path"; then
            log_success "$name: $path"
        else
            log_warn "$name: $path (見つからない)"
        fi
    done
}

# シンボリックリンクの状態確認
check_symlink_status() {
    log_progress "シンボリックリンクの状態確認中"
    
    if [ -d "$LOCAL_BIN" ]; then
        local symlinks
        symlinks=$(find "$LOCAL_BIN" -type l 2>/dev/null | wc -l)
        
        if [ "$symlinks" -gt 0 ]; then
            log_info "$LOCAL_BIN に $symlinks 個のシンボリックリンクがあります:"
            ls -la "$LOCAL_BIN"/ | grep "^l" | while read -r line; do
                log_info "  $line"
            done
        else
            log_info "$LOCAL_BIN にシンボリックリンクはありません"
        fi
    else
        log_warn "$LOCAL_BIN が存在しません"
    fi
}

# =============================================================================
# メイン処理
# =============================================================================

main() {
    log_step "Step 6: PATH設定"
    
    # 現状確認
    show_current_path_status
    check_important_directories
    check_executable_files
    check_symlink_status
    
    # PATH完全セットアップ実行
    setup_path_complete
    
    # 設定後の確認
    log_step "PATH設定後の確認"
    check_command_availability
    
    # PATH情報表示
    show_path_info
    
    log_success "PATH設定が完了しました"
    log_info "新しいターミナルまたは以下のコマンドで設定を有効化:"
    
    local shell_rc
    shell_rc=$(detect_shell_rc)
    if [ -n "$shell_rc" ]; then
        log_info "  source $shell_rc"
    else
        log_info "  新しいターミナルを開く"
    fi
    
    return 0
}

# スクリプトが直接実行された場合のみmainを呼び出し
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi