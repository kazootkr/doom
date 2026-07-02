#!/usr/bin/env bash
# git-commit スキル実行前に gitleaks で working tree をスキャンし、
# シークレット検出時（または gitleaks 不在時 = fail-closed）は
# PreToolUse で deny してコミットを未然に防ぐ。
set -euo pipefail

deny() {
  jq -n --arg reason "$1" \
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$reason}}'
  exit 0
}

skill="$(jq -r '.tool_input.skill // ""')"
[ "$skill" = "git-commit" ] || exit 0

command -v gitleaks >/dev/null 2>&1 \
  || deny 'gitleaks が見つからないためコミットを中止しました。brew install gitleaks でインストールしてから再実行してください。'

# 未追跡ファイルも含む全差分がコミット対象のスキルなので dir モードで全体をスキャンする
if ! output="$(gitleaks dir "${CLAUDE_PROJECT_DIR:-.}" --no-banner --redact 2>&1)"; then
  count="$(printf '%s\n' "$output" | grep -Eo 'leaks found: [0-9]+' | grep -Eo '[0-9]+' || echo '?')"
  deny "gitleaks がシークレットを ${count} 件検出したためコミットを中止しました。詳細は 'gitleaks dir . -v' で確認し、修正するか、誤検知なら .gitleaksignore に fingerprint を追加してください。"
fi

exit 0
