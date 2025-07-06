#!/bin/bash
# Step 7: 設定ファイル生成
# システム環境に最適化されたconfig.jsonを生成

set -euo pipefail

# ライブラリ読み込み
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"
# shellcheck source=../lib/logger.sh
source "$SCRIPT_DIR/../lib/logger.sh"

# =============================================================================
# 環境検出関数
# =============================================================================

# Pythonコマンドを検出
detect_python_command() {
    if executable_exists "$PYPY_DIR/bin/pypy3"; then
        echo "python"  # シンボリックリンク経由
    elif command_exists "python3"; then
        echo "python3"
    elif command_exists "python"; then
        echo "python"
    else
        echo "python3"  # デフォルト
    fi
}

# C++コンパイルフラグを検出
detect_cpp_flags() {
    if command_exists "g++"; then
        # C++20サポートテスト
        if echo 'int main(){}' | g++ -std=c++20 -x c++ - -o /dev/null 2>/dev/null; then
            echo "-std=c++20 -O2 -Wall -Wextra"
        elif echo 'int main(){}' | g++ -std=c++17 -x c++ - -o /dev/null 2>/dev/null; then
            echo "-std=c++17 -O2 -Wall -Wextra"
        else
            echo "-std=c++14 -O2 -Wall -Wextra"
        fi
    else
        echo "-std=c++20 -O2 -Wall -Wextra"  # デフォルト
    fi
}

# エディタを検出
detect_editor() {
    if command_exists "code"; then
        echo "code"
    elif command_exists "vim"; then
        echo "vim"
    elif command_exists "nano"; then
        echo "nano"
    elif command_exists "gedit"; then
        echo "gedit"
    elif [ -n "${EDITOR:-}" ]; then
        echo "$EDITOR"
    else
        echo "vim"  # デフォルト
    fi
}

# =============================================================================
# 設定値生成関数
# =============================================================================

# 言語設定を生成
generate_language_config() {
    local python_cmd="$1"
    local cpp_flags="$2"
    
    cat << EOF
    "cpp": {
      "name": "C++",
      "file_extension": "cpp",
      "main_file": "main.cpp",
      "compile_command": "g++ {{flags}} {{file}}",
      "run_command": "./a.out",
      "flags": "$cpp_flags",
      "template_file": "main.cpp"
    },
    "python": {
      "name": "Python",
      "file_extension": "py",
      "main_file": "main.py",
      "compile_command": "$python_cmd {{file}}",
      "run_command": "$python_cmd",
      "command": "$python_cmd",
      "template_file": "main.py"
    }
EOF
}

# デバッグパターンを生成
generate_debug_patterns() {
    cat << 'EOF'
["debug", "DEBUG", "cout.*<<.*endl.*//.*debug", "print.*debug", "console\\.log"]
EOF
}

# =============================================================================
# config.json生成
# =============================================================================

# 設定ファイルのバックアップ
backup_existing_config() {
    if file_exists "$CONFIG_FILE"; then
        local backup_file="$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$CONFIG_FILE" "$backup_file"
        log_success "既存の設定ファイルをバックアップ: $backup_file"
    fi
}

# config.jsonを生成
generate_config_file() {
    local python_cmd="$1"
    local cpp_flags="$2"
    local editor="$3"
    local os_type="$4"
    
    log_progress "config.jsonを生成中"
    
    # 設定ファイル生成
    cat > "$CONFIG_FILE" << EOF
{
  "default_language": "python",
  "supported_languages": {
$(generate_language_config "$python_cmd" "$cpp_flags")
  },
  "default_template_dir": "templates",
  "test_timeout": 2000,
  "parallel_tests": false,
  "auto_submit_confirm": true,
  "editor": "$editor",
  "test_dir_name": "test",
  "submission_backup": true,
  "submission_backup_dir": "~/.ac-env/submissions",
  "debug_patterns": $(generate_debug_patterns),
  "clean_keep_days": 30,
  "color_output": true,
  "detected_os": "$os_type",
  "auto_generated": true,
  "generation_date": "$(date -Iseconds)"
}
EOF
    
    log_success "config.jsonが生成されました: $CONFIG_FILE"
}

# 生成された設定の表示
show_generated_config() {
    local python_cmd="$1"
    local cpp_flags="$2"
    local editor="$3"
    local os_type="$4"
    
    log_step "生成された設定"
    log_info "デフォルト言語: C++"
    log_info "Pythonコマンド: $python_cmd"
    log_info "C++フラグ: $cpp_flags"
    log_info "エディタ: $editor"
    log_info "OS: $os_type"
}

# 設定ファイルの検証
validate_config_file() {
    log_progress "設定ファイルを検証中"
    
    if ! file_exists "$CONFIG_FILE"; then
        log_error "設定ファイルが生成されていません"
        return 1
    fi
    
    # JSONの構文チェック
    if command_exists "jq"; then
        if jq empty "$CONFIG_FILE" >/dev/null 2>&1; then
            log_success "JSON構文が正しいです"
        else
            log_error "JSON構文にエラーがあります"
            return 1
        fi
        
        # 必須キーの存在確認
        local required_keys=("default_language" "supported_languages" "editor")
        for key in "${required_keys[@]}"; do
            if jq -e ".$key" "$CONFIG_FILE" >/dev/null 2>&1; then
                log_debug "必須キー '$key' が存在します"
            else
                log_error "必須キー '$key' が見つかりません"
                return 1
            fi
        done
        
        log_success "設定ファイルの検証が完了しました"
    else
        log_warn "jqが利用できないため、JSON検証をスキップします"
    fi
    
    # ファイルサイズチェック
    local file_size
    file_size=$(wc -c < "$CONFIG_FILE")
    if [ "$file_size" -gt 100 ]; then
        log_success "設定ファイルサイズ: $file_size バイト"
    else
        log_warn "設定ファイルが小さすぎます: $file_size バイト"
    fi
}

# 設定ファイルの表示
show_config_contents() {
    if command_exists "jq"; then
        log_step "設定ファイル内容 (整形済み)"
        jq . "$CONFIG_FILE" | head -20
        
        local line_count
        line_count=$(jq . "$CONFIG_FILE" | wc -l)
        if [ "$line_count" -gt 20 ]; then
            log_info "... (他 $((line_count - 20)) 行)"
        fi
    else
        log_step "設定ファイル内容"
        head -20 "$CONFIG_FILE"
        
        local line_count
        line_count=$(wc -l < "$CONFIG_FILE")
        if [ "$line_count" -gt 20 ]; then
            log_info "... (他 $((line_count - 20)) 行)"
        fi
    fi
}

# =============================================================================
# メイン処理
# =============================================================================

main() {
    log_step "Step 7: 設定ファイル生成"
    
    # 環境検出
    log_progress "システム環境を検出中"
    
    local python_cmd
    python_cmd=$(detect_python_command)
    log_debug "検出されたPythonコマンド: $python_cmd"
    
    local cpp_flags
    cpp_flags=$(detect_cpp_flags)
    log_debug "検出されたC++フラグ: $cpp_flags"
    
    local editor
    editor=$(detect_editor)
    log_debug "検出されたエディタ: $editor"
    
    local os_type
    os_type=$(detect_os)
    log_debug "検出されたOS: $os_type"
    
    # 既存設定のバックアップ
    backup_existing_config
    
    # 設定ファイル生成
    generate_config_file "$python_cmd" "$cpp_flags" "$editor" "$os_type"
    
    # 設定内容表示
    show_generated_config "$python_cmd" "$cpp_flags" "$editor" "$os_type"
    
    # 検証
    if ! validate_config_file; then
        log_error "設定ファイルの生成に失敗しました"
        return 1
    fi
    
    # 内容表示
    show_config_contents
    
    log_success "設定ファイルの生成が完了しました"
    log_info "設定の変更は以下のコマンドで行えます:"
    log_info "  make config"
    log_info "  make config <キー> <値>"
    
    return 0
}

# スクリプトが直接実行された場合のみmainを呼び出し
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi