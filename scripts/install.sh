#!/bin/bash
# 競技プログラミング環境セットアップ - メインインストーラー
# 全てのセットアップステップを順次実行

set -euo pipefail

# =============================================================================
# 初期設定
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_SCRIPTS_DIR="$SCRIPT_DIR/install"

# ライブラリ読み込み
# shellcheck source=./lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=./lib/logger.sh
source "$SCRIPT_DIR/lib/logger.sh"

# =============================================================================
# インストール設定
# =============================================================================

# インストールステップ定義
readonly INSTALL_STEPS=(
    "01-check-deps.sh:依存関係チェック"
    "02-setup-python.sh:Python環境セットアップ"
    "03-setup-cpp.sh:C++環境セットアップ"
    "04-install-acc.sh:AtCoder CLI インストール"
    "05-install-oj.sh:online-judge-tools インストール"
    "06-setup-path.sh:PATH設定"
    "07-generate-config.sh:設定ファイル生成"
    "08-final-check.sh:最終確認"
)

# デフォルト設定
SKIP_EXISTING=${SKIP_EXISTING:-false}
DRY_RUN=${DRY_RUN:-false}
VERBOSE=${VERBOSE:-false}
FORCE_REINSTALL=${FORCE_REINSTALL:-false}

# =============================================================================
# ヘルプ・使用方法
# =============================================================================

show_usage() {
    cat << EOF
競技プログラミング環境セットアップ

使用方法:
  $0 [オプション] [ステップ...]
  $0 関数名 [オプション]    # 個別関数の直接実行

オプション:
  -h, --help              このヘルプを表示
  -v, --verbose           詳細なログを表示
  -n, --dry-run           実際のインストールを行わず、確認のみ
  -s, --skip-existing     既存のツールがある場合はスキップ
  -f, --force             既存のインストールを強制的に上書き
  --log-level LEVEL       ログレベル (debug|info|warn|error)

個別実行可能な関数:
  install_pypy            PyPyをインストール
  install_cpp             C++環境をインストール
  install_acc             AtCoder CLIをインストール
  install_oj              online-judge-toolsをインストール
  check_deps              依存関係をチェック
  setup_path              PATH設定
  generate_config         設定ファイル生成
  final_check             最終チェック

ステップ:
  特定のステップのみを実行する場合は、ステップ番号またはステップ名を指定
  例: $0 01 03    # ステップ1と3のみ実行
      $0 python   # Python関連のステップのみ実行

利用可能なステップ:
EOF

    local i=1
    for step_entry in "${INSTALL_STEPS[@]}"; do
        local step_file="${step_entry%:*}"
        local step_desc="${step_entry#*:}"
        printf "  %02d. %s\n" "$i" "$step_desc"
        i=$((i + 1))
    done

    cat << EOF

例:
  $0                      # 全ステップを実行
  $0 --verbose            # 詳細ログ付きで全実行
  $0 --dry-run            # 実行内容の確認のみ
  $0 01 02                # 依存関係チェックとPython環境のみ
  $0 --skip-existing      # 既存ツールをスキップ
  $0 install_pypy         # PyPyのみインストール
  $0 install_cpp --force  # C++環境を強制再インストール
EOF
}

# =============================================================================
# 個別インストール関数
# =============================================================================

# PyPyをインストール
install_pypy() {
    log_step "PyPyインストール"
    export SKIP_EXISTING FORCE_REINSTALL VERBOSE
    "$INSTALL_SCRIPTS_DIR/02-setup-python.sh"
}

# C++環境をインストール
install_cpp() {
    log_step "C++環境インストール"
    export SKIP_EXISTING FORCE_REINSTALL VERBOSE
    "$INSTALL_SCRIPTS_DIR/03-setup-cpp.sh"
}

# AtCoder CLIをインストール
install_acc() {
    log_step "AtCoder CLIインストール"
    export SKIP_EXISTING FORCE_REINSTALL VERBOSE
    "$INSTALL_SCRIPTS_DIR/04-install-acc.sh"
}

# online-judge-toolsをインストール
install_oj() {
    log_step "online-judge-toolsインストール"
    export SKIP_EXISTING FORCE_REINSTALL VERBOSE
    "$INSTALL_SCRIPTS_DIR/05-install-oj.sh"
}

# 依存関係をチェック
check_deps() {
    log_step "依存関係チェック"
    export SKIP_EXISTING FORCE_REINSTALL VERBOSE
    "$INSTALL_SCRIPTS_DIR/01-check-deps.sh"
}

# PATH設定
setup_path() {
    log_step "PATH設定"
    export SKIP_EXISTING FORCE_REINSTALL VERBOSE
    "$INSTALL_SCRIPTS_DIR/06-setup-path.sh"
}

# 設定ファイル生成
generate_config() {
    log_step "設定ファイル生成"
    export SKIP_EXISTING FORCE_REINSTALL VERBOSE
    "$INSTALL_SCRIPTS_DIR/07-generate-config.sh"
}

# 最終チェック
final_check() {
    log_step "最終チェック"
    export SKIP_EXISTING FORCE_REINSTALL VERBOSE
    "$INSTALL_SCRIPTS_DIR/08-final-check.sh"
}


# =============================================================================
# インストール制御関数
# =============================================================================

# ステップ番号からファイル名を取得
get_step_file() {
    local step_num="$1"
    
    # 2桁の番号に正規化
    if [[ "$step_num" =~ ^[0-9]$ ]]; then
        step_num="0$step_num"
    fi
    
    for step_entry in "${INSTALL_STEPS[@]}"; do
        local step_file="${step_entry%:*}"
        if [[ "$step_file" =~ ^${step_num}- ]]; then
            echo "$step_file"
            return 0
        fi
    done
    
    return 1
}

# ステップ名からファイル名を取得
get_step_file_by_name() {
    local step_name="$1"
    
    for step_entry in "${INSTALL_STEPS[@]}"; do
        local step_file="${step_entry%:*}"
        local step_desc="${step_entry#*:}"
        
        if [[ "$step_file" =~ $step_name ]] || [[ "$step_desc" =~ $step_name ]]; then
            echo "$step_file"
            return 0
        fi
    done
    
    return 1
}

# 実行するステップリストを決定
determine_steps_to_run() {
    local requested_steps=("$@")
    local steps_to_run=()
    
    if [ ${#requested_steps[@]} -eq 0 ]; then
        # 引数なしの場合は全ステップ
        for step_entry in "${INSTALL_STEPS[@]}"; do
            steps_to_run+=("${step_entry%:*}")
        done
    else
        # 指定されたステップのみ
        for requested in "${requested_steps[@]}"; do
            local step_file=""
            
            # 番号で指定された場合
            if [[ "$requested" =~ ^[0-9]+$ ]]; then
                step_file=$(get_step_file "$requested") || {
                    log_error "無効なステップ番号: $requested"
                    return 1
                }
            # 名前で指定された場合
            else
                step_file=$(get_step_file_by_name "$requested") || {
                    log_error "無効なステップ名: $requested"
                    return 1
                }
            fi
            
            steps_to_run+=("$step_file")
        done
    fi
    
    # 配列が空でない場合のみ出力
    if [ ${#steps_to_run[@]} -gt 0 ]; then
        printf '%s\n' "${steps_to_run[@]}"
    fi
}

# 単一ステップの実行
execute_step() {
    local step_file="$1"
    local step_script="$INSTALL_SCRIPTS_DIR/$step_file"
    
    # ステップ情報を取得
    local step_desc=""
    for step_entry in "${INSTALL_STEPS[@]}"; do
        if [[ "$step_entry" =~ ^${step_file}: ]]; then
            step_desc="${step_entry#*:}"
            break
        fi
    done
    
    log_step "実行中: $step_desc"
    
    # スクリプトファイルの存在確認
    if ! file_exists "$step_script"; then
        log_error "ステップスクリプトが見つかりません: $step_script"
        return 1
    fi
    
    # 実行権限確認
    if ! executable_exists "$step_script"; then
        log_warn "実行権限がありません。付与します: $step_script"
        chmod +x "$step_script"
    fi
    
    # DRY RUNの場合
    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] $step_script を実行します"
        return 0
    fi
    
    # 環境変数設定
    export SKIP_EXISTING FORCE_REINSTALL VERBOSE
    
    # ステップ実行
    local start_time
    start_time=$(date +%s)
    
    if "$step_script"; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log_success "$step_desc が完了しました (${duration}秒)"
        return 0
    else
        local exit_code=$?
        log_error "$step_desc が失敗しました (終了コード: $exit_code)"
        return $exit_code
    fi
}

# =============================================================================
# メイン処理
# =============================================================================

# 引数解析
parse_arguments() {
    local args=()
    
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                log_set_level debug
                ;;
            -n|--dry-run)
                DRY_RUN=true
                ;;
            -s|--skip-existing)
                SKIP_EXISTING=true
                ;;
            -f|--force)
                FORCE_REINSTALL=true
                ;;
            --log-level)
                shift
                if [ $# -eq 0 ]; then
                    log_error "--log-level にはレベルを指定してください"
                    exit 1
                fi
                log_set_level "$1"
                ;;
            -*)
                log_error "不明なオプション: $1"
                show_usage
                exit 1
                ;;
            *)
                args+=("$1")
                ;;
        esac
        shift
    done
    
    # 引数配列が空の場合は何も出力しない
    if [ ${#args[@]} -gt 0 ]; then
        printf '%s\n' "${args[@]}"
    fi
}

# 事前チェック
pre_installation_check() {
    log_step "事前チェック"
    
    # スクリプトディレクトリの確認
    if [ ! -d "$INSTALL_SCRIPTS_DIR" ]; then
        log_error "インストールスクリプトディレクトリが見つかりません: $INSTALL_SCRIPTS_DIR"
        return 1
    fi
    
    # 必要なスクリプトファイルの存在確認
    local missing_scripts=()
    for step_entry in "${INSTALL_STEPS[@]}"; do
        local step_file="${step_entry%:*}"
        local step_script="$INSTALL_SCRIPTS_DIR/$step_file"
        
        if ! file_exists "$step_script"; then
            missing_scripts+=("$step_file")
        fi
    done
    
    if [ ${#missing_scripts[@]} -gt 0 ]; then
        log_error "以下のスクリプトファイルが見つかりません:"
        for script in "${missing_scripts[@]}"; do
            log_error "  $script"
        done
        return 1
    fi
    
    log_success "事前チェックが完了しました"
}

# インストール実行計画の表示
show_installation_plan() {
    local steps_to_run=("$@")
    
    log_step "インストール実行計画"
    
    log_info "実行予定のステップ:"
    local i=1
    for step_file in "${steps_to_run[@]}"; do
        local step_desc=""
        for step_entry in "${INSTALL_STEPS[@]}"; do
            if [[ "$step_entry" =~ ^${step_file}: ]]; then
                step_desc="${step_entry#*:}"
                break
            fi
        done
        log_info "  $i. $step_desc ($step_file)"
        i=$((i + 1))
    done
    
    log_info "設定:"
    log_info "  DRY RUN: $([ "$DRY_RUN" = "true" ] && echo "有効" || echo "無効")"
    log_info "  既存スキップ: $([ "$SKIP_EXISTING" = "true" ] && echo "有効" || echo "無効")"
    log_info "  強制再インストール: $([ "$FORCE_REINSTALL" = "true" ] && echo "有効" || echo "無効")"
    log_info "  詳細ログ: $([ "$VERBOSE" = "true" ] && echo "有効" || echo "無効")"
}

# メイン関数
main() {
    # 第1引数が関数名かチェック
    if [ $# -gt 0 ]; then
        case "$1" in
            install_pypy|install_cpp|install_acc|install_oj|check_deps|setup_path|generate_config|final_check)
                # 関数名を保存して引数から削除
                local function_name="$1"
                shift
                
                # 残りの引数を解析
                parse_arguments "$@" > /dev/null
                
                # ログ初期化
                log_init
                
                # 関数を実行
                "$function_name"
                exit $?
                ;;
        esac
    fi
    
    # ログ初期化
    log_init
    
    log_step "競技プログラミング環境セットアップ開始"
    log_info "開始時刻: $(date)"
    
    # 引数解析
    local requested_steps
    mapfile -t requested_steps < <(parse_arguments "$@")
    
    
    # 事前チェック
    if ! pre_installation_check; then
        log_error "事前チェックに失敗しました"
        exit 1
    fi
    
    # 実行ステップ決定
    local steps_to_run
    mapfile -t steps_to_run < <(determine_steps_to_run "${requested_steps[@]}")
    
    
    # 実行計画表示
    show_installation_plan "${steps_to_run[@]}"
    
    # DRY RUNでない場合は確認
    if [ "$DRY_RUN" != "true" ] && [ -t 0 ]; then
        echo ""
        if ! confirm "インストールを開始しますか？" "y"; then
            log_info "インストールがキャンセルされました"
            exit 0
        fi
    fi
    
    # インストール実行
    log_step "インストール実行"
    
    local start_time
    start_time=$(date +%s)
    local failed_steps=()
    local completed_steps=()
    
    for step_file in "${steps_to_run[@]}"; do
        if execute_step "$step_file"; then
            completed_steps+=("$step_file")
        else
            failed_steps+=("$step_file")
            
            # 致命的エラーの場合は中断
            if [[ "$step_file" =~ ^01- ]]; then
                log_error "依存関係チェックに失敗したため、インストールを中断します"
                break
            fi
            
            # その他のステップは継続するか確認
            if [ -t 0 ]; then
                if ! confirm "ステップが失敗しましたが、継続しますか？" "n"; then
                    log_info "インストールが中断されました"
                    break
                fi
            fi
        fi
    done
    
    # 結果サマリー
    local end_time
    end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    log_step "インストール結果"
    log_info "完了時刻: $(date)"
    log_info "総実行時間: ${total_duration}秒"
    log_info "完了ステップ: ${#completed_steps[@]}"
    log_info "失敗ステップ: ${#failed_steps[@]}"
    
    if [ ${#failed_steps[@]} -eq 0 ]; then
        log_success "✅ すべてのステップが正常に完了しました！"
        echo ""
        log_info "🎯 AtCoder競技プログラミング環境のセットアップが完了しました"
        echo ""
        log_info "📝 次のステップ:"
        log_info "  1. make status     - 現在の状態を確認（ログイン状態含む）"
        log_info "  2. make new abc300 - 新しいコンテストを作成"
        log_info "  3. make test       - テストを実行"
        log_info "  4. make submit     - 問題を提出"
        echo ""
        log_info "💡 ログイン方法:"
        log_info "  - ブラウザで https://atcoder.jp/login を開いてログイン"
        log_info "  - acc login および oj login https://atcoder.jp/ を実行"
        log_info "  - ヘルプを表示: make help"
        echo ""
        exit 0
    else
        log_error "❌ 以下のステップで失敗が発生しました:"
        for step in "${failed_steps[@]}"; do
            log_error "  $step"
        done
        exit 1
    fi
}

# 全てのスクリプトを実行可能にする
chmod +x "$SCRIPT_DIR"/lib/*.sh "$INSTALL_SCRIPTS_DIR"/*.sh 2>/dev/null || true

# メイン関数実行
main "$@"