# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Doom Emacs の個人設定（DOOMDIR）。

## 実行環境

- macOS 26（Apple Silicon）
- GNU Emacs 30.2（NS port, ns-inline-patch 適用済み）。主要ビルドフィーチャー: TREE_SITTER / SQLITE3 / MODULES / GNUTLS / LIBXML2

## 開発スタイル: spec 駆動開発

要求 → タスク → 実装の3ステップで進め、各ステップは必ず対応するスキルで実行する。

1. `/create-requirement` — プロンプト → 要求（docs/requirements/）
2. `/create-task` — 要求 → タスク（docs/tasks/）
3. `/sync-implementation` — タスク → 実装・検証（完了条件のチェック更新まで）

**ステップ間とステップ完了後で挙動が異なる**ので厳守すること:

- **次のステップはユーザーの明示指示があってから開始する**。要求とタスクを同時に作らない／先回りして実装しない。
- **各ステップの作業が完了したら、ユーザーの指示を待たず自動で `/git-commit` でコミットする**。1ステップ = 1コミット。差分すべてを対象に Conventional Commits の subject 1行（本文・フッターなし）。

### 要求ファイルとタスクファイル

要求・タスクの背景と経緯は docs/ を正とする。

- **要求ファイル（docs/requirements/）= 要求仕様**。「なぜ・何を作るか」に焦点を当て、構造化して明瞭・簡潔に書く。「満たすべき状態」と「受け入れ確認手順」を正とし、実装手段（配線コード・advice/hook の組み方・recipe 文字列等）はタスクへ委ねて本文には書かない。ただしユーザーが指定した確定コードや参照スニペットは、本文に混ぜず専用セクション `* タスクへの引き継ぎ` に分離する。
- **タスクファイル（docs/tasks/）= 実装仕様**。「どう実装するか」に焦点を当てる。
  - **冪等**: `/sync-implementation` を何度実行しても同じ最終状態に収束させる。変更対象を一意に特定し「既にあれば変えない」粒度で書く。自然に冪等でない elisp（`advice-add` 等）は一度だけ適用されるようアンカー編集／ガードする。
  - **決定的**: 同じ環境なら同じ実装に再現できることを目指す。実行時にしか確定できない分岐は実装者の裁量に委ねず判断ルールを明示する。

## リポジトリ構成

- `init.el` — `doom!` モジュール選択。**変更時は `doom sync` が必要**
- `packages.el` — 追加パッケージ宣言。**変更時は `doom sync` が必要**
- `config.el` — 設定本体（`doom sync` 不要）。パッケージは遅延ロードされるため、doom がパッケージロード時に設定する変数の上書きは素の `setq` ではなく `after!` ブロックで行う（例: `diff-hl-update-async`）
- `docs/requirements/`・`docs/tasks/` — spec 駆動開発の文書
- `.claude/skills/` — このリポジトリ用のプロジェクトスキル（上記3ステップ・`/git-commit`）

`doom sync` の実行は、ホスト側で init.el / packages.el を変更した場合はユーザーに依頼する（docker の batch / screenshot は自動で実行する → 下記）。

config.el の macOS/NS 固有設定は `(when (and (eq system-type 'darwin) (featurep 'ns)) ...)` ガード内にあり、Linux・docker など対象外環境では no-op になる。現状の中身は外観設定（`ns-antialias-text`・標準フォントセットへの Hiragino 割り当て・`face-font-rescale-alist`）。IME 連携（ns-inline-patch 適用ビルド向け、`mac-get-current-input-source` 等）は今後追加予定の未実装。

## 実装方針

- 人が読みやすく・メンテしやすい、明瞭で簡潔なコードにする。
- **doom-first**: 実装方法を検討する際は、相当する doom モジュール（`:ui` 等）が既にないか `init.el` の `doom!` ブロック（コメントアウトされた無効モジュール含む）で確認し、あれば手作り設定より優先採用を検討する。挙動・変数・キーバインドは doom ソースの README で確定する。
  - **doom ソース**: `~/.config/emacs/`（doomemacs/core）。標準モジュールと各 README は `~/.config/emacs/sources/doom+/modules/<カテゴリ>/<モジュール>/README.org`（例: `.../ui/unicode/README.org`）にあり、ここを直接 Read / grep する。`~/.config/emacs/modules/` 直下は core モジュールのみで標準モジュールは無い。
  - **設定資料**: `~/.config/emacs/docs/getting_started.org`（同 `docs/` に faq.org・examples.org 等）。doom の作法・`doom!` の構造・設定の流儀を確認する一次資料。

## 動作確認（Docker）

Emacs 設定の動作確認は**ホストで Emacs を起動せず**、`docker/` の隔離された Linux コンテナで行う（doomemacs 本体インストール済みのコンテナに、このリポジトリを DOOMDIR としてマウントして検証）。

```sh
./docker/run.sh build              # イメージ作成（初回・Dockerfile 変更時）
./docker/run.sh batch              # doom sync + 設定ロード + 標準チェック（evil 等）
./docker/run.sh batch '<ELISP>'    # 任意の検証式をコンテナ内 Emacs で評価
./docker/run.sh screenshot         # Xvfb 上の GUI を PNG 撮影（docker/out/*.png）
./docker/run.sh clean              # イメージ・パッケージキャッシュ破棄（クリーン初回状態の再現）
```

- **doom sync は自動**: init.el / packages.el（と doom 本体）が前回から変わっていれば batch / screenshot 前に自動実行される。config.el だけの変更では走らない。
- **検証式の出力は `message` ではなく `princ`**: batch では doom が message を CLI コンテキストの buffer に吸い込むため `message` は何も表示されない。
- **screenshot は目視確認**: `docker/out/*.png` を **Read で開いて**文字化け・豆腐・minibuffer プロンプト等を確認する。
- **macOS 固有要素は検証不可**: コンテナは Linux のため、Hiragino フォント・NS port の `mac-*` 関数・darwin ガード内のコード・`:os macos` モジュールは確認できない。その範囲の最終確認はユーザーに依頼する。
- **クリーン初回状態の再現**: パッケージ未インストールからの挙動は `clean` → `batch`。初回 batch は全パッケージ導入で数分かかり、2 回目以降は named volume キャッシュで数秒。
- **colima が必要**: docker デーモン停止時は run.sh がエラーを出すので、ユーザーに `start-colima` の実行を依頼する。
- **ホストで GUI Emacs を起動しない**: ユーザーのデスクトップに直接ウィンドウが出て、minibuffer プロンプトで固まると外から観測できない。
