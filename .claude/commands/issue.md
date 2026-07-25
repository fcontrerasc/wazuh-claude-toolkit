---
description: Start work on a GitHub issue - worktree, branch, docs scaffold
argument-hint: <issue-number>
allowed-tools: Bash(gh issue view:*), Bash(gh pr list:*), Bash(git worktree:*), Bash(git branch:*), Read, Write
---

Start work on issue **$ARGUMENTS**.

## 1. Read

`gh issue view $ARGUMENTS --json number,title,labels,body,comments` plus
`gh pr list --search "$ARGUMENTS" --state all` for prior attempts.

## 2. Branch prefix from labels

First match wins. Derived from what this repo actually names branches
(`enhancement/` 420, `fix/` 288, `test/` 101, `spike/` 16) — not from the legacy
4.x `bug/` form.

| Label | Prefix |
|---|---|
| `spike` | `spike` |
| `type/bug`, `type/bug/*` | `fix` |
| `type/enhancement`, `type/enhancement/*` | `enhancement` |
| `type/documentation` | `docs` |
| `type/test`, `type/test/*` | `test` |
| `type/research` without `spike` | `spike` |
| `type/change`, `type/maintenance` | `change` |
| none of the above | `enhancement` |

`level/*` labels never affect naming — they are on every issue.

Branch: `<prefix>/<issue>-<kebab-title>`. Strip a leading `Spike: `, truncate at
72 chars on a word boundary.

## 3. Worktree

```bash
git worktree add /Users/fabioc/ubuntu-data/wazuh-wt/<prefix>-<issue>-<slug> -b <branch>
```

The path is not a free choice: a worktree's `.git` is a file pointing into the
main repo, so `vmx sync` mounts the shared parent `/Users/fabioc/ubuntu-data`.
Worktrees elsewhere break git inside the guests.

Then link the toolkit into it — Claude Code reads `.claude/` from the project
directory, so a fresh worktree has no hooks, commands or `bin/vmx` until this runs:

```bash
/Users/fabioc/ubuntu-data/wazuh-claude-toolkit/install.sh <worktree-path>
```

## 4. Scaffold

Create `docs/<issue>/notes.md` with: issue title, labels, branch, worktree path,
and empty `## Findings` / `## Decisions` / `## Open` sections.

## 5. Report

Print branch, worktree path, docs dir, and the one-line issue summary. Do not
start implementing until asked.
