#!/usr/bin/env bash
# install.sh - link this toolkit into a Wazuh checkout or worktree.
#
#   ./install.sh /Users/fabioc/ubuntu-data/wazuh
#   ./install.sh /Users/fabioc/ubuntu-data/wazuh-wt/spike-37534-foo
#
# Claude Code reads .claude/ from the *project directory*, so every worktree needs
# its own link. Symlinks rather than copies: one place to edit, no drift.
#
# The links are added to the target's .git/info/exclude, which is local-only - so
# nothing leaks into a branch or a PR of the upstream repo.

set -euo pipefail

TOOLKIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-}"

if [ -z "$TARGET" ]; then
    echo "usage: $0 <path-to-wazuh-checkout-or-worktree>" >&2
    exit 2
fi
if [ ! -d "$TARGET" ]; then
    echo "install.sh: not a directory: $TARGET" >&2
    exit 2
fi
if [ ! -e "$TARGET/src/Makefile" ]; then
    echo "install.sh: $TARGET does not look like a wazuh checkout" >&2
    exit 2
fi

link() {  # link <relative-path-in-toolkit> <relative-path-in-target>
    local src="$TOOLKIT/$1" dst="$TARGET/$2"
    mkdir -p "$(dirname "$dst")"
    ln -sfn "$src" "$dst"
    echo "  $2 -> $1"
}

echo "linking $TOOLKIT into $TARGET"
link ".claude"              ".claude"
link ".markdownlint.jsonc"  ".markdownlint.jsonc"
# bin/ already holds repo scripts (wazuh-control), so link the files, not the dir.
link "bin/vmx"              "bin/vmx"
link "bin/wzfmt"            "bin/wzfmt"
link "bin/mdcheck"          "bin/mdcheck"
link "bin/wzissue"          "bin/wzissue"
link "bin/usage-report"     "bin/usage-report"

# --git-common-dir, not --git-dir: in a worktree the latter is
# .git/worktrees/<name>/, and git does not read info/exclude from there (verified
# with a probe file - it stayed untracked-visible). The common dir is also the
# right scope, since every worktree gets the same links.
EXCLUDE="$(git -C "$TARGET" rev-parse --path-format=absolute --git-common-dir)/info/exclude"
mkdir -p "$(dirname "$EXCLUDE")"
for path in ".claude" ".markdownlint.jsonc" "bin/vmx" "bin/wzfmt" \
            "bin/mdcheck" "bin/wzissue" "bin/usage-report"; do
    grep -qxF "/$path" "$EXCLUDE" 2>/dev/null || echo "/$path" >> "$EXCLUDE"
done
echo "excluded locally via $EXCLUDE"

echo
echo "check it:  cd $TARGET && bin/vmx doctor"
