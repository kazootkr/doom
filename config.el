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

;; req-4.1〜4.4 (docs/requirements/req-4_ns-inline-patch.org)
;; ns-inline-patch（NS port の IME 連携パッチ）適用ビルド向けの IME 制御。
;; mac-* 関数はパッチ適用ビルドのみが提供するため、未適用ビルド・対象外環境（Linux/docker）では
;; fboundp ガードでブロックごと no-op になる。
(when (and (eq system-type 'darwin) (featurep 'ns)
           (fboundp 'mac-input-method-mode))
  ;; req-4.1: 既定入力ソースを macOS 標準の日本語 IME (Kotoeri) にし、IME 連携を有効化する。
  ;; 基底は英数（IME オフ）。入力ソース ID は macOS バージョンで変わりうるので、実機の
  ;; (mac-ime-input-source-list) で確認し、異なればこの 1 か所を合わせる。
  (when (fboundp 'mac-get-current-input-source)
    (custom-set-variables
     '(mac-default-input-source "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese")))
  (unless noninteractive
    (mac-input-method-mode 1))

  ;; req-4.2: evil ノーマルステートに入ったら IME を自動オフにする（コマンドキーの誤爆防止）。
  (add-hook 'evil-normal-state-entry-hook #'mac-ime-deactivate)

  ;; req-4.4: これらのコマンドに伴う minibuffer 入力では IME を自動オフにしない（日本語入力を許可）。
  ;; isearch 系は minibuffer-setup-hook を経由しないため列挙せず、「オフのフックを足さない」ことで
  ;; 日本語入力可のままにする。
  (defvar +ime-minibuffer-japanese-commands
    '(+default/search-project org-tags-view org-capture org-ctrl-c-ctrl-c)
    "minibuffer 入力で IME を自動オフにしないコマンド。")

  ;; req-4.3: minibuffer 読み取り開始時、例外コマンド以外では IME をオフにする（「M-x あ」対策）。
  (defun +ime/minibuffer-setup ()
    "例外コマンド以外の minibuffer 読み取りで IME をオフにする。"
    (unless (memq this-command +ime-minibuffer-japanese-commands)
      (mac-ime-deactivate)))
  (add-hook 'minibuffer-setup-hook #'+ime/minibuffer-setup)

  ;; fix-1: アプリスイッチ時に IME 状態を他アプリへ引きずらせない（task-4 fix-1）。
  ;; mac-input-method-mode はフォーカス変化・buffer-list-update に IME 状態を同期し、内部で
  ;; mac-toggle-input-source（TISSelectInputSource）を呼んでシステム全体の入力ソースを書き換える。
  ;; Emacs が非フォーカスの間も同期が走り前面アプリの入力ソースを Emacs の状態（英数）に引き戻すため、
  ;; frame-focus-state が真（Emacs が前面）のときだけ入力ソースを変更する。advice は名前付き関数を
  ;; シンボル登録して再評価でも二重登録されないようにする。
  (defun +ime/toggle-input-source-when-focused (orig &rest args)
    "Emacs フレームがフォーカスを持つときだけ ORIG（mac-toggle-input-source）を実行する。"
    (when (frame-focus-state) (apply orig args)))
  (advice-add 'mac-toggle-input-source :around #'+ime/toggle-input-source-when-focused))

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
;; req-3.1 (docs/requirements/req-3_org-notes.org)
;; メモ・日誌・ToDo を置くノート用ルートディレクトリ。journal の保存先・capture の出力先・
;; agenda の対象は、すべてこの 1 つの定義を参照する。実環境に合わせてここを変える。
;; 末尾の "/" は capture の (concat my-dev-notes-dir "Reminder.org") のため必須。
(defvar my-dev-notes-dir "~/dev-home/notes/"
  "メモ・日誌・ToDo を置くノート用ルートディレクトリ。")

;; org-directory を notes ルートに合わせる（org ロード前に設定する必要がある）。
;; これにより :lang (org +journal) は org-journal-dir を {notes}/journal/ に既定設定し、
;; req-3.2 の保存先（notes/journal/）が自動でそろう。
(setq org-directory my-dev-notes-dir)


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

;; req-3.2 (docs/requirements/req-3_org-notes.org)
;; org-journal の書式設定。保存先 org-journal-dir は doom (+journal) が org-directory 配下の
;; "journal/" に設定するため、ここでは書式のみ指定する。
(after! org-journal
  (setq org-journal-file-format "org-journal_%Y-%m-%d.org")
  (setq org-journal-date-prefix "#+TITLE: ")
  (setq org-journal-date-format "%Y/%m/%d (%a)")
  (setq org-journal-time-prefix "* TODO ")
  (setq org-journal-file-header "#+STARTUP: indent\n#+STARTUP: showall\n#+STARTUP: nolineimages\n#+STARTUP: hidestars"))

;; req-3.3 (docs/requirements/req-3_org-notes.org)
;; タグ検索・agenda・TODO 一覧の対象を notes 配下の org 全体にする。
;; notes ルートと全サブディレクトリを列挙（各ディレクトリは agenda 構築時に *.org 再走査）。
;; notes が無い環境では directory-files-recursively がエラーになるためガードして no-op にする。
(when (file-directory-p my-dev-notes-dir)
  (setq org-agenda-files
        (cons (directory-file-name my-dev-notes-dir)
              (seq-filter #'file-directory-p
                          (directory-files-recursively my-dev-notes-dir "" t)))))

;; req-3.4 (docs/requirements/req-3_org-notes.org)
;; org-capture で ToDo を notes/Reminder.org に書き留める。
(after! org-capture
  (setq org-capture-templates
        `(("t" "Todo" entry
           (file+headline ,(concat my-dev-notes-dir "Reminder.org") "■ ToDo")
           "* TODO %? [Created by %t]")
          ("s" "Scheduled Todo" entry
           (file+headline ,(concat my-dev-notes-dir "Reminder.org") "■ Scheduled Todo")
           "* TODO %? # SCHEDULED: %^t"))))

;; req-4.5 (docs/requirements/req-4_ns-inline-patch.org)
;; doom の :ui vc-gutter は Emacs 30 系で diff-hl-update-async を 'thread にする。macOS NS port +
;; Emacs 30 + スレッド非同期更新で diff-hl がフリーズする (dgutov/diff-hl#230) ため、非同期更新を
;; 無効化する。doom が diff-hl の :config で設定するため after! で上書きする（fringe 表示は維持）。
(after! diff-hl
  (setq diff-hl-update-async nil))

;; req-6.3 (docs/requirements/req-6_docset-lookup.org)
;; dash-docs 系コマンドを SPC d 配下に集約（dash-docs / consult-dash は lookup +docsets で導入）。
(map! :leader
      (:prefix ("d" . "dash")
       :desc "Search all docsets"     "d" #'+lookup/in-all-docsets
       :desc "consult-dash"           "f" #'consult-dash
       :desc "Documentation at point" "k" #'+lookup/documentation
       :desc "Install docset"         "i" #'dash-docs-install-docset
       :desc "Activate docset"        "a" #'dash-docs-activate-docset
       :desc "Deactivate docset"      "A" #'dash-docs-deactivate-docset))

;; req-6.2 (docs/requirements/req-6_docset-lookup.org)
;; Ruby バッファで K / +lookup/in-docsets が "Ruby" docset を検索するよう紐付け。
;; docset 名は dash-docs-install-docset で取得した名称に一致させる。
(set-docsets! '(ruby-mode ruby-ts-mode) "Ruby"
  ["ruby_on_rails_guides_ja" (eq major-mode 'ruby-mode)]
  ["Emacs_Lisp" (eq major-mode 'emacs-lisp-mode)])


;; 非アクティブ時に 85% へ落とす(数字を下げるほど目立つ)
(add-to-list 'default-frame-alist '(alpha . (100 . 85)))
;; 既存フレームにも今すぐ適用するなら
(set-frame-parameter nil 'alpha '(100 . 88))
