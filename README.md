# wazuh-claude-toolkit

Claude Code configuration and VM tooling for Wazuh development on this machine:
hooks, commands, skills, agents, and two scripts that hold all the deterministic
logic (`bin/vmx`, `bin/wzfmt`).

Kept out of the wazuh repo on purpose. That repo is upstream — committing this
there would put it in every branch and PR, and one `git add -A` from leaking.

**Full documentation, including the three workflows (feature/spike,
reproduce + fix, E2E): [`.claude/README.md`](.claude/README.md).**

## Layout

```
.claude/
├── README.md          the real documentation - start there
├── settings.json      hooks + permissions (shared)
├── settings.local.json host-specific allowlist and statusline
├── vmx.toml           VM instance registry
├── hooks/             guard-write, fmt-on-write, md-lint, usage-log, ...
├── commands/          /issue /vm /build /ut /repro /e2e /cheatsheet ...
├── skills/            wazuh-vm, wazuh-cpp, wazuh-docs
├── agents/            wazuh-mapper, wazuh-builder, wazuh-reviewer
├── cheats/            cached command-only cheatsheets
└── setup/             guest setup scripts (win-ssh-key, win-packager, win-msi)
bin/vmx                VM layer: lima (Linux), tart (macOS), ssh (Windows)
bin/wzfmt              formatter router: clang-format vs astyle vs neither
install.sh             link the toolkit into a checkout or worktree
assets/README.md       third-party installers to fetch (binaries stay untracked)
```

## Install into a checkout

```bash
./install.sh /Users/fabioc/ubuntu-data/wazuh
```

Symlinks `.claude`, `.markdownlint.jsonc`, `bin/vmx` and `bin/wzfmt` into the
target and adds them to that repo's `.git/info/exclude` (local-only, never
committed upstream).

**Every worktree needs its own run** — Claude Code reads `.claude/` from the
project directory, and a worktree is its own project directory:

```bash
./install.sh /Users/fabioc/ubuntu-data/wazuh-wt/spike-37534-foo
```

## First run on a new machine

```bash
bin/vmx doctor                      # host prerequisites, each with its fix
bin/vmx list                        # instances and state
bin/vmx up builder-ubuntu-arm       # create the Linux builder (bridged)
bin/vmx provision builder-ubuntu-arm
```

`vmx doctor` is the entry point for anything that looks broken; it checks rsync
3.x (macOS ships openrsync), lima's bridged interface, lima sudoers, free disk,
ssh-agent, and per-guest toolchains.

## Host-specific bits

`vmx.toml` carries VM names, sizes, the Windows VM's IP and the automation key
path; `settings.local.json` carries the permission allowlist. Fine for a private
repo. If this is ever shared more widely, move those to a gitignored
`vmx.local.toml` overlay.

`.claude/settings.local.json` is deliberately untracked: your global
`~/.config/git/ignore` excludes `**/.claude/settings.local.json`, and Claude Code
appends to that file on its own, so tracking it would mean constant churn. Anything
worth sharing belongs in `settings.json`.

Binaries are never committed — see `assets/README.md` for what to download and
where `vmx` expects it (`~/.local/share/vmx/assets`, set by `assets_dir`).
