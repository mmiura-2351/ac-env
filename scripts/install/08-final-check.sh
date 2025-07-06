#!/bin/bash
# Step 8: 最終確認
# インストール完了後の動作確認と次のステップ案内

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
# 最終確認関数
# =============================================================================

# システム要件の最終確認
final_system_check() {
    log_step "システム要件の最終確認"
    
    local all_ok=true
    
    # OS情報
    local os_type
    os_type=$(detect_os)
    log_info "OS: $os_type"
    
    # ディスク使用量
    local used_space
    used_space=$(du -sh "$INSTALL_DIR" 2>/dev/null | cut -f1 || echo "不明")
    log_info "インストールディスク使用量: $used_space"
    
    # 権限確認
    if [ -w "$LOCAL_BIN" ] && [ -w "$PROJECT_ROOT" ]; then
        log_success "必要な権限が揃っています"
    else
        log_warn "一部のディレクトリで書き込み権限がない可能性があります"
        all_ok=false
    fi
    
    return $([ "$all_ok" = "true" ])
}

# インストールされたツールの詳細確認
detailed_tool_check() {
    log_step "インストールされたツールの詳細確認"
    
    local tools=(
        "python:PyPy/Python"
        "g++:C++コンパイラ"
        "acc:AtCoder CLI"
        "oj:online-judge-tools"
        "jq:JSON処理ツール"
        "git:バージョン管理"
    )
    
    for tool_entry in "${tools[@]}"; do
        local tool="${tool_entry%:*}"
        local description="${tool_entry#*:}"
        
        if command_exists "$tool"; then
            local path
            path=$(command -v "$tool")
            log_success "$description ($tool): $path"
            
            # バージョン情報表示
            case "$tool" in
                python)
                    local version
                    version=$(python --version 2>&1 || echo "不明")
                    log_info "  バージョン: $version"
                    ;;
                g++)
                    local version
                    version=$(g++ --version | head -1 || echo "不明")
                    log_info "  バージョン: $version"
                    ;;
                acc)
                    local version
                    version=$(acc --version 2>/dev/null || echo "不明")
                    log_info "  バージョン: $version"
                    ;;
                oj)
                    local version
                    version=$(oj --version 2>/dev/null | head -1 || echo "不明")
                    log_info "  バージョン: $version"
                    ;;
                jq)
                    local version
                    version=$(jq --version 2>/dev/null || echo "不明")
                    log_info "  バージョン: $version"
                    ;;
                git)
                    local version
                    version=$(git --version | head -1 || echo "不明")
                    log_info "  バージョン: $version"
                    ;;
            esac
        else
            log_warn "$description ($tool): 見つかりません"
        fi
    done
}

# 設定ファイルの確認
check_config_file() {
    log_step "設定ファイルの確認"
    
    if file_exists "$CONFIG_FILE"; then
        log_success "設定ファイル: $CONFIG_FILE"
        
        # 設定値の表示
        if command_exists "jq"; then
            local default_lang
            default_lang=$(jq -r '.default_language' "$CONFIG_FILE" 2>/dev/null || echo "不明")
            log_info "  デフォルト言語: $default_lang"
            
            local python_cmd
            python_cmd=$(jq -r '.supported_languages.python.command' "$CONFIG_FILE" 2>/dev/null || echo "不明")
            log_info "  Pythonコマンド: $python_cmd"
            
            local cpp_flags
            cpp_flags=$(jq -r '.supported_languages.cpp.flags' "$CONFIG_FILE" 2>/dev/null || echo "不明")
            log_info "  C++フラグ: $cpp_flags"
            
            local editor
            editor=$(jq -r '.editor' "$CONFIG_FILE" 2>/dev/null || echo "不明")
            log_info "  エディタ: $editor"
        else
            log_info "  jqが利用できないため、詳細確認をスキップ"
        fi
    else
        log_error "設定ファイルが見つかりません: $CONFIG_FILE"
        return 1
    fi
}

# テンプレートディレクトリの確認
check_templates() {
    log_step "テンプレートディレクトリの確認"
    
    local template_dir="$PROJECT_ROOT/templates"
    
    if [ -d "$template_dir" ]; then
        log_success "テンプレートディレクトリ: $template_dir"
        
        # テンプレートファイルの確認
        local templates
        templates=$(find "$template_dir" -name "*.cpp" -o -name "*.py" 2>/dev/null || true)
        
        if [ -n "$templates" ]; then
            log_info "  利用可能なテンプレート:"
            echo "$templates" | while read -r template; do
                log_info "    $(basename "$template")"
            done
        else
            log_warn "  テンプレートファイルが見つかりません"
        fi
    else
        log_warn "テンプレートディレクトリが見つかりません: $template_dir"
    fi
}

# PATH設定の最終確認
final_path_check() {
    log_step "PATH設定の最終確認"
    
    # 現在のセッションでの確認
    check_command_availability
    
    # シェル設定ファイルの確認
    local shell_rc
    shell_rc=$(detect_shell_rc)
    
    if [ -n "$shell_rc" ] && file_exists "$shell_rc"; then
        if grep -q "ac-env PATH settings" "$shell_rc"; then
            log_success "シェル設定ファイルにPATH設定が追加されています: $shell_rc"
        else
            log_warn "シェル設定ファイルにPATH設定が見つかりません: $shell_rc"
        fi
    else
        log_warn "シェル設定ファイルが見つかりません"
    fi
}

# 基本動作テスト
basic_functionality_test() {
    log_step "基本動作テスト"
    
    local test_passed=true
    
    # Pythonテスト
    if command_exists "python"; then
        if python -c "print('Python動作確認OK')" 2>/dev/null; then
            log_success "Python基本動作: OK"
        else
            log_warn "Python基本動作: NG"
            test_passed=false
        fi
    fi
    
    # C++テスト
    if command_exists "g++"; then
        local test_cpp="/tmp/test_cpp_$$.cpp"
        echo 'int main(){return 0;}' > "$test_cpp"
        
        if g++ "$test_cpp" -o "/tmp/test_cpp_$$" 2>/dev/null; then
            log_success "C++コンパイル: OK"
            rm -f "/tmp/test_cpp_$$" "$test_cpp"
        else
            log_warn "C++コンパイル: NG"
            test_passed=false
        fi
    fi
    
    # accテスト
    if command_exists "acc"; then
        if acc --help >/dev/null 2>&1; then
            log_success "AtCoder CLI基本動作: OK"
        else
            log_warn "AtCoder CLI基本動作: NG"
            test_passed=false
        fi
    fi
    
    # ojテスト
    if command_exists "oj"; then
        if oj --help >/dev/null 2>&1; then
            log_success "online-judge-tools基本動作: OK"
        else
            log_warn "online-judge-tools基本動作: NG"
            test_passed=false
        fi
    fi
    
    return $([ "$test_passed" = "true" ])
}

# 次のステップ案内
show_next_steps() {
    log_step "次のステップ"
    
    log_info "セットアップが完了しました！以下の手順で利用を開始してください："
    echo ""
    
    log_info "1. 新しいターミナルを開く、または以下を実行:"
    local shell_rc
    shell_rc=$(detect_shell_rc)
    if [ -n "$shell_rc" ]; then
        log_info "   source $shell_rc"
    fi
    echo ""
    
    log_info "2. AtCoderにログイン:"
    log_info "   acc login"
    log_info "   oj login https://atcoder.jp/"
    echo ""
    
    log_info "3. 新しいコンテストを開始:"
    log_info "   make new abc300"
    log_info "   cd contests/abc300/a"
    echo ""
    
    log_info "4. テンプレートをコピーして編集:"
    log_info "   make template"
    log_info "   make template python  # Python用"
    echo ""
    
    log_info "5. テスト実行・提出:"
    log_info "   make test"
    log_info "   make submit"
    echo ""
    
    log_info "6. 設定確認・変更:"
    log_info "   make config"
    log_info "   make config default_language python"
    echo ""
    
    log_info "7. ヘルプ表示:"
    log_info "   make help"
}

# 問題がある場合のトラブルシューティング案内
show_troubleshooting() {
    log_step "トラブルシューティング"
    
    log_info "問題が発生した場合:"
    echo ""
    
    log_info "• コマンドが見つからない場合:"
    log_info "  - 新しいターミナルを開く"
    log_info "  - source ~/.bashrc または source ~/.zshrc"
    log_info "  - echo \$PATH でPATHを確認"
    echo ""
    
    log_info "• 権限エラーが発生する場合:"
    log_info "  - sudo を使用せずに実行"
    log_info "  - ホームディレクトリの権限を確認"
    echo ""
    
    log_info "• ログの確認:"
    log_info "  - $INSTALL_DIR/logs/ 内のログファイル"
    echo ""
    
    log_info "• 再インストール:"
    log_info "  - rm -rf $INSTALL_DIR"
    log_info "  - make install"
}

# 成功・失敗の判定とサマリー
final_summary() {
    log_step "インストールサマリー"
    
    local critical_tools=("python" "g++" "acc" "oj")
    local working_tools=0
    local total_tools=${#critical_tools[@]}
    
    for tool in "${critical_tools[@]}"; do
        if command_exists "$tool"; then
            working_tools=$((working_tools + 1))
        fi
    done
    
    if [ "$working_tools" -eq "$total_tools" ]; then
        log_success "✅ すべての重要ツールが正常にインストールされました！"
        log_success "インストール成功率: 100% ($working_tools/$total_tools)"
        return 0
    elif [ "$working_tools" -gt $((total_tools / 2)) ]; then
        log_warn "⚠️  一部のツールで問題があります"
        log_warn "インストール成功率: $((working_tools * 100 / total_tools))% ($working_tools/$total_tools)"
        return 1
    else
        log_error "❌ 多くのツールでインストールに失敗しました"
        log_error "インストール成功率: $((working_tools * 100 / total_tools))% ($working_tools/$total_tools)"
        return 2
    fi
}

# =============================================================================
# メイン処理
# =============================================================================

main() {
    log_step "Step 8: 最終確認"
    
    # 詳細確認
    final_system_check
    detailed_tool_check
    check_config_file
    check_templates
    final_path_check
    
    # 動作テスト
    if basic_functionality_test; then
        log_success "基本動作テストが完了しました"
    else
        log_warn "一部の基本動作テストで問題が発生しました"
    fi
    
    # 最終サマリー
    local exit_code=0
    if ! final_summary; then
        exit_code=$?
    fi
    
    # 案内表示
    if [ "$exit_code" -eq 0 ]; then
        show_next_steps
    else
        show_troubleshooting
    fi
    
    echo ""
    log_info "詳細なログは以下で確認できます:"
    log_info "  $INSTALL_DIR/logs/"
    
    return $exit_code
}

# スクリプトが直接実行された場合のみmainを呼び出し
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi