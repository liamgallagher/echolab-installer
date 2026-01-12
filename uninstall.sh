#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

INSTALL_DIR="${ECHOLAB_DIR:-/opt/echolab}"

echo -e "${YELLOW}EchoLab - Uninstaller${NC}"
echo

# Stop containers
if [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/docker-compose.yml" ]; then
    echo "Stopping EchoLab containers..."
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
echo -e "${YELLOW}Remove all data (segments, clips, config)?${NC}"
echo "This will delete: $INSTALL_DIR"
read -p "Are you sure? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo rm -rf "$INSTALL_DIR"
    echo -e "${GREEN}✓ Removed $INSTALL_DIR${NC}"
else
    echo "Data preserved at $INSTALL_DIR"
fi

echo
echo -e "${GREEN}Uninstall complete.${NC}"
