# doom 設定検証用イメージ
# Debian trixie の Emacs 30.1（ホストは 30.2。arm64 ネイティブで動かすため
# amd64 のみ提供の silex/emacs ではなく Debian 公式パッケージを使う）
FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        emacs \
        git \
        ripgrep \
        fd-find \
        xvfb \
        imagemagick \
        x11-utils \
        fontconfig \
        fonts-noto-cjk \
        fonts-jetbrains-mono \
        locales \
        ca-certificates \
        curl \
        xz-utils \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/bin/fdfind /usr/local/bin/fd

# 日本語ロケール
RUN sed -i 's/^# *\(ja_JP.UTF-8\)/\1/' /etc/locale.gen && locale-gen
ENV LANG=ja_JP.UTF-8 \
    LC_ALL=ja_JP.UTF-8 \
    TERM=xterm-256color \
    DISPLAY=:99

# Symbols Nerd Font Mono（nerd-icons / doom-modeline のアイコン描画用）
RUN mkdir -p /usr/local/share/fonts/nerd \
    && curl -fsSL -o /tmp/nfm.tar.xz \
        https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.tar.xz \
    && tar -xJf /tmp/nfm.tar.xz -C /usr/local/share/fonts/nerd \
    && rm /tmp/nfm.tar.xz \
    && fc-cache -f

# doomemacs 本体とモジュール群（v3 構成ではモジュールが別リポジトリで、
# sources/doom+ に配置される）。検証対象の設定（このリポジトリ）はランタイムに
# DOOMDIR としてマウントし、パッケージ類（.local）は named volume に置く
ENV EMACSDIR=/root/.config/emacs \
    DOOMDIR=/workspace/doom \
    PATH=/root/.config/emacs/bin:$PATH
RUN git clone --depth 1 https://github.com/doomemacs/doomemacs "$EMACSDIR" \
    && git clone --depth 1 https://github.com/doomemacs/modules "$EMACSDIR/sources/doom+"

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["batch"]
