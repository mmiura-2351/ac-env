#!/bin/bash
# 競技プログラミング環境アンインストール
# インストールした全てのコンポーネントを安全に削除

set -euo pipefail

# ライブラリ読み込み
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/logger.sh
source "$SCRIPT_DIR/lib/logger.sh"

# =============================================================================
# アンインストール設定
# =============================================================================

# デフォルト設定
DRY_RUN=${DRY_RUN:-false}
FORCE=${FORCE:-false}
VERBOSE=${VERBOSE:-false}
KEEP_CONFIG=${KEEP_CONFIG:-false}
KEEP_LOGS=${KEEP_LOGS:-false}

# アンインストール対象
readonly TARGETS=(
    "pypy:PyPy 3.10環境"
    "symlinks:シンボリックリンク"
    "shell-config:シェル設定"
    "install-dir:インストールディレクトリ"
    "npm-packages:npm グローバルパッケージ"
    "config:設定ファイル"
    "logs:ログファイル"
)

# =============================================================================
# ヘルプ・使用方法
# =============================================================================

show_usage() {
    cat << EOF
競技プログラミング環境アンインストール

使用方法:
  $0 [オプション] [対象...]

オプション:
  -h, --help              このヘルプを表示
  -v, --verbose           詳細なログを表示
  -n, --dry-run           実際の削除を行わず、確認のみ
  -f, --force             確認なしで削除実行
  --keep-config           設定ファイルを保持
  --keep-logs             ログファイルを保持
  --log-level LEVEL       ログレベル (debug|info|warn|error)

対象 (指定しない場合は全て):
  pypy                    PyPy環境のみ削除
  symlinks                シンボリックリンクのみ削除
  shell-config            シェル設定のみ削除
  install-dir             インストールディレクトリのみ削除
  npm-packages            npmパッケージのみ削除
  config                  設定ファイルのみ削除
  logs                    ログファイルのみ削除

例:
  $0                      # 全コンポーネントを削除
  $0 --dry-run            # 削除内容の確認のみ
  $0 --keep-config        # 設定ファイルを保持して削除
  $0 pypy symlinks        # PyPyとシンボリックリンクのみ削除
  $0 --force              # 確認なしで全削除

警告:
  このスクリプトは競技プログラミング環境を完全に削除します。
  重要なデータがある場合は事前にバックアップを取ってください。
EOF
}

# =============================================================================
# アンインストール確認
# =============================================================================

# インストール状況の確認
check_installation_status() {
    log_step "現在のインストール状況を確認中"
    
    local installed_components=()
    
    # PyPy
    if [ -d "$PYPY_DIR" ]; then
        installed_components+=("PyPy環境: $PYPY_DIR")
    fi
    
    # シンボリックリンク
    if [ -d "$LOCAL_BIN" ]; then
        local symlinks
        symlinks=$(find "$LOCAL_BIN" -type l 2>/dev/null | wc -l)
        if [ "$symlinks" -gt 0 ]; then
            installed_components+=("シンボリックリンク: $symlinks 個")
        fi
    fi
    
    # npm パッケージ
    if command_exists "npm" && npm list -g atcoder-cli >/dev/null 2>&1; then
        installed_components+=("AtCoder CLI (npm)")
    fi
    
    # 設定ファイル
    if [ -f "$CONFIG_FILE" ]; then
        installed_components+=("設定ファイル: $CONFIG_FILE")
    fi
    
    # ログファイル
    if [ -d "$INSTALL_DIR/logs" ]; then
        local log_count
        log_count=$(find "$INSTALL_DIR/logs" -name "*.log" 2>/dev/null | wc -l)
        if [ "$log_count" -gt 0 ]; then
            installed_components+=("ログファイル: $log_count 個")
        fi
    fi
    
    # シェル設定
    local shell_rc
    shell_rc=$(detect_shell_rc)
    if [ -n "$shell_rc" ] && [ -f "$shell_rc" ] && grep -q "ac-env" "$shell_rc" 2>/dev/null; then
        installed_components+=("シェル設定: $shell_rc")
    fi
    
    if [ ${#installed_components[@]} -eq 0 ]; then
        log_info "競技プログラミング環境はインストールされていません"
        return 1
    else
        log_info "検出されたコンポーネント:"
        for component in "${installed_components[@]}"; do
            log_info "  • $component"
        done
        return 0
    fi
}

# シェル設定ファイル検出
detect_shell_rc() {
    local shell_rc=""
    
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
# 個別削除関数
# =============================================================================

# PyPy環境の削除
uninstall_pypy() {
    log_progress "PyPy環境を削除中"
    
    if [ ! -d "$PYPY_DIR" ]; then
        log_info "PyPy環境は見つかりませんでした"
        return 0
    fi
    
    local size
    size=$(du -sh "$PYPY_DIR" 2>/dev/null | cut -f1 || echo "不明")
    log_info "削除予定: $PYPY_DIR ($size)"
    
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "[DRY RUN] PyPy環境を削除します"
        return 0
    fi
    
    if rm -rf "$PYPY_DIR" 2>/dev/null; then
        log_success "PyPy環境を削除しました"
    else
        log_error "PyPy環境の削除に失敗しました"
        return 1
    fi
}

# シンボリックリンクの削除
uninstall_symlinks() {
    log_progress "シンボリックリンクを削除中"
    
    if [ ! -d "$LOCAL_BIN" ]; then
        log_info "ローカルbinディレクトリが見つかりませんでした"
        return 0
    fi
    
    local symlinks=("python" "acc" "oj")
    local removed_count=0
    
    for link_name in "${symlinks[@]}"; do
        local link_path="$LOCAL_BIN/$link_name"
        
        if [ -L "$link_path" ]; then
            local target
            target=$(readlink "$link_path" 2>/dev/null || echo "不明")
            log_info "削除予定: $link_path -> $target"
            
            if [ "${DRY_RUN:-false}" != "true" ]; then
                if rm -f "$link_path" 2>/dev/null; then
                    removed_count=$((removed_count + 1))
                else
                    log_warn "シンボリックリンクの削除に失敗: $link_path"
                fi
            else
                removed_count=$((removed_count + 1))
            fi
        fi
    done
    
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "[DRY RUN] $removed_count 個のシンボリックリンクを削除します"
    elif [ "$removed_count" -gt 0 ]; then
        log_success "$removed_count 個のシンボリックリンクを削除しました"
    else
        log_info "削除対象のシンボリックリンクは見つかりませんでした"
    fi
}

# シェル設定の削除
uninstall_shell_config() {
    log_progress "シェル設定を削除中"
    
    local shell_rc
    shell_rc=$(detect_shell_rc)
    
    if [ -z "$shell_rc" ] || [ ! -f "$shell_rc" ]; then
        log_info "シェル設定ファイルが見つかりませんでした"
        return 0
    fi
    
    if ! grep -q "ac-env" "$shell_rc" 2>/dev/null; then
        log_info "シェル設定にac-env関連の設定は見つかりませんでした"
        return 0
    fi
    
    log_info "削除予定: $shell_rc 内のac-env設定"
    
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "[DRY RUN] シェル設定からac-env設定を削除します"
        return 0
    fi
    
    # バックアップ作成
    local backup_file="$shell_rc.backup.$(date +%Y%m%d_%H%M%S)"
    if cp "$shell_rc" "$backup_file" 2>/dev/null; then
        log_info "バックアップを作成: $backup_file"
    else
        log_warn "バックアップの作成に失敗しました"
    fi
    
    # ac-env関連設定を削除
    if sed -i '/# === ac-env PATH settings ===/,/# === ac-env PATH settings ===/d' "$shell_rc" 2>/dev/null; then
        log_success "シェル設定からac-env設定を削除しました"
    else
        log_warn "シェル設定の更新に失敗しました"
    fi
}

# インストールディレクトリの削除
uninstall_install_dir() {
    log_progress "インストールディレクトリを削除中"
    
    if [ ! -d "$INSTALL_DIR" ]; then
        log_info "インストールディレクトリは見つかりませんでした"
        return 0
    fi
    
    local size
    size=$(du -sh "$INSTALL_DIR" 2>/dev/null | cut -f1 || echo "不明")
    log_info "削除予定: $INSTALL_DIR ($size)"
    
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "[DRY RUN] インストールディレクトリを削除します"
        return 0
    fi
    
    if rm -rf "$INSTALL_DIR" 2>/dev/null; then
        log_success "インストールディレクトリを削除しました"
    else
        log_error "インストールディレクトリの削除に失敗しました"
        return 1
    fi
}

# npmパッケージの削除
uninstall_npm_packages() {
    log_progress "npmパッケージを削除中"
    
    if ! command_exists "npm"; then
        log_info "npmが見つかりませんでした"
        return 0
    fi
    
    # AtCoder CLIの確認
    if npm list -g atcoder-cli >/dev/null 2>&1; then
        log_info "削除予定: atcoder-cli (npm global)"
        
        if [ "${DRY_RUN:-false}" = "true" ]; then
            log_info "[DRY RUN] atcoder-cliを削除します"
        else
            if npm uninstall -g atcoder-cli >/dev/null 2>&1; then
                log_success "atcoder-cliを削除しました"
            else
                log_warn "atcoder-cliの削除に失敗しました"
            fi
        fi
    else
        log_info "atcoder-cli (npm) は見つかりませんでした"
    fi
}

# 設定ファイルの削除
uninstall_config() {
    log_progress "設定ファイルを削除中"
    
    if [ "${KEEP_CONFIG:-false}" = "true" ]; then
        log_info "設定ファイルは保持されます"
        return 0
    fi
    
    if [ ! -f "$CONFIG_FILE" ]; then
        log_info "設定ファイルは見つかりませんでした"
        return 0
    fi
    
    log_info "削除予定: $CONFIG_FILE"
    
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "[DRY RUN] 設定ファイルを削除します"
        return 0
    fi
    
    # バックアップ作成
    local backup_file="$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    if cp "$CONFIG_FILE" "$backup_file" 2>/dev/null; then
        log_info "バックアップを作成: $backup_file"
    fi
    
    if rm -f "$CONFIG_FILE" 2>/dev/null; then
        log_success "設定ファイルを削除しました"
    else
        log_warn "設定ファイルの削除に失敗しました"
    fi
}

# ログファイルの削除
uninstall_logs() {
    log_progress "ログファイルを削除中"
    
    if [ "${KEEP_LOGS:-false}" = "true" ]; then
        log_info "ログファイルは保持されます"
        return 0
    fi
    
    local log_dir="$INSTALL_DIR/logs"
    
    if [ ! -d "$log_dir" ]; then
        log_info "ログディレクトリは見つかりませんでした"
        return 0
    fi
    
    local log_count
    log_count=$(find "$log_dir" -name "*.log" 2>/dev/null | wc -l)
    
    if [ "$log_count" -eq 0 ]; then
        log_info "ログファイルは見つかりませんでした"
        return 0
    fi
    
    log_info "削除予定: $log_count 個のログファイル"
    
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "[DRY RUN] ログファイルを削除します"
        return 0
    fi
    
    if rm -rf "$log_dir" 2>/dev/null; then
        log_success "ログファイルを削除しました"
    else
        log_warn "ログファイルの削除に失敗しました"
    fi
}

# =============================================================================
# メイン処理
# =============================================================================

# [削除] parse_arguments関数は main() 内に移動

# アンインストール実行
execute_uninstall() {
    local targets=("$@")
    
    # 対象が指定されていない場合は全て
    if [ ${#targets[@]} -eq 0 ]; then
        targets=("pypy" "symlinks" "shell-config" "install-dir" "npm-packages" "config" "logs")
    fi
    
    log_step "アンインストール実行"
    
    local failed_targets=()
    local success_count=0
    
    for target in "${targets[@]}"; do
        case "$target" in
            pypy)
                if uninstall_pypy; then
                    success_count=$((success_count + 1))
                else
                    failed_targets+=("$target")
                fi
                ;;
            symlinks)
                if uninstall_symlinks; then
                    success_count=$((success_count + 1))
                else
                    failed_targets+=("$target")
                fi
                ;;
            shell-config)
                if uninstall_shell_config; then
                    success_count=$((success_count + 1))
                else
                    failed_targets+=("$target")
                fi
                ;;
            install-dir)
                if uninstall_install_dir; then
                    success_count=$((success_count + 1))
                else
                    failed_targets+=("$target")
                fi
                ;;
            npm-packages)
                if uninstall_npm_packages; then
                    success_count=$((success_count + 1))
                else
                    failed_targets+=("$target")
                fi
                ;;
            config)
                if uninstall_config; then
                    success_count=$((success_count + 1))
                else
                    failed_targets+=("$target")
                fi
                ;;
            logs)
                if uninstall_logs; then
                    success_count=$((success_count + 1))
                else
                    failed_targets+=("$target")
                fi
                ;;
            *)
                log_error "不明な対象: $target"
                failed_targets+=("$target")
                ;;
        esac
    done
    
    # 結果サマリー
    log_step "アンインストール結果"
    log_info "成功: $success_count"
    log_info "失敗: ${#failed_targets[@]}"
    
    if [ ${#failed_targets[@]} -eq 0 ]; then
        log_success "✅ アンインストールが正常に完了しました"
        return 0
    else
        log_error "❌ 以下の対象で失敗しました: ${failed_targets[*]}"
        return 1
    fi
}

# アンインストール計画の表示
show_uninstall_plan() {
    local targets=("$@")
    
    log_step "アンインストール計画"
    
    if [ ${#targets[@]} -eq 0 ]; then
        log_info "全コンポーネントを削除します"
    else
        log_info "以下のコンポーネントを削除します:"
        for target in "${targets[@]}"; do
            log_info "  • $target"
        done
    fi
    
    log_info "設定:"
    log_info "  DRY RUN: $([ "${DRY_RUN:-false}" = "true" ] && echo "有効" || echo "無効")"
    log_info "  設定ファイル保持: $([ "${KEEP_CONFIG:-false}" = "true" ] && echo "有効" || echo "無効")"
    log_info "  ログファイル保持: $([ "${KEEP_LOGS:-false}" = "true" ] && echo "有効" || echo "無効")"
}

# メイン関数
main() {
    # 引数解析（ログ初期化より前に）
    local targets=()
    local arg
    
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                export VERBOSE
                ;;
            -n|--dry-run)
                DRY_RUN=true
                export DRY_RUN
                ;;
            -f|--force)
                FORCE=true
                export FORCE
                ;;
            --keep-config)
                KEEP_CONFIG=true
                export KEEP_CONFIG
                ;;
            --keep-logs)
                KEEP_LOGS=true
                export KEEP_LOGS
                ;;
            --log-level)
                shift
                if [ $# -eq 0 ]; then
                    echo "エラー: --log-level にはレベルを指定してください" >&2
                    exit 1
                fi
                LOG_LEVEL_ARG="$1"
                ;;
            -*)
                echo "エラー: 不明なオプション: $1" >&2
                show_usage
                exit 1
                ;;
            *)
                targets+=("$1")
                ;;
        esac
        shift
    done
    
    # ログ初期化
    log_init
    
    # ログレベル設定（ログ初期化後）
    if [ -n "${LOG_LEVEL_ARG:-}" ]; then
        log_set_level "$LOG_LEVEL_ARG"
    fi
    if [ "${VERBOSE:-false}" = "true" ]; then
        log_set_level debug
    fi
    
    log_step "競技プログラミング環境アンインストール開始"
    log_info "開始時刻: $(date)"
    
    # インストール状況確認
    if ! check_installation_status; then
        log_info "アンインストール対象が見つかりませんでした"
        exit 0
    fi
    
    # アンインストール計画表示
    show_uninstall_plan "${targets[@]}"
    
    # 確認プロンプト
    if [ "${FORCE:-false}" != "true" ] && [ "${DRY_RUN:-false}" != "true" ] && [ -t 0 ]; then
        echo ""
        log_warn "この操作は競技プログラミング環境を削除します"
        if ! confirm "続行しますか？" "n"; then
            log_info "アンインストールがキャンセルされました"
            exit 0
        fi
    fi
    
    # アンインストール実行
    if execute_uninstall "${targets[@]}"; then
        echo ""
        log_success "アンインストールが完了しました"
        log_info "新しい環境をセットアップするには 'make install' を実行してください"
    else
        echo ""
        log_error "アンインストールで問題が発生しました"
        exit 1
    fi
}

# メイン関数実行
main "$@"