---
name: wazuh-docs
description: Style for Wazuh design docs, use-case docs and verification docs under docs/<issue>/ - the judgment calls markdownlint cannot check. Use when writing or revising any document in docs/, or a document that will be posted as a GitHub comment.
---

# Doc style

The mechanical rules are enforced by the `md-lint` hook (no in-page anchor links,
no stacked images, no cleanup sections). What is left is judgment:

- **Lean.** Cut every sentence that does not change what the reader does.
- **Option-framed.** Present choices as options with trade-offs, then a
  recommendation. Do not editorialise about missing features or absent work.
- **Version availability.** State which version a behaviour applies to when it
  matters.
- **No cleanup or teardown steps.** VMs are short-lived and use cases are
  independent.
- **One image per labeled verification section.** Never two placeholders in a row —
  a reader cannot tell which image proves which claim.
- **GitHub comments carry no in-page anchors.** They do not resolve. Use plain
  bold section names.
- Absolute dates, never "last week". Update headings use `DD/MM/YYYY`.

## Shapes that work here

| Doc | Contains |
|---|---|
| `<topic>-design.md` | problem, options with trade-offs, decision, architecture, scope boundaries |
| `<topic>-analysis.md` | the question, what was measured, what it implies |
| `<topic>-evidence.md` | verbatim transcripts with provenance (commit, arch, kernel) |
| `final-decisions-summary.md` | changelog of decisions superseding earlier updates |
| `review-and-local-testing-guide.md` | how a reviewer reproduces the result |

## Fenced blocks

Commands and output verbatim, never re-typed or tidied. Errors quoted exactly —
a cleaned-up error message is a different error message.
