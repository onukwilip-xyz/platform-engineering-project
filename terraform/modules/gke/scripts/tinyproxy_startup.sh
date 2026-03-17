#!/usr/bin/env bash
set -euxo pipefail

apt-get update
apt-get install -y tinyproxy

# Listen on 8888
sed -i 's/^#\?Port .*/Port 8888/' /etc/tinyproxy/tinyproxy.conf

# Allow localhost (so SSH local-forward works cleanly)
grep -q '^Allow localhost$' /etc/tinyproxy/tinyproxy.conf || echo "Allow localhost" >> /etc/tinyproxy/tinyproxy.conf

systemctl enable --now tinyproxy
systemctl restart tinyproxy