#!/bin/bash
# Enable root login with no password for simplicity (Containerlab lab environment only)
mkdir -p /root/.ssh
echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config

# Start SSH server in the background
service ssh start

# Keep the container running (if needed)
tail -f /dev/null