```bash
bin/vmx list                                      # instances, state, arch
bin/vmx doctor                                    # host prerequisites
bin/vmx doctor agent-win11-arm                  # guest prerequisites
bin/vmx up builder-ubuntu-arm
bin/vmx up aio-ubuntu-arm agent-debian-arm    # E2E topology
bin/vmx sync builder-ubuntu-arm
bin/vmx deps builder-ubuntu-arm TARGET=winagent # once per VM
bin/vmx build builder-ubuntu-arm TARGET=manager TEST=1 --json
bin/vmx test builder-ubuntu-arm --ctest-filter dbsync
bin/vmx exec builder-ubuntu-arm -- uname -a
bin/vmx exec agent-win11-arm --record docs/37191/evidence/run.log -- <cmd>
bin/vmx winagent --issue 37534
bin/vmx collect agent-win11-arm --issue 37191 --from 'C:/.../ossec.log'
bin/vmx fetch agent-win11-arm '~/*.msi' --issue 37534
```
