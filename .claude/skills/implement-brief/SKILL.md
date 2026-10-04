---
name: implement-brief
description: brief-<番号>（例: brief-7）を受け取り、その change brief を実装する（実装・docker/checks.el へのテスト追加・docker 検証・受け入れ基準のチェック更新）。
disable-model-invocation: true
argument-hint: <実装する brief 番号(形式: brief-[0-9]+)>
allowed-tools: Read(./**) Read(~/.config/emacs/**)
---

# implement-brief

指定された brief の「意図」と「受け入れ基準」を満たすよう実装する。brief には実装方法を書かないので、コードと doom のモジュールを読んで決める。brief の範囲外の改善は実装せず報告にとどめる。

## 手順

1. **brief の解決**: 引数は `brief-<番号>` 形式のみ受け付ける（番号単体・ファイル名・パスは不可）。`docs/changes/brief-<番号>_*.org` を読む。無ければ `ls docs/changes` を示して確認する。
2. **未決事項の確認**: 「決めてほしいこと」に未決の項目があれば実装せず、選択肢を示してユーザーに判断を求める。
3. **設計**: 影響範囲のコードを読み、doom-first で実装方法を決める（AGENTS.md の実装方針）。部分的に実装済みなら未実装分だけ実装する。
4. **実装**: config.el / init.el / packages.el を編集する。
   - コメントには「なぜそうしたか」を、brief を見なくても分かる形で書く。brief は出荷時に消えるので brief 番号やパスを参照しない。
   - 再評価しても同じ状態になるように書く（advice は名前付き関数をシンボルで登録する等）。
5. **チェックの追加**: docker で確かめられる受け入れ基準のうち、doom の既定値やロード順の変化で壊れうるもの（`after!` による上書き、ガードによる no-op、キー割当など）を `docker/checks.el` に ERT テストとして追加する。設定値を写すだけで回帰の検出にならないものは足さない。
6. **検証**: `./docker/run.sh batch`（引数なしで checks.el の全テスト）を実行する。個別の確認は `./docker/run.sh batch '<ELISP>'`（出力は `princ`）。一時スクリプトは `docker/out/` に置き、終わったら削除する。macOS 固有の項目はスキップしてユーザー確認に回す。
7. **brief の更新**: 検証が通った受け入れ基準だけ `[X]` にする。macOS 実機での確認待ちは `[ ]` のまま残す。
8. **報告**: 変更箇所、検証結果、残りの macOS 確認項目とその手順を伝え、確認後に `/ship-brief brief-<番号>` を実行するよう案内する。

## 失敗したとき

- 検証が失敗したらチェックを付けずに原因を調べて直し、再検証する。
- brief の意図どおりには実現できない（前提が誤っている等）と分かったら、brief を勝手に書き換えず、調査結果と修正案を報告して判断を仰ぐ。
- docker デーモン停止時はユーザーに `start-colima` の実行を依頼する。
