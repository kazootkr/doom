---
name: git-commit
description: このリポジトリの差分ファイルすべて（未ステージ・未追跡を含む）を Conventional Commits の subject 1行（本文・フッターなし）でコミットする。spec 駆動開発の各ステップ（要求の作成・タスク化・実装）が完了した直後のコミットでは必ずこのスキルを使うこと。ユーザーが「コミットして」「commit して」と依頼したときもこのスキルを使う。ステージ済みの変更だけを対象にしたい場合のみユーザーグローバルの git-commit-staged スキルを使い分ける。
allowed-tools: Bash(git add:*) Bash(git commit:*) Bash(git status:*)
---

# git-commit

リポジトリの差分をすべてステージし、Conventional Commits 形式の subject 1行で
コミットする。

このリポジトリは spec 駆動開発の **1ステップ毎にコミットする運用**:

1. 要求の作成（/create-requirement）→ コミット
2. タスク化（/create-task）→ コミット
3. 実装（/sync-implementation）→ コミット

## ルール

- **対象は差分ファイルのすべて** — 未ステージ・未追跡も含めて `git add -A` でステージする
- **メッセージは subject 1行のみ** — `<type>(<scope>): <説明>` の形式。
  本文・フッター（Co-Authored-By 等）は付けないこと
- type / scope は英語、説明は日本語で「何を・なぜ」が伝わる一文にする
- 1コミット = 1ステップ。差分に複数ステップの成果（例: 要求とタスクの両方）が
  混在している場合は、ステップ単位に `git add` を分けて順にコミットする

## 手順

1. `git status --short` と `git diff` / `git diff --stat` で差分の全体像を把握する
2. 差分がどのステップ（要求 / タスク / 実装、またはそれ以外）の成果かを判定する
3. `git add -A`（複数ステップ混在時はステップ単位で `git add <paths>`）
4. subject 1行でコミットする:

   ```sh
   git commit -m "<type>(<scope>): <説明>"
   ```

5. コミットハッシュと subject を報告する。複数コミットに分けた場合はその一覧を示す

## type / scope の目安

| ステップ・変更内容 | 例 |
|---|---|
| 1. 要求の作成 | `docs(req): req-3 xxx の要求を追加` |
| 2. タスク化 | `docs(task): task-3 xxx のタスクを追加` |
| 3. 実装（機能追加） | `feat(ime): フォーカスガードを追加` |
| 3. 実装（不具合修正） | `fix(ime): バックグラウンドスレッドからのクラッシュを修正` |
| init.el / packages.el のモジュール・パッケージ変更 | `feat(modules): vterm と yaml を有効化` |
| docker 検証環境 | `chore(docker): 検証イメージを doom ベースに変更` |
| スキル・CLAUDE.md の整備 | `docs(claude): spec 駆動 3 ステップの記載を更新` |

完了条件のチェックボックス更新だけの差分も実装ステップの一部としてよい
（例: `docs(task): task-2 の完了条件を更新`）。
