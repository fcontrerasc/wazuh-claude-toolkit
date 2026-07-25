# lib-usage.sh - one-line usage accounting, sourced by every hook.
#
#   . "$(dirname "$0")/lib-usage.sh"
#   log_use hook guard-write deny
#
# TSV, not JSON: appending a line needs no jq, so a hook that fires on every tool
# call costs a printf instead of a process. Never fails loudly - accounting must
# not be able to break a hook.

USAGE_LOG="${CLAUDE_USAGE_LOG:-$HOME/.claude/usage/wazuh-tooling.jsonl}"

log_use() {
    # kind, name, detail (optional): detail records whether a hook merely fired or
    # actually acted, which is the difference between "runs" and "earns its keep".
    mkdir -p "$(dirname "$USAGE_LOG")" 2>/dev/null || return 0
    printf '%s\t%s\t%s\t%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${1:-?}" "${2:-?}" "${3:-fired}" \
        >> "$USAGE_LOG" 2>/dev/null || true
}
