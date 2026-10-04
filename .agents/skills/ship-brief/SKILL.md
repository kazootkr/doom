---
name: ship-brief
description: brief-<番号>（例: brief-7）を受け取り、受け入れ基準をすべて満たした change brief を出荷する。残すべき事実をコードのコメント・docker/checks.el・docs/macos-checklist.org・docs/decisions/・README.org へ移してから brief を削除する。
disable-model-invocation: true
argument-hint: <出荷する brief 番号(形式: brief-[0-9]+)>
allowed-tools: Read(./**)
---

# ship-brief

brief は変更中だけの文書。出荷では、今後も必要な事実だけを恒久的な置き場所へ移し、brief を削除する。経緯は git 履歴に残る。

## 手順

1. **brief の解決**: 引数は `brief-<番号>` 形式のみ受け付ける（番号単体・ファイル名・パスは不可）。`docs/changes/brief-<番号>_*.org` を読む。
2. **出荷できるかの確認**: 受け入れ基準に `[ ]` が残っていれば一覧を示し、ユーザーが確認済みと答えた項目だけ `[X]` にする。未確認の項目や「決めてほしいこと」の未決が残る場合は中止する。
3. **事実の移し替え**: brief の各記述を次の表で振り分ける。どれにも当てはまらないもの（実装の手順、調査メモ、検討の過程）は捨てる。

   | 残す事実 | 移す先 |
   |---|---|
   | なぜその設定・回避策にしたか | 該当コードのコメント（brief を参照せず単体で読める形）。回避策なら外せる条件も書く |
   | docker で確かめられ、doom の更新等で壊れうる挙動 | `docker/checks.el`（未追加なら追加する） |
   | docker では確かめられない macOS 固有の確認項目 | `docs/macos-checklist.org` の該当分野 |
   | 調べ直すと高くつく判断で、コメントに収まらないもの（採らなかった案を含む） | `docs/decisions/<subject>.org` |
   | 実行環境・ホストでの手順 | `README.org` の「実行環境」 |

4. **参照の除去**: `grep -rn 'brief-<番号>' --exclude-dir=.git .` で brief への参照が残っていないことを確かめる。
5. **削除と検証**: `git rm` で brief を削除し、`./docker/run.sh batch` が通ることを確かめる。
6. **報告**: 各事実の移し先と、捨てたものの要約を伝える。

## 移し先の書式

`docs/macos-checklist.org` は状態を持たない確認手順なので、チェックボックスではなく箇条書きで書く（確認のたびに付け外ししない）。

`docs/decisions/<subject>.org`:

```org
#+title: <subject>
#+STARTUP: indent
#+STARTUP: showall
#+STARTUP: nolineimages
#+STARTUP: hidestars

* 決定

* 理由

* 採らなかった案
```
