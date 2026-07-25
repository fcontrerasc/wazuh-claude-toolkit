---
description: Draft a short issue update/summary comment from this session
argument-hint: <issue-number> [update|summary]
allowed-tools: Read, Write, Bash(git log:*), Bash(git branch:*), Bash(gh issue comment:*)
---

Draft a comment for **$ARGUMENTS**.

Write to `docs/<issue>/comments/<utc>-<kind>.md`, print it, and stop. Posting is a
separate confirmed step (`gh issue comment --body-file <path>`). Never
`gh issue edit`.

Keep it **short**. These are read on a phone between meetings: decisions and
verified facts, no narration of the session.

## `update` — mid-flight, matches the `# Update:` shape

```markdown
# Update: <topic>

Branch: `<branch>`

**<Section>**
- <finding or decision> — <one-line why>
```

## `summary` — closing, spike or feature

```markdown
# Update: Summary

Changelog of the decisions, superseding the updates above.

**Decisions**
- <decision> — <why, one line>

**Architecture**
- <2-4 bullets>

**Verified**
| arch | build | tests |
|---|---|---|
| linux/arm64 | 🟢 | 🟢 |
| linux/x86_64 | 🟢 | 🟢 |
| macos/arm64 | 🟢 | — |
| windows/i686 | 🟢 | 🟢 |

**Deliverables**: `docs/<issue>/*.md`
**Open**: <or "none">
```

The Verified table comes from `vmx --json` results. If an arch was not run, its
cell is `—`, never blank and never assumed green.

## `summary` — closing, bug fix

```markdown
### Summary

**Root cause**: <one sentence, file:line>
**Trigger**: <3-5 numbered steps, exact log lines quoted>
**Fix**: <what changed, where> — `<branch>`
**Verified**: linux/arm64 🟢 · linux/x86_64 🟢 · macos/arm64 🟢 · windows 🟢
**Not reproduced under**: <negative results — these are findings, not gaps>
```

Dates in headings use `DD/MM/YYYY`.
