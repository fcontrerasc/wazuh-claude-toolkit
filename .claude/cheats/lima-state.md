```bash
limactl list                                  # state, arch, ssh port
limactl list --json | jq -r '.name+" "+.status'
limactl start builder-ubuntu-arm
limactl stop builder-ubuntu-arm             # rarely: no cleanup policy
ssh -F ~/.lima/builder-ubuntu-arm/ssh.config lima-builder-ubuntu-arm
limactl shell builder-ubuntu-arm -- nproc
limactl edit builder-ubuntu-arm             # cpus/memory/disk
limactl create --name=X --arch=x86_64 --network=lima:bridged template://ubuntu-22.04
limactl factory-reset builder-ubuntu-arm    # destructive
```
