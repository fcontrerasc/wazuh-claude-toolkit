---
description: List, start or inspect build/test VMs (lima, tart, ssh)
argument-hint: [list|doctor|up|sync|deps] [instance...]
allowed-tools: Bash(bin/vmx *), Bash(limactl list:*), Bash(tart list:*)
---

Run `bin/vmx` for: **$ARGUMENTS**

Default verb is `list` — always show what exists before creating anything.

```bash
bin/vmx list                                   # instances, state, arch
bin/vmx doctor builder-ubuntu-arm            # host + guest prerequisites
bin/vmx up aio-ubuntu-arm agent-debian-arm # multiple = an E2E topology
bin/vmx sync builder-ubuntu-arm              # one-way host -> guest tree
bin/vmx deps builder-ubuntu-arm TARGET=winagent
```

Rules the script enforces, do not work around them:

- Instances are named `<component>-<os>-<arm|amd>`; that name is the guest hostname.
- New VMs are bridged. `up` never stops or deletes; there is no cleanup verb.
- Source reaches a guest by one-way rsync into a guest-local tree, never a shared
  mount — build artifacts live in the source tree, so a shared mount corrupts
  parallel builds.
- macOS x86_64 and Windows x86_64 exit 3. No fallback.

If an instance is missing from `.claude/vmx.toml`, add it there rather than
passing ad-hoc ssh flags.
