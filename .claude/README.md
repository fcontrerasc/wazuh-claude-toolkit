# Wazuh development toolkit

Hooks, commands, skills, agents and two scripts for day-to-day Wazuh work on this
machine. Built from session history: issue-driven investigation, cross-arch
builds in VMs, reproduction harnesses, E2E evidence, and short issue write-ups.

Design rule: **anything deterministic lives in a script, not a prompt.** Hooks,
commands, skills and agents are thin callers of `bin/vmx` and `bin/wzfmt`, so
there is one implementation to fix and no drift between surfaces.

---

## 1. Inventory

### Scripts — the deterministic core

| Script | Job |
|---|---|
| `bin/vmx` | one VM execution layer: lima (Linux), tart (macOS), ssh-only (Windows). List, provision, sync, build, test, package, collect evidence |
| `bin/wzfmt` | formatter router: derives clang-format and astyle scopes from CI config, leaves ungoverned files alone |
| `bin/mdcheck` | the three doc rules markdownlint cannot express, in one place. `--rules-only` skips markdownlint |
| `bin/wzissue` | issue number → label-derived branch, worktree, toolkit links, `docs/<n>/notes.md`. `--dry-run`, `--self-test` |
| `bin/usage-report` | what of this toolkit gets used; hooks reported as wired, not counted |
| `git-hooks/pre-commit` | on **your** commits: blocks on the three doc rules, warns on style. Linked by `install.sh` into the git common dir, so one link covers every worktree |
| `tests/hooks.sh` | 43 assertions over the above. Run it after touching any hook or script |

### Hooks — `.claude/hooks/`, wired in `.claude/settings.json`

| Hook | Event | Behaviour |
|---|---|---|
| `guard-write.sh` | PreToolUse Bash | **deny** `git commit/push/tag` (you commit); **deny** `gh issue/pr edit`, `gh issue close/reopen`, `gh api -X PATCH/PUT/DELETE` (that text is QA's and reviewers'); **ask** `gh issue/pr comment`, `gh pr create/review`, `gh api -X POST`, `rm -rf`, `git reset --hard`, `git clean`, `limactl/tart delete` |
| `wrong-host-build.sh` | PreToolUse Bash | **ask** when `make`/`cmake`/`g++`/`astyle` runs on the macOS host inside the repo, with the `vmx` equivalent |
| `fmt-on-write.sh` | PostToolUse Edit/Write | routes the edited C/C++ file through `wzfmt --check`; reports the count and the fix command, never the diff; silent for ungoverned files |
| `md-lint.sh` | PostToolUse Edit/Write | scope check, then `bin/mdcheck` on `docs/**/*.md` |
| `usage-log.sh` | UserPromptSubmit + PreToolUse | one TSV line per command/skill/agent/script use; command names keyed without the leading slash so they match the file on disk |
| `build-notify.sh` | Notification | desktop notification with instance, os/arch and result |
| `status-line.sh` | statusLine | host, model, context %, project:branch |

### Commands — `.claude/commands/`

| Command | Does |
|---|---|
| `/issue <n>` | `bin/wzissue` does branch, worktree and scaffold; the model reads the issue and writes the summary |
| `/vm [verb] [instance...]` | `bin/vmx`, default verb `list` |
| `/build [instance] [VAR=…]` | build in a VM; routes Windows to the two-stage pipeline |
| `/ut <module>` | fixed `TEST=1` build + `ctest -R` + failures only |
| `/repro <n>` | reproduction harness on the platform the bug lives on |
| `/e2e <n>` | provision the topology, draft the evidence comment skeleton |
| `/e2e-comment <n>` | size-check (65,536 limit), lint, post on confirm |
| `/issue-comment <n> [update\|summary]` | draft the short issue write-up |
| `/cheatsheet <topic>` | commands-only cheatsheet, cached in `.claude/cheats/` |
| `/usage-report` | what actually gets used; prune candidates |
| `/pr-description` | existing user-level command, uses `docs/pull_request_template.md` |

### Skills — `.claude/skills/` (model-invoked)

| Skill | Loads when |
|---|---|
| `wazuh-vm` | a needed VM does not exist, or a backend/network/arch decision is required |
| `wazuh-cpp` | writing or reviewing C++ — Iglberger for architecture, Turner for code |
| `wazuh-docs` | writing docs or a comment: the judgment rules lint cannot check |

### Agents — `.claude/agents/`

| Agent | Model | Job |
|---|---|---|
| `wazuh-mapper` | sonnet | read-only `file:line` maps and call chains |
| `wazuh-builder` | sonnet | runs `vmx` builds/tests, returns results + failing lines |
| `wazuh-reviewer` | opus | diff review through Turner/Iglberger lenses + repo failure classes |

---

## 2. How `vmx` works

```bash
bin/vmx list                                   # always first
bin/vmx doctor [instance]
bin/vmx up <instance>...                       # create if absent, bridged
bin/vmx sync <instance>                        # one-way host -> guest tree
bin/vmx provision <instance> [--symbols]       # toolchain, once per VM
bin/vmx deps <instance> [TARGET=…]             # once per VM per target
bin/vmx exec <instance> [--record F] [--step N] -- CMD
bin/vmx build <instance> [TARGET=… DEBUG=1 TEST=1] [--json]
bin/vmx test  <instance> [--ctest-filter RE] [--json]
bin/vmx winagent --issue N [--debug] [--builder I] [--packager I]
bin/vmx install <instance> <pkg> [KEY=VALUE...] [--manager I]
bin/vmx install <instance> --from-source [--manager I]
bin/vmx enroll  <instance> --manager I [--force]
bin/vmx agents   <manager>                     # id, name, status, version
bin/vmx agent-rm <manager> <id|name>...        # delete via the manager API
bin/vmx fetch <instance> PATH... --issue N
bin/vmx collect <instance> --issue N --from PATH...
```

### Instance naming

`<component>-<os>-<arm|amd>`, registered in `.claude/vmx.toml`; the instance name is
also the guest hostname, so evidence transcripts read
`root@aio-ubuntu-arm:~#` and stay comparable across releases.

| Instance | Backend | Role |
|---|---|---|
| `builder-ubuntu-arm` | lima `vz`, Ubuntu 24.04 | default Linux builder **and** default winagent stage-1 builder |
| `kernel-ubuntu-amd` | lima qemu | real x86 kernel: eBPF, whodata, syscalls. Created lazily |

| `agent-macos-arm` | tart | macOS agent, built from source |
| `agent-ubuntu22-arm` | lima `vz` | Linux arm64 agent, built from source |
| `agent-ubuntu-amd` | lima qemu | Linux **x86_64** agent, built from source. Emulated, so slow — but it is the only leg that sees `__x86_64__` code, x86 alignment behaviour and CI's architecture |
| `agent-win11-arm` | ssh only | MSI packaging + install. Never created or stopped by `vmx` |
| `aio-ubuntu-arm`, `agent-debian-arm` | lima | E2E topology |

macOS amd64 and Windows amd64 exit 3. No fallback, no emulation shortcut.

### Non-native (x86_64) guests

Homebrew's lima bottle ships a guest agent only for the host architecture, so an
amd64 guest fails at start with
`guest agent binary could not be found for Linux-x86_64`. One-time fix:

```bash
brew install lima-additional-guestagents      # must match your lima version
```

`vmx doctor` checks for it whenever an `amd64` lima instance is registered. qemu
also has to be present (`brew install qemu`).

### Host budget

8 CPU / 16GB RAM / ~24GiB free disk. No VM takes more than half the cores or 6GB:
builder and kernel 4cpu/4GB, aio 4cpu/6GB, agent 2cpu/2GB. lima disks are sparse,
so the disk figures are caps. `vmx doctor` fails under 20GiB free, because a synced
tree plus deps plus build output runs several GB per VM.

### Windows packaging prerequisites

`vmx provision agent-win11-arm` installs them from `assets_dir`
(`~/.local/share/vmx/assets`, outside the repo — binaries do not belong in git):

| Tool | Source | Needed for |
|---|---|---|
| WiX v3.14 `candle.exe`/`light.exe` | `wix314-binaries.zip` (preferred, extraction only) or `wix314.exe` | the MSI |
| `cv2pdb.exe` 0.52 | downloaded in-guest from GitHub, same version CI pins | debug symbols |
| 32-bit `mspdb*.dll` | `--symbols`: VS Build Tools `VC.Tools.x86.x64`, ~3GB | debug symbols |

`--symbols` is opt-in because it is a multi-GB download; without it the MSI still
builds and `*-debug-symbols.zip` does not.

**Everything Windows-side runs from a pushed `.ps1`, never an inline
`powershell -Command`.** Inline scripts lose their quoting through ssh → cmd →
powershell: they come back echoed with exit code 0, which reads as success. That
produced a false "WiX already installed" on a VM where nothing was installed. The
scripts print `KEY=OK/MISS` lines and `vmx` parses them.

**The packaging script assumes symbols always succeed.**
`generate_wazuh_msi.ps1` calls `ExtractDebugSymbols` (`:138`) before
`BuildWazuhMsi` (`:139`). Without the PDB writer, cv2pdb emits no `.pdb`,
`Compress-Archive` gets an empty `-Path`, and a parameter-binding exception is
*always terminating* — no `ErrorActionPreference` can downgrade it, so the MSI is
never built. `win-msi.ps1` therefore comments out that one call in its working copy
when the PDB writer is absent, exactly as CI comments out `signtool`.

### Toolchain provisioning

A fresh guest has no compiler. `vmx provision` installs the package set from
`5_builderpackage_agent-windows.yml` + `packages/windows/Dockerfile`, and takes
**cmake from apt** when it is new enough: the repo's highest
`cmake_minimum_required` is 3.22.1 and Ubuntu 24.04 ships 3.28. CI's 3.31.6 pin
exists because the CodeBuild images ship no cmake at all, not because 3.28 is too
old — so building cmake from source here would cost minutes for nothing. It falls
back to the repo's own `tools/devContainer/reinstall-cmake.sh` only if apt is older
than the minimum.

### macOS guests (tart)

Seven things differ from Linux, and each one broke a run before it was handled:

| Difference | Handling |
|---|---|
| `tart ip` is blind to bridged VMs (it reads NAT DHCP leases) | try `--resolver arp` first, then fall back |
| Guest starts password-only, and macOS ships no `sshpass` | `.claude/setup/tart-ssh-key.sh <ip>` (expect-based); it verifies key auth before reporting success |
| Homebrew ships **CMake 4.x**, which refuses `cmake_minimum_required < 3.5` — two bundled deps declare 2.8.12 and 3.4 | `provision` pins CI's **3.31.6** from Kitware into `/opt/cmake-3.31.6` and symlinks it into `/usr/local/bin`, ahead of brew |
| Non-interactive PATH is only `/usr/bin:/bin:/usr/sbin:/sbin`; brew and `/usr/local/bin` are absent | every build step gets an explicit PATH prefix, and `install.sh` receives it as a **literal** string via `sudo env` — sudo drops the caller's PATH |
| `install.sh` defaults an agent to `/var/ossec` on **every** OS (no Darwin branch) | `USER_DIR=/Library/Ossec` is passed explicitly — the documented macOS location, also used by `packages/macos/*` and `src/init/pkg_installer.sh:30` |
| The image's own hostname would become the agent name on the manager | `up` sets HostName, LocalHostName and ComputerName from the instance name |
| BSD userland is not GNU | `stat -f %Sg`, `sed -i ''`, `$(sysctl -n hw.ncpu)` |

Cloning the cirruslabs base image needs ~33GB, so an existing local VM is reused
where possible; `tart list` shows what is on disk.

### Deploying and enrolling agents

```bash
bin/vmx install agent-win11-arm <msi> --manager aio-ubuntu-arm     # package
bin/vmx install agent-ubuntu22-arm --from-source --manager aio-ubuntu-arm
bin/vmx enroll  agent-ubuntu22-arm --manager aio-ubuntu-arm        # re-enroll only
```

`--manager` reads that instance's bridged address and its generated
`/var/wazuh-manager/etc/authd.pass`, so no password is copied by hand. It has to be
applied differently per platform:

| Platform | Address | Password |
|---|---|---|
| Windows MSI | `WAZUH_MANAGER=` property | `WAZUH_REGISTRATION_PASSWORD=` property |
| Linux source | `USER_AGENT_MANAGER_IP` in `preloaded-vars.conf` | `authd.pass` written **after** install — `install.sh` has no password variable |

Explicit `KEY=VALUE` arguments always win over `--manager`.

**Rebuilt a VM? The old registration blocks it.** The agent name comes from the
instance name, so a recreated VM hits `Duplicate agent name` forever. Either delete
the record first or pass `--force`, which does it for you:

```bash
bin/vmx agent-rm aio-ubuntu-arm agent-macos-arm
bin/vmx enroll   agent-macos-arm --manager aio-ubuntu-arm --force
```

**Never edit `client.keys` by hand.** It desynchronises the manager database from
authd's registry, and the API then refuses to delete the agent with
`Agent does not exist` (1701) while still listing it as active — a state only a
restore-plus-restart repairs. `agent-rm` runs the API from inside the manager guest
(no exposed port, local certificate) and does the two-step dance:
`POST /security/user/authenticate?raw=true` then
`DELETE /agents?agents_list=…&status=all&older_than=0s`. API credentials come from
`api_user`/`api_password` in `vmx.toml` (default `wazuh:wazuh`).

Four things here are not obvious and each one broke a run:

- **The NAT address is useless between guests.** Every lima guest has the same
  `192.168.5.15` on `eth0`; `guest_ip()` returns the bridged `lima0` address, or an
  agent would be pointed at itself.
- **`authd.pass` must be group-readable by the agent.** `wazuh-agentd` runs as user
  `wazuh`; a `root:root` file makes it log `No authentication password provided`, as
  if the file were absent. The group is taken from `<dir>/etc`, not hardcoded.
- **Enrollment needs the password at all.** Without it the manager answers
  `Invalid password. Unable to add agent`, which is the wall the 37470 E2E test hit.
- **`/qn` does not start the service.** The installer's `StartWazuhSvc` action is not
  deferred (WiX warns `ICE68`), so the service registers but reports `STOPPED` with
  1077; `install` runs `sc start WazuhSvc` itself.

Install paths differ by role: an **agent** lands in `/var/ossec`, a **manager** in
`/var/wazuh-manager` (`install.sh:1122`). Checking the wrong one produces a
confident false negative.

### Sync, not mount

Source reaches a guest by one-way rsync into `~/wz/<worktree>/`. Mounting was
rejected because Wazuh builds inside the source tree:

| Fact in this repo | Consequence of a shared mount |
|---|---|
| `src/build/CMakeCache.txt` pins compiler + absolute paths | one cache cannot serve two arches |
| 685 `*.o/*.a/*.so` in `src/`, ignored by `.gitignore` | arm64 and x86_64 objects collide |
| `src/external` 112M of built, arch-specific deps | one dir cannot hold two arches |
| `.git` 1.4G shared across guests | concurrent `index.lock` corruption |

Excludes: `.git/`, `docs/` (982M), `src/external/`, `src/build/`, `**/build/`,
objects, `src/var/`, `compile_commands.json`. Measured: **660M** transferred of a
3.4G tree, and a re-sync of an unchanged tree takes ~6s.

`--delete` never removes excluded paths, so guest `src/external` and `src/build`
survive every resync and incremental builds stay warm.

Parallel builds are *correct* — guest trees share nothing — but on this host
(8 cores, 16GB) they are bad practice: three concurrent builds thrash the host, and
qemu emulation makes the amd64 leg worse. **Run one build VM at a time**; treat the
parallel form as available, not recommended:

```bash
bin/vmx build builder-ubuntu-arm TARGET=manager --json   # then the next, in turn
```

Sync is also the snapshot point: you can keep editing on the host mid-build
without corrupting it, which a shared mount cannot promise.

### Worktrees

`/issue` puts worktrees in `/Users/fabioc/ubuntu-data/wazuh-wt/<branch>` because a
worktree's `.git` is a *file* pointing into the main repo — `vmx` mounts the shared
parent `/Users/fabioc/ubuntu-data`, so one path covers the main checkout and every
worktree. Worktrees elsewhere break git inside the guests.

### Windows: two stages

Windows has no compiler here. `vmx build` on a Windows instance exits 3; use
`vmx winagent`, which follows `.github/workflows/5_builderpackage_agent-windows.yml`
(not `packages/windows/generate_compiled_windows_agent.sh`, which needs `.git` in
the tree and docker in the guest):

1. **arm64 Linux builder** — patch `VERSION.json` with the commit from the host
   (the guest has no `.git`), `make -C src deps TARGET=winagent`,
   `make -C src TARGET=winagent`, drop `src/external`, zip.
2. **Windows VM** — `Expand-Archive`, copy `generate_wazuh_msi.ps1` into
   `src/win32/`, disable signing, `./generate_wazuh_msi.ps1 -MSI_NAME … -SIGN no`.

**Deps host tools arrive for the wrong architecture.** The published bundles are
produced on amd64 CI hosts, so `src/external/flatbuffers/build/flatc` is an x86-64
ELF. `flatc` runs *on the builder* to generate `inventorySync_generated.h`, so on
arm64 the build dies with `Exec format error` (make Error 126). The build will not
recover on its own: `sync_protocol/CMakeLists.txt:30` hardcodes the path with no
existence check, `:68-70` forces `FLATBUFFERS_BUILD_FLATC OFF`, and removing the
binary just changes the failure to Error 127 (verified). `vmx deps` therefore runs
`fix_host_tools`: it tests whether `flatc` executes and, if not, rebuilds it from
the bundled sources into `build-native/` — never into `build/`, because the bundle
also ships a `CMakeCache.txt` generated at `/wazuh-local-src` inside Wazuh's build
container, which cmake refuses to reuse from another path. `make deps` rewrites
`build/flatc` from the bundle on every run, so the native copy is kept aside and
reinstalled; `winagent` runs deps, then the fix, then the build, in that order.

The build is **i686** (`i686-w64-mingw32-strip`, `libgcc_s_dw2-1.dll`), so the MSI
runs under x86 emulation on the ARM Windows VM. Stage 2 prerequisites — WiX v3.14,
.NET 4.8.1, Windows SDK, cv2pdb 0.52, 32-bit `mspdb*.dll` on PATH — are checked by
`vmx doctor agent-win11-arm`; a missing 32-bit `mspdb*.dll` fails deep inside
cv2pdb, so check before the first run.

### No cleanup

There is no cleanup verb. `up` and `sync` are idempotent. The only stop `vmx` ever
performs is lima mount repair, announced first.

### Exit codes

`0` ok · `1` guest command failed · `2` bad config/target · `3` unsupported combo
· `4` VM absent and creation forbidden · `5` sync unrepairable · `6` timeout ·
`7` host prerequisite missing.

### Host prerequisites

`vmx doctor`. The one that bites: macOS ships **openrsync**, whose filter/delete
semantics differ from rsync 3.x — `brew install rsync`. `socket_vmnet` and
`/etc/sudoers.d/lima` are already present, so lima bridged works.

---

## 3. How `wzfmt` works

```bash
bin/wzfmt --which <file>      # clang-format | astyle | none
bin/wzfmt --check <file>      # exit 1 if it would change; prints the diff
bin/wzfmt --write <file>
bin/wzfmt --staged            # pre-push parity
bin/wzfmt --list-scope        # print the derived scope tables
```

Wazuh gates style with two tools over two narrow scopes, and **most of `src/` is
governed by neither**. Reformatting an ungoverned file produces churn CI never
asked for, mixed into a real change. Both scopes are derived at runtime, never
hardcoded, so they follow CI instead of drifting from it:

| Route | Source of truth | Scope |
|---|---|---|
| clang-format | `.github/workflows/5_codelinter_clangformat.yml` `paths:` | 6 paths: `shared_modules/{router,indexer_connector,content_manager,utils}`, `wazuh_modules/{inventory_sync,vulnerability_scanner}` |
| astyle | `src/ci/utils.py` `MODULE_LIST` + `getFoldersToAStyle` (parsed with `ast`) | 10 modules, 4 with special globs; **recursive**, because `--recursive` is in `src/ci/input/astyle.config` |
| none | — | everything else — left alone |

### Two host limits, both verified

- CI's clang-format is a **pinned Linux x86-64 ELF** from
  `packages.wazuh.com/utils/clang-format`. A host clang-format of a different
  version reports differences CI would not, so local checks are **advisory** and
  say so. Set `WAZUH_CLANG_FORMAT` to point at the pinned binary where it runs.
- **astyle ≥ 3.2 rejects the repo config** (`max-instatement-indent` was removed).
  Local astyle 3.6.16 cannot reproduce CI's result at all, so `wzfmt` exits 2 with
  the VM command rather than guessing.

Authoritative check before pushing:

```bash
bin/vmx exec kernel-ubuntu-amd -- bin/wzfmt --staged   # x86_64: pinned binary runs here
```

---

## 4. Workflows

### A. Feature or spike, all archs

For final-production work or a spike (e.g. 37382, 37534): design, prototype,
verify everywhere, leave deliverables in `docs/<issue>/`, close with a short
comment.

```bash
/issue 37382
```

Labels `spike` + `type/research` → branch `spike/37382-<slug>`, worktree at
`/Users/fabioc/ubuntu-data/wazuh-wt/spike-37382-<slug>`, scaffold `docs/37382/`.

| Step | Do this | Notes |
|---|---|---|
| Understand | ask for a `wazuh-mapper` trace per subsystem | maps land in `docs/37382/notes.md`; the archaeology stays out of the main context |
| Design | write `docs/37382/<topic>-design.md` | `wazuh-docs` + `wazuh-cpp` load themselves; `md-lint` enforces the mechanical rules |
| Prototype | edit in the worktree | `fmt-on-write` checks each file through `wzfmt`; ungoverned files stay untouched |
| Verify | `/build` on all four targets, in parallel | `--json` results feed the matrix; `guard-write` ensures **you** commit |
| Evidence | `bin/vmx collect <instance> --issue 37382 --from …` | manifest records commit, dirty flag, uname, arch |
| Deliverables | the `docs/37382/` set: design, analysis, evidence, final-decisions-summary, review-and-testing guide | |
| Close | `/issue-comment 37382 update` during, `summary` at the end | drafted to `docs/37382/comments/`, printed, posted only on confirm |

Closing comment, matching the shape already used on 37382:

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

**Deliverables**: `docs/37382/*.md`
**Open**: none
```

The Verified table is built from `vmx --json` output. An arch that was not run is
`—`, never blank and never assumed green.

### B. Reproduce and fix, all archs

For a bug report (e.g. 37191).

```bash
/issue 37191      # type/bug -> fix/37191-<slug>
/repro 37191
```

| Step | Do this | Notes |
|---|---|---|
| Sources | issue + comments, then **`wazuh-qa-automation`**, then product code | on 37191 the answer was in the QA suite: setup restarted the manager, which produced the `(1137): Lost connection with manager` line |
| Platform | pick the instance where the bug lives | Windows agent → `agent-win11-arm`; eBPF/whodata → `kernel-ubuntu-amd` |
| Harness | `~/wazuh-repro37191/` — outside the scratchpad | the scratchpad is wiped between sessions; include iteration counter and freeze detection |
| Run | `bin/vmx exec <instance> --record docs/37191/evidence/run.log -- <cmd>` | transcript in `user@instance:~#` form, no reformatting needed |
| Root cause | grep every caller before editing | one guard in the shared function, not one per caller |
| Fix + test | one gtest, no comments in the body | |
| Verify | `/ut <module>` on all four targets | a fix verified on one arch is not verified |
| Evidence | `bin/vmx collect … --issue 37191 --from <log>` | before/after plus manifest |
| Close | `/issue-comment 37191 summary` | |

```markdown
### Summary

**Root cause**: <one sentence, file:line>
**Trigger**: <3-5 numbered steps, exact log lines quoted>
**Fix**: <what changed, where> — `fix/37191-<slug>`
**Verified**: linux/arm64 🟢 · linux/x86_64 🟢 · macos/arm64 🟢 · windows 🟢
**Not reproduced under**: <negative results>
```

`Not reproduced under` is not filler: on 37191 the failed reproduction plus the
corrected root cause **was** the deliverable.

### C. E2E test — environment plus comment skeleton

For a release E2E subtask (e.g. 37470). Two hard boundaries.

**Never run a guide step.** Its output is the evidence; pre-running it destroys
the artifact. The Environment block (`cat /etc/os-release`, `uname -a`, `ip a`) is
a placeholder too.

**Never edit the issue body.** Guideline, results table, Feedback and Reviewers
checkboxes belong to QA. Only new comments — `guard-write` denies
`gh issue edit` and `gh api -X PATCH` outright.

| Mine | Yours |
|---|---|
| VMs exist, reachable, bridged, right os/arch | every numbered guide step |
| packages the guide assumes (docker, compose, curl) | every command output |
| host prep the guide lists (`vm.max_map_count`) | every 🟢 / 🟡 / 🔴 call |
| comment skeleton with placeholders | filling the placeholders |

```bash
/e2e 37470
```

1. Reads the issue (comments only).
2. Asks for the test guide — `documentation.xdrsiem.wazuh.info` is VPN-gated and
   cannot be fetched — and caches it at `docs/37470/guide.md`.
3. Parses the required os/arch matrix, the ordered section list and each section's
   numbered step text.
4. `bin/vmx up aio-ubuntu-arm agent-debian-arm`, saving the list to
   `docs/37470/topology.txt`.
5. Writes `docs/37470/comments/e2e-draft.md`:

````markdown
## Environment

<details><summary>aio-ubuntu-arm</summary>

```bash
root@aio-ubuntu-arm:~# cat /etc/os-release
<PASTE>
root@aio-ubuntu-arm:~# uname -a
<PASTE>
```

</details>

## Results

| Status | Arch | Test section | Issue found | Notes |
|---|---|---|---|---|
|  | aarch64 | Prerequisites |  |  |
|  | aarch64 | Single-node deployment |  |  |
|  | x86_64 | Prerequisites |  |  |

## Evidence — aarch64

<details><summary>Prerequisites — status: </summary>

### 1. <step text from guide>

```bash
<PASTE>
```

</details>
````

Section names, step text and the row set come from the guide — never invented, and
a section that was not reached stays visibly empty rather than absent.

Then you fill it and:

```bash
/e2e-comment 37470 --post
```

which reports unfilled `<PASTE>` markers and empty statuses, measures the body
against GitHub's **65,536-character** comment limit, lints it, and posts on
confirm. Expect a split on large tests: 37470's two arch transcripts were 36.8k +
37.5k = 74k, over the single-comment limit.

---

## 5. Status

Everything below was exercised end to end on this host, not just written.

| Verified | Evidence |
|---|---|
| `bin/wzfmt` scope derivation | all 4 astyle special cases + the 6 clang-format paths; router correct on 9 sample files |
| VM create | 4cpu/4GiB/40GiB, `mounts: []`, `user.name: wazuh`, hostname `builder-ubuntu-arm` |
| Bridged networking | `lima0 192.168.18.236/24` — same LAN as host (.194) and the Windows VM (.234) |
| `sync` | 660M main tree / 198M tag worktree, `docs`+`.git`+objects excluded, ~6s incremental |
| Per-worktree isolation | `~/wz/wazuh` and `~/wz/tag-v5.0.0-beta4` side by side, independent |
| Excluded paths survive `--delete` | 321M of built deps intact across a re-sync |
| `provision` | cmake 3.28.3 from apt (no source build), `i686-w64-mingw32-g++-posix (GCC) 13-posix` |
| `deps TARGET=winagent` | 231M of external deps built at `v5.0.0-beta4` |
| `fix_host_tools` | rebuilt `flatc` as ARM aarch64 after the bundle's x86-64 copy |
| `winagent` both stages | i686 cross-build → MSI 6.5MB + debug symbols 8MB, fetched to `docs/<issue>/artifacts/` |
| AIO stack | beta4 from packages on `aio-ubuntu-arm`, indexer + manager + dashboard active |
| Windows agent deploy | MSI installed, enrolled as `001`, `(4102): Connected to the server` |
| Linux source agent | Ubuntu 22.04 built from the tag, enrolled as `002`, connected |
| macOS source agent | macOS 15.7.7 arm64 built from the tag into `/Library/Ossec`, enrolled as `003`, connected |
| Windows guest | passwordless `exec` via `identity_file`, `cmd /c ver` → `10.0.26100.1742` |
| All 6 hooks | every deny/ask decision checked per matcher |

**17 bugs were found by running this, not by reading it.** Five would have produced
silently wrong results rather than clean failures: the host home left mounted, the
bridge bound to a dead interface (every VM NAT-only), `up` reporting success on a
fatal error, `up` skipping hostname convergence, and `$HOME` surviving neither ssh
nor rsync quoting (a 660M sync landed in a directory literally named `$HOME`).

| Not done | Why |
|---|---|
| `vmx winagent` stage 2 | needs WiX v3.14, .NET 4.8.1, Windows SDK, cv2pdb 0.52 and a 32-bit `mspdb*.dll` on the Windows VM — `vmx doctor agent-win11-arm` reports all four missing |
| `dev-macos-arm` (tart) | the cirruslabs base image ships user `admin`; a `wazuh` account must be created inside it once before `vmx` can reach it |
| `kernel-ubuntu-amd` | created lazily, on the first eBPF/whodata task |
| `/pr-description` in project scope | still the user-level command |

Deps caveat: bundles with a `99-` prefix are dev revisions and are not all
published. `main` and current spike branches pin `99-29734`, which returns **403**,
so a from-scratch build outside Wazuh's network needs a tag whose `DEPS_VERSION`
resolves — `v5.0.0-beta4` (`99-37361`) does. `CURL := curl -so` in `src/Makefile`
omits `-f`, so the 403 body lands in the tarball and the visible error is
`not in gzip format`, which looks like corruption but is not.

Prune from data, not taste: `/usage-report` at 30 days — 0 uses means delete,
1–2 means fold into a neighbour.
