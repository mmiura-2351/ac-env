#!/bin/bash
# Step 2: Python環境セットアップ
# PyPy 3.10-v7.3.12をインストールして、pythonコマンドとして利用可能にする

set -euo pipefail

# ライブラリ読み込み
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"
# shellcheck source=../lib/logger.sh
source "$SCRIPT_DIR/../lib/logger.sh"

# =============================================================================
# Python/PyPy セットアップ関数
# =============================================================================

# 既存のPythonコマンドをチェック
check_existing_python() {
    log_progress "既存のPythonコマンドをチェック中"
    
    if command_exists "python"; then
        local py_version
        py_version=$(python --version 2>&1)
        
        if [[ "$py_version" =~ Python\ 3\. ]]; then
            log_success "利用可能なPython: $py_version"
            
            # PyPyかどうか確認
            if [[ "$py_version" =~ PyPy ]]; then
                log_info "PyPyが既にインストールされています"
                return 0
            else
                log_info "通常のPythonが見つかりました"
                log_info "競技プログラミング用にPyPyをインストールします"
            fi
        else
            log_warn "Python 2が検出されました: $py_version"
            log_info "Python 3対応のPyPyをインストールします"
        fi
    else
        log_info "Pythonコマンドが見つかりません"
        log_info "PyPy 3.10をインストールします"
    fi
    
    return 1
}

# PyPyダウンロードURL生成
get_pypy_download_url() {
    local os_type
    os_type=$(detect_os)
    local base_url="https://downloads.python.org/pypy"
    
    case "$os_type" in
        linux)
            echo "$base_url/pypy$PYPY_VERSION-linux64.tar.bz2"
            ;;
        macos)
            echo "$base_url/pypy$PYPY_VERSION-macos_x86_64.tar.bz2"
            ;;
        *)
            log_error "このOS ($os_type) はPyPyの自動インストールに対応していません"
            return 1
            ;;
    esac
}

# PyPyアーカイブファイル名生成
get_pypy_archive_name() {
    local url="$1"
    basename "$url"
}

# PyPyフォルダ名生成
get_pypy_folder_name() {
    local archive="$1"
    echo "${archive%.tar.bz2}"
}

# PyPyダウンロード
download_pypy() {
    local url="$1"
    local archive="$2"
    
    log_progress "PyPyをダウンロード中: $url"
    
    ensure_dir "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    if command_exists "wget"; then
        if ! wget -q "$url" -O "$archive"; then
            log_error "PyPyのダウンロードに失敗しました (wget)"
            return 1
        fi
    elif command_exists "curl"; then
        if ! curl -sL "$url" -o "$archive"; then
            log_error "PyPyのダウンロードに失敗しました (curl)"
            return 1
        fi
    else
        log_error "wgetまたはcurlが必要です"
        return 1
    fi
    
    log_success "PyPyのダウンロードが完了しました"
}

# PyPy展開とインストール
extract_and_install_pypy() {
    local archive="$1"
    local folder="$2"
    
    log_progress "PyPyを展開中"
    
    cd "$INSTALL_DIR"
    
    # 既存のディレクトリを削除
    if [ -d "$PYPY_DIR" ]; then
        log_progress "既存のPyPyディレクトリを削除中"
        rm -rf "$PYPY_DIR"
    fi
    
    # 展開
    if ! tar -xf "$archive"; then
        log_error "PyPyの展開に失敗しました"
        return 1
    fi
    
    # リネーム
    if ! mv "$folder" "$(basename "$PYPY_DIR")"; then
        log_error "PyPyディレクトリのリネームに失敗しました"
        return 1
    fi
    
    # アーカイブファイル削除
    rm -f "$archive"
    
    log_success "PyPyの展開が完了しました: $PYPY_DIR"
}

# pipセットアップ
setup_pip() {
    log_progress "pipをセットアップ中"
    
    local python_bin="$PYPY_DIR/bin/pypy3"
    
    if ! executable_exists "$python_bin"; then
        log_error "PyPy実行ファイルが見つかりません: $python_bin"
        return 1
    fi
    
    # pipを有効化
    if ! "$python_bin" -m ensurepip --upgrade 2>/dev/null; then
        log_warn "pipの初期化に問題が発生しました（継続します）"
    fi
    
    # pipのアップグレード
    if ! "$python_bin" -m pip install --upgrade pip 2>/dev/null; then
        log_warn "pipのアップグレードに問題が発生しました（継続します）"
    fi
    
    log_success "pipのセットアップが完了しました"
}

# PyPyインストール確認
verify_pypy_installation() {
    log_progress "PyPyインストールを確認中"
    
    local python_bin="$PYPY_DIR/bin/pypy3"
    
    if ! executable_exists "$python_bin"; then
        log_error "PyPy実行ファイルが見つかりません"
        return 1
    fi
    
    local version
    version=$("$python_bin" --version 2>&1)
    log_success "PyPyインストール確認: $version"
    
    # pipが利用可能か確認
    if "$python_bin" -m pip --version >/dev/null 2>&1; then
        log_success "pipが利用可能です"
    else
        log_warn "pipが利用できません"
    fi
    
    return 0
}

# =============================================================================
# メイン処理
# =============================================================================

install_pypy() {
    log_progress "PyPy $PYPY_VERSION をインストール中"
    
    # ダウンロードURL取得
    local download_url
    if ! download_url=$(get_pypy_download_url); then
        return 1
    fi
    
    local archive_name
    archive_name=$(get_pypy_archive_name "$download_url")
    
    local folder_name
    folder_name=$(get_pypy_folder_name "$archive_name")
    
    # ダウンロード
    if ! download_pypy "$download_url" "$archive_name"; then
        return 1
    fi
    
    # 展開とインストール
    if ! extract_and_install_pypy "$archive_name" "$folder_name"; then
        return 1
    fi
    
    # pipセットアップ
    if ! setup_pip; then
        return 1
    fi
    
    # インストール確認
    if ! verify_pypy_installation; then
        return 1
    fi
    
    log_success "PyPy $PYPY_VERSION のインストールが完了しました"
    return 0
}

main() {
    log_step "Step 2: Python環境セットアップ"
    
    # 既存のPythonチェック
    if check_existing_python; then
        log_info "適切なPython環境が既に利用可能です"
        log_info "スキップして次のステップに進みます"
        return 0
    fi
    
    # PyPyインストール
    if ! install_pypy; then
        log_error "PyPyのインストールに失敗しました"
        return 1
    fi
    
    log_success "Python環境のセットアップが完了しました"
    return 0
}

# スクリプトが直接実行された場合のみmainを呼び出し
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi