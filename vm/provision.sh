#!/bin/bash
# ゲスト（macOS VM）の検証環境を作る。ホストの ./vm/run.sh provision が tart exec で呼ぶ。
#
#   provision.sh TAP_COMMIT EMACS_VERSION EMACS_BUILD_COMMIT DOOM_CORE DOOM_MODULES
#
# 引数はすべてホストから読んだ値。ホストと同じ Emacs・doom で検証しないと、結果がホストの
# 挙動と一致する保証がないため、版とコミットをホストにそろえる。何度実行しても同じ状態になる
# （そろっている部分は飛ばす）。途中で入力を求めない。
set -euo pipefail

TAP_COMMIT="$1"
EMACS_VERSION="$2"
EMACS_BUILD_COMMIT="$3"
DOOM_CORE="$4"
DOOM_MODULES="$5"

SHARE="/Volumes/My Shared Files"
REPO="$SHARE/doom"
HOSTPREFS="$SHARE/out/provision"
FORMULA="emacs-plus@31"
TAP="d12frosted/emacs-plus"
EMACSDIR="$HOME/.config/emacs"
MIN_FREE_GB=15

export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
# tap を固定したコミットから動かさないため、brew の自動更新を止める
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 NONINTERACTIVE=1

log() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# --- 空き容量（Emacs のビルドと doom のパッケージで 10GB 以上使う） ---
free_gb=$(df -g / | awk 'NR == 2 { print $4 }')
log "ゲストの空き: ${free_gb}GB"
[ "$free_gb" -ge "$MIN_FREE_GB" ] || die "空きが ${MIN_FREE_GB}GB 未満です。ディスクを広げてから実行してください"

# --- 権限を守る ---
# guest agent の権限（画面収録・入力送出）は実体のパス（版ごとのフォルダ）に結びつくため、
# 版が上がると外れる。brew upgrade で上がらないよう固定する
brew pin tart-guest-agent 2>/dev/null || true

# --- 画面共有を切る（検証では使わず、開けておくと攻撃面になるため） ---
sudo launchctl disable system/com.apple.screensharing
sudo launchctl bootout system/com.apple.screensharing 2>/dev/null || true

# --- ログイン時にアプリを開き直さない ---
# VM を止めて起動し直すと、前回開いていたアプリ（TextEdit など）が開き直し、テストの前面の
# アプリが変わるため
defaults write com.apple.loginwindow TALLogoutSavesState -bool false
defaults write com.apple.loginwindow LoginwindowLaunchesRelaunchApps -bool false
defaults write -g NSQuitAlwaysKeepsWindows -bool false

# --- 言語・地域・時刻帯をホストに合わせる（ns-inline-patch は OS の第 1 言語で挙動が変わる） ---
defaults write -g AppleLanguages -array ja-JP
defaults write -g AppleLocale ja_JP
sudo systemsetup -settimezone Asia/Tokyo >/dev/null

# --- 入力ソースと、その切り替えのショートカット（Ctrl+Space など）をホストと同じにする ---
# ホストの設定は run.sh が書き出して渡す。ショートカットが無効だと、Ctrl+Space が OS ではなく
# Emacs に届き、ホストと挙動が変わる
for domain in com.apple.HIToolbox com.apple.inputmethod.Kotoeri com.apple.symbolichotkeys; do
    [ -f "$HOSTPREFS/$domain.plist" ] || die "$HOSTPREFS/$domain.plist がありません（run.sh provision から実行してください）"
    defaults import "$domain" "$HOSTPREFS/$domain.plist"
done

# --- ホストにある道具とフォント ---
# fd はホストに無い。doom は fd があればファイル一覧に使うので、入れると挙動がホストと変わる
brew list --formula ripgrep >/dev/null 2>&1 || brew install ripgrep
for cask in font-udev-gothic font-jetbrains-mono font-symbols-only-nerd-font; do
    brew list --cask "$cask" >/dev/null 2>&1 || brew install --cask "$cask"
done

# --- Emacs をホストと同じ条件でビルドする ---
receipt_value() { # INSTALL_RECEIPT.json から tap のコミットと版を読む（無ければ空）
    local receipt
    receipt="$(brew --cellar)/$FORMULA/$EMACS_VERSION/INSTALL_RECEIPT.json"
    [ -f "$receipt" ] || return 0
    /usr/bin/plutil -extract "$1" raw -o - "$receipt" 2>/dev/null || true
}
if [ "$(receipt_value source.tap_git_head)" = "$TAP_COMMIT" ]; then
    log "Emacs ${EMACS_VERSION}（tap ${TAP_COMMIT}）はビルド済み"
else
    brew tap | grep -qx "$TAP" || brew tap "$TAP"
    git -C "$(brew --repo "$TAP")" fetch -q origin
    git -C "$(brew --repo "$TAP")" checkout -q "$TAP_COMMIT"
    # Homebrew は信頼していない tap の formula を読まない。ホストと同じく信頼するが、範囲は
    # ビルドする formula だけにする
    brew trust --formula "$TAP/$FORMULA"

    # ns-inline-patch の取得元と sha256 は emacs-build の build.yml で固定されている
    build_dir="$HOME/emacs-build"
    [ -d "$build_dir/.git" ] || git clone -q https://github.com/kazootkr/emacs-build "$build_dir"
    git -C "$build_dir" fetch -q origin
    git -C "$build_dir" checkout -q "$EMACS_BUILD_COMMIT"
    export HOMEBREW_EMACS_PLUS_BUILD_CONFIG="$build_dir/build.yml"

    brew list --formula "$FORMULA" >/dev/null 2>&1 && brew uninstall "$FORMULA"
    log "$FORMULA をソースからビルドします（30 分以上かかります）"
    # emacs-build の install.sh と同じ手順。ただし最後の「/Applications にエイリアスを作る」は
    # 飛ばす。osascript で Finder を操作し、ゲストにはその権限が無く止まるため
    set +e
    brew install --build-from-source "$FORMULA"
    status=$?
    set -e
    if [ "$status" -ne 0 ]; then
        # post_install（再署名）だけが一過性で失敗することがあり、その場合は keg が入っている
        brew list --versions "$FORMULA" >/dev/null 2>&1 || die "brew install が失敗しました"
        brew postinstall "$FORMULA"
    fi
    [ "$(receipt_value source.tap_git_head)" = "$TAP_COMMIT" ] || die "ビルドした Emacs の tap のコミットがホストと一致しません"
    [ "$(receipt_value source.versions.stable)" = "$EMACS_VERSION" ] || die "ビルドした Emacs の版がホストと一致しません"
fi
EMACS_PREFIX="$(brew --prefix "$FORMULA")"
export PATH="$EMACS_PREFIX/bin:$PATH"

# --- doom（ホストと同じコミット） ---
fetch_ref() { # $1=URL $2=DIR $3=COMMIT
    [ "$(git -C "$2" rev-parse HEAD 2>/dev/null || true)" = "$3" ] && return 0
    [ -d "$2/.git" ] || { git init -q "$2" && git -C "$2" remote add origin "$1"; }
    git -C "$2" fetch -q --depth 1 origin "$3"
    git -C "$2" checkout -q FETCH_HEAD
}
fetch_ref https://github.com/doomemacs/doomemacs "$EMACSDIR" "$DOOM_CORE"
fetch_ref https://github.com/doomemacs/modules "$EMACSDIR/sources/doom+" "$DOOM_MODULES"

# 検証対象の設定は、ホストのリポジトリを共有フォルダ経由で読む（読み取り専用）
if [ "$(readlink "$HOME/.config/doom" 2>/dev/null || true)" != "$REPO" ]; then
    [ -e "$HOME/.config/doom" ] && die "$HOME/.config/doom が既にあります（共有フォルダへのリンクではありません）"
    ln -s "$REPO" "$HOME/.config/doom"
fi

log "doom sync"
LANG=ja_JP.UTF-8 "$EMACSDIR/bin/doom" sync --force
# guest.sh の batch が、init.el・packages.el・doom が変わったときだけ sync するための印
/bin/bash "$REPO/vm/guest.sh" sync-stamp

# emojify の絵文字の画像を、ホストと同じく取得しておく。無いと、絵文字を初めて表示したときに
# 取得の問い合わせ（y/n）が出て、GUI の確認が止まる。展開先は、先に作って末尾に / を付けて
# 渡す。まだ無いフォルダのままだと、展開の処理は「done」と出すのに何も書き出さない
log "emojify の画像"
/bin/bash "$REPO/vm/guest.sh" batch '(progn
  (require (quote emojify))
  (let ((emojify-emojis-dir (file-name-as-directory (expand-file-name emojify-emojis-dir))))
    (make-directory emojify-emojis-dir t)
    (unless (file-exists-p (emojify-image-dir))
      (emojify-download-emoji emojify-emoji-set))
    (unless (file-exists-p (emojify-image-dir))
      (error "emojify の画像を取得できませんでした"))))'

log "provision 完了（空き: $(df -g / | awk 'NR == 2 { print $4 }')GB）"
