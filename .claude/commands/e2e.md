---
description: Set up an E2E test environment and draft the results comment skeleton
argument-hint: <issue-number>
allowed-tools: Bash(bin/vmx *), Bash(gh issue view:*), Read, Write
---

E2E test issue **$ARGUMENTS**.

## Boundary — read this first

| Mine | Yours |
|---|---|
| VMs exist, reachable, bridged, right os/arch | every numbered step in the guide |
| Packages the guide *assumes* (docker, compose, curl) | every command output |
| Host prep the guide lists (e.g. `vm.max_map_count`) | every 🟢 / 🟡 / 🔴 call |
| Comment skeleton with placeholders | filling the placeholders |

**Never run a guide step.** Its output is the evidence; pre-running it destroys
the artifact. That includes the Environment block — `cat /etc/os-release`,
`uname -a`, `ip a` are placeholders too.

**Never edit the issue body.** The guideline, results table, Feedback and
Reviewers checkboxes belong to QA. Only add new comments.

## 1. Read the issue

`gh issue view $ARGUMENTS --json title,body,labels,comments`. Extract the
Deployment requirements: components, OS, arch. Two architectures are usually
mandatory (aarch64 + x86_64).

## 2. Get the guide

The test guide is on `documentation.xdrsiem.wazuh.info`, which is VPN-gated and
cannot be fetched. Ask for a paste or a local copy, then cache it at
`docs/<issue>/guide.md`. Parse it once for: ordered section names and each
section's numbered step text.

## 3. Provision

```bash
bin/vmx list
bin/vmx up aio-ubuntu-arm agent-debian-arm
```

Add any missing component to `.claude/vmx.toml` first, named
`<component>-<os>-<arm|amd>`. Save the instance list to `docs/<issue>/topology.txt`
so a re-run brings up the same set.

## 4. Draft the comment

Write `docs/<issue>/comments/e2e-draft.md` containing, in order:

1. `## Environment` — one `<details>` per instance, prompts pre-written
   (`root@aio-ubuntu-arm:~#`), outputs as `<PASTE>`.
2. `## Results` — one row per (arch × section) from the parsed guide, status
   column empty.
3. `## Evidence — <arch>` — one `<details>` per section, containing each numbered
   step's text from the guide and a `<PASTE>` fenced block.

Section names, step text and the row set all come from the guide. Never invent a
section, never silently drop one that was not reached — leave it visibly empty.

## 5. Hand over

Print the draft path and the instance list. Then stop: you fill it, and
`/e2e-comment` posts it.
