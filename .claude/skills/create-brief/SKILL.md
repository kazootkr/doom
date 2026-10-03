---
name: create-brief
description: ユーザーのプロンプトから変更のリスク段階を判定し、中・高リスクなら docs/changes/ に brief-<番号>_<subject>.org（change brief）を作成する。小リスクなら brief を作らず直接実装を提案する。引数で brief-<番号>（例: brief-7）が渡されたら新規作成せず、その進行中の brief に追記する。
disable-model-invocation: true
argument-hint: [<brief番号(形式: brief-[0-9]+)(optional)>] <自由記述...>
allowed-tools: Read(~/.config/emacs/**) Read(./**)
---

# create-brief

ユーザーの要望を、次の変更の差分だけを書く使い捨ての change brief（`docs/changes/` 下の org）にする。成果物は brief 1 つのみで、**実装コードは変更しない**（実装は `/implement-brief`）。brief は出荷時に `/ship-brief` で削除されるため、恒久的に必要な事実はコードと `docker/checks.el` に置かれる前提で書く。

## リスク判定

CLAUDE.md の「リスク段階」で判定する。迷ったら 1 段上にする。

- **小** → brief を作らない。判定理由を示し、直接実装してよいかをユーザーに確認して終了する。
- **中・高** → 以下の手順で brief を作る。

## モード判定

引数の先頭が `brief-<番号>` 形式のときだけ既存 brief の指定とみなす（番号単体・ファイル名・パスは受け付けない）。

- `docs/changes/brief-<N>_*.org` が存在する → **追記モード**
- 指定なし → **新規作成モード**
- 指定があるがファイルが無い（出荷済み等）→ `ls docs/changes` を示して確認する

## 手順

1. **調査**: 影響範囲（init.el のモジュール/フラグ、config.el の該当ブロック、packages.el）をリポジトリで確認する。相当する doom モジュールが無いかも確認する（doom-first）。ユーザーが求めていないことを意図に足さない。
2. **作成／追記**:
   - 新規: 採番して `docs/changes/brief-<N>_<subject>.org` をテンプレートで作る。
   - 追記: 既存の見出しに追加分だけ足す。動作確認で見つかった不具合や追加の要望もここに入れる。`[X]` の受け入れ基準のうち、今回の変更で挙動が変わるものは `[ ]` に戻す。
3. **報告**: ファイルへのリンク、リスク段階、「決めてほしいこと」があればその一覧を伝える。実装はユーザーの指示を待つ。

## 採番

出荷で削除された番号も再利用しないよう、git 履歴を含めた最大番号 + 1 にする（旧 `req-<N>` も数える）。

```sh
{ ls docs/changes 2>/dev/null; git log --all --name-only --format= -- docs/changes docs/requirements; } \
  | grep -oE '(brief|req)-[0-9]+_' | grep -oE '[0-9]+' | sort -n | tail -1
```

subject は主題を表す短いケバブケース英語（例: `org-todo-keywords`）。日本語・スペースは使わない。

## テンプレート

`#+title` はファイル名から拡張子を除いたものと一致させる。

```org
#+title: brief-<番号>_<subject>
#+STARTUP: indent
#+STARTUP: showall
#+STARTUP: nolineimages
#+STARTUP: hidestars

リスク: <中|高> — <判定理由を 1 行>

* 意図と非目標

<この変更で満たすべき状態を数行で>

やらないこと:

- <非目標>

* 決めてほしいこと

- <人の判断が要る未知点。選択肢と推奨を添える。決まったら決定事項だけを断定形で残す。無ければ「なし」>

* 影響範囲

- <init.el の =:category module=、config.el の =after! xxx= ブロック等。行番号は書かない>
- <=doom sync= の要否>

* 現状と異なる制約

- <今回新たに課す制約だけ: darwin/NS ガード、遅延ロード（=after!=）、対象外環境での no-op 等>

* 受け入れ基準

- [ ] docker: <docker/checks.el のテストや batch で確認すること>
- [ ] macOS: <実機でユーザーが確認すること>
- [ ] <既存動作が退行しないこと>
```

## 書き方

- 書くのは現状との差分だけ。実装コード・行番号・コードを読めば分かる現状説明・検討の経緯は書かない（決定事項だけを断定形で書く）。
- ユーザーが確定コードを指定した場合だけ、`* 影響範囲` の後に `* 指定コード` を置いて載せる。
- 高リスクでは、調査で分かった選択肢を「決めてほしいこと」に挙げ、合意を得てから実装に進む。
- 受け入れ基準は `docker:` / `macOS:` を明示する。docker で確かめられるものは checks.el のテストにできる粒度で書く。
- Emacs のシンボルやコードは org の verbatim（=symbol=）で囲む。
