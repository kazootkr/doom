;;; vm/checks-gui.el --- GUI の Emacs の中で走るチェック -*- lexical-binding: t; -*-
;;
;; ./vm/run.sh gui-checks が、ゲストで GUI の Emacs を起動してこのファイルを読み、
;; (checks-gui-run FILE) で全テストを実行して結果を FILE に書く。
;; batch では確かめられないもの（実際に描画に使われるフォント、画面の倍率、map! によるキー割当）が
;; 対象。目で見ないと判定できないもの（豆腐・合字・アンチエイリアス）は対象外。

(require 'ert)

(defun checks-gui--font-family-at (text)
  "TEXT を表示して、その 1 文字目を描画するフォントのファミリー名を返す。"
  (let ((buf (get-buffer-create " *checks-gui*")))
    (switch-to-buffer buf)
    (erase-buffer)
    (insert text)
    (redisplay t)
    (let ((font (font-at (point-min) (selected-window))))
      (and font (format "%s" (font-get font :family))))))

(ert-deftest checks-gui/screen-scale ()
  "内蔵 Retina と同じ見かけの大きさ・2 倍描画になっている。"
  ;; VM の倍率は起動時のホストの主画面で決まるため、外部モニターが主画面だとずれる
  (should (= (display-pixel-width) 1710))
  (should (= (frame-scale-factor) 2.0)))

(ert-deftest checks-gui/japanese-font ()
  "ASCII もかな・漢字も、主フォントの UDEV Gothic LG で描画される。"
  ;; 日本語フォントを明示しないと、CJK 統合により中国語字形のフォントで描画されたり豆腐になる
  (dolist (char '("a" "あ" "漢"))
    (should (equal (cons char (checks-gui--font-family-at char)) (cons char "UDEV Gothic LG")))))

(ert-deftest checks-gui/fullwidth-is-two-columns ()
  "全角 1 文字の幅が、半角 2 文字分になる（org テーブルの罫線が縦にそろう）。"
  (let ((half (string-pixel-width "a")))
    (dolist (char '("あ" "ア" "漢" "「"))
      (should (equal (cons char (string-pixel-width char)) (cons char (* 2 half)))))))

(ert-deftest checks-gui/variable-pitch-japanese ()
  "可変ピッチの地の文では、日本語も英字と同じ Hiragino Kaku Gothic ProN で、同じ大きさで描画される。"
  (let ((buf (get-buffer-create " *checks-gui*")))
    (switch-to-buffer buf)
    (erase-buffer)
    (insert (propertize "あ" 'face 'variable-pitch))
    (redisplay t)
    (should (equal (format "%s" (font-get (font-at (point-min) (selected-window)) :family))
                   "Hiragino Kaku Gothic ProN")))
  (should (= (string-pixel-width (propertize "あ" 'face 'variable-pitch))
             (font-get doom-variable-pitch-font :size))))

(ert-deftest checks-gui/emoji-font ()
  "絵文字がカラー絵文字のフォントで描画される。"
  (should (string-match-p "Apple Color Emoji" (checks-gui--font-family-at "😀"))))

(ert-deftest checks-gui/no-unicode-fonts-error ()
  "起動時に unicode-fonts の void-variable エラーが出ていない（キャッシュの破損で出る）。
失敗したら、unicode-fonts のキャッシュを削除して起動し直す。"
  (with-current-buffer "*Messages*"
    (should-not (string-match-p "void-variable" (buffer-string)))))

(ert-deftest checks-gui/leader-dash-keys ()
  "docset の操作が SPC d 配下に割り当てられている。"
  (dolist (binding '(("d" . +lookup/in-all-docsets)
                     ("f" . consult-dash)
                     ("k" . +lookup/documentation)
                     ("i" . dash-docs-install-docset)
                     ("a" . dash-docs-activate-docset)
                     ("A" . dash-docs-deactivate-docset)))
    (should (equal (cons (car binding) (lookup-key doom-leader-map (kbd (concat "d " (car binding)))))
                   binding))))

(defun checks-gui-run (file)
  "全テストを実行し、結果を FILE に書く。"
  (let ((lines (list (format "=== gui-checks (Emacs %s, %s) ===" emacs-version window-system)))
        (stats (ert-run-tests "^checks-gui/" #'ignore)))
    (dolist (test (ert-select-tests "^checks-gui/" t))
      (let ((result (ert-test-most-recent-result test)))
        (push (format "%-5s %s" (cond ((ert-test-passed-p result) "ok")
                                      ((ert-test-skipped-p result) "skip")
                                      (t "FAIL"))
                      (ert-test-name test))
              lines)
        (when (ert-test-failed-p result)
          (push (format "      %S" (ert-test-result-with-condition-condition result)) lines))))
    (push (format "=== %d passed, %d failed, %d skipped ==="
                  (ert-stats-completed-expected stats)
                  (ert-stats-completed-unexpected stats)
                  (ert-stats-skipped stats))
          lines)
    (with-temp-file file
      (insert (string-join (nreverse lines) "\n") "\n"))
    t))

;;; checks-gui.el ends here
