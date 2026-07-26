#!/usr/bin/env bash
# usage-log.sh - one JSONL line per command/skill/agent/script invocation.
#
# Exists so the toolkit can be pruned from data instead of taste: /usage-report
# reads this and flags anything unused for 30 days as a delete candidate.
# Never blocks and never prints: a telemetry hook that fails must be invisible.

set -u

. "$(dirname "$0")/lib-usage.sh"

INPUT="$(cat)"
EVENT="$(printf '%s' "$INPUT" | jq -r '.hook_event_name // ""')"
SESSION="$(printf '%s' "$INPUT" | jq -r '.session_id // ""')"

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
            # Name without the slash, so it matches the file on disk: a report
            # keyed on "/cheatsheet" can never find commands/cheatsheet.md.
            /[a-zA-Z]*) kind="command"; name="${FIRST#/}" ;;
        esac
        ;;
    PreToolUse)
        TOOL="$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')"
        case "$TOOL" in
            # Slash commands are exposed to the model as skills, so the Skill
            # tool fires for both. Whichever directory holds the file wins.
            Skill)
                name="$(printf '%s' "$INPUT" | jq -r '.tool_input.skill // ""')"
                if [ -f "$(dirname "$0")/../commands/$name.md" ]; then
                    kind="command"
                else
                    kind="skill"
                fi ;;
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

log_use "$kind" "$name" invoked
exit 0
