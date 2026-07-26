#!/usr/bin/env bash
# guard-write.sh - PreToolUse guard for Bash.
#
# Three classes:
#   deny  - things only the user does (commits) or that edit text they do not own
#           (issue/PR bodies belong to QA and reviewers)
#   ask   - outward-facing publishes and destructive local operations
#   allow - everything else
#
# `gh api` is matched explicitly: an allowlisted `Bash(gh api *)` otherwise
# routes straight around every gh matcher below.

set -u

. "$(dirname "$0")/lib-usage.sh"

INPUT="$(cat)"
CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')"

deny() {
    log_use hook guard-write deny
    jq -n --arg r "$1" '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: $r
        }
    }'
exit 0
}

ask() {
    log_use hook guard-write ask
    jq -n --arg r "$1" '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "ask",
            permissionDecisionReason: $r
        }
    }'
    exit 0
}

# --- deny: the user commits, always ---------------------------------------
case "$CMD" in
    *"git commit"*|*"git push"*)
        deny "You commit and push, not Claude. Stage/describe the change instead." ;;
esac

# `git tag` both reads and writes; only the writing forms are the user's call.
if printf '%s' "$CMD" | grep -q 'git tag'; then
    if ! printf '%s' "$CMD" | grep -qE 'git tag +(-l\b|--list|-n|--contains|--points-at|--sort|--merged|--no-merged|$)'; then
        deny "Creating or deleting tags is yours to do. Listing tags (git tag --list) is fine."
    fi
fi

# --- deny: never edit issue/PR text or state -----------------------------
case "$CMD" in
    *"gh issue edit"*|*"gh pr edit"*|*"gh issue close"*|*"gh issue reopen"*)
        deny "Issue/PR bodies and state are owned by QA and reviewers. Add a new comment instead." ;;
esac
if printf '%s' "$CMD" | grep -qE 'gh api .*-X *(PATCH|PUT|DELETE)'; then
    deny "gh api write method would edit content you may not own. Add a comment instead."
fi

# --- ask: outward-facing publish -----------------------------------------
case "$CMD" in
    *"gh issue comment"*|*"gh pr comment"*|*"gh pr review"*|*"gh pr create"*)
        ask "Posts to GitHub (visible to the team). Confirm the exact text." ;;
esac
if printf '%s' "$CMD" | grep -qE 'gh api .*-X *POST'; then
    ask "gh api POST publishes to GitHub. Confirm."
fi

# --- ask: destructive local ----------------------------------------------
case "$CMD" in
    *"git reset --hard"*|*"git clean"*|\
    *"limactl delete"*|*"tart delete"*|*"limactl factory-reset"*)
        ask "Destructive: $CMD
Confirm the paths/instances above are the intended targets." ;;
esac

# Any rm, not only rm -rf: deleting one file is just as irreversible. Scratchpad
# paths are exempt - that directory exists to be thrown away.
if printf '%s' "$CMD" | grep -qE '(^|[;&|[:space:]])rm([[:space:]]|$)'; then
    # The temp exemptions must anchor at the start of a path: a bare */tmp/*
    # also exempts ~/work/tmp/something-that-matters.
    case "$CMD" in
        *"/scratchpad/"*|*[[:space:]]/private/tmp/*|*[[:space:]]/tmp/*) ;;
        *) ask "Deletion: $CMD
Confirm the target above; deletions are not recoverable." ;;
    esac
fi

# No log line on the allow path: this hook runs on every Bash call, so logging
# it would turn the usage log into a Bash counter. Only deny/ask are events.
exit 0
