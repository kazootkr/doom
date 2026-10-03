# CLAUDE.md

Doom Emacs の個人設定（DOOMDIR）。実行環境は [README.org](README.org) の「実行環境」を参照。

## 開発スタイル: change brief（リスク段階制）

変更のリスク段階で手順を変える。迷ったら 1 段上にする。brief の書き方は各 SKILL.md を正とする。

| 段階 | 目安 | 手順 |
|---|---|---|
| 小 | 設定値・キー割当・テーマ 1 つ、モジュール/フラグ 1 つの有効化などで、docker で検証が完結する | brief なし。実装 → docker 検証 → コミット |
| 中 | 複数の設定・ファイルにまたがる機能、パッケージ追加、doom 既定の上書き（`after!`） | `/create-brief` → `/implement-brief` → macOS 実機確認 → `/ship-brief` |
| 高 | macOS/NS 固有（IME・`mac-*`）、起動全体に影響、docker で検証できない部分が中心 | 中と同じ。brief の「決めてほしいこと」をユーザーと合意してから実装する |

- 中・高の変更を直接頼まれたら実装せず、`/create-brief` の実行を提案する（3 スキルはユーザー専用）。
- **IMPORTANT: 各ステップ完了後は指示を待たず自動で `/git-commit`**（小は実装で 1 コミット、中・高は brief 作成・実装・出荷で各 1 コミット）。
- brief（`docs/changes/`）は変更中だけの文書。挙動の正はコードと `docker/checks.el`、経緯は git 履歴。恒久文書は `docs/macos-checklist.org`（docker で検証できない確認項目）と `docs/decisions/`（ADR）だけ。
- コードのコメントには「なぜ」を単体で読める形で書き、brief を参照しない。

## 実装方針

- **doom-first**: 自作前に相当する doom モジュールが `init.el` の `doom!` ブロック（無効=コメントアウト含む）に無いか確認し、あれば優先採用を検討。挙動・変数・キーバインドは README で確定する。
  - doom 標準モジュールと README: `~/.config/emacs/sources/doom+/modules/<カテゴリ>/<モジュール>/README.org`（`~/.config/emacs/modules/` は core のみ）。設定資料: `~/.config/emacs/docs/getting_started.org`（同 `docs/` に faq.org・examples.org）。
- init.el / packages.el の変更後は `doom sync` が必要（ホストでの実行はユーザーに依頼。docker では自動）。config.el のみなら不要。
- 遅延ロードされる変数の上書きは素の `setq` でなく `after!` ブロックで（例: `diff-hl-update-async`）。
- macOS/NS 固有設定は `(when (and (eq system-type 'darwin) (featurep 'ns)) ...)` ガード内（Linux・docker では no-op）。

## 動作確認（Docker）

**ホストで Emacs を起動しない**（GUI 起動は PreToolUse フックで deny）。検証は `./docker/run.sh batch`（引数なしで `docker/checks.el` の全テスト）と `./docker/run.sh batch '<ELISP>'`（サブコマンド一覧は run.sh 冒頭コメント）。

- doom の既定値やロード順の変化で壊れうる挙動（`after!` の上書き・ガードの no-op・キー割当）は `docker/checks.el` にテストとして残す。
- 検証式の出力は `message` でなく `princ`（batch では message が CLI buffer に吸われ表示されない）。
- screenshot は `docker/out/*.png` を Read で開き目視確認（文字化け・豆腐・minibuffer プロンプト等）。
- macOS 固有（Hiragino・`mac-*` 関数・darwin ガード内・`:os macos`）は検証不可。最終確認はユーザーに依頼（恒久的な確認項目は `docs/macos-checklist.org`）。
- docker デーモン停止時はユーザーに `start-colima` の実行を依頼。
