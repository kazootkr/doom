# AGENTS.md

このファイルは、このリポジトリで作業する AI エージェント（Claude Code など）向けのガイドです。
- 実行環境は [README.org](README.org) の「実行環境」を参照。

## 作業ファイルは `workspace/` に置く

メモ・調査結果・一時スクリプトなど、設定そのものではないファイルは必ず `workspace/` 以下に作ること。`workspace/` は `.gitignore` で除外済み（`.gitkeep` だけ追跡）なので git の差分にならない。リポジトリ直下に置くと差分が発生する。

## 変更したら `CHANGELOG.md` に追記する

Emacs の挙動が変わる変更（`init.el` / `packages.el` / `config.el` と、そこから読み込むファイル）をしたら、同じ作業の中で `CHANGELOG.md` に追記する。AGENTS.md や `.gitignore` だけの変更は書かない。

- 見出しは日付（`## YYYY-MM-DD`）で、新しい日付を上に置く。その日の見出しがすでにあれば、そこに足す。
- 1つの変更を1行の箇条書きで、何を変えたかだけ簡潔に書く（例: `- org-directory を ~/Documents/org に変更`）。

## このリポジトリ

Doom Emacs の個人設定ディレクトリ（`$DOOMDIR` = `~/.config/doom`）。Doom 本体は `~/.config/emacs`（`$EMACSDIR`）にあり、このリポジトリの管理外。現状はほぼ `doom install` 直後の雛形。

| ファイル | 役割 | 変更後に必要な操作 |
|---|---|---|
| `init.el` | `doom!` ブロックで有効にする Doom モジュールを宣言 | `doom sync` → Emacs 再起動 |
| `packages.el` | Doom モジュール外の追加パッケージを `package!` で宣言 | `doom sync` → Emacs 再起動 |
| `config.el` | 個人設定 | sync 不要。Emacs 再起動か `M-x doom/reload` |

- `config.el` でパッケージの変数を設定するときは `after!`（または `with-eval-after-load`）で包む。包まないと Doom の既定値に上書きされる。例外は `doom-` / `+` で始まる変数や `org-directory` のように「ロード前に設定せよ」とされている変数。

## コマンド

`doom` は `~/.config/emacs/bin/doom`（PATH 上にある）。

- `doom sync`: `init.el` / `packages.el` の変更を反映（パッケージのインストール・削除）。Emacs のバージョンを上げ下げしたときも実行する（パッケージが再ビルドされる）
- `doom doctor`: 環境や設定の問題を診断
- `doom upgrade`: Doom 本体とパッケージを更新

Emacs を起動せずに括弧の対応だけ確認する（不一致なら終了コード 255）:

```sh
emacs --batch --eval '(with-temp-buffer (insert-file-contents "config.el") (emacs-lisp-mode) (check-parens))'
```
