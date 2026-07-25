#!/usr/bin/env bash
# build-notify.sh - desktop notification when a long vmx build/test finishes.
#
# Notification carries os, arch and result so a glance is enough; qemu x86 builds
# run long enough that watching the terminal is wasted time.

set -u

. "$(dirname "$0")/lib-usage.sh"

INPUT="$(cat)"
MSG="$(printf '%s' "$INPUT" | jq -r '.message // ""')"

case "$MSG" in
    *vmx*|*build*|*ctest*|*winagent*) ;;
    *) exit 0 ;;
esac

log_use hook build-notify notified
TITLE="wazuh build"
# vmx --json prints {"instance": "...", "os": "...", "arch": "...", "exit": N}
DETAIL="$(printf '%s' "$MSG" | tr -d '\n' | cut -c1-180)"

if command -v terminal-notifier >/dev/null 2>&1; then
    terminal-notifier -title "$TITLE" -message "$DETAIL" >/dev/null 2>&1
else
    osascript -e "display notification \"${DETAIL//\"/}\" with title \"$TITLE\"" \
        >/dev/null 2>&1
fi
exit 0
