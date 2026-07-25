---
name: wazuh-cpp
description: C++17 architecture and coding conventions for Wazuh - Klaus Iglberger for design, Jason Turner for code, plus this repo's formatter split (clang-format vs astyle) and test conventions. Use when writing or reviewing a new module, class, or interface in src/, or when deciding how to make something unit-testable.
---

# Wazuh C++17 conventions

Two reference points, deliberately: **Klaus Iglberger** for architecture,
**Jason Turner** for code. Where they pull in different directions, architecture
wins for public boundaries and Turner wins inside a function body.

## Architecture (Iglberger)

- **Design for change and testability first.** Ask what varies, isolate that.
- **Prefer composition and value semantics over inheritance hierarchies.** An
  inheritance tree with one implementation is a liability, not a design.
- **Depend on abstractions at boundaries, concrete types inside.** One interface
  per collaborator the unit needs mocked (`IFileSystemWrapper`, `IInodeReader`) —
  not one god-interface.
- **No interface with a single implementation and no prospect of a second.**
  That is a rung on the ladder, not an abstraction.
- Keep each component independently unit-testable. If a class cannot be tested
  without a live socket, the socket is not injected yet.

## Code (Turner)

- Modern C++17 only. No C idioms where the standard library has an answer.
- Prefer algorithms over hand-rolled loops; prefer `const` and `constexpr` by
  default; prefer returning values over out-parameters.
- No unnecessary allocation or copies; `std::string_view` / `span` at read-only
  boundaries.
- Simplicity and readability over cleverness. Boring is what someone can debug at
  3am.
- Specific, honest names. Generic names hide generic thinking.

## Formatting — two tools, narrow scopes

Never guess; ask the router:

```bash
bin/wzfmt --which <file>     # clang-format | astyle | none
bin/wzfmt --check <file>
```

- **clang-format** gates exactly 6 paths (from
  `.github/workflows/5_codelinter_clangformat.yml`): `shared_modules/router`,
  `indexer_connector`, `content_manager`, `utils`, `wazuh_modules/inventory_sync`,
  `vulnerability_scanner`.
- **astyle** gates the `MODULE_LIST` modules in `src/ci/utils.py`, recursively
  (`--recursive` is in `src/ci/input/astyle.config`).
- **Everything else is governed by neither.** Do not reformat it. Style churn in
  a change nobody asked for is how a review dies.

Host limits, both real: a host clang-format of a different version than CI's
pinned Linux x86-64 build reports differences CI would not, and astyle ≥ 3.2
rejects the repo config outright. Advisory locally; authoritative in a Linux VM.

## Tests

- Mirror the source tree under `src/unit_tests/`.
- GoogleTest, built with `TEST=1`.
- **No explanatory or banner comments inside test bodies.** Keep them bare — the
  test name says what it tests.
- One test that fails if the logic breaks beats five that restate the happy path.

## Module skeleton

C glue in `src/wazuh_modules/` + `src/config/wmodules-<name>.c`, C++17
implementation behind it. Follow the nearest existing module rather than inventing
a layout; `wm_syscollector.c` is the lifecycle reference.
