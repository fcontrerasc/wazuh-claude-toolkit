---
description: Which commands/skills/agents actually get used - prune candidates
allowed-tools: Bash(python3:*), Read
---

Report toolkit usage from `~/.claude/usage/wazuh-tooling.jsonl`.

```bash
python3 - <<'PY'
import json, collections, datetime, pathlib
p = pathlib.Path.home() / ".claude/usage/wazuh-tooling.jsonl"
rows = [json.loads(l) for l in p.read_text().splitlines() if l.strip()] if p.exists() else []
now = datetime.datetime.now(datetime.timezone.utc)
agg = collections.defaultdict(lambda: [0, None])
for r in rows:
    k = f"{r['kind']}:{r['name']}"
    ts = datetime.datetime.fromisoformat(r["ts"].replace("Z", "+00:00"))
    agg[k][0] += 1
    agg[k][1] = max(agg[k][1] or ts, ts)
for k, (n, last) in sorted(agg.items(), key=lambda kv: -kv[1][0]):
    days = (now - last).days
    flag = "  <- prune candidate" if days >= 30 else ""
    print(f"{k:<34} {n:>4}   last {days}d ago{flag}")
if not rows:
    print("no usage recorded yet")
PY
```

Then list anything that exists on disk but never appears in the log — those
never fired at all:

- `.claude/commands/*.md`
- `.claude/skills/*/SKILL.md`
- `.claude/agents/*.md`

## Decision rule

| Usage at 30 days | Action |
|---|---|
| 0 | delete it |
| 1–2 | fold into a neighbour |
| steady | keep |

Report the numbers and the recommendation. Do not delete anything without being
asked.
