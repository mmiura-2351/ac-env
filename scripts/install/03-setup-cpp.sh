#!/bin/bash
# Step 3: C++環境セットアップ
# gcc 12.2以上でC++20対応環境を構築

set -euo pipefail

# ライブラリ読み込み
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"
# shellcheck source=../lib/logger.sh
source "$SCRIPT_DIR/../lib/logger.sh"

# =============================================================================
# C++環境セットアップ関数
# =============================================================================

# 既存のC++コンパイラをチェック
check_existing_cpp() {
    log_progress "既存のC++コンパイラをチェック中"
    
    if command_exists "g++"; then
        local gcc_version
        gcc_version=$(g++ --version | head -n1)
        log_info "検出されたコンパイラ: $gcc_version"
        
        # バージョン番号を抽出
        local version_number
        version_number=$(g++ -dumpversion | cut -d. -f1)
        
        if [ "$version_number" -ge 12 ]; then
            log_progress "C++20サポートをテスト中"
            
            if test_cpp20_support; then
                log_success "C++20対応のg++が利用可能です"
                return 0
            else
                log_warn "C++20サポートが不完全です"
            fi
        else
            log_warn "g++のバージョンが古いです (必要: 12以上, 現在: $version_number)"
        fi
    elif command_exists "clang++"; then
        local clang_version
        clang_version=$(clang++ --version | head -n1)
        log_info "検出されたコンパイラ: $clang_version"
        
        if test_cpp20_support_clang; then
            log_success "C++20対応のclang++が利用可能です"
            return 0
        else
            log_warn "clang++のC++20サポートが不完全です"
        fi
    else
        log_warn "C++コンパイラが見つかりません"
    fi
    
    return 1
}

# C++20サポートテスト (g++)
test_cpp20_support() {
    local test_code='#include <concepts>
int main() { return 0; }'
    
    if echo "$test_code" | g++ -std=c++20 -x c++ - -o /dev/null 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# C++20サポートテスト (clang++)
test_cpp20_support_clang() {
    local test_code='#include <concepts>
int main() { return 0; }'
    
    if echo "$test_code" | clang++ -std=c++20 -x c++ - -o /dev/null 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# gcc-12をインストール (Ubuntu/Debian)
install_gcc12_ubuntu() {
    log_progress "Ubuntu/Debianでgcc-12をインストール中"
    
    # 既にインストール済みかチェック
    if command_exists "gcc-12"; then
        log_success "gcc-12は既にインストールされています"
        return 0
    fi
    
    log_progress "パッケージリストを更新中"
    if ! sudo apt-get update; then
        log_error "パッケージリストの更新に失敗しました"
        return 1
    fi
    
    log_progress "必要なパッケージをインストール中"
    if ! sudo apt-get install -y software-properties-common; then
        log_error "software-properties-commonのインストールに失敗しました"
        return 1
    fi
    
    log_progress "Ubuntu toolchain PPAを追加中"
    if ! sudo add-apt-repository ppa:ubuntu-toolchain-r/test -y; then
        log_warn "PPAの追加に失敗しました（継続します）"
    fi
    
    log_progress "パッケージリストを再更新中"
    if ! sudo apt-get update; then
        log_error "パッケージリストの再更新に失敗しました"
        return 1
    fi
    
    log_progress "gcc-12とg++-12をインストール中"
    if ! sudo apt-get install -y gcc-12 g++-12; then
        log_error "gcc-12のインストールに失敗しました"
        return 1
    fi
    
    log_progress "デフォルトのgcc/g++を設定中"
    sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 100 || true
    sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-12 100 || true
    
    log_success "gcc-12のインストールが完了しました"
    return 0
}

# gcc-12をインストール (CentOS/RHEL)
install_gcc12_rhel() {
    log_progress "CentOS/RHELでgcc-12をインストール中"
    
    local pkg_manager="yum"
    if command_exists "dnf"; then
        pkg_manager="dnf"
    fi
    
    log_progress "Development Toolsをインストール中"
    if ! sudo "$pkg_manager" groupinstall -y "Development Tools"; then
        log_error "Development Toolsのインストールに失敗しました"
        return 1
    fi
    
    log_progress "gcc-toolset-12をインストール中"
    if ! sudo "$pkg_manager" install -y gcc-toolset-12-gcc gcc-toolset-12-gcc-c++; then
        log_error "gcc-toolset-12のインストールに失敗しました"
        return 1
    fi
    
    log_success "gcc-toolset-12のインストールが完了しました"
    log_info "使用時は以下のコマンドでSCLを有効化してください:"
    log_info "  scl enable gcc-toolset-12 bash"
    
    return 0
}

# gcc-12をインストール (macOS)
install_gcc12_macos() {
    log_progress "macOSでgcc-12をインストール中"
    
    if ! command_exists "brew"; then
        log_error "Homebrewが見つかりません"
        log_info "Homebrewをインストールしてください: https://brew.sh/"
        return 1
    fi
    
    log_progress "Homebrewでgcc@12をインストール中"
    if ! brew install gcc@12; then
        log_error "gcc@12のインストールに失敗しました"
        return 1
    fi
    
    # gcc-12をgccとしてリンク
    local gcc12_path
    gcc12_path=$(brew --prefix gcc@12)
    
    ensure_dir "$LOCAL_BIN"
    
    if ! safe_symlink "$gcc12_path/bin/gcc-12" "$LOCAL_BIN/gcc"; then
        log_warn "gccシンボリックリンクの作成に失敗しました"
    fi
    
    if ! safe_symlink "$gcc12_path/bin/g++-12" "$LOCAL_BIN/g++"; then
        log_warn "g++シンボリックリンクの作成に失敗しました"
    fi
    
    log_success "gcc-12のインストールが完了しました"
    return 0
}

# OSに応じてgcc-12をインストール
install_gcc12() {
    local os_type
    os_type=$(detect_os)
    
    log_progress "gcc 12.2をインストール中 (OS: $os_type)"
    
    case "$os_type" in
        linux)
            if command_exists "apt-get"; then
                install_gcc12_ubuntu
            elif command_exists "yum" || command_exists "dnf"; then
                install_gcc12_rhel
            else
                log_error "このLinuxディストリビューションは自動インストールに対応していません"
                log_info "手動でgcc 12以上をインストールしてください"
                return 1
            fi
            ;;
        macos)
            install_gcc12_macos
            ;;
        *)
            log_error "このOS ($os_type) はgcc 12.2の自動インストールに対応していません"
            log_info "手動でgcc 12以上をインストールしてください"
            return 1
            ;;
    esac
}

# C++コンパイラのインストール確認
verify_cpp_installation() {
    log_progress "C++コンパイラのインストールを確認中"
    
    if ! command_exists "g++"; then
        log_error "g++が利用できません"
        return 1
    fi
    
    local gcc_version
    gcc_version=$(g++ --version | head -n1)
    log_success "利用可能なコンパイラ: $gcc_version"
    
    # C++20サポート確認
    if test_cpp20_support; then
        log_success "C++20サポートが利用可能です"
        return 0
    else
        log_warn "C++20サポートが利用できません"
        return 1
    fi
}

# 推奨コンパイルフラグを決定
determine_compile_flags() {
    log_progress "推奨コンパイルフラグを決定中"
    
    local flags=""
    
    # C++20サポートチェック
    if test_cpp20_support; then
        flags="-std=c++20"
        log_success "C++20フラグを使用: $flags"
    elif echo 'int main(){}' | g++ -std=c++17 -x c++ - -o /dev/null 2>/dev/null; then
        flags="-std=c++17"
        log_info "C++17フラグを使用: $flags"
    else
        flags="-std=c++14"
        log_warn "C++14フラグを使用: $flags"
    fi
    
    # 最適化とデバッグフラグを追加
    flags="$flags -O2 -Wall -Wextra"
    
    echo "$flags"
}

# =============================================================================
# メイン処理
# =============================================================================

main() {
    log_step "Step 3: C++環境セットアップ"
    
    # 既存のC++コンパイラチェック
    if check_existing_cpp; then
        log_info "適切なC++環境が既に利用可能です"
        local flags
        flags=$(determine_compile_flags)
        log_info "推奨コンパイルフラグ: $flags"
        return 0
    fi
    
    # gcc-12インストール
    log_info "gcc 12.2をインストールします"
    
    if ! install_gcc12; then
        log_error "gcc 12.2のインストールに失敗しました"
        return 1
    fi
    
    # インストール確認
    if ! verify_cpp_installation; then
        log_error "C++環境のセットアップに失敗しました"
        return 1
    fi
    
    # 推奨フラグ表示
    local flags
    flags=$(determine_compile_flags)
    log_info "推奨コンパイルフラグ: $flags"
    
    log_success "C++環境のセットアップが完了しました"
    return 0
}

# スクリプトが直接実行された場合のみmainを呼び出し
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi