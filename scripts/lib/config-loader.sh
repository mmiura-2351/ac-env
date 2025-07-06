#!/bin/bash
# 設定読み込み用の共通ライブラリ
# 他のスクリプトからsourceして使用

# プロジェクトルートの取得
if [ -z "${PROJECT_ROOT:-}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
fi

CONFIG_FILE="$PROJECT_ROOT/config.json"

# 設定値を取得する関数
get_config() {
    local key="$1"
    local default="${2:-}"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "$default"
        return
    fi
    
    local value
    if command -v jq &> /dev/null; then
        value=$(jq -r ".$key // empty" "$CONFIG_FILE" 2>/dev/null || echo "")
    else
        # jqがない場合は簡易的なgrep/sed処理
        value=$(grep "\"$key\"" "$CONFIG_FILE" | sed -E 's/.*"'"$key"'"\s*:\s*"?([^",}]*)"?.*/\1/' | head -1)
    fi
    
    if [ -n "$value" ] && [ "$value" != "null" ]; then
        echo "$value"
    else
        echo "$default"
    fi
}

# 配列型の設定値を取得
get_config_array() {
    local key="$1"
    
    if [ ! -f "$CONFIG_FILE" ] || ! command -v jq &> /dev/null; then
        return
    fi
    
    jq -r ".$key[]? // empty" "$CONFIG_FILE" 2>/dev/null
}

# 色出力の設定
if [ "$(get_config "color_output" "true")" == "true" ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    BLUE=''
    YELLOW=''
    NC=''
fi

# パスの展開（~を$HOMEに変換）
expand_path() {
    local path="$1"
    echo "${path/#\~/$HOME}"
}

# サポートされている言語のリストを取得
get_supported_languages() {
    if [ ! -f "$CONFIG_FILE" ] || ! command -v jq &> /dev/null; then
        echo "python cpp"
        return
    fi
    
    jq -r '.supported_languages | keys[]' "$CONFIG_FILE" 2>/dev/null | tr '\n' ' '
}

# 言語がサポートされているかチェック
is_language_supported() {
    local lang="$1"
    local supported_langs=($(get_supported_languages))
    
    for supported_lang in "${supported_langs[@]}"; do
        if [ "$lang" = "$supported_lang" ]; then
            return 0
        fi
    done
    return 1
}

# 言語の設定値を取得
get_language_config() {
    local lang="$1"
    local key="$2"
    local default="${3:-}"
    
    if [ ! -f "$CONFIG_FILE" ] || ! command -v jq &> /dev/null; then
        echo "$default"
        return
    fi
    
    local value
    value=$(jq -r ".supported_languages.\"$lang\".\"$key\" // empty" "$CONFIG_FILE" 2>/dev/null || echo "")
    
    if [ -n "$value" ] && [ "$value" != "null" ]; then
        echo "$value"
    else
        echo "$default"
    fi
}

# 言語のコンパイル/実行コマンドを生成
get_language_command() {
    local lang="$1"
    local file="$2"
    local template command flags
    
    case "$lang" in
        cpp)
            template=$(get_language_config "$lang" "compile_command" "g++ {{flags}} {{file}}")
            flags=$(get_language_config "$lang" "flags" "-std=c++17 -O2 -Wall -Wextra")
            ;;
        python)
            template=$(get_language_config "$lang" "compile_command" "{{command}} {{file}}")
            command=$(get_language_config "$lang" "command" "python3")
            ;;
        *)
            echo "Error: Unsupported language: $lang" >&2
            return 1
            ;;
    esac
    
    # テンプレート置換
    if [ "$lang" = "cpp" ]; then
        echo "$template" | sed "s/{{flags}}/$flags/g" | sed "s/{{file}}/$file/g"
    elif [ "$lang" = "python" ]; then
        echo "$template" | sed "s/{{command}}/$command/g" | sed "s/{{file}}/$file/g"
    fi
}

# メインファイルを探す（設定に基づく優先順位）
find_main_file() {
    local lang="${1:-}"
    local supported_langs=($(get_supported_languages))
    
    # 言語が指定されている場合
    if [ -n "$lang" ] && is_language_supported "$lang"; then
        local main_file
        main_file=$(get_language_config "$lang" "main_file")
        if [ -f "$main_file" ]; then
            echo "$main_file"
            return 0
        fi
    fi
    
    # デフォルト言語を試す
    local default_lang
    default_lang=$(get_config "default_language" "python")
    if is_language_supported "$default_lang"; then
        local main_file
        main_file=$(get_language_config "$default_lang" "main_file")
        if [ -f "$main_file" ]; then
            echo "$main_file"
            return 0
        fi
    fi
    
    # サポートされている言語の順番で探す
    for lang in "${supported_langs[@]}"; do
        local main_file
        main_file=$(get_language_config "$lang" "main_file")
        if [ -f "$main_file" ]; then
            echo "$main_file"
            return 0
        fi
    done
    
    # 拡張子ベースで探す
    for lang in "${supported_langs[@]}"; do
        local ext
        ext=$(get_language_config "$lang" "file_extension")
        for file in *."$ext"; do
            if [ -f "$file" ]; then
                echo "$file"
                return 0
            fi
        done
    done
    
    return 1
}

# ファイルから言語を推定
detect_language_from_file() {
    local file="$1"
    local ext="${file##*.}"
    local supported_langs=($(get_supported_languages))
    
    for lang in "${supported_langs[@]}"; do
        local lang_ext
        lang_ext=$(get_language_config "$lang" "file_extension")
        if [ "$ext" = "$lang_ext" ]; then
            echo "$lang"
            return 0
        fi
    done
    
    return 1
}