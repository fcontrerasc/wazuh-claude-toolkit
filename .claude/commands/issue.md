---
description: Start work on a GitHub issue - worktree, branch, docs scaffold
argument-hint: <issue-number>
allowed-tools: Bash(bin/wzissue *), Bash(gh issue view:*), Read, Write, Edit
---

Start work on issue **$ARGUMENTS**.

```bash
bin/wzissue $ARGUMENTS --dry-run     # branch, worktree path, prior PRs
bin/wzissue $ARGUMENTS               # create, link the toolkit, scaffold notes
```

The script owns everything mechanical and is the authority on it: the label →
prefix map, the kebab slug truncated at a word boundary, the worktree path under
`wazuh-wt/`, running `install.sh`, and `docs/<issue>/notes.md`. Idempotent — an
existing worktree or branch is reused, never recreated.

Your part is the half a script cannot do:

1. Read the issue properly — `gh issue view $ARGUMENTS --json title,body,comments`.
   Prior PRs are already listed by `wzissue`.
2. Write the one-line statement of what is actually being asked into
   `docs/<issue>/notes.md`, plus anything already known under `## Findings`.
3. Report branch, worktree and that summary. Do not start implementing until asked.
