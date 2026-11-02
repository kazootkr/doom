#!/bin/bash
# ゲスト（macOS VM）の中の入口。ホストの ./vm/run.sh が tart exec で呼ぶ。
#
#   batch [ELISP]                        doom を batch でロードして ELISP を評価（省略時は vm/checks.el）
#   screenshot [ELISP] [NAME] [N] [SEC]  GUI の Emacs を起動して撮る（N 枚を SEC 秒ごと）
#   gui-checks                           GUI の Emacs の中で vm/checks-gui.el を実行
#   ime                                  IME の自動テスト
#   emacs [ELISP]                        GUI の Emacs を起動したままにする（server あり）
#   eval ELISP                           起動中の Emacs で ELISP を評価して結果を出す
#   keys KEY...                          キーを送る（書き方は vm/keysend.swift）
#   shot NAME [N] [SEC]                  今の画面を撮る
#   quit-emacs / quit-others             Emacs / Emacs と Finder 以外のアプリを終了する
#   front / input-source [--enabled]     前面のアプリ / 今の（有効な）入力ソースを出す
#   screeninfo / versions / capture-hint / sync-stamp   run.sh・provision.sh が使う
set -eu

SHARE="/Volumes/My Shared Files"
OUT="$SHARE/out"
REPO="$SHARE/doom"
export EMACSDIR="$HOME/.config/emacs"
export DOOMDIR="$HOME/.config/doom"
export LANG=ja_JP.UTF-8
export PATH="/opt/homebrew/opt/emacs-plus@31/bin:$EMACSDIR/bin:/opt/homebrew/bin:$PATH"
export HOMEBREW_NO_AUTO_UPDATE=1

EMACS_APP=/opt/homebrew/opt/emacs-plus@31/Emacs.app
WORK=/tmp/doom-vm
# GUI の Emacs（open で起動）と tart exec のプロセスでは TMPDIR が異なりうるので、server の
# ソケットは決まった場所に置く
SOCKDIR="$WORK/server"
SOCK="$SOCKDIR/server"
BIN="$HOME/.local/bin"
mkdir -p "$WORK" "$BIN"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# Swift の小さな道具（keysend など）を、ソースが新しいときだけコンパイルして使う。
# swift での逐次実行は 1 回 0.4 秒以上かかり、キーを続けて送る確認が遅くなるため
tool() {
    name="$1"; shift
    src="$REPO/vm/$name.swift"
    if [ ! -x "$BIN/$name" ] || [ "$src" -nt "$BIN/$name" ]; then
        swiftc -O -o "$BIN/$name" "$src" >&2
    fi
    "$BIN/$name" "$@"
}

sync_hash() {
    { cat "$DOOMDIR/init.el" "$DOOMDIR/packages.el"
      git -C "$EMACSDIR" rev-parse HEAD
      git -C "$EMACSDIR/sources/doom+" rev-parse HEAD; } | /sbin/md5 # tart exec の PATH に /sbin は無い
}

# init.el・packages.el・doom 本体が前回の sync から変わっていなければ doom sync を飛ばす
# （config.el はロード時に読まれるだけなので sync は要らない）
sync_if_needed() {
    stamp="$EMACSDIR/.local/.verify-sync-hash"
    if [ ! -f "$stamp" ] || [ "$(cat "$stamp")" != "$(sync_hash)" ]; then
        doom sync --force >&2
        sync_hash > "$stamp"
    fi
}

# doom の bin/doom は引数を eval で再パースし、emacs の --eval は quoting が壊れやすいため、
# ELISP はファイルに書いて -l で渡す
write_elisp() { printf '%s\n' "$2" > "$1"; }

# batch の Emacs は init を自動で読まないので、doom の起動列（early-init → モジュールの登録 →
# プロファイルの init → doom-startup）を明示的に踏む。doom-load-packages-incrementally は
# 対話起動でしか読まれない doom-start.el で定義され、未定義だと org などの use-package! が途中で
# エラーになるため、何もしない関数で補う（パッケージは require のときに読まれる）
DOOM_BATCH_BOOT='(progn
  (unless (fboundp (quote doom-load-packages-incrementally))
    (defun doom-load-packages-incrementally (&rest _)))
  (doom-modules-initialize)
  (load (doom-profile-init-file doom-profile))
  (doom-startup))'

DEFAULT_SCREENSHOT_SETUP='(progn
  (switch-to-buffer "*日本語検証*")
  (insert "日本語表示テスト: 漢字 ひらがな カタカナ 「約物」\n")
  (insert "吾輩は猫である。名前はまだ無い。\n")
  (goto-char (point-min)))'

emacs_running() { pgrep -x Emacs >/dev/null 2>&1; }

quit_emacs() {
    emacs_running || return 0
    emacsclient -s "$SOCK" --eval '(kill-emacs)' >/dev/null 2>&1 || pkill -x Emacs || true
    i=0
    while emacs_running && [ "$i" -lt 20 ]; do sleep 0.5; i=$((i + 1)); done
    emacs_running && pkill -9 -x Emacs || true
}

# Emacs と Finder 以外の前面に出るアプリを終了する。テストは Emacs が前面であることを前提にし、
# 他のアプリが残っていると前面やキーの送り先が変わるため
# アプリは表示名ではなく実行ファイルで判定する（ゲストは日本語なので TextEdit が「テキストエディット」になる）
quit_others() {
    for asn in $(lsappinfo visibleProcessList | grep -o 'ASN:0x[0-9a-f]*-0x[0-9a-f]*'); do
        exe="$(lsappinfo info -only executablepath "$asn:" | sed -n 's/.*executable path="\(.*\)"/\1/p')"
        pid="$(lsappinfo info -only pid "$asn:" | sed -n 's/.*pid = \([0-9]*\).*/\1/p')"
        case "$(basename "${exe:-x}")" in
            Finder|Emacs|x) ;;
            *) [ -n "$pid" ] && kill "$pid" 2>/dev/null || true ;;
        esac
    done
}

# lsappinfo info の 1 行目は「"アプリ名" ASN:… (in front)」の形
front_app() { lsappinfo info -only name "$(lsappinfo front)" | sed -n '1s/^"\([^"]*\)".*/\1/p'; }

# GUI の Emacs を open で起動する（ホストで Dock から起動するのと同じ経路で、環境変数の受け取り方も
# そろう）。ELISP を評価し終えたら印のファイルを作るので、それを最大 TIMEOUT 秒待つ
start_gui() {
    setup="$1"; timeout="${2:-90}"
    quit_emacs
    quit_others
    rm -rf "$SOCKDIR"; mkdir -p "$SOCKDIR"; chmod 700 "$SOCKDIR"
    rm -f "$WORK/ready"
    write_elisp "$WORK/setup.el" "(progn
  (setq server-socket-dir \"$SOCKDIR\")
  (server-start)
  $setup
  (with-temp-file \"$WORK/ready\" (insert \"ok\")))"
    open -a "$EMACS_APP" --args -l "$WORK/setup.el"
    i=0
    while [ ! -f "$WORK/ready" ] && [ "$i" -lt "$timeout" ]; do sleep 1; i=$((i + 1)); done
    [ -f "$WORK/ready" ] || echo "warning: Emacs が ${timeout} 秒で準備完了になりませんでした（そのまま続けます）" >&2
    activate_emacs
}

activate_emacs() {
    open -a "$EMACS_APP"
    i=0
    while [ "$(front_app)" != "Emacs" ] && [ "$i" -lt 10 ]; do sleep 0.5; i=$((i + 1)); done
    [ "$(front_app)" = "Emacs" ] || echo "warning: Emacs が前面になりません（前面: $(front_app)）" >&2
}

# 画面を N 枚、SEC 秒ごとに撮る。NAME が .jpg なら JPEG で撮る（PNG より 1 枚が速い）
shot() {
    name="$1"; count="${2:-1}"; interval="${3:-0}"
    case "$name" in *.jpg) fmt=jpg ;; *) fmt=png ;; esac
    if [ "$count" -le 1 ]; then
        screencapture -x -t "$fmt" "$OUT/$name"
        echo "saved: vm/out/$name"
        return
    fi
    base="${name%.*}"; n=1
    while [ "$n" -le "$count" ]; do
        file="$(printf '%s-%02d.%s' "$base" "$n" "$fmt")"
        screencapture -x -t "$fmt" "$OUT/$file"
        n=$((n + 1))
        [ "$n" -le "$count" ] && sleep "$interval"
    done
    echo "saved: vm/out/$base-01.$fmt 〜 $(printf '%02d' "$count") 枚"
}

# 画面収録の確認ダイアログ（30 日ごと）の次の表示予定までの日数を出す
capture_hint() {
    plist="$HOME/Library/Group Containers/group.com.apple.replayd/ScreenCaptureApprovals"
    next="$(defaults read "$plist" 2>/dev/null | sed -n 's/.*kScreenCapturePrivacyHintDate = "\(.*\)";/\1/p' | sort | head -1)"
    [ -n "$next" ] || { echo "next= days="; return; }
    secs=$(( $(date -j -f '%Y-%m-%d %H:%M:%S %z' "$next" +%s) - $(date +%s) ))
    echo "next=$next days=$(( secs / 86400 ))"
}

# IME の自動テスト。キーは前面のアプリに届き、config.el は Emacs が前面のときだけ入力ソースを
# 変えるため、最初に Emacs が前面であることを確かめる。状態は emacsclient で読む（画面より正確）
ime_checks() {
    passed=0; failed=0
    ev() { emacsclient -s "$SOCK" --eval "$1" 2>&1; }
    check() { # 名前 期待 実際
        if [ "$3" = "$2" ]; then
            printf 'ok    %s\n' "$1"; passed=$((passed + 1))
        else
            printf 'FAIL  %s\n      期待: %s / 実際: %s\n' "$1" "$2" "$3"; failed=$((failed + 1))
        fi
    }
    # キーを送ってから状態が変わるまでの待ち時間（入力ソースの切り替えは非同期で伝わる）
    settle() { sleep 1; }

    start_gui '(progn (switch-to-buffer (get-buffer-create "*ime-test*")) (evil-normal-state))'
    echo "=== ime (Emacs $(ev emacs-version)) ==="
    check ime/emacs-is-front Emacs "$(front_app)"
    check ime/mode-enabled t "$(ev mac-input-method-mode)"
    check ime/default-input-source '"com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese"' \
        "$(ev mac-default-input-source)"
    check ime/starts-in-eisu nil "$(ev '(mac-ime-active-p)')"

    # ノーマルステートに入ると IME がオフになる（コマンドキーの誤爆を防ぐ）。
    # emacsclient の式は server のバッファで評価されるため、表示中のバッファの evil-state を読む
    state='(with-current-buffer (window-buffer (selected-window)) (format "%s %s" evil-state (mac-ime-active-p)))'
    ev '(progn (switch-to-buffer "*ime-test*") (evil-normal-state) t)' >/dev/null
    tool keysend i kana; settle
    check ime/kana-turns-ime-on '"insert t"' "$(ev "$state")"
    tool keysend esc; settle
    check ime/normal-state-turns-ime-off '"normal nil"' "$(ev "$state")"

    printf '=== %d passed, %d failed ===\n' "$passed" "$failed"
    quit_emacs
    [ "$failed" -eq 0 ]
}

cmd="${1:-help}"
[ $# -gt 0 ] && shift

case "$cmd" in
    batch)
        sync_if_needed
        write_elisp "$WORK/boot.el" "$DOOM_BATCH_BOOT"
        write_elisp "$WORK/verify.el" "${1:-(load \"$DOOMDIR/vm/checks.el\" nil t)}"
        exec emacs --batch -l "$EMACSDIR/early-init.el" -l "$WORK/boot.el" -l "$WORK/verify.el"
        ;;
    screenshot)
        sync_if_needed
        start_gui "${1:-$DEFAULT_SCREENSHOT_SETUP}"
        sleep 2 # 描画が落ち着くのを待つ
        shot "${2:-verify.png}" "${3:-1}" "${4:-0}"
        quit_emacs
        ;;
    gui-checks)
        sync_if_needed
        result="$OUT/gui-checks.txt"
        rm -f "$result"
        start_gui "(load \"$DOOMDIR/vm/checks-gui.el\" nil t)"
        emacsclient -s "$SOCK" --eval "(checks-gui-run \"$result\")" >/dev/null
        cat "$result"
        quit_emacs
        ! grep -q '^FAIL' "$result"
        ;;
    ime)
        sync_if_needed
        ime_checks
        ;;
    emacs)
        sync_if_needed
        start_gui "${1:-nil}"
        echo "Emacs: 起動中（前面: $(front_app)）"
        ;;
    eval)
        # emacsclient の式は server のバッファで評価されるので、画面に出ているバッファで評価する
        emacsclient -s "$SOCK" --eval "(with-current-buffer (window-buffer (selected-window)) $1)"
        ;;
    keys) tool keysend "$@" ;;
    shot) shot "$@" ;;
    quit-emacs) quit_emacs ;;
    quit-others) quit_others ;;
    activate) activate_emacs ;;
    front) front_app ;;
    input-source) tool inputsource "$@" ;;
    screeninfo) tool screeninfo ;;
    capture-hint) capture_hint ;;
    sync-stamp) sync_hash > "$EMACSDIR/.local/.verify-sync-hash" ;;
    versions)
        receipt=$(ls /opt/homebrew/Cellar/emacs-plus@31/*/INSTALL_RECEIPT.json 2>/dev/null | head -1)
        printf 'tap=%s\n' "$( [ -n "$receipt" ] && plutil -extract source.tap_git_head raw -o - "$receipt" )"
        printf 'emacs=%s\n' "$( [ -n "$receipt" ] && plutil -extract source.versions.stable raw -o - "$receipt" )"
        printf 'core=%s\n' "$(git -C "$EMACSDIR" rev-parse HEAD 2>/dev/null)"
        printf 'modules=%s\n' "$(git -C "$EMACSDIR/sources/doom+" rev-parse HEAD 2>/dev/null)"
        ;;
    *)
        sed -n '2,15p' "$0"
        exit 2
        ;;
esac
