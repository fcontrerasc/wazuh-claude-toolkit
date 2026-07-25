---
name: wazuh-vm
description: Provisioning judgment for Wazuh build/test VMs - which backend, image, arch and network when `bin/vmx list` shows no instance matching the required os/arch/distro. Use when a needed VM does not exist yet, when a lima/tart/vmware VM fails to create or reach the network, or when deciding between an arm64 VM and a real x86_64 kernel VM. Routine builds, syncs and execs need `bin/vmx` directly, not this skill.
---

# Provisioning a Wazuh VM

`bin/vmx` handles every routine operation. This skill covers the decisions it
cannot make for you.

## Always list first

```bash
bin/vmx list
```

Never provision a VM whose role already exists. Instances are named
`<component>-<os>-<arm|amd>` (`aio-ubuntu-arm`, `agent-debian-arm`,
`builder-ubuntu-arm`) and that name is the guest hostname, so evidence
transcripts stay comparable across releases.

## Backend by target

| os / arch | Backend | Create? |
|---|---|---|
| linux arm64 | lima, `vz` (native) | yes |
| linux x86_64 | lima, **qemu, real x86 kernel** | yes, lazily |
| macos arm64 | tart | yes |
| macos amd64 | — | unsupported, exit 3 |
| windows arm64 | VMware Fusion, externally managed | never — start it by hand |
| windows amd64 | — | unsupported, exit 3 |

## arm64 vs x86_64 Linux

Default to arm64. It is native, and the MinGW winagent cross-build works there,
so packaging needs no x86 detour.

Create `kernel-ubuntu-amd` only for **x86 kernel behaviour**: eBPF, FIM
whodata, syscall paths. There is no Rosetta shortcut for those — Rosetta
translates user binaries and gives you no x86 kernel. Expect 5–20× slower builds;
keep the VM running (no cleanup) and use `ccache` in the guest so the cost is
paid once.

That VM is also the only place the CI-pinned clang-format runs: it ships as a
Linux **x86-64 ELF** binary (`packages.wazuh.com/utils/clang-format`), so neither
the macOS host nor an arm64 guest can execute it.

## Bridged networking is mandatory on create

Prerequisites, both already present on this host: `socket_vmnet` and
`/etc/sudoers.d/lima`. If either is missing, creation fails rather than falling
back to NAT — a NAT VM that looks fine is the trap this rule exists to prevent.

Bridged also lets guests talk to each other directly, which is what makes
`vmx winagent` hand its zip from the Linux builder to the Windows VM without a
host round-trip.

## Never a shared mount

Source reaches a guest by one-way rsync into a guest-local tree
(`~/wz/<worktree>/`). Reasons, all verified in this repo:

- `src/build/CMakeCache.txt` pins compiler and absolute paths — one cache cannot
  serve two arches.
- Objects build in the source tree (`.gitignore` lists `*.o`, `*.a`; 685 such
  files present) — arm64 and x86_64 artifacts collide on the same paths.
- `src/external` holds arch-specific `make deps` output.
- A shared `.git` invites concurrent `index.lock` corruption.

Excluded paths are also protected from `--delete`, so guest `src/external` and
`src/build` survive every resync and incremental builds stay warm. First sync is
~300M of a 3.4G tree; later syncs are deltas.

Worktrees must live under `/Users/fabioc/ubuntu-data/wazuh-wt/` so the shared
parent covers the main repo and every worktree — a worktree's `.git` is a file
pointing back into the main repo.

## Host prerequisites

`bin/vmx doctor` checks them. The one that bites: macOS ships **openrsync**, whose
filter and delete semantics differ from rsync 3.x. `brew install rsync`.

## No cleanup, ever

There is no cleanup verb. `up`, `sync` and `mount` are idempotent; if state
exists, use it. The only time `vmx` stops a VM is lima mount repair, which is
announced first.
