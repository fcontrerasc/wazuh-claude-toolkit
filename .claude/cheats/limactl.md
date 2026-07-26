```bash
limactl list                                    # name, state, arch, ssh port
limactl start agent-ubuntu-amd
limactl stop agent-ubuntu-amd                   # stop, never delete
limactl shell agent-ubuntu-amd -- nproc
ssh -F ~/.lima/agent-ubuntu-amd/ssh.config lima-agent-ubuntu-amd
limactl create --name=N --arch=x86_64 --tty=false --set='.user.name="wazuh"' --set='.mounts=[]' --network=lima:bridged template://ubuntu-24.04
limactl edit N --set '.mounts=[]' --tty=false   # stop the instance first
limactl delete -f N                             # destructive
limactl sudoers --check                         # after networks.yaml edits
limactl sudoers > /tmp/l && sudo install -o root /tmp/l /private/etc/sudoers.d/lima
brew install lima-additional-guestagents        # required for x86_64 guests
grep -A2 bridged ~/.lima/_config/networks.yaml  # interface must be the LAN one
limactl shell N -- ip -4 -o addr show lima0     # bridged address
```
