---
description: Generate PR title and description from the repo template
argument-hint: <issue-number>
allowed-tools: Read, Bash(git log:*), Bash(git diff:*), Bash(git branch:*), Bash(markdownlint:*)
---

PR description for issue **$ARGUMENTS**.

## 1. Inputs

- `docs/pull_request_template.md` — the template is the structure; follow its
  sections and do not invent new ones.
- `git log --oneline <base>..HEAD` and `git diff --stat <base>..HEAD` for what
  actually changed. Base is `main` unless the branch says otherwise.
- The issue: `gh issue view $ARGUMENTS` for the stated scope, so the description
  answers what was asked rather than narrating the diff.

## 2. Write it

- Title follows the branch's own convention: `<type>/<issue>-<slug>` maps to a
  title that names the change, not the process.
- Describe what changed and why. Skip anything the diff makes obvious.
- Tests: say which were added or run, and on which architectures. If a target was
  not exercised, say so — never imply coverage that does not exist.
- Include the verification matrix when the change touches more than one platform:

  | arch | build | tests |
  |---|---|---|
  | linux/arm64 | | |
  | linux/amd64 | | |
  | macos/arm64 | | |
  | windows/i686 | | |

  Cells come from `bin/vmx build --json` / `bin/vmx test --json` results, and an
  unrun target is `—`.

## 3. Before handing it over

Run the md-lint rules on the text: no in-page anchor links (they do not resolve in
GitHub), no stacked images, no cleanup sections.

Print it for review. Do not post it — `gh pr create` and `gh pr edit` are gated,
and the PR body is yours to submit.
