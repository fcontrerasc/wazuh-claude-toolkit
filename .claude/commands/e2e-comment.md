---
description: Size-check, lint and post a filled E2E evidence comment
argument-hint: <issue-number> [--post]
allowed-tools: Read, Bash(bin/mdcheck *), Bash(gh issue comment:*), Bash(wc:*)
---

E2E comment for **$ARGUMENTS**.

## 1. Read the filled draft

`docs/<issue>/comments/e2e-draft.md`. Report any `<PASTE>` still unfilled and any
Results row with an empty status — those are gaps, not defaults.

## 2. Size check

GitHub caps one comment at **65,536 characters**. Measure the assembled body and
report which shape still fits:

| Size | Shape |
|---|---|
| ≤ 65k | one comment, collapsible sections |
| > 65k | split per arch: Environment + Results in comment 1, evidence per arch after |
| far over | structure in the comment, full logs as attached files |

Say the number. A rejected comment after a two-day test run is a bad way to find
this out. (For reference: issue 37470's two arch transcripts were 36.8k + 37.5k.)

## 3. Lint

```bash
bin/mdcheck docs/<issue>/comments/e2e-draft.md
```

## 4. Post — only with `--post`, and only after confirmation

```bash
gh issue comment <issue> --body-file docs/<issue>/comments/e2e-draft.md
```

Never `gh issue edit`. The body is QA's. Your own posted comment can be edited
afterwards — theirs cannot.
