#!/bin/bash

# Exit on any error and treat unset variables as errors
set -e
set -u
set -o pipefail

# === Config ===
CLIENT_USER="your_client_username" # Customize this
CLIENT_HOST="your_client_hostname.local" # Customize this
SERVER_HOST="your_server_hostname.local" # Customize this
INSTALL_DIR="$PWD/input-leap"
CONFIG_FILE="$HOME/input-leap.sgc"

SERVER_BINARY="$INSTALL_DIR/macOS-Apple_Silicon-debug/InputLeap.app/Contents/MacOS/input-leaps"
CLIENT_BINARY="$HOME/input-leap/macOS-Apple_Silicon-debug/InputLeap.app/Contents/MacOS/input-leapc"

# === Helper functions ===
check_ssh_connection() {
    echo "🔍 Checking SSH connection to $CLIENT_HOST..."
    if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$CLIENT_USER@$CLIENT_HOST" true 2>/dev/null; then
        echo "❌ Cannot connect to $CLIENT_HOST. Please check SSH setup."
        exit 1
    fi
    echo "✅ SSH connection verified"
}

check_command_success() {
    if [ $? -ne 0 ]; then
        echo "❌ Command failed: $1"
        exit 1
    fi
}

# === Check SSH connectivity first ===
check_ssh_connection

# === Start server ===
echo "🚀 Starting Input Leap server..."
pkill input-leaps 2>/dev/null || true

if [ ! -f "$SERVER_BINARY" ]; then
    echo "❌ Server binary not found at $SERVER_BINARY. Please run setup-input-leap.sh first."
    exit 1
fi

"$SERVER_BINARY" --no-tray --config "$CONFIG_FILE" --daemon --log "$INSTALL_DIR/input-leaps.log" --address 0.0.0.0 &
sleep 2 # Give the server a moment to start as a daemon

if ! ps aux | grep "$SERVER_BINARY" | grep -v grep > /dev/null; then
    echo "❌ Failed to start Input Leap server."
    exit 1
fi
echo "✅ Server started"

# === Start client ===
echo "🚀 Starting Input Leap client..."
ssh -o ConnectTimeout=10 "$CLIENT_USER@$CLIENT_HOST" bash <<EOF
  set -e
  pkill input-leapc 2>/dev/null || true
  
  if [ ! -f "$CLIENT_BINARY" ]; then
    echo "❌ Client binary not found at $CLIENT_BINARY. Please run setup-input-leap.sh on the client first."
    exit 1
  fi
  
  "$CLIENT_BINARY" --no-tray --name $CLIENT_HOST $SERVER_HOST &
  sleep 2
  echo "✅ Client started"
EOF
check_command_success "Starting client"

echo "✅ Input Leap server and client started. Move your mouse to the right to control the MacBook Pro."
