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
(setq doom-theme 'doom-solarized-light)

(setq doom-font (font-spec :family "JetBrains Mono" :size 15))

;; 漢字・かな・全角記号を Hiragino Sans で表示する。
;; 指定しないと漢字や句読点に中国語フォント（PingFang SC など）が選ばれる。
(add-hook! 'after-setting-font-hook
  (defun my-set-japanese-font-h ()
    (dolist (script '(han kana cjk-misc))
      (set-fontset-font t script (font-spec :family "Hiragino Sans")))))
;; 全角1文字の幅を半角2文字分にそろえる（org の表などの桁ずれ防止）。
;; JetBrains Mono の半角幅は文字サイズの 0.6 倍なので、全角を 1.2 倍にする。
(setq face-font-rescale-alist '(("Hiragino Sans" . 1.2)))
;; 1.2 倍の Hiragino Sans は英字より背が高く、そのままだと日本語を含む行だけ高くなる。
;; すべての行の最低の高さを、既定の行の高さ（20px）の 1.15 倍 = 日本語の行の高さ（23px）にそろえる。
;; そのぶん行間を 0.2（4px）から 1px に減らし、1行の高さは以前の英字の行と同じ 24px に保つ。
(setq-default default-text-properties '(line-height 1.15)
              line-spacing 1)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

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


(defvar my-dev-notes-dir "~/dev-home/notes/"
  "メモ・日誌・ToDo を置くノート用ルートディレクトリ。")

;; org-directory を notes ルートに合わせる（org ロード前に設定する必要がある）。
;; これにより :lang (org +journal) は org-journal-dir を {notes}/journal/ に既定設定し、
;; 日誌の保存先（notes/journal/）が自動でそろう。
(setq org-directory my-dev-notes-dir)

;; org-journal の書式設定。保存先 org-journal-dir は doom (+journal) が org-directory 配下の
;; "journal/" に設定するため、ここでは書式のみ指定する。
(after! org-journal
  (setq org-journal-file-type 'monthly)
  (setq org-journal-file-format "org-journal_%Y-%m-%d.org")
  (setq org-journal-date-prefix "* ")
  (setq org-journal-date-format "%m/%d (%a)")
  (setq org-journal-time-prefix "** TODO ")
  (setq org-journal-time-format "%H:%M")
  (setq org-journal-file-header "#+STARTUP: indent\n#+STARTUP: showall\n#+STARTUP: nolineimages\n#+STARTUP: hidestars"))

;; タグ検索・agenda・TODO 一覧の対象を notes 配下の org 全体にする。doom 既定の
;; (list org-directory) はサブディレクトリを辿らないため、明示的に列挙する。
;; notes ルートと全サブディレクトリを列挙（各ディレクトリは agenda 構築時に *.org 再走査）。
;; notes が無い環境では directory-files-recursively がエラーになるためガードして no-op にする。
(when (file-directory-p my-dev-notes-dir)
  (setq org-agenda-files
        (cons (directory-file-name my-dev-notes-dir)
              (seq-filter #'file-directory-p
                          (directory-files-recursively my-dev-notes-dir "" t)))))

;; org-capture で ToDo を notes/Reminder.org に書き留める（doom 既定のテンプレートを差し替える）。
(after! org-capture
  (setq org-capture-templates
        `(("t" "Todo" entry
           (file+headline ,(concat my-dev-notes-dir "Reminder.org") "■ ToDo")
           "* TODO %? [Created by %t]")
          ("s" "Scheduled Todo" entry
           (file+headline ,(concat my-dev-notes-dir "Reminder.org") "■ Scheduled Todo")
           "* TODO %?\nSCHEDULED: %^t"))))

;; TODO 状態を実際に使う 5 つに絞る。doom の :lang org が :config で org-todo-keywords に
;; 16 状態（3 本の sequence）を設定するため、after! でその後に適用して上書きする。
;; 既存ノートで使用中の TODO / DONE / STRT は必ず残す（外すと既存見出しが素のテキストに落ちる）。
(after! org
  (setq org-todo-keywords
        '((sequence "TODO(t)" "STRT(s)" "WAIT(w)" "|" "DONE(d)" "KILL(k)"))))
