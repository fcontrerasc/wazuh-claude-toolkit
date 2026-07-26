#!/usr/bin/env bash
# md-lint.sh - PostToolUse markdown check for docs/**/*.md.
#
# Scope only. The rules live in bin/mdcheck, so the hook, /e2e-comment,
# /pr-description and a pre-commit check all enforce the same three and cannot
# drift apart.

set -u

. "$(dirname "$0")/lib-usage.sh"

INPUT="$(cat)"
FILE="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""')"
[ -n "$FILE" ] || exit 0
[ -f "$FILE" ] || exit 0

ROOT="${CLAUDE_PROJECT_DIR:-.}"

# Only the repo's docs/ tree, anchored at the project root: a path like
# .claude/skills/wazuh-docs/SKILL.md must not match.
REL="${FILE#"$ROOT"/}"
case "$REL" in
    docs/*.md) ;;
    *) exit 0 ;;
esac

MDCHECK="$ROOT/bin/mdcheck"
[ -x "$MDCHECK" ] || exit 0

if OUT="$("$MDCHECK" "$FILE" 2>&1)"; then
    log_use hook md-lint clean
    exit 0
fi

log_use hook md-lint finding
printf '%s\n' "$OUT" >&2
exit 2
