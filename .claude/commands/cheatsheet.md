---
description: Commands-only cheatsheet for a topic (cached, near-zero tokens)
argument-hint: <topic words>
allowed-tools: Read, Write, Bash(ls:*), Bash(grep:*)
---

Cheatsheet: **$ARGUMENTS**

## 1. Cache first

Slugify the topic (`lima state` → `lima-state`). If `.claude/cheats/<slug>.md`
exists, print it verbatim and stop. That is the whole point: a second lookup
costs a file read, not a generation.

If no exact hit, `ls .claude/cheats/` and grep the filenames for the topic words
before generating anything.

## 2. On a miss

Generate, save to `.claude/cheats/<slug>.md`, then print.

## Format contract — enforced

- One fenced block. Commands only.
- One command per line.
- Optional trailing comment, **≤ 6 words**.
- Hard cap 20 lines.
- No prose, no headings, no explanation, no alternatives.

```bash
bin/vmx list                      # state + arch
limactl start builder-ubuntu-arm
bin/vmx build builder-ubuntu-arm TARGET=agent
```

If the topic genuinely cannot be answered in 20 command lines, say so in one line
and name the doc that covers it. Do not expand the format.
