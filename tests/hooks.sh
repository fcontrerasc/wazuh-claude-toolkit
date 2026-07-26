#!/usr/bin/env bash
# tests/hooks.sh - the checks that fail if the toolkit's decision logic breaks.
#
# Covers: usage-log naming (a name keyed with a slash never matches the file on
# disk), command-vs-skill routing, guard-write's deny/ask/allow classes, the rm
# temp-path anchoring, mdcheck's three rules, md-lint's scope, that fmt-on-write
# never pastes a diff, wzissue's label map and slug truncation, and
# usage-report's argument guard.
#
# CLAUDE_USAGE_LOG points at a temp file: a test must not truncate the real log.
set -u
TOOLKIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
H="$TOOLKIT/.claude/hooks"
LOG="$(mktemp -t wztest-usage)"
export CLAUDE_USAGE_LOG="$LOG"
SANDBOX="$(mktemp -d -t wztest-root)"
trap 'rm -rf "$LOG" "$SANDBOX"' EXIT
pass=0; fail=0
ck() { # ck <label> <expected> <actual>
    if [ "$2" = "$3" ]; then printf 'ok   %s\n' "$1"; pass=$((pass+1))
    else printf 'FAIL %s\n       want: %s\n       got:  %s\n' "$1" "$2" "$3"; fail=$((fail+1)); fi
}

fresh() { : > "$LOG"; }
lastlog() { cut -f2,3,4 "$LOG" | tr '\t' ' '; }

# --- usage-log: naming -----------------------------------------------------
fresh
jq -n '{hook_event_name:"UserPromptSubmit",prompt:"/cheatsheet limactl",session_id:"t"}' \
    | "$H/usage-log.sh" >/dev/null
ck "prompt /cheatsheet logs stem, no slash" "command cheatsheet invoked" "$(lastlog)"

fresh
jq -n '{hook_event_name:"UserPromptSubmit",prompt:"/Users/fabioc/ubuntu-data/x",session_id:"t"}' \
    | "$H/usage-log.sh" >/dev/null
ck "pasted absolute path logs nothing" "" "$(lastlog)"

fresh
jq -n '{hook_event_name:"PreToolUse",tool_name:"Skill",tool_input:{skill:"cheatsheet"}}' \
    | "$H/usage-log.sh" >/dev/null
ck "Skill on a command file -> kind=command" "command cheatsheet invoked" "$(lastlog)"

fresh
jq -n '{hook_event_name:"PreToolUse",tool_name:"Skill",tool_input:{skill:"wazuh-vm"}}' \
    | "$H/usage-log.sh" >/dev/null
ck "Skill on a real skill -> kind=skill" "skill wazuh-vm invoked" "$(lastlog)"

fresh
jq -n '{hook_event_name:"PreToolUse",tool_name:"Agent",tool_input:{subagent_type:"wazuh-mapper"}}' \
    | "$H/usage-log.sh" >/dev/null
ck "Agent logs the subagent type" "agent wazuh-mapper invoked" "$(lastlog)"

# --- guard-write: events only, and rm anchoring ----------------------------
fresh
jq -n '{tool_input:{command:"git status --short"}}' | "$H/guard-write.sh" >/dev/null
ck "allow path logs nothing" "" "$(lastlog)"

fresh
OUT=$(jq -n '{tool_input:{command:"git commit -m x"}}' | "$H/guard-write.sh")
ck "git commit denied" "deny" "$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.permissionDecision')"
ck "deny is logged as an event" "hook guard-write deny" "$(lastlog)"

fresh
OUT=$(jq -n '{tool_input:{command:"git tag --list v5*"}}' | "$H/guard-write.sh")
ck "git tag --list still allowed" "" "$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.permissionDecision // ""')"

# An allowed command produces no output at all, so empty means allow.
D() { local o; o=$(jq -n --arg c "$1" '{tool_input:{command:$c}}' | "$H/guard-write.sh")
      [ -z "$o" ] && { echo allow; return; }
      printf '%s' "$o" | jq -r '.hookSpecificOutput.permissionDecision'; }
ck "rm in a nested tmp dir asks"     "ask"   "$(D 'rm /Users/fabioc/work/tmp/keepme')"
ck "rm in real /tmp is exempt"       "allow" "$(D 'rm -rf /tmp/scratch')"
ck "rm in /private/tmp is exempt"    "allow" "$(D 'rm -rf /private/tmp/claude-501/x')"
ck "rm of a source file asks"        "ask"   "$(D 'rm src/foo.cpp')"

# --- mdcheck: the three rules, one implementation --------------------------
mkdir -p "$SANDBOX/docs" "$SANDBOX/bin"
ln -sfn "$TOOLKIT/bin/mdcheck" "$SANDBOX/bin/mdcheck"
printf '# D\n\nSee [setup](#setup).\n\n![one](a.png)\n![two](b.png)\n\n## Cleanup\n\nx\n' \
    > "$SANDBOX/docs/bad.md"
printf '# D\n\n## Verification: connects\n\n![status](a.png)\n' > "$SANDBOX/docs/good.md"

BAD="$("$TOOLKIT/bin/mdcheck" "$SANDBOX/docs/bad.md" 2>&1)"
ck "mdcheck flags in-page anchors" "1" "$(printf '%s' "$BAD" | grep -c 'anchor link')"
ck "mdcheck flags stacked images"  "1" "$(printf '%s' "$BAD" | grep -c 'stacked images')"
ck "mdcheck flags cleanup section" "1" "$(printf '%s' "$BAD" | grep -c 'cleanup/teardown')"
"$TOOLKIT/bin/mdcheck" "$SANDBOX/docs/good.md" >/dev/null 2>&1
ck "mdcheck passes a clean doc" "0" "$?"
"$TOOLKIT/bin/mdcheck" >/dev/null 2>&1
ck "mdcheck with no args exits 2" "2" "$?"

# --- md-lint hook: scope, and delegation to mdcheck -------------------------
mdlint() { # mdlint <path> -> stderr
    jq -n --arg f "$1" '{tool_input:{file_path:$f}}' \
        | CLAUDE_PROJECT_DIR="$SANDBOX" "$H/md-lint.sh" 2>&1 >/dev/null
}
fresh
ck "hook reports the bad doc via mdcheck" "1" "$(mdlint "$SANDBOX/docs/bad.md" | grep -c 'cleanup/teardown')"
ck "and logs it as a finding" "hook md-lint finding" "$(lastlog)"

fresh
ck "hook passes the clean doc" "" "$(mdlint "$SANDBOX/docs/good.md")"
ck "and logs it as clean" "hook md-lint clean" "$(lastlog)"

# A doc outside docs/ is out of scope even with the same problems in it.
mkdir -p "$SANDBOX/.claude/skills/x"
cp "$SANDBOX/docs/bad.md" "$SANDBOX/.claude/skills/x/SKILL.md"
ck "a SKILL.md is out of scope" "" "$(mdlint "$SANDBOX/.claude/skills/x/SKILL.md")"

# --- fmt-on-write: a bounded message, never the diff -----------------------
# Stub wzfmt: 500 findings. The hook must still emit a short fix instruction.
cat > "$SANDBOX/bin/wzfmt" <<'STUB'
#!/bin/sh
case "$1" in
    --which) printf 'clang-format\tstub\n'; exit 0 ;;
    --check) i=0; while [ $i -lt 500 ]; do echo "line $i differs"; i=$((i+1)); done; exit 1 ;;
esac
STUB
chmod +x "$SANDBOX/bin/wzfmt"
printf 'int main(){}\n' > "$SANDBOX/x.cpp"
FMT="$(jq -n --arg f "$SANDBOX/x.cpp" '{tool_input:{file_path:$f}}' \
       | CLAUDE_PROJECT_DIR="$SANDBOX" "$H/fmt-on-write.sh" 2>&1 >/dev/null)"
ck "fmt-on-write does not paste the diff" "2" "$(printf '%s\n' "$FMT" | grep -c .)"
ck "fmt-on-write reports the count" "1" "$(printf '%s' "$FMT" | grep -c '500 finding')"
ck "fmt-on-write names the fix" "1" "$(printf '%s' "$FMT" | grep -c 'wzfmt --write')"

# --- wzissue: label map, slug and branch truncation ------------------------
"$TOOLKIT/bin/wzissue" --self-test >/dev/null 2>&1
ck "wzissue self-test passes" "0" "$?"

# --- usage-report: argument guard, and hooks reported as wired -------------
R="$TOOLKIT/bin/usage-report"
"$R" --days >/dev/null 2>&1;     ck "--days with no value exits 2" "2" "$?"
"$R" --days abc >/dev/null 2>&1; ck "--days abc exits 2" "2" "$?"
"$R" --days 60 >/dev/null 2>&1;  ck "--days 60 exits 0" "0" "$?"
"$R" --json >/dev/null 2>&1;     ck "--json exits 0" "0" "$?"

# A log younger than the window proves nothing; only an old one licenses DELETE.
fresh
printf '%s\tcommand\tvm\tinvoked\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$LOG"
ck "today-only log gives no verdict" "no data" \
   "$("$R" --json | jq -r '.[] | select(.name=="ut") | .verdict')"
ck "and prints no delete list" "0" \
   "$("$R" | grep -c 'delete:')"

printf '%s\tcommand\tvm\tinvoked\n' "$(date -u -v-90d +%Y-%m-%dT%H:%M:%SZ)" >> "$LOG"
ck "90d of history licenses DELETE" "DELETE" \
   "$("$R" --json | jq -r '.[] | select(.name=="ut") | .verdict')"
ck "an item used inside the window is kept off it" "fold?" \
   "$("$R" --json | jq -r '.[] | select(.name=="vm") | .verdict')"

fresh
ck "every hook on disk is wired in settings" "" \
   "$("$R" --json | jq -r '.[] | select(.verdict=="ORPHAN") | .name' | tr '\n' ' ' | sed 's/ $//')"
ck "no hook is judged by call count" "" \
   "$("$R" --json | jq -r '.[] | select(.kind=="hook" and (.verdict|test("DELETE|fold")))' )"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
