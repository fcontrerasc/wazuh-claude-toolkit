---
description: Build a reproduction harness for a bug on the platform it happens on
argument-hint: <issue-number>
allowed-tools: Bash(bin/vmx *), Bash(gh issue view:*), Bash(grep:*), Read, Write, Edit
---

Reproduce issue **$ARGUMENTS**.

## 1. Sources, in this order

1. The issue body and every comment.
2. **`/Users/fabioc/ubuntu-data/wazuh-qa-automation`** — grep it for the failing
   suite before writing any harness. On 37191 the answer was in the QA sequence,
   not the product code: the setup step restarted the manager, which produced the
   `(1137): Lost connection with manager` line everyone was chasing.
3. The product code path, traced with the `wazuh-mapper` agent.

## 2. Platform

Pick the instance from where the bug happens, not from what is convenient:

| Bug is on | Instance |
|---|---|
| Linux userspace | `builder-ubuntu-arm` |
| eBPF / whodata / syscalls | `kernel-ubuntu-amd` |
| macOS agent | `dev-macos-arm` |
| Windows agent | `agent-win11-arm` |

## 3. Harness

Lives in a stable directory outside the scratchpad (`~/wazuh-repro<issue>/`) — the
scratchpad is wiped between sessions and rebuilding harnesses is pure waste.
Include: capture script, replay loop, iteration counter, and freeze detection
(a stalled iteration must be reported and the process killed, not waited on).

## 4. Run with a transcript

```bash
bin/vmx exec <instance> --record docs/<issue>/evidence/run.log -- <cmd>
```

`--record` writes the transcript in `user@instance:~#` prompt form, so evidence
never needs reformatting.

## 5. Root cause before fix

Grep every caller of the function about to change. One guard in the shared
function beats a guard in each caller, and patching only the path the ticket
names leaves the siblings broken.

## 6. Evidence

```bash
bin/vmx collect <instance> --issue $ARGUMENTS --from <log>...
```

Writes `docs/<issue>/evidence/<instance>/<utc>/` plus a manifest recording
commit, dirty flag, uname and arch. Un-provenanced evidence is unreproducible
three weeks later.

## 7. Verify the fix on all archs

`vmx test` on each of the four targets; a fix verified on one arch is not
verified. Record negative results too — "did not reproduce under X" is a finding,
not a gap.
