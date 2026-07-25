#!/usr/bin/env bash
# tart-ssh-key.sh - authorize the automation key on a tart macOS guest.
#
#   ./tart-ssh-key.sh <ip> [user] [password] [pubkey]
#
# Defaults: user admin, password admin (the cirruslabs image default),
# pubkey ~/.ssh/wazuh-vmx.pub
#
# Uses expect because macOS ships no sshpass, and the guest starts with password
# auth only. Once the key is in place vmx never needs a password again.

set -euo pipefail

IP="${1:?usage: tart-ssh-key.sh <ip> [user] [password] [pubkey]}"
USER_NAME="${2:-admin}"
PASSWORD="${3:-admin}"
PUBKEY="${4:-$HOME/.ssh/wazuh-vmx.pub}"

[ -f "$PUBKEY" ] || { echo "no public key at $PUBKEY" >&2; exit 2; }
command -v expect >/dev/null || { echo "expect is required" >&2; exit 2; }

KEY="$(cat "$PUBKEY")"

expect <<EOF
set timeout 45
log_user 0
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    ${USER_NAME}@${IP} \
    "mkdir -p ~/.ssh && chmod 700 ~/.ssh && grep -qxF '${KEY}' ~/.ssh/authorized_keys 2>/dev/null || echo '${KEY}' >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys; echo KEY_OK"
expect {
    -re "assword:" { send "${PASSWORD}\r"; exp_continue }
    "KEY_OK"       { }
    timeout        { puts "TIMEOUT"; exit 1 }
    eof            { }
}
expect eof
EOF

# Verify without a password: that is the whole point.
if ssh -i "${PUBKEY%.pub}" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
       -o BatchMode=yes -o ConnectTimeout=10 "${USER_NAME}@${IP}" true 2>/dev/null; then
    echo "key auth OK for ${USER_NAME}@${IP}"
else
    echo "key auth still failing for ${USER_NAME}@${IP}" >&2
    exit 1
fi
