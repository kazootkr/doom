# CHANGELOG

## 2026-11-15
- org-agenda-files から `.git` などの隠しディレクトリを除き、列挙を起動時から org のロード時に遅らせる
- TODO 一覧で日付の見出しを出す対象を、org-journal-mode で開かれる日誌ファイルに限る
- 日誌ヘッダーの `#+STARTUP:` の誤字 nolineimages を noinlineimages に直す

## 2026-11-13
- org-journal の carryover を無効化し、未完了の TODO を翌日へ移さず書いた日付の下に残す
- TODO 一覧の左の列に、日誌のエントリーではファイル名の代わりに日付の見出しを出す

## 2026-11-09
- テーマを doom-solarized-light、フォントを JetBrains Mono 15 に変更し、行間を 0.2 に広げる
- モジュールを追加: emoji / indent-guides / unicode / vterm / tree-sitter / `(lsp +eglot)`
- モジュールにフラグを追加: `(dired +dirvish +icons)` / `(lookup +docsets)` / `(org +journal)`
- 言語モジュールを tree-sitter 付きで有効化: json / markdown / yaml / `(swift +tree-sitter +lsp)`
- org-directory を `~/dev-home/notes/` に変更（日誌は notes/journal/ に保存される）
- org-journal を月ごとのファイルにし、日付・時刻見出しの書式を設定
- org-agenda-files を notes 配下の全ディレクトリにする
- org-capture のテンプレートを notes/Reminder.org への ToDo と予定付き ToDo に差し替え
- org-todo-keywords を TODO / STRT / WAIT / DONE / KILL の 5 つに絞る
- 漢字・かな・全角記号のフォントを Hiragino Sans に指定
- 全角文字を 1.2 倍に拡大して半角2文字分の幅にそろえる
- すべての行の最低の高さを日本語を含む行の高さにそろえる（`default-text-properties` の line-height 1.15）
- 行間を 0.2 から 1px に変更

## 2026-11-03
- ns-inline-patch の IME 連携を有効化（入力ソースの切り替えは Emacs が前面のときだけ。インサートはバッファごとに抜けたときの IME の状態に戻す）

## 2026-11-01
- `doom install` で初期化（`init.el` / `config.el` / `packages.el` は雛形のまま）
- AGENTS.md を作成（作業ファイルは `workspace/` に置くルールなど）
- CHANGELOG.md を作成
