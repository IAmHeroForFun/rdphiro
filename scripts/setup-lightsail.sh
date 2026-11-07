#!/usr/bin/env bash
# ==============================================================================
# rdphiro - AWS Lightsail Automated Setup Script (Ubuntu 22.04 / 24.04 LTS)
# ==============================================================================
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (e.g. sudo bash scripts/setup-lightsail.sh)"
  exit 1
fi

INSTALL_DIR="/opt/rdphiro"

echo "=== [1/6] Updating package cache and installing prerequisites ==="
apt-get update -y
apt-get install -y curl git libcap2-bin build-essential

echo "=== [2/6] Installing Node.js 22 LTS ==="
if ! command -v node >/dev/null 2>&1 || [ "$(node -v | cut -d'.' -f1 | tr -d 'v')" -lt 22 ]; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
fi

NODE_BIN=$(command -v node)
echo "Node.js installed: $("$NODE_BIN" -v)"
echo "NPM installed: $(npm -v)"

echo "=== [3/6] Setting Linux capabilities for privileged port binding (80/443) ==="
# Allows node to bind to ports 80 and 443 without root privileges
setcap 'cap_net_bind_service=+ep' "$NODE_BIN"

echo "=== [4/6] Creating dedicated service user 'rdphiro' ==="
if ! id -u rdphiro >/dev/null 2>&1; then
  useradd -r -s /usr/sbin/nologin -d "$INSTALL_DIR" rdphiro
  echo "Created system user 'rdphiro'."
fi

echo "=== [5/6] Setting directory permissions and installing dependencies ==="
mkdir -p "$INSTALL_DIR/meshcentral-data" "$INSTALL_DIR/meshcentral-files" "$INSTALL_DIR/meshcentral-backups"
cd "$INSTALL_DIR"
npm install --production

# If config.json doesn't exist, create it from template
if [ ! -f "$INSTALL_DIR/meshcentral-data/config.json" ]; then
  if [ -f "$INSTALL_DIR/config.lightsail.json.template" ]; then
    cp "$INSTALL_DIR/config.lightsail.json.template" "$INSTALL_DIR/meshcentral-data/config.json"
    echo "Created $INSTALL_DIR/meshcentral-data/config.json from template."
    echo "IMPORTANT: Edit this file to insert your real domain and email for Let's Encrypt."
  fi
fi

chown -R rdphiro:rdphiro "$INSTALL_DIR"

echo "=== [6/6] Installing and starting systemd service ==="
cp "$INSTALL_DIR/systemd/rdphiro.service" /etc/systemd/system/rdphiro.service
systemctl daemon-reload
systemctl enable rdphiro.service

echo ""
echo "=============================================================================="
echo " Setup Complete! "
echo "=============================================================================="
echo "Next Steps:"
echo "1. Edit /opt/rdphiro/meshcentral-data/config.json and set your real domain name."
echo "2. Start the service:"
echo "       sudo systemctl start rdphiro"
echo "3. Check service status:"
echo "       sudo systemctl status rdphiro"
echo "       sudo journalctl -u rdphiro -f"
echo "4. Ensure Lightsail Firewall has Ports 80 and 443 OPEN."
echo "=============================================================================="
