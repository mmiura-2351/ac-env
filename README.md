# 競技プログラミング環境

AtCoder等の競技プログラミングを効率的に行うための環境です。

## セットアップ

```bash
# 利用可能なコマンド確認
make

# 環境をセットアップ（不足している依存関係のみ）
make install

# 環境ステータス確認（ログイン状態含む）
make status

# 新しいコンテストを開始
make new abc300
```

## 基本的な使い方

```bash
# 新規コンテスト作成
make new abc300

# テンプレートをコピー
make template

# テスト実行
make test

# 提出
make submit
```

## コマンド一覧

```bash
# ヘルプ
make                      # 利用可能なコマンド一覧を表示（デフォルト）
make help                 # 同上

# セットアップ
make install              # 環境をセットアップ（不足している依存関係のみ）
make uninstall            # 環境を削除

# 競技プログラミング
make new abc300           # 新しいコンテストを作成
make test [問題名]        # テストを実行
make submit [問題名]      # 問題を提出
make template [言語]      # テンプレートをコピー
make status               # 現在の状態を表示（ログイン状態含む）

# 管理
make config               # 設定の表示
make config キー 値       # 設定値の変更
make clean                # 一時ファイルをクリーンアップ
```

## 設定

`config.json`で設定をカスタマイズできます：

```bash
# デフォルト言語をPythonに変更
make config default_language python

# テストタイムアウトを3秒に変更
make config test_timeout 3000
```

## ログイン

初回セットアップ後は手動でログインが必要です：

```bash
# AtCoderログイン状況確認
make status

# 手動ログイン（未ログインの場合）
acc login
oj login https://atcoder.jp/
```

## コンテスト参加フロー

### 1. コンテスト開始前
```bash
# ログイン状態を確認
make status

# 必要に応じてログイン
acc login
oj login https://atcoder.jp/
```

### 2. コンテスト開始時（例: ABC300）
```bash
# コンテストディレクトリを作成
make new abc300

# 問題選択画面でスペースキーで問題を選択、Enterで確定
# テストケースは自動的にダウンロードされます
```

### 3. 問題を解く（A問題の例）
```bash
# 問題ディレクトリへ移動
cd contests/abc300/a

# テンプレートをコピー（デフォルトはPython）
make template

# C++を使う場合
make template cpp

# コーディング
# エディタが自動的に開くか、手動で編集
```

### 4. テスト・提出
```bash
# サンプルケースでテスト
make test

# 全てのテストが通ったら提出
make submit
# 提出前に以下をチェック：
# - ファイルサイズ
# - デバッグコード
# - TODO/FIXME
# 最後に確認プロンプトが表示されます (y/n)
```

### 5. 次の問題へ
```bash
# B問題へ移動
cd ../b

# 同じ流れを繰り返す
make template
make test
make submit
```

## 対応言語

- **Python** (PyPy 3.10) (デフォルト)
- **C++20**

## プロジェクト構造

```
ac-env/
├── Makefile           # コマンドインターフェース
├── config.json        # 設定ファイル
├── contests/          # コンテスト別ディレクトリ
├── templates/         # 言語別テンプレート
└── scripts/           # 実行スクリプト
```
