---
description: What of this toolkit actually gets used (deterministic, no analysis)
allowed-tools: Bash(bin/usage-report*)
---

Run `bin/usage-report` and print its output verbatim.

Do not summarise, interpret or recommend unless asked — the script already applies
the decision rule (0 uses in the window means delete, 1-2 means fold into a
neighbour). Accounting is deterministic on purpose; the model adds nothing here.

`bin/usage-report --days 60` widens the window, `--json` for machine output.
