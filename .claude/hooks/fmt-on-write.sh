#!/usr/bin/env bash
# fmt-on-write.sh - PostToolUse style check for the file just edited.
#
# Routes through bin/wzfmt, which derives its scope from CI config: most of src/
# is governed by neither clang-format nor astyle and is left alone.
#
# Local limits, both verified:
#   - CI's clang-format is a pinned Linux x86-64 binary; a host clang-format of a
#     different version reports differences CI would not. Advisory here.
#   - astyle >= 3.2 rejects src/ci/input/astyle.config, so those files cannot be
#     checked on the host at all; wzfmt exits 2 and this hook stays quiet.
# Authoritative check: bin/wzfmt --staged inside a Linux VM before pushing.

set -u

. "$(dirname "$0")/lib-usage.sh"

INPUT="$(cat)"
FILE="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""')"
[ -n "$FILE" ] || exit 0

case "$FILE" in
    *.c|*.cpp|*.h|*.hpp) ;;
    *) exit 0 ;;
esac

ROOT="${CLAUDE_PROJECT_DIR:-$(git -C "$(dirname "$FILE")" rev-parse --show-toplevel 2>/dev/null)}"
WZFMT="$ROOT/bin/wzfmt"
[ -x "$WZFMT" ] || exit 0

OUT="$(WZFMT_QUIET_VERSION=1 "$WZFMT" --check "$FILE" 2>&1)"
RC=$?

# 0 clean or ungoverned; 2 tool unusable on this host; 3 config missing.
if [ "$RC" -ne 1 ]; then log_use hook fmt-on-write clean; exit 0; fi
log_use hook fmt-on-write finding

DECISION="$(WZFMT_QUIET_VERSION=1 "$WZFMT" --which "$FILE" 2>/dev/null | cut -f1)"
printf 'Style (%s, advisory - host tool version differs from CI):\n%s\n' \
    "$DECISION" "$OUT" >&2
exit 2
