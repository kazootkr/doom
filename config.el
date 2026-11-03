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
(setq doom-theme 'doom-one)

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


;;; macOS の日本語入力（ns-inline-patch）
;; mac-* の関数はパッチを当てた NS 版 Emacs にだけある（--batch でも定義されている）
(when (and (featurep 'ns) (fboundp 'mac-input-method-mode))
  ;; IME オンで切り替える入力ソース（自動検出に失敗したとき用に明示する）
  (setq mac-default-input-source "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese")

  ;; 入力ソースの切り替えは Emacs が前面のときだけにする。パッチは、別アプリで入力ソースを変えたとき
  ;; （OS の通知。Emacs が前面でなくても届く）、フォーカスを失ったとき、バッファ一覧が変わったときにも
  ;; 切り替えうるので、そのままだと前面の別アプリの入力ソースが変わる。
  ;; 起動直後（まだフォーカスを得ていない間）も止まる。そのときの状態は、Emacs が前面になって
  ;; フォーカスを得たときに、パッチが合わせ直す
  (defun +ime/toggle-input-source-when-focused (fn &rest args)
    "Emacs のフレームがフォーカスを得ていると分かっているときだけ FN（`mac-toggle-input-source'）を呼ぶ。
起動直後の、まだフォーカスを得ていない間も呼ばない。"
    (when (eq (frame-focus-state) t)
      (apply fn args)))
  (advice-add 'mac-toggle-input-source :around #'+ime/toggle-input-source-when-focused)

  ;; インサートに入ると、そのバッファで抜けたときの IME の状態に戻す（evil がバッファごとに覚える）。
  ;; evil は、ノーマルなどで IME がオンにされると（かな キー、別アプリから戻ったときの合わせ直し）、
  ;; 覚えている状態を「日本語」に書き換えてからオフにする。その書き換えだけを元に戻す
  (defun +ime/keep-insert-record (fn)
    "ノーマルなどのステートでは、evil がインサート用の記録（`evil-input-method'）を書き換えないようにする。"
    (if (and (bound-and-true-p evil-local-mode) evil-state
             (not (evil-state-property evil-state :input-method)))
        (let ((saved evil-input-method))
          (unwind-protect (funcall fn)
            (setq evil-input-method saved)))
      (funcall fn)))
  (advice-add 'evil-activate-input-method :around #'+ime/keep-insert-record)

  ;; 入力ソースに触る処理（モードの有効化）は GUI のときだけ。batch・-nw では有効にしない。
  ;; パッチの C 関数は入力ソース API の戻り値を確かめないので、GUI のログインセッションが
  ;; ない環境で動くと落ちるおそれがある
  (when (display-graphic-p)
    (mac-input-method-mode 1)))
