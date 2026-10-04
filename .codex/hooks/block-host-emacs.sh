#!/usr/bin/env bash
# AGENTS.md ルール: ホストで GUI Emacs を起動しない。
# 設定の動作確認は ./docker/run.sh（隔離 Linux コンテナ）で行う。
# Bash コマンドの各セグメントの先頭プログラムが emacs/Emacs
# （--batch/--version/--help を除く）なら PreToolUse で deny する。
set -euo pipefail

deny() {
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"ホストでの GUI Emacs 起動は AGENTS.md で禁止です。設定の動作確認は ./docker/run.sh batch / screenshot を使ってください。"}}'
  exit 0
}

cmd="$(jq -r '.tool_input.command // ""')"

# 公式の検証パスは許可（run.sh はコンテナ内で emacs を起動する）。
printf '%s' "$cmd" | grep -q 'docker/run\.sh' && exit 0

# ;/&/| でセグメント分割し、各先頭プログラム名だけを判定する
# （which emacs / ls ~/.config/emacs / (emacs-version) 等を誤ブロックしない）。
while IFS= read -r seg; do
  prog="$(printf '%s' "$seg" | sed -E 's/^[[:space:]]+//; s/[[:space:]].*$//')"
  [ -n "$prog" ] || continue
  case "$(basename -- "$prog")" in
    emacs|Emacs)
      printf '%s' "$seg" | grep -Eq -- '(--batch|--version|--help)' || deny
      ;;
  esac
done < <(printf '%s' "$cmd" | tr ';&|' '\n')

exit 0
