#!/bin/bash
# 競技プログラミング環境セットアップ - ログライブラリ
# 統一されたログ出力機能

# 依存関係
if [ -z "${PROJECT_ROOT:-}" ]; then
    LIB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # shellcheck source=common.sh
    source "$LIB_SCRIPT_DIR/common.sh"
fi

# =============================================================================
# ログ設定
# =============================================================================

readonly LOG_DIR="$INSTALL_DIR/logs"
readonly LOG_FILE="$LOG_DIR/install_$(date +%Y%m%d_%H%M%S).log"
readonly CURRENT_LOG="$LOG_DIR/current.log"

# ログレベル
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3

# 現在のログレベル（デフォルト: INFO）
LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}

# =============================================================================
# 内部関数
# =============================================================================

# ログレベル名取得
_get_level_name() {
    case "$1" in
        "$LOG_LEVEL_DEBUG") echo "DEBUG" ;;
        "$LOG_LEVEL_INFO")  echo "INFO"  ;;
        "$LOG_LEVEL_WARN")  echo "WARN"  ;;
        "$LOG_LEVEL_ERROR") echo "ERROR" ;;
        *) echo "UNKNOWN" ;;
    esac
}

# ログファイルに書き込み
_write_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local level_name=$(_get_level_name "$level")
    
    ensure_dir "$LOG_DIR"
    echo "[$timestamp] [$level_name] $message" >> "$LOG_FILE"
    echo "[$timestamp] [$level_name] $message" >> "$CURRENT_LOG"
}

# カラー付きコンソール出力
_print_colored() {
    local level="$1"
    local message="$2"
    local color=""
    
    case "$level" in
        "$LOG_LEVEL_DEBUG") color="$CYAN" ;;
        "$LOG_LEVEL_INFO")  color="$BLUE" ;;
        "$LOG_LEVEL_WARN")  color="$YELLOW" ;;
        "$LOG_LEVEL_ERROR") color="$RED" ;;
    esac
    
    echo -e "${color}$message${NC}"
}

# =============================================================================
# パブリック関数
# =============================================================================

# ログ初期化
log_init() {
    ensure_dir "$LOG_DIR"
    
    # 現在のログファイルをクリア
    : > "$CURRENT_LOG"
    
    log_info "ログシステム初期化完了"
    log_info "ログファイル: $LOG_FILE"
}

# デバッグログ
log_debug() {
    [ "$LOG_LEVEL" -le "$LOG_LEVEL_DEBUG" ] || return 0
    _write_log "$LOG_LEVEL_DEBUG" "$1"
    [ "${LOG_CONSOLE:-1}" = "1" ] && _print_colored "$LOG_LEVEL_DEBUG" "DEBUG: $1"
}

# 情報ログ
log_info() {
    [ "$LOG_LEVEL" -le "$LOG_LEVEL_INFO" ] || return 0
    _write_log "$LOG_LEVEL_INFO" "$1"
    [ "${LOG_CONSOLE:-1}" = "1" ] && info "$1"
}

# 警告ログ
log_warn() {
    [ "$LOG_LEVEL" -le "$LOG_LEVEL_WARN" ] || return 0
    _write_log "$LOG_LEVEL_WARN" "$1"
    [ "${LOG_CONSOLE:-1}" = "1" ] && warn "$1"
}

# エラーログ
log_error() {
    _write_log "$LOG_LEVEL_ERROR" "$1"
    [ "${LOG_CONSOLE:-1}" = "1" ] && echo -e "${RED}エラー: $1${NC}" >&2
}

# 成功ログ
log_success() {
    _write_log "$LOG_LEVEL_INFO" "SUCCESS: $1"
    [ "${LOG_CONSOLE:-1}" = "1" ] && success "$1"
}

# ステップ開始ログ
log_step() {
    local step_name="$1"
    _write_log "$LOG_LEVEL_INFO" "STEP: $step_name"
    [ "${LOG_CONSOLE:-1}" = "1" ] && step_header "$step_name"
}

# 進行状況ログ
log_progress() {
    _write_log "$LOG_LEVEL_INFO" "PROGRESS: $1"
    [ "${LOG_CONSOLE:-1}" = "1" ] && progress "$1"
}

# コマンド実行ログ
log_exec() {
    local cmd="$1"
    local description="${2:-実行中: $cmd}"
    
    log_debug "実行コマンド: $cmd"
    log_progress "$description"
    
    if eval "$cmd" >> "$LOG_FILE" 2>&1; then
        log_debug "コマンド成功: $cmd"
        return 0
    else
        local exit_code=$?
        log_error "コマンド失敗 (終了コード: $exit_code): $cmd"
        return $exit_code
    fi
}

# ログレベル設定
log_set_level() {
    case "${1:-info}" in
        debug) LOG_LEVEL=$LOG_LEVEL_DEBUG ;;
        info)  LOG_LEVEL=$LOG_LEVEL_INFO ;;
        warn)  LOG_LEVEL=$LOG_LEVEL_WARN ;;
        error) LOG_LEVEL=$LOG_LEVEL_ERROR ;;
        *) log_warn "不正なログレベル: $1" ;;
    esac
}

# ログファイル表示
log_show() {
    if [ -f "$CURRENT_LOG" ]; then
        cat "$CURRENT_LOG"
    else
        echo "ログファイルが見つかりません"
    fi
}

# ログファイルクリーンアップ（7日以上古いログを削除）
log_cleanup() {
    if [ -d "$LOG_DIR" ]; then
        find "$LOG_DIR" -name "install_*.log" -mtime +7 -delete 2>/dev/null || true
        log_info "古いログファイルをクリーンアップしました"
    fi
}