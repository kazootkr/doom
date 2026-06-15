#!/bin/sh
# コンテナ内で doom 設定を検証するエントリポイント
#
#   batch [ELISP]              doom 設定を batch ロードして ELISP を評価（省略時は標準チェック）
#   screenshot [ELISP] [NAME]  Xvfb 上で GUI Emacs を起動し /out/NAME に PNG を保存
#   shell [CMD...]             デバッグ用シェル
set -eu

mkdir -p /out

# init.el / packages.el / doomemacs 本体が前回 sync 時から変わっていなければ
# doom sync を省略する（config.el はロード時に読まれるだけなので sync 不要）
sync_if_needed() {
    stamp="$EMACSDIR/.local/.verify-sync-hash"
    hash=$({ cat "$DOOMDIR/init.el" "$DOOMDIR/packages.el" 2>/dev/null
             git -C "$EMACSDIR" rev-parse HEAD
             git -C "$EMACSDIR/sources/doom+" rev-parse HEAD; } | md5sum)
    if [ ! -f "$stamp" ] || [ "$(cat "$stamp")" != "$hash" ]; then
        doom sync --force
        echo "$hash" > "$stamp"
    fi
}

# bin/doom の sh ヘッダは引数を eval で再パースするため、また emacs の --eval は
# quoting が壊れやすいため、ELISP はファイルに書いて -l で渡す
write_elisp() {
    printf '%s\n' "$2" > "$1"
}

# batch モードの Emacs は init を自動ロードしないので、doom の起動列
# （early-init → モジュール登録 → プロファイル init → doom-startup）を明示的に踏む。
# early-init.el はコマンドラインから -l で渡す（doom の「universal bootstrapper」）
DOOM_BATCH_BOOT='(progn
  (doom-modules-initialize)
  (load (doom-profile-init-file doom-profile))
  (doom-startup))'

# batch では doom が CLI コンテキストの buffer に message 出力を吸い込むため、
# 検証式の出力には message ではなく princ を使うこと
DEFAULT_BATCH_CHECK='(progn
  (princ "=== VERIFY ===\n")
  (princ (format "doom: %s / evil: %s / config.el org-directory: %s\n"
                 doom-version (featurep (quote evil)) (bound-and-true-p org-directory)))
  (princ (format "C-u (motion state): %s\n"
                 (and (boundp (quote evil-motion-state-map))
                      (lookup-key evil-motion-state-map (kbd "C-u"))))))'

DEFAULT_SCREENSHOT_SETUP='(progn
  (switch-to-buffer "*日本語検証*")
  (insert "日本語表示テスト: 漢字 ひらがな カタカナ 「約物」\n")
  (insert "吾輩は猫である。名前はまだ無い。\n")
  (goto-char (point-min)))'

cmd="${1:-batch}"
[ $# -gt 0 ] && shift

case "$cmd" in
    batch)
        sync_if_needed
        write_elisp /tmp/boot.el "$DOOM_BATCH_BOOT"
        write_elisp /tmp/verify.el "${1:-$DEFAULT_BATCH_CHECK}"
        exec emacs --batch -l "$EMACSDIR/early-init.el" -l /tmp/boot.el -l /tmp/verify.el
        ;;

    screenshot)
        sync_if_needed
        setup="${1:-$DEFAULT_SCREENSHOT_SETUP}"
        name="${2:-verify.png}"
        ready=/tmp/emacs-ready
        rm -f "$ready"

        Xvfb :99 -screen 0 1280x800x24 >/dev/null 2>&1 &
        xvfb_pid=$!
        trap 'kill $xvfb_pid 2>/dev/null || true' EXIT
        sleep 1

        # GUI は通常起動（early-init 経由で doom がフルロードされる）
        write_elisp /tmp/setup.el "(progn $setup (with-temp-file \"$ready\" (insert \"ok\")))"
        emacs --maximized -l /tmp/setup.el &
        emacs_pid=$!

        # ready 待ち（最大 60 秒）。タイムアウトしてもそのまま撮影する:
        # minibuffer プロンプト等で固まった画面こそ確認したい
        i=0
        while [ ! -f "$ready" ] && [ "$i" -lt 60 ]; do
            sleep 1
            i=$((i + 1))
        done
        [ -f "$ready" ] || echo "warning: emacs が ready になりませんでした（そのまま撮影します）" >&2
        sleep 2 # 描画の安定待ち

        import -window root "/out/$name"
        kill "$emacs_pid" 2>/dev/null || true
        echo "screenshot saved: /out/$name"
        ;;

    shell)
        exec "${@:-/bin/bash}"
        ;;

    *)
        echo "unknown command: $cmd (batch | screenshot | shell)" >&2
        exit 2
        ;;
esac
