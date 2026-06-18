# CLAUDE.md

Doom Emacs の個人設定（DOOMDIR）。

## 実行環境

OS・Emacs バージョン・ビルドフィーチャーは [README.org](README.org) の「実行環境」を参照。Emacs は NS port + ns-inline-patch 適用ビルド（macOS/NS 固有設定・IME 連携の前提）。

## 開発スタイル: spec 駆動開発

3ステップ（要求 → タスク → 実装）の各スキルとコミット運用は [README.org](README.org) の「設定(コード)変更プロセス」を参照。各ステップは必ず対応スキルで実行する。

**IMPORTANT**（エージェントの挙動）:
- **各ステップ完了後は指示を待たず自動で `/git-commit`**（1ステップ = 1コミット）。

### 要求ファイルとタスクファイル（背景・経緯は docs/ を正とする）

- **要求（docs/requirements/）= 要求仕様**。「なぜ・何を作るか」に絞り明瞭・簡潔に。実装手段（配線・advice/hook・recipe 等）はタスクへ委ねる。ユーザー指定の確定コード／参照スニペットは本文に混ぜず `* タスクへの引き継ぎ` に分離。
- **タスク（docs/tasks/）= 実装仕様**。「どう実装するか」。
  - **冪等**: 何度 `/sync-implementation` しても同じ最終状態。変更対象を一意特定し「既にあれば変えない」粒度で。非冪等な elisp（`advice-add` 等）はアンカー編集／ガードで一度だけ。
  - **決定的**: 同じ環境で同じ実装に再現。実行時分岐は裁量に委ねず判断ルールを明示。

## リポジトリ構成

- `init.el`（`doom!` モジュール選択）・`packages.el`（追加パッケージ）— **変更時は `doom sync` が必要**。ホストでの実行はユーザーに依頼（docker は自動 → 下記。編集時は PostToolUse フックがリマインド）。
- `config.el` — 設定本体（`doom sync` 不要）。**遅延ロードされる変数の上書きは素の `setq` でなく `after!` ブロックで**（例: `diff-hl-update-async`）。
- macOS/NS 固有設定は `(when (and (eq system-type 'darwin) (featurep 'ns)) ...)` ガード内（Linux・docker では no-op）。現状は外観設定のみ。IME 連携は未実装。
- `.claude/hooks/` — ハーネス強制ルール（`.claude/settings.json` で配線）。PreToolUse: ホストでの GUI Emacs 起動を deny／PostToolUse: init.el・packages.el 編集時に doom sync をリマインド。

## 実装方針

- 明瞭・簡潔で、読みやすくメンテしやすいコードにする。
- **doom-first**: 自作前に相当する doom モジュールが `init.el` の `doom!` ブロック（無効=コメントアウト含む）に無いか確認し、あれば優先採用を検討。挙動・変数・キーバインドは README で確定する。
  - doom ソース: 標準モジュールと README は `~/.config/emacs/sources/doom+/modules/<カテゴリ>/<モジュール>/README.org`。`~/.config/emacs/modules/` は core のみ。
  - 設定資料: `~/.config/emacs/docs/getting_started.org`（同 `docs/` に faq.org・examples.org）。

## 動作確認（Docker）

**ホストで Emacs を起動せず**（GUI 起動は PreToolUse フックで deny）、`docker/` の隔離 Linux コンテナで検証（このリポジトリを DOOMDIR にマウント）。

```sh
./docker/run.sh build              # イメージ作成（初回・Dockerfile 変更時）
./docker/run.sh batch              # doom sync + 設定ロード + 標準チェック
./docker/run.sh batch '<ELISP>'    # 任意の検証式を評価
./docker/run.sh screenshot         # Xvfb 上の GUI を PNG 撮影（docker/out/*.png）
./docker/run.sh clean              # イメージ・キャッシュ破棄（クリーン初回の再現）
```

- **doom sync は自動**: init.el / packages.el（と doom 本体）が変わっていれば batch / screenshot 前に走る。config.el だけなら走らない。
- **検証式の出力は `message` でなく `princ`**（batch では message が CLI buffer に吸われ表示されない）。
- **screenshot は目視**: `docker/out/*.png` を Read で開き文字化け・豆腐・minibuffer プロンプト等を確認。
- **macOS 固有は検証不可**（Hiragino・`mac-*` 関数・darwin ガード内・`:os macos`）。最終確認はユーザーに依頼。
- **クリーン初回の再現**: `clean` → `batch`（初回は全パッケージ導入で数分、以降はキャッシュで数秒）。
- **colima が必要**: docker デーモン停止時は run.sh がエラー。ユーザーに `start-colima` を依頼。
