#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

INSTALL_DIR="${ECHOLAB_DIR:-/opt/echolab}"
CONFIG_DIR="$INSTALL_DIR/config"

echo -e "${YELLOW}EchoLab - Uninstaller${NC}"
echo

# Stop containers - check both old location and new config directory
if [ -f "$CONFIG_DIR/docker-compose.yml" ]; then
    echo "Stopping EchoLab containers..."
    cd "$CONFIG_DIR" && docker compose down
    echo -e "${GREEN}✓ Containers stopped${NC}"
elif [ -f "$INSTALL_DIR/docker-compose.yml" ]; then
    # Legacy location
    echo "Stopping EchoLab containers (legacy location)..."
    cd "$INSTALL_DIR" && docker compose down
    echo -e "${GREEN}✓ Containers stopped${NC}"
else
    echo -e "${YELLOW}No installation found at $INSTALL_DIR${NC}"
fi

# Remove mDNS service
if [ -f /etc/avahi/services/echolab.service ]; then
    echo "Removing mDNS service..."
    sudo rm -f /etc/avahi/services/echolab.service
    sudo systemctl restart avahi-daemon
    echo -e "${GREEN}✓ mDNS service removed${NC}"
fi

# Ask about data removal
echo
echo -e "${YELLOW}Remove all data (clips, config, volumes)?${NC}"
echo "This will delete:"
echo "  - Directory: $INSTALL_DIR"
echo "  - Docker volumes: echolab_clips, echolab_logs, echolab_config, echolab_ssl"
read -p "Are you sure? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo rm -rf "$INSTALL_DIR"
    echo -e "${GREEN}✓ Removed $INSTALL_DIR${NC}"

    # Remove Docker volumes
    echo "Removing Docker volumes..."
    docker volume rm echolab_clips echolab_logs echolab_config echolab_ssl 2>/dev/null || true
    echo -e "${GREEN}✓ Removed Docker volumes${NC}"
else
    echo "Data preserved at $INSTALL_DIR"
    echo "Docker volumes preserved (use 'docker volume rm' to remove manually)"
fi

echo
echo -e "${GREEN}Uninstall complete.${NC}"
