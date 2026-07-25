---
description: Build and run unit tests for a module in a VM (deterministic path)
argument-hint: <module> [instance]
allowed-tools: Bash(bin/vmx *)
---

Unit tests for: **$ARGUMENTS**

Fixed sequence, no improvisation:

```bash
bin/vmx build <instance> TARGET=manager TEST=1
bin/vmx test  <instance> --ctest-filter <module>
```

Default instance `builder-ubuntu-arm`. `vmx test` runs
`cmake -DTARGET=manager .. && make && ctest -R <module> --output-on-failure`
inside `src/unit_tests/build` in the guest tree and returns only failures.

Report: module, instance, pass/fail counts, and the failing test names with their
assertion lines. Nothing else.

If the module is one of the `build.py` shared modules, the module-local path is
also valid inside the guest:

```bash
bin/vmx exec builder-ubuntu-arm -- bash -c 'cd src && python3 build.py -t <module>'
```

Tests added while fixing something: no explanatory or banner comments inside test
bodies — keep them bare.
