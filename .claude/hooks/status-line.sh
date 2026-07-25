#!/usr/bin/env bash
# status-line.sh — interactive statusline + context-usage writer.
#
# Registered as `statusLine.command` in settings.json. Claude pipes a JSON
# payload describing the session on stdin; the first line we print on stdout
# becomes the visible statusline.
#
# Display: "<host>: <model> <tokens> (<percent>%) | <project>:<branch>"
# Color of the percent reflects threshold bands.

set -u

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THRESHOLD="${CLAUDE_CONTEXT_THRESHOLD:-75}"
CRITICAL="${CLAUDE_CONTEXT_CRITICAL:-90}"

INPUT="$(cat)"

model=$(printf '%s' "$INPUT" | jq -r '.model.display_name // "Claude"')
window=$(printf '%s' "$INPUT" | jq -r '.context_window.context_window_size // 200000')
in_t=$(printf '%s' "$INPUT" | jq -r '
    (.context_window.current_usage.input_tokens // 0) +
    (.context_window.current_usage.cache_creation_input_tokens // 0) +
    (.context_window.current_usage.cache_read_input_tokens // 0)
')
out_t=$(printf '%s' "$INPUT" | jq -r '.context_window.current_usage.output_tokens // 0')
total=$((in_t + out_t))
percent=0
[ "$window" -gt 0 ] && percent=$((total * 100 / window))

cwd=$(printf '%s' "$INPUT" | jq -r '.workspace.current_dir // .cwd // "."')

# git context if available
project=""
branch=""
if command -v git >/dev/null 2>&1 && [ -d "$cwd" ]; then
    project=$(cd "$cwd" 2>/dev/null && basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null) || project=""
    branch=$(cd "$cwd" 2>/dev/null && git branch --no-color --show-current 2>/dev/null) || branch=""
fi

# colors
NC='\033[0m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
PINK='\033[1;35m'
RED='\033[0;31m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
GRAY='\033[0;37m'
GOLD='\033[0;33m'
DIM='\033[1;30m'
PURPLE='\033[0;35m'

case "$(printf '%s' "$model" | tr '[:upper:]' '[:lower:]')" in
    *opus*)   model_color="$BLUE"   ;;
    *sonnet*) model_color="$CYAN"   ;;
    *haiku*)  model_color="$GRAY"   ;;
    *)        model_color="$GOLD"   ;;
esac

if   [ "$percent" -ge "$CRITICAL" ];  then pct_color="$RED"
elif [ "$percent" -ge "$THRESHOLD" ]; then pct_color="$PINK"
elif [ "$percent" -ge $((THRESHOLD - 10)) ]; then pct_color="$YELLOW"
else pct_color="$GREEN"
fi

if [ -n "$project" ]; then
    location="${PURPLE}[${NC}${project}:${branch}${PURPLE}]${NC}"
else
    location="${PURPLE}$(basename "$cwd")${NC}"
fi

printf "${PINK}%s: ${model_color}%s${NC} ${DIM}%d (${pct_color}%d%%${DIM})${NC} | %b\n" \
    "$(hostname -s 2>/dev/null || hostname)" "$model" "$total" "$percent" "$location"
