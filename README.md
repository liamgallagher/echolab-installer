# EchoLab Installer

One-liner installer for [EchoLab](https://github.com/liamgallagher/echolab) - a delayed video replay application for training and coaching.

## Quick Install

```bash
curl -sSL https://raw.githubusercontent.com/liamgallagher/echolab-installer/main/install.sh | bash
```

## What It Does

The installer:

1. **Installs Docker** if not present (uses get.docker.com)
2. **Installs Docker Compose** plugin if needed
3. **Configures GPU monitoring** for Intel GPU utilization (sets `perf_event_paranoid=2`)
4. **Creates directories** at `/opt/echolab/config/`
5. **Downloads docker-compose.yml** to the config directory
6. **Sets up mDNS** via avahi-daemon for `echolab.local` access
7. **Starts containers** (backend, frontend, updater)

## Directory Structure

```
/opt/echolab/
└── config/
    ├── docker-compose.yml   # Production compose file (canonical location)
    ├── config.json          # Camera settings, presets, etc.
    └── activation.json      # License activation data
```

Docker volumes are used for:
- `echolab_clips` - Saved video clips
- `echolab_logs` - Application logs
- `echolab_ssl` - SSL certificates

Video segments are stored in RAM (tmpfs) to prevent disk wear.

## How Updates Work

1. The **updater service** reads `docker-compose.yml` from the config volume
2. When you change the update channel (Settings > System), the backend syncs image tags in the compose file
3. Updates pull images matching the channel (`:latest` for beta, `:stable` for stable, `:alpha` for alpha)
4. The updater downloads compose from this repo if the file is missing (migration path for existing installs)

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ECHOLAB_DIR` | `/opt/echolab` | Installation directory |
| `REPLAY_HTTPS_PORT` | `443` | HTTPS port (host networking) |
| `REPLAY_HTTP_PORT` | `80` | HTTP port (redirects to HTTPS) |
| `MDNS_HOSTNAME` | `echolab` | mDNS hostname (access via `{hostname}.local`) |

## Manual Management

```bash
# View logs
cd /opt/echolab/config && docker compose logs -f

# Restart services
cd /opt/echolab/config && docker compose restart

# Stop all services
cd /opt/echolab/config && docker compose down

# Start services
cd /opt/echolab/config && docker compose up -d

# Pull latest images manually
cd /opt/echolab/config && docker compose pull && docker compose up -d
```

## Uninstall

```bash
# Stop containers and remove volumes (clips, logs, ssl)
cd /opt/echolab/config && docker compose down -v

# Remove config directory
sudo rm -rf /opt/echolab

# Remove mDNS advertisement (optional)
sudo rm -f /etc/avahi/services/echolab.service && sudo systemctl restart avahi-daemon
```

## Requirements

- Linux (tested on Ubuntu 22.04, Debian 12)
- Docker (installed automatically if missing)
- Intel GPU recommended for hardware-accelerated encoding
- Network access to GitHub Container Registry (ghcr.io)

## Troubleshooting

### Services won't start

Check logs:
```bash
cd /opt/echolab/config && docker compose logs
```

### GPU encoding not working

Verify GPU access:
```bash
ls -la /dev/dri/
```

Check if backend detects GPU:
```bash
docker exec echolab-backend cat /proc/sys/kernel/perf_event_paranoid
```

### mDNS not working

Restart avahi:
```bash
sudo systemctl restart avahi-daemon
```

Check if service is advertised:
```bash
avahi-browse -a | grep echolab
```

### Port conflicts

If ports 80/443 are in use, set custom ports:
```bash
REPLAY_HTTPS_PORT=8443 REPLAY_HTTP_PORT=8080 curl -sSL .../install.sh | bash
```
