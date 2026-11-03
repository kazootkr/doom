;;; vm/checks.el --- macOS VM の標準チェック -*- lexical-binding: t; -*-
;;
;; ./vm/run.sh batch（ELISP 省略時）が、ゲストの Emacs（ホストと同じ emacs-plus + ns-inline-patch）で
;; doom をロードした後にこのファイルを読み、全テストを実行する。失敗があれば終了コード 1 で終わる。
;;
;; 対象は doom の既定値やロード順の変化で壊れうる設定に限る（after! による上書き、darwin/NS ガード
;; 内の登録など）。設定値を写すだけで回帰の検出にならないものは足さない。
;; batch では message が doom の CLI バッファに吸われるため、結果は princ で出力する。
;; doom の map! は noninteractive では何もしないため、キー割当は ./vm/run.sh gui-checks で確かめる。

(require 'ert)

(defconst checks--doomdir
  (file-name-directory (directory-file-name (file-name-directory load-file-name)))
  "検証対象の DOOMDIR。")

(defun checks--macos-ns-p ()
  "ns-inline-patch 適用ビルドの macOS（NS port）なら真。"
  (and (eq system-type 'darwin) (featurep 'ns) (fboundp 'mac-input-method-mode)))

(ert-deftest checks/config-files-balanced ()
  "設定ファイルの括弧が閉じている。"
  (dolist (file '("init.el" "config.el" "packages.el"))
    (with-temp-buffer
      (insert-file-contents (expand-file-name file checks--doomdir))
      (emacs-lisp-mode)
      (should (equal (list file (condition-case err (progn (check-parens) 'ok)
                                  (error (error-message-string err))))
                     (list file 'ok))))))

(ert-deftest checks/dired-overrides-doom-defaults ()
  "doom の dired モジュールが設定する値を after! で上書きできている。"
  (require 'dired)
  (should (equal dired-listing-switches "-AFlh"))
  (should (eq dired-dwim-target t))
  (should (eq dired-recursive-copies 'always))
  (should (eq dired-isearch-filenames t)))

(ert-deftest checks/org-todo-keywords ()
  "doom 既定（16 状態）ではなく 5 状態だけになっている。"
  (require 'org)
  (should (equal org-todo-keywords
                 '((sequence "TODO(t)" "STRT(s)" "WAIT(w)" "|" "DONE(d)" "KILL(k)")))))

(ert-deftest checks/org-notes-paths ()
  "日誌・capture の出力先がノート用ルート配下にそろっている。"
  (require 'org-journal)
  (require 'org-capture)
  (let ((notes (file-name-as-directory (expand-file-name my-dev-notes-dir))))
    (should (equal (file-name-as-directory (expand-file-name org-directory)) notes))
    ;; doom (+journal) が org-directory 配下の journal/ に設定する
    (should (equal (file-name-as-directory (expand-file-name org-journal-dir))
                   (expand-file-name "journal/" notes)))
    (should (equal (mapcar #'car org-capture-templates) '("t" "s")))
    (dolist (template org-capture-templates)
      (should (equal (expand-file-name (nth 1 (nth 3 template)))
                     (expand-file-name "Reminder.org" notes))))))

(ert-deftest checks/diff-hl-sync-update ()
  "doom の vc-gutter が有効にするスレッド非同期更新を無効化できている。"
  (require 'diff-hl)
  (should-not diff-hl-update-async))

(ert-deftest checks/region-background-distinct ()
  "テーマのロード後も、選択範囲の背景が地・現在行・org の src ブロックと異なる色になっている。"
  ;; batch ではテーマ自体の face が GUI 向けの表示条件で当たらず、条件なしの custom-set-faces! の
  ;; 上書きだけが値を持つ。そのため地・現在行の色はテーマのパレットから引いて比べる
  (load-theme doom-theme t)
  (require 'org)
  (let ((region (face-background 'region nil t)))
    (should region)
    (should-not (member region (list (doom-color 'bg) (doom-color 'bg-alt) (doom-color 'base0)
                                     (face-background 'org-block nil t))))))

;;; macOS（NS port + ns-inline-patch）でだけ評価される設定（darwin/NS ガードの中）

(ert-deftest checks/macos-variable-pitch-hiragino ()
  "可変ピッチのフォントが Hiragino のまま、doom に上書きされていない。"
  (skip-unless (checks--macos-ns-p))
  ;; font-get はファミリー名をシンボルで返す
  (should (equal (format "%s" (font-get doom-variable-pitch-font :family))
                 "Hiragino Kaku Gothic ProN")))

(ert-deftest checks/macos-japanese-font-reapplied ()
  "フォントの再設定のたびに、日本語フォントの割り当てをやり直す。"
  ;; unicode-fonts（:ui unicode）が fontset を上書きするため、after-setting-font-hook で再適用する
  (skip-unless (checks--macos-ns-p))
  (should (memq #'+appearance/set-japanese-font after-setting-font-hook)))

(ert-deftest checks/macos-ime-default-input-source ()
  "既定の入力ソースがことえりのローマ字入力（日本語）になっている。"
  (skip-unless (checks--macos-ns-p))
  (should (equal mac-default-input-source
                 "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese")))

(ert-deftest checks/macos-ime-mode-gui-only ()
  "batch では IME 連携を有効にしない（入力ソースに触らない）。
ノーマルステート・ミニバッファの IME は evil とパッチの仕組みに任せ、./vm/run.sh ime で確かめる。"
  (skip-unless (checks--macos-ns-p))
  (should-not (bound-and-true-p mac-input-method-mode)))

(ert-deftest checks/macos-ime-toggle-advice ()
  "入力ソースの切り替えが、Emacs が前面のときだけに限られている。"
  (skip-unless (checks--macos-ns-p))
  (should (advice-member-p #'+ime/toggle-input-source-when-focused 'mac-toggle-input-source)))

(defun checks--run ()
  "全テストを実行し、結果を princ で出力して終了する。"
  (princ (format "=== checks (Emacs %s, doom %s, %s%s) ===\n" emacs-version doom-version
                 system-type (if (featurep 'ns) " ns" "")))
  (let ((stats (ert-run-tests
                t
                (lambda (event &rest args)
                  (when (eq event 'test-ended)
                    (let ((test (nth 1 args))
                          (result (nth 2 args)))
                      (princ (format "%-5s %s\n"
                                     (cond ((ert-test-passed-p result) "ok")
                                           ((ert-test-skipped-p result) "skip")
                                           (t "FAIL"))
                                     (ert-test-name test)))
                      (when (ert-test-failed-p result)
                        (princ (format "      %S\n"
                                       (ert-test-result-with-condition-condition result))))))))))
    (princ (format "=== %d passed, %d failed, %d skipped ===\n"
                   (ert-stats-completed-expected stats)
                   (ert-stats-completed-unexpected stats)
                   (ert-stats-skipped stats)))
    (kill-emacs (if (zerop (ert-stats-completed-unexpected stats)) 0 1))))

(checks--run)

;;; checks.el ends here
