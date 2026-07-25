```bash
bin/wzfmt --which src/shared_modules/utils/x.h   # clang-format|astyle|none
bin/wzfmt --check <file>                          # exit 1 if it would change
bin/wzfmt --write <file>
bin/wzfmt --staged                                # pre-push parity
bin/wzfmt --list-scope                            # derived CI scopes
WAZUH_CLANG_FORMAT=/path/clang-format bin/wzfmt --check <file>
bin/vmx exec kernel-ubuntu-amd -- bin/wzfmt --staged   # authoritative
```
