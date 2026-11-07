#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Check if node is installed
if ! command -v node >/dev/null 2>&1; then
  echo "Error: Node.js is not found in PATH."
  echo "rdphiro (MeshCentral) requires Node.js >= 22.12.0."
  echo "You can install Node.js on Arch/CachyOS via:"
  echo "    sudo pacman -S nodejs npm"
  echo "or install NVM via:"
  echo "    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash"
  echo "    nvm install 22"
  exit 1
fi

NODE_VERSION=$(node -v | sed 's/v//')
MAJOR_VERSION=$(echo "$NODE_VERSION" | cut -d'.' -f1)

if [ "$MAJOR_VERSION" -lt 22 ]; then
  echo "Warning: Current Node.js version is v$NODE_VERSION."
  echo "MeshCentral requires Node.js >= 22.12.0. Please upgrade Node.js if you encounter issues."
fi

# Ensure node_modules exist
if [ ! -d "$PROJECT_DIR/node_modules" ]; then
  echo "Installing dependencies (npm install)..."
  npm install --production
fi

echo "Starting rdphiro locally..."
echo "Config: $PROJECT_DIR/meshcentral-data/config.json"
echo "Web URL: https://localhost:4430 (or http://localhost:8080)"
echo "Press Ctrl+C to stop."

exec node "$PROJECT_DIR/meshcentral.js" --datapath "$PROJECT_DIR/meshcentral-data"
