#!/bin/sh
# doom 設定を macOS の VM（Tart）で検証するホスト側の入口
#
#   ./run.sh provision                       ゲストの環境を作る（初回と、Emacs・doom・macOS を更新したとき）
#   ./run.sh batch [ELISP]                   batch 検証（省略時は vm/checks.el の全テスト）
#   ./run.sh screenshot [ELISP] [NAME] [N] [SEC]   GUI を撮って vm/out/NAME に保存（N 枚を SEC 秒ごと）
#   ./run.sh gui-checks                      GUI の Emacs の中で vm/checks-gui.el を実行
#   ./run.sh ime                             IME の自動テスト
#   ./run.sh emacs [ELISP]                   GUI の Emacs を起動したままにする（以下は Claude の確認用）
#   ./run.sh eval ELISP                      起動中の Emacs で ELISP を評価
#   ./run.sh keys KEY...                     キーを送る（例: keys esc i kana a ret opt+x）
#   ./run.sh shot NAME [N] [SEC]             今の画面を vm/out/NAME に撮る
#   ./run.sh front | input-source [--enabled] | quit-emacs | quit-others | activate
#   ./run.sh stop                            VM を止める
#
# ELISP はゲストの Emacs でのみ評価される（ホストでは実行されない）。
#
# Claude Code の許可の一覧には、このスクリプトと tart exec・tart list だけを入れ、tart run・stop・set
# は入れない（VM の起動・停止はこのスクリプト経由に限る）。tart run と tart exec を両方許可すると、
# ホストの任意のフォルダを書き込み可で共有したうえで、問い合わせなしにファイルを消せるため。
set -eu

cd "$(dirname "$0")"
VM=doom-macos
REPO="$(cd .. && pwd)"
OUT="$REPO/vm/out"
GUEST="/Volumes/My Shared Files/doom/vm/guest.sh"
HOST_EMACSDIR="${EMACSDIR:-$HOME/.config/emacs}"
HOST_RECEIPT=/opt/homebrew/Cellar/emacs-plus@31/31.1/INSTALL_RECEIPT.json
EMACS_BUILD_DIR="$HOME/dev-home/emacs-build"
# 内蔵 Retina の論理解像度と倍率。VM の倍率は tart run の時点のホストの主画面で決まり、
# 外部モニター（1 倍の画面など）が主画面だと VM もそれに合わせてしまう。
# VM_EXPECTED_SCREEN・VM_CAPTURE_WARN_DAYS は、判定そのものを確かめるときだけ上書きする
EXPECTED_SCREEN="${VM_EXPECTED_SCREEN:-1710x1112 pt, backingScaleFactor=2.0}"
CAPTURE_WARN_DAYS="${VM_CAPTURE_WARN_DAYS:-2}"

mkdir -p "$OUT"

vm_state() { tart list --format json | jq -r --arg vm "$VM" '.[] | select(.Name == $vm) | .State'; }
guest() { tart exec "$VM" /bin/bash "$GUEST" "$@"; }

start_vm() {
    [ "$(vm_state)" = "running" ] && return 0
    [ -n "$(vm_state)" ] || { echo "error: VM $VM がありません" >&2; exit 1; }
    echo "VM を画面なしで起動します" >&2
    # 共有はリポジトリ（読み取り専用）と結果の受け取り先（vm/out）だけにする
    nohup tart run "$VM" --no-graphics --dir="doom:$REPO:ro" --dir="out:$OUT" \
        >"$OUT/tart-run.log" 2>&1 &
    i=0
    until tart exec "$VM" true 2>/dev/null; do
        i=$((i + 1))
        [ "$i" -lt 60 ] || { echo "error: VM が応答しません（$OUT/tart-run.log）" >&2; exit 1; }
        sleep 2
    done
    check_screen
}

# 起動のたびに倍率を確かめる。値が違えば止める。値が取れなければ、判定の不具合で検証が全部
# 止まらないよう警告だけにする（gui-checks の frame-scale-factor でも確かめる）
check_screen() {
    info="$(guest screeninfo 2>/dev/null | grep '^screen0:' || true)"
    case "$info" in
        "screen0: $EXPECTED_SCREEN"*) ;;
        "") echo "warning: VM の画面の倍率を読めませんでした" >&2 ;;
        *)
            # 変数の直後に全角文字が続くと、macOS の bash 3.2 は変数名の一部と読むので ${} で囲む
            echo "error: VM の画面が想定と違います（${info}。想定は ${EXPECTED_SCREEN}）" >&2
            echo "  ホストの主画面を内蔵ディスプレイにしてから ./vm/run.sh stop で止め、起動し直してください" >&2
            exit 1
            ;;
    esac
}

# ゲストの Emacs・doom がホストとずれていると、検証結果がホストの挙動と一致しないため警告する
warn_if_drift() {
    versions="$(guest versions 2>/dev/null || true)"
    v() { printf '%s\n' "$versions" | sed -n "s/^$1=//p"; }
    [ "$(v tap)" = "$(host_tap)" ] && [ "$(v emacs)" = "$(host_emacs)" ] ||
        echo "warning: ゲストの Emacs（$(v emacs) / tap $(v tap)）がホスト（$(host_emacs) / tap $(host_tap)）と異なります。./vm/run.sh provision で作り直してください" >&2
    [ "$(v core)" = "$(git -C "$HOST_EMACSDIR" rev-parse HEAD)" ] &&
        [ "$(v modules)" = "$(git -C "$HOST_EMACSDIR/sources/doom+" rev-parse HEAD)" ] ||
        echo "warning: ゲストの doom がホスト（${HOST_EMACSDIR}）と異なります。./vm/run.sh provision で合わせてください" >&2
}

# 画面収録の確認ダイアログは 30 日ごとに出て、出ている間は撮った画像の一部を隠す
warn_capture_hint() {
    hint="$(guest capture-hint 2>/dev/null || true)"
    days="$(printf '%s' "$hint" | sed -n 's/.*days=//p')"
    [ -n "$days" ] || return 0
    if [ "$days" -le "$CAPTURE_WARN_DAYS" ]; then
        echo "warning: 画面収録の確認ダイアログが近く出ます（${hint%% days=*}）。出たら ./vm/run.sh stop のあと VM を窓ありで起動し（tart run ${VM}）、Allow を押してください" >&2
    fi
}

host_tap() { plutil -extract source.tap_git_head raw -o - "$HOST_RECEIPT"; }
host_emacs() { plutil -extract source.versions.stable raw -o - "$HOST_RECEIPT"; }

cmd="${1:-help}"
[ $# -gt 0 ] && shift

case "$cmd" in
    provision)
        start_vm
        # 入力ソースと、その切り替えのショートカットは、ホストの設定を書き出して渡す
        # （ゲストで defaults import する）
        mkdir -p "$OUT/provision"
        for domain in com.apple.HIToolbox com.apple.inputmethod.Kotoeri com.apple.symbolichotkeys; do
            defaults export "$domain" "$OUT/provision/$domain.plist"
        done
        tart exec "$VM" /bin/bash "/Volumes/My Shared Files/doom/vm/provision.sh" \
            "$(host_tap)" "$(host_emacs)" "$(git -C "$EMACS_BUILD_DIR" rev-parse HEAD)" \
            "$(git -C "$HOST_EMACSDIR" rev-parse HEAD)" \
            "$(git -C "$HOST_EMACSDIR/sources/doom+" rev-parse HEAD)"
        # 言語・地域・入力ソースは、ログインし直すまで反映されないため起動し直す
        echo "設定を反映するため VM を起動し直します" >&2
        tart stop "$VM"
        start_vm
        warn_if_drift
        ;;
    batch|gui-checks|ime)
        start_vm
        warn_if_drift
        [ "$cmd" = batch ] || warn_capture_hint
        guest "$cmd" "$@"
        ;;
    screenshot|emacs|shot)
        start_vm
        warn_if_drift
        warn_capture_hint
        guest "$cmd" "$@"
        ;;
    eval|keys|front|input-source|quit-emacs|quit-others|activate)
        start_vm
        guest "$cmd" "$@"
        ;;
    stop)
        [ "$(vm_state)" = "running" ] && tart stop "$VM"
        ;;
    *)
        sed -n '2,17p' "$0"
        exit 2
        ;;
esac
