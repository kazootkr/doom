---
name: git-commit
description: このリポジトリの差分ファイルすべて（未ステージ・未追跡を含む）を Conventional Commits の subject 1行（本文・フッターなし）でコミットする。変更の各ステップ（brief の作成・実装・出荷、小リスクの直接実装）が完了した直後のコミットでは必ずこのスキルを使うこと。ユーザーが「コミットして」「commit して」と依頼したときもこのスキルを使う。ステージ済みの変更だけを対象にしたい場合のみユーザーグローバルの git-commit-staged スキルを使い分ける。
allowed-tools: Bash(git add:*) Bash(git commit:*) Bash(git status:*)
---

# git-commit

リポジトリの差分をすべてステージし、Conventional Commits 形式の subject 1行で
コミットする。

このリポジトリは **1ステップ毎にコミットする運用**（CLAUDE.md のリスク段階）:

- 小: 直接実装 → コミット
- 中・高:
  1. brief の作成（/create-brief）→ コミット
  2. 実装（/implement-brief）→ コミット
  3. 出荷（/ship-brief）→ コミット

## ルール

- **対象は差分ファイルのすべて** — 未ステージ・未追跡も含めて `git add -A` でステージする
- **メッセージは subject 1行のみ** — `<type>(<scope>): <説明>` の形式。
  本文・フッター（Co-Authored-By 等）は付けないこと
- type / scope は英語、説明は日本語で「何を・なぜ」が伝わる一文にする
- 1コミット = 1ステップ。差分に複数ステップの成果（例: brief の作成と実装の両方）が
  混在している場合は、ステップ単位に `git add` を分けて順にコミットする

## 手順

1. `git status --short` と `git diff` / `git diff --stat` で差分の全体像を把握する
2. 差分がどのステップ（brief の作成 / 実装 / 出荷、またはそれ以外）の成果かを判定する
3. `git add -A`（複数ステップ混在時はステップ単位で `git add <paths>`）
4. subject 1行でコミットする:

   ```sh
   git commit -m "<type>(<scope>): <説明>"
   ```

5. コミットハッシュと subject を報告する。複数コミットに分けた場合はその一覧を示す

## type / scope の目安

| ステップ・変更内容 | 例 |
|---|---|
| 1. brief の作成 | `docs(brief): brief-7 xxx の brief を追加` |
| 2. 実装（機能追加） | `feat(ime): フォーカスガードを追加` |
| 2. 実装（不具合修正） | `fix(ime): バックグラウンドスレッドからのクラッシュを修正` |
| 3. 出荷 | `docs(brief): brief-7 xxx を出荷し brief を削除` |
| 小リスクの直接実装 | `feat(ui): 非アクティブフレームを半透明にする` |
| init.el / packages.el のモジュール・パッケージ変更 | `feat(modules): vterm と yaml を有効化` |
| docker 検証環境・チェック | `test(docker): xxx の回帰チェックを追加` / `chore(docker): 検証イメージを更新` |
| スキル・CLAUDE.md の整備 | `docs(claude): リスク段階の目安を更新` |

受け入れ基準のチェックボックス更新だけの差分も実装ステップの一部としてよい
（例: `docs(brief): brief-7 の受け入れ基準を更新`）。
