# CLAUDE.md

Doom Emacs の個人設定（DOOMDIR）。実行環境は [README.org](README.org) の「実行環境」を参照。

## 開発スタイル: spec 駆動開発

3ステップ（要求 → タスク → 実装）。各ステップは必ず対応スキル（`/create-requirement` → `/create-task` → `/sync-implementation`）で実行する。要求・タスクの書き方は各 SKILL.md を正とする。

- **IMPORTANT: 各ステップ完了後は指示を待たず自動で `/git-commit`**（1ステップ = 1コミット）。
- 背景・経緯は docs/requirements/・docs/tasks/ を正とする。

## 実装方針

- **doom-first**: 自作前に相当する doom モジュールが `init.el` の `doom!` ブロック（無効=コメントアウト含む）に無いか確認し、あれば優先採用を検討。挙動・変数・キーバインドは README で確定する。
  - doom 標準モジュールと README: `~/.config/emacs/sources/doom+/modules/<カテゴリ>/<モジュール>/README.org`（`~/.config/emacs/modules/` は core のみ）。設定資料: `~/.config/emacs/docs/getting_started.org`（同 `docs/` に faq.org・examples.org）。
- init.el / packages.el の変更後は `doom sync` が必要（ホストでの実行はユーザーに依頼。docker では自動）。config.el のみなら不要。
- 遅延ロードされる変数の上書きは素の `setq` でなく `after!` ブロックで（例: `diff-hl-update-async`）。
- macOS/NS 固有設定は `(when (and (eq system-type 'darwin) (featurep 'ns)) ...)` ガード内（Linux・docker では no-op）。

## 動作確認（Docker）

**ホストで Emacs を起動しない**（GUI 起動は PreToolUse フックで deny）。検証は `./docker/run.sh batch '<ELISP>'`（サブコマンド一覧は run.sh 冒頭コメント）。

- 検証式の出力は `message` でなく `princ`（batch では message が CLI buffer に吸われ表示されない）。
- screenshot は `docker/out/*.png` を Read で開き目視確認（文字化け・豆腐・minibuffer プロンプト等）。
- macOS 固有（Hiragino・`mac-*` 関数・darwin ガード内・`:os macos`）は検証不可。最終確認はユーザーに依頼。
- docker デーモン停止時はユーザーに `start-colima` の実行を依頼。
