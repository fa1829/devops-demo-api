#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# server-setup.sh
# One-time setup script for the deployment server (Ubuntu 22.04+)
#
# Run this ONCE on a fresh server to prepare it for CI/CD deployments.
# After this runs, the GitHub Actions pipeline takes over all future deploys.
#
# Usage:
#   ssh user@your-server
#   curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/devops-demo-api/main/server-setup.sh | bash
#
# OR copy and run manually:
#   chmod +x server-setup.sh && ./server-setup.sh
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail  # Exit on error, unset variable, or pipe failure

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log()  { echo -e "${GREEN}[SETUP]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step() { echo -e "\n${BLUE}══════════════════════════════════════${NC}"; echo -e "${BLUE}  $1${NC}"; echo -e "${BLUE}══════════════════════════════════════${NC}"; }

# ── Verify we're on a supported OS ────────────────────────────────────────────
if [[ ! -f /etc/debian_version ]]; then
    err "This script requires Ubuntu/Debian. Detected: $(uname -a)"
fi

DEPLOY_USER=${1:-$USER}
APP_DIR="/home/${DEPLOY_USER}/devops-demo"

step "Server Setup for devops-demo-api"
log "Deploy user: ${DEPLOY_USER}"
log "App directory: ${APP_DIR}"

# ── 1. System update ──────────────────────────────────────────────────────────
step "1/6 — System Update"
sudo apt-get update -qq
sudo apt-get upgrade -y -qq
sudo apt-get install -y -qq \
    curl \
    wget \
    git \
    ufw \
    fail2ban \
    unattended-upgrades
log "System packages updated ✓"

# ── 2. Install Docker ─────────────────────────────────────────────────────────
step "2/6 — Docker Installation"
if command -v docker &>/dev/null; then
    log "Docker already installed: $(docker --version)"
else
    log "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo systemctl enable docker
    sudo systemctl start docker
    log "Docker installed: $(docker --version) ✓"
fi

# Add deploy user to docker group (no sudo needed for docker commands)
sudo usermod -aG docker "${DEPLOY_USER}"
log "Added ${DEPLOY_USER} to docker group ✓"

# Install Docker Compose v2
if docker compose version &>/dev/null 2>&1; then
    log "Docker Compose already available: $(docker compose version)"
else
    log "Installing Docker Compose plugin..."
    sudo apt-get install -y docker-compose-plugin
    log "Docker Compose installed: $(docker compose version) ✓"
fi

# ── 3. Set up app directory ───────────────────────────────────────────────────
step "3/6 — App Directory Setup"
mkdir -p "${APP_DIR}"
mkdir -p "${APP_DIR}/nginx"

# Copy docker-compose.yml and nginx.conf to server
# (These will be pulled from the repo in a real setup)
log "App directory created: ${APP_DIR} ✓"

# Create a placeholder docker-compose.yml the pipeline will use
cat > "${APP_DIR}/docker-compose.yml" << 'COMPOSE'
services:
  api:
    image: ${DOCKERHUB_USERNAME}/devops-demo-api:latest
    container_name: devops-demo-api
    restart: unless-stopped
    environment:
      - ENVIRONMENT=production
      - PORT=5000
      - APP_VERSION=${APP_VERSION:-unknown}
      - BUILD_TIME=${BUILD_TIME:-unknown}
    ports:
      - "5000:5000"
    healthcheck:
      test: ["CMD", "python", "-c",
             "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
    networks:
      - app-network

  nginx:
    image: nginx:1.27-alpine
    container_name: devops-demo-nginx
    restart: unless-stopped
    ports:
      - "80:80"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      api:
        condition: service_healthy
    networks:
      - app-network

networks:
  app-network:
    driver: bridge
COMPOSE

log "docker-compose.yml created ✓"

# ── 4. Firewall setup ─────────────────────────────────────────────────────────
step "4/6 — Firewall Configuration (UFW)"
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh          # Port 22
sudo ufw allow 80/tcp       # HTTP
sudo ufw allow 443/tcp      # HTTPS (for future SSL)
sudo ufw --force enable
log "Firewall rules applied ✓"
sudo ufw status

# ── 5. Fail2ban (brute force protection) ──────────────────────────────────────
step "5/6 — Fail2ban (SSH Brute Force Protection)"
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
log "fail2ban enabled ✓"

# ── 6. Verify setup ───────────────────────────────────────────────────────────
step "6/6 — Verification"
echo ""
log "Docker: $(docker --version)"
log "Docker Compose: $(docker compose version)"
log "Firewall: $(sudo ufw status | head -1)"
log "App dir: ${APP_DIR}"
echo ""

cat << 'DONE'
╔═══════════════════════════════════════════════════════════╗
║  ✅ SERVER SETUP COMPLETE                                  ║
║                                                           ║
║  Next steps:                                              ║
║  1. Add your SSH public key to ~/.ssh/authorized_keys     ║
║  2. Copy nginx/nginx.conf to ~/devops-demo/nginx/         ║
║  3. Add GitHub Secrets to your repo (see README.md)       ║
║  4. Push to main branch to trigger first deployment       ║
║                                                           ║
║  ⚠️  Log out and back in for docker group to take effect  ║
╚═══════════════════════════════════════════════════════════╝
DONE
