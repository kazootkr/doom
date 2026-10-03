;;; docker/checks.el --- docker 検証環境の標準チェック -*- lexical-binding: t; -*-
;;
;; ./docker/run.sh batch（ELISP 省略時）が doom のロード後にこのファイルを読み、全テストを
;; 実行する。失敗があれば終了コード 1 で終わる。
;;
;; 対象は doom の既定値やロード順の変化で壊れうる設定に限る（after! による上書き、ガードに
;; よる no-op など）。設定値を写すだけで回帰の検出にならないものは足さない。
;; batch では message が doom の CLI バッファに吸われるため、結果は princ で出力する。
;; doom の map! は noninteractive では何もしないため、キー割当はここでは確かめられない
;; （./docker/run.sh screenshot の GUI 起動で確認する）。

(require 'ert)

(defconst checks--doomdir
  (file-name-directory (directory-file-name (file-name-directory load-file-name)))
  "検証対象の DOOMDIR。")

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

(ert-deftest checks/macos-settings-noop-elsewhere ()
  "darwin/NS ガード内の設定が対象外環境では評価されない。"
  (skip-unless (not (and (eq system-type 'darwin) (featurep 'ns))))
  ;; Hiragino の指定がガード外に出ると、Linux の GUI 起動がフォント不在で止まる
  (should-not doom-variable-pitch-font)
  (should-not (fboundp '+appearance/set-japanese-font))
  (should-not (fboundp '+ime/minibuffer-setup))
  (should-not (fboundp '+ime/toggle-input-source-when-focused)))

(defun checks--run ()
  "全テストを実行し、結果を princ で出力して終了する。"
  (princ (format "=== checks (Emacs %s, doom %s) ===\n" emacs-version doom-version))
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
