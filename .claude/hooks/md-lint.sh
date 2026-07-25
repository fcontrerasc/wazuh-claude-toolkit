#!/usr/bin/env bash
# md-lint.sh - PostToolUse markdown check for docs/**/*.md.
#
# markdownlint is the same binary nvim uses (lua/kickstart/plugins/lint.lua),
# reading .markdownlint.jsonc so editor and hook agree.
#
# Three extra rules markdownlint cannot express, each from a standing rule about
# how these docs get read:
#   1. no in-page anchor links   - they do not resolve in GitHub comments
#   2. no stacked image placeholders - one image per labeled verification section
#   3. no Cleanup/Teardown sections  - VMs are short-lived; no cleanup steps

set -u

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
PROBLEMS=""

if command -v markdownlint >/dev/null 2>&1; then
    CFG=""
    [ -f "$ROOT/.markdownlint.jsonc" ] && CFG="--config $ROOT/.markdownlint.jsonc"
    OUT="$(markdownlint $CFG "$FILE" 2>&1)" || PROBLEMS="$OUT"
fi

# 1. in-page anchors: [text](#anchor)
ANCHORS="$(grep -nE '\]\(#[^)]+\)' "$FILE" || true)"
[ -n "$ANCHORS" ] && PROBLEMS="$PROBLEMS
in-page anchor links do not resolve in GitHub comments:
$ANCHORS"

# 2. two image placeholders/images with nothing between them
STACKED="$(awk '
    /^[[:space:]]*(!\[|<!--[[:space:]]*image|<PASTE.*image)/ {
        if (prev_img && NR - prev_line <= 2) print prev_line": "prev"\n"NR": "$0
        prev_img = 1; prev_line = NR; prev = $0; next
    }
    /^[[:space:]]*$/ { next }
    { prev_img = 0 }
' "$FILE" || true)"
[ -n "$STACKED" ] && PROBLEMS="$PROBLEMS
stacked images: give each one its own labeled verification section:
$STACKED"

# 3. cleanup sections
CLEAN="$(grep -nEi '^#{1,6}[[:space:]]*(clean[ -]?up|tear[ -]?down)' "$FILE" || true)"
[ -n "$CLEAN" ] && PROBLEMS="$PROBLEMS
cleanup/teardown sections are not used in these docs:
$CLEAN"

if [ -n "$(printf '%s' "$PROBLEMS" | tr -d '[:space:]')" ]; then
    printf 'md-lint %s:\n%s\n' "$FILE" "$PROBLEMS" >&2
    exit 2
fi
exit 0
