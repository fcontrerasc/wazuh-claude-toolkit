#!/usr/bin/env bash
# wrong-host-build.sh - PreToolUse net for builds aimed at the macOS host.
#
# The toolchain lives in VMs; a host build either fails ("cmake: not found") or
# produces macOS-arm artifacts inside a tree meant for a Linux guest. Asks rather
# than denies: an intentional host-side macOS agent build is legitimate.

set -u

. "$(dirname "$0")/lib-usage.sh"

INPUT="$(cat)"
CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')"
CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // ""')"

case "$CWD" in
    */wazuh|*/wazuh/*|*/wazuh-wt/*) ;;
    *) exit 0 ;;
esac

# Guest-side invocations arrive wrapped in ssh/vmx, so skip those.
case "$CMD" in
    *vmx*|*ssh*|*limactl*|*tart*) exit 0 ;;
esac

case "$CMD" in
    make\ *|*"make -C src"*|cmake\ *|*" cmake "*|g++\ *|gcc\ *|*astyle*)
        log_use hook wrong-host-build ask
        jq -n --arg r "Build/style command on the macOS host. The toolchain lives in a VM:
  bin/vmx build builder-ubuntu-arm TARGET=agent
  bin/vmx winagent --issue N
Confirm only if a host-side macOS build is what you meant." '{
            hookSpecificOutput: {
                hookEventName: "PreToolUse",
                permissionDecision: "ask",
                permissionDecisionReason: $r
            }
        }'
        exit 0 ;;
esac

exit 0
