#!/bin/bash
# Standalone mDNS setup for existing EchoLab installations
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

HTTPS_PORT="${REPLAY_HTTPS_PORT:-8443}"

echo -e "${YELLOW}Setting up echolab.local...${NC}"

if ! command -v avahi-daemon &> /dev/null; then
    echo "Installing avahi-daemon..."
    sudo apt-get update && sudo apt-get install -y avahi-daemon
fi

sudo tee /etc/avahi/services/echolab.service > /dev/null << EOF
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name>EchoLab Video Replay</name>
  <service>
    <type>_https._tcp</type>
    <port>${HTTPS_PORT}</port>
  </service>
</service-group>
EOF

sudo systemctl enable avahi-daemon
sudo systemctl restart avahi-daemon

echo -e "${GREEN}Done!${NC} Access via: https://echolab.local:${HTTPS_PORT}"
