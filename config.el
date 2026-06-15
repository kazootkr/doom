;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
;; req-1.4 (docs/requirements/req-1_appearance.org)
(setq doom-theme 'doom-solarized-dark-high-contrast)

;; req-1.1: 主フォントは JetBrains Mono・サイズ 15、行の高さを約 1.2 倍にする
(setq doom-font (font-spec :family "JetBrains Mono" :size 15))
(setq-default line-spacing 0.2)

;; req-1.3: 地の文の可変ピッチフォント。日本語が崩れないよう Hiragino を使う
(setq doom-variable-pitch-font (font-spec :family "Hiragino Kaku Gothic ProN" :size 15))

;; macOS（NS port）固有の外観設定。Linux など対象外環境ではブロックごと no-op。
(when (and (eq system-type 'darwin) (featurep 'ns))
  ;; req-1.2: 文字を anti-aliasing 表示する
  (setq ns-antialias-text t)

  ;; req-1.3: default フォントセットに Hiragino 系の日本語フォントを割り当てる。
  ;; after-setting-font-hook の後段で再適用することで、:ui unicode (unicode-fonts)
  ;; による上書きに勝ち、日本語の中華フォント化・豆腐化を防ぐ。
  (defun +appearance/set-japanese-font ()
    "default フォントセットに Hiragino 系の日本語フォントを割り当てる。"
    (dolist (charset '(japanese-jisx0208 katakana-jisx0201 cp932))
      (set-fontset-font t charset (font-spec :family "Hiragino Sans")))
    ;; かな・約物（U+3000–30FF）と漢字（U+4E00–9FFF）
    (set-fontset-font t '(#x3000 . #x30ff) (font-spec :family "Hiragino Sans"))
    (set-fontset-font t '(#x4e00 . #x9fff) (font-spec :family "Hiragino Sans")))
  (add-hook 'after-setting-font-hook #'+appearance/set-japanese-font)
  (+appearance/set-japanese-font)

  ;; req-1.3: 全角日本語の表示幅を半角英数の整数倍（2 倍）にそろえる。
  ;; 係数は org テーブルの罫線が縦にそろうまで macOS 実機で調整する。
  (add-to-list 'face-font-rescale-alist '(".*Hiragino.*" . 1.0)))

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `with-eval-after-load' block, otherwise Doom's defaults may override your
;; settings. E.g.
;;
;;   (with-eval-after-load 'PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look them up).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.

;; req-2.1 (docs/requirements/req-2_dired.org)
;; dired は遅延ロードされ、doom の :config が dired-listing-switches を上書きするため、
;; after! でモジュール設定の後に適用して要求値を確実に効かせる。
(after! dired
  (setq dired-dwim-target t)
  (setq dired-recursive-copies 'always)
  (setq dired-isearch-filenames t)
  (setq dired-listing-switches "-AFlh"))
