#!/usr/bin/env bats

# Test suite for EchoLab installer
# Run with: bats test/install.bats

setup() {
    export INSTALL_DIR="/tmp/echolab-test-$$"
    export TEST_MODE=1
}

teardown() {
    rm -rf "$INSTALL_DIR" 2>/dev/null || true
}

@test "install script exists and is executable" {
    [ -f "install.sh" ]
    [ -x "install.sh" ] || chmod +x install.sh
}

@test "docker-compose.yml exists" {
    [ -f "docker-compose.yml" ]
}

@test "docker-compose.yml has required services" {
    grep -q "backend:" docker-compose.yml
    grep -q "frontend:" docker-compose.yml
    grep -q "updater:" docker-compose.yml
}

@test "docker-compose.yml uses correct image registry" {
    grep -q "ghcr.io/liamgallagher/echolab" docker-compose.yml
}

@test "docker-compose.yml has health checks" {
    grep -q "healthcheck:" docker-compose.yml
}

@test "uninstall script exists" {
    [ -f "uninstall.sh" ]
}

@test "setup-mdns script exists" {
    [ -f "setup-mdns.sh" ]
}

@test "install script has correct INSTALLER_URL" {
    grep -q "https://raw.githubusercontent.com/liamgallagher/echolab-installer/main" install.sh
}

@test "install script downloads docker-compose.yml" {
    grep -q 'INSTALLER_URL/docker-compose.yml' install.sh
}

@test "install script checks for docker" {
    grep -q "command -v docker" install.sh
}

@test "install script sets up mDNS" {
    grep -q "avahi" install.sh
}

@test "uninstall script removes mDNS service" {
    grep -q "/etc/avahi/services/echolab.service" uninstall.sh
}

@test "default HTTPS port is 8443" {
    grep -q "REPLAY_HTTPS_PORT:-8443" install.sh
    grep -q "REPLAY_HTTPS_PORT:-8443" docker-compose.yml
}

@test "default HTTP port is 8080" {
    grep -q "REPLAY_HTTP_PORT:-8080" install.sh
    grep -q "REPLAY_HTTP_PORT:-8080" docker-compose.yml
}

@test "install script uses sg docker for group activation" {
    grep -q "sg docker" install.sh
}

@test "docker-compose.yml does not contain GHCR_TOKEN" {
    ! grep -q "GHCR_TOKEN" docker-compose.yml
}

@test "install script does not contain GHCR_TOKEN" {
    ! grep -q "GHCR_TOKEN" install.sh
}
