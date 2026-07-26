---
description: Build in a VM (Linux, macOS, or the two-stage Windows agent)
argument-hint: [instance|all] [TARGET=... DEBUG=1 TEST=1]
allowed-tools: Bash(bin/vmx *)
---

Build: **$ARGUMENTS**

```bash
bin/vmx build builder-ubuntu-arm TARGET=manager TEST=1
bin/vmx build agent-macos-arm      TARGET=agent
bin/vmx winagent --issue N                    # two-stage Windows pipeline
```

`build` does `up` → `sync` → `make`, prints one line on success, and on failure
prints only the lines that explain it. Add `--json` when the result feeds a
verification matrix.

## Target routing

| Ask | Instance |
|---|---|
| Linux (default) | `builder-ubuntu-arm` |
| x86 **kernel** behaviour: eBPF, whodata, syscalls | `kernel-ubuntu-amd` (qemu, slow, created lazily) |
| macOS agent | `agent-macos-arm` |
| Windows agent | `bin/vmx winagent` — never `build`; the Windows VM has no compiler |

`vmx build` on a Windows instance exits 3 by design.

## All archs

For "verify on all archs", run the four in parallel (independent guest trees, no
shared state) and collect `--json` results into a matrix:

| arch | build | tests |
|---|---|---|
| linux/arm64 | | |
| linux/x86_64 | | |
| macos/arm64 | | |
| windows/i686 | | |

Never report "all archs" from a single run.

## Windows notes

Stage 1 is a MinGW **i686** cross-build on arm64 Linux (confirmed working, so
arm64 is the default builder); stage 2 packages the MSI on the Windows VM and
needs WiX v3.14, .NET 4.8.1, Windows SDK, cv2pdb 0.52 and a 32-bit `mspdb*.dll`
on PATH. Run `bin/vmx doctor agent-win11-arm` before the first packaging run.
