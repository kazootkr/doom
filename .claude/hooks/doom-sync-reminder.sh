#!/usr/bin/env bash
# AGENTS.md ルール: init.el / packages.el を変更したら doom sync が必要。
# 編集後に PostToolUse の additionalContext でリマインドを注入する
# （実行はユーザー依頼方針のため通知のみ。ブロックはしない）。
set -euo pipefail

path="$(jq -r '.tool_input.file_path // ""')"
case "$(basename -- "$path")" in
  init.el|packages.el)
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"init.el/packages.el を変更しました。反映には doom sync が必要です（ホストでの実行はユーザーに依頼、docker 検証では run.sh が自動実行）。"}}'
    ;;
esac
exit 0
