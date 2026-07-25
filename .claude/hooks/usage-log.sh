#!/usr/bin/env bash
# usage-log.sh - one JSONL line per command/skill/agent/script invocation.
#
# Exists so the toolkit can be pruned from data instead of taste: /usage-report
# reads this and flags anything unused for 30 days as a delete candidate.
# Never blocks and never prints: a telemetry hook that fails must be invisible.

set -u

LOG="${CLAUDE_USAGE_LOG:-$HOME/.claude/usage/wazuh-tooling.jsonl}"
mkdir -p "$(dirname "$LOG")" 2>/dev/null || exit 0

INPUT="$(cat)"
EVENT="$(printf '%s' "$INPUT" | jq -r '.hook_event_name // ""')"
SESSION="$(printf '%s' "$INPUT" | jq -r '.session_id // ""')"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

kind=""; name=""
case "$EVENT" in
    UserPromptSubmit)
        # Slash commands only; free-form prompts are not tooling usage.
        PROMPT="$(printf '%s' "$INPUT" | jq -r '.prompt // ""')"
        # A slash command is /word, not any path the user happened to paste
        # (an absolute path like /Users/... starts with / too).
        FIRST="$(printf '%s' "$PROMPT" | awk '{print $1}')"
        case "$FIRST" in
            /*/*) : ;;                       # a path, not a command
            /[a-zA-Z]*) kind="command"; name="$FIRST" ;;
        esac
        ;;
    PreToolUse)
        TOOL="$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')"
        case "$TOOL" in
            Skill) kind="skill"; name="$(printf '%s' "$INPUT" | jq -r '.tool_input.skill // ""')" ;;
            Agent) kind="agent"; name="$(printf '%s' "$INPUT" | jq -r '.tool_input.subagent_type // "general-purpose"')" ;;
            Bash)
                C="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')"
                case "$C" in
                    *bin/vmx*)   kind="script"; name="vmx" ;;
                    *bin/wzfmt*) kind="script"; name="wzfmt" ;;
                esac
                ;;
        esac
        ;;
esac

[ -n "$kind" ] || exit 0

jq -n -c --arg ts "$TS" --arg kind "$kind" --arg name "$name" --arg session "$SESSION" \
    '{ts:$ts, kind:$kind, name:$name, session:$session}' >> "$LOG" 2>/dev/null

exit 0
