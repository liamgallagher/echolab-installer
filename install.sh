#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

INSTALL_DIR="${ECHOLAB_DIR:-/opt/echolab}"
HTTPS_PORT="${REPLAY_HTTPS_PORT:-8443}"
HTTP_PORT="${REPLAY_HTTP_PORT:-8080}"
INSTALLER_URL="https://raw.githubusercontent.com/liamgallagher/echolab-installer/main"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}EchoLab - Installer${NC}"
echo -e "${GREEN}========================================${NC}"
echo

# Check for Docker, install if missing
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker not found. Installing...${NC}"
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker $USER
    echo -e "${GREEN}✓ Docker installed${NC}"
    echo
    echo -e "${YELLOW}Activating docker group and continuing installation...${NC}"
    # Use sg to activate the docker group and re-run this script
    exec sg docker -c "curl -sSL $INSTALLER_URL/install.sh | bash"
fi
echo -e "${GREEN}✓ Docker is installed${NC}"

# Check for Docker Compose
if ! docker compose version &> /dev/null; then
    echo -e "${YELLOW}Docker Compose not found. Installing...${NC}"
    sudo apt-get update && sudo apt-get install -y docker-compose-plugin
    echo -e "${GREEN}✓ Docker Compose installed${NC}"
fi
echo -e "${GREEN}✓ Docker Compose is available${NC}"

# Verify docker works
if ! docker info &> /dev/null; then
    echo -e "${RED}Cannot connect to Docker. You may need to log out and back in.${NC}"
    echo "Then re-run: curl -sSL $INSTALLER_URL/install.sh | bash"
    exit 1
fi

# Configure GPU monitoring permissions
echo
echo -e "${YELLOW}Configuring GPU monitoring permissions...${NC}"

# Detect if running in a container (LXC/Docker) vs bare metal/VM
is_container() {
    # Check for LXC
    if [ -f /proc/1/environ ] && grep -qa 'container=lxc' /proc/1/environ 2>/dev/null; then
        return 0
    fi
    # Check for Docker
    if [ -f /.dockerenv ]; then
        return 0
    fi
    # Check cgroup for container indicators
    if grep -qa 'docker\|lxc\|kubepod' /proc/1/cgroup 2>/dev/null; then
        return 0
    fi
    return 1
}

PERF_PARANOID=$(cat /proc/sys/kernel/perf_event_paranoid 2>/dev/null || echo "unknown")

if [ "$PERF_PARANOID" = "unknown" ]; then
    echo -e "${YELLOW}⚠ Could not read perf_event_paranoid${NC}"
elif [ "$PERF_PARANOID" -le 2 ]; then
    echo -e "${GREEN}✓ GPU monitoring already configured (perf_event_paranoid=$PERF_PARANOID)${NC}"
elif is_container; then
    echo -e "${YELLOW}⚠ Running in a container - cannot modify kernel parameters${NC}"
    echo -e "${YELLOW}  For GPU utilization monitoring, run this on your Proxmox/host:${NC}"
    echo -e "    echo 'kernel.perf_event_paranoid = 2' > /etc/sysctl.d/99-echolab-gpu.conf"
    echo -e "    sysctl -p /etc/sysctl.d/99-echolab-gpu.conf"
else
    # Bare metal or VM - can modify sysctl
    echo "kernel.perf_event_paranoid = 2" | sudo tee /etc/sysctl.d/99-echolab-gpu.conf > /dev/null
    if sudo sysctl -p /etc/sysctl.d/99-echolab-gpu.conf > /dev/null 2>&1; then
        echo -e "${GREEN}✓ GPU monitoring enabled (perf_event_paranoid=2)${NC}"
    else
        echo -e "${YELLOW}⚠ Could not apply sysctl change - GPU utilization may not work${NC}"
    fi
fi

# Create install directory
echo
echo -e "${YELLOW}Creating installation directory...${NC}"
sudo mkdir -p "$INSTALL_DIR"
sudo chown $USER:$USER "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Download docker-compose.yml
echo -e "${YELLOW}Downloading configuration...${NC}"
curl -sSL $INSTALLER_URL/docker-compose.yml -o docker-compose.yml
echo -e "${GREEN}✓ Configuration downloaded${NC}"

# Create data directories
echo -e "${YELLOW}Creating data directories...${NC}"
mkdir -p data/segments data/clips data/config data/logs
if [ ! -f data/config/cameras.json ]; then
    echo '{"cameras": {}, "presets": {}}' > data/config/cameras.json
fi
chmod -R 755 data/
echo -e "${GREEN}✓ Data directories ready${NC}"

# Setup mDNS
echo
echo -e "${YELLOW}Configuring local network discovery (echolab.local)...${NC}"
if ! command -v avahi-daemon &> /dev/null; then
    echo "Installing avahi-daemon..."
    sudo apt-get update && sudo apt-get install -y avahi-daemon
fi

# Detect primary network interface (the one with default route)
# This prevents Avahi from advertising on Docker bridges (172.17.x.x)
PRIMARY_IF=$(ip route | grep default | awk '{print $5}' | head -1)
if [ -n "$PRIMARY_IF" ]; then
    echo "Configuring Avahi for interface: $PRIMARY_IF"
    # Enable allow-interfaces with the primary interface
    sudo sed -i "s/^#allow-interfaces=.*/allow-interfaces=${PRIMARY_IF}/" /etc/avahi/avahi-daemon.conf
    # If the line doesn't exist (wasn't commented), add it
    if ! grep -q "^allow-interfaces=" /etc/avahi/avahi-daemon.conf; then
        sudo sed -i "/^\[server\]/a allow-interfaces=${PRIMARY_IF}" /etc/avahi/avahi-daemon.conf
    fi
else
    echo -e "${YELLOW}⚠ Could not detect primary interface, Avahi may advertise on Docker IPs${NC}"
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
echo -e "${GREEN}✓ mDNS configured (echolab.local)${NC}"

# Enable Docker service for boot
echo
echo -e "${YELLOW}Enabling Docker service for system boot...${NC}"
if systemctl is-enabled docker >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Docker service already enabled${NC}"
else
    sudo systemctl enable docker
    echo -e "${GREEN}✓ Docker service enabled${NC}"
fi

# Start containers
echo
echo -e "${YELLOW}Pulling and starting containers...${NC}"
docker compose pull
docker compose up -d

# Wait for health
echo
echo -e "${YELLOW}Waiting for services to start...${NC}"
sleep 10

# Check services
if docker compose ps | grep -q "echolab-backend"; then
    echo -e "${GREEN}✓ Backend is running${NC}"
else
    echo -e "${RED}✗ Backend failed to start${NC}"
fi

if docker compose ps | grep -q "echolab-frontend"; then
    echo -e "${GREEN}✓ Frontend is running${NC}"
else
    echo -e "${RED}✗ Frontend failed to start${NC}"
fi

# Get local IP
LOCAL_IP=$(hostname -I | awk '{print $1}')

echo
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo
echo "Access EchoLab at:"
echo -e "  mDNS:    ${GREEN}https://echolab.local:${HTTPS_PORT}${NC}"
echo -e "  Local:   ${GREEN}https://localhost:${HTTPS_PORT}${NC}"
echo -e "  Network: ${GREEN}https://${LOCAL_IP}:${HTTPS_PORT}${NC}"
echo
echo -e "${YELLOW}Note:${NC} Your browser will show a certificate warning."
echo "This is expected for self-signed certificates."
echo
echo "Installed to: $INSTALL_DIR"
echo "Manage with: cd $INSTALL_DIR && docker compose [up|down|logs]"
echo
echo "Next steps:"
echo "  1. Open the web interface in your browser"
echo "  2. Go to Settings and add your camera RTSP URLs"
echo "  3. Cameras will auto-start on next reboot"
