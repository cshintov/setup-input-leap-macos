#!/bin/bash

# Exit on any error and treat unset variables as errors
set -e
set -u
set -o pipefail

# === Config ===
CLIENT_USER="your_client_username" # Customize this
CLIENT_HOST="your_client_hostname.local" # Customize this
SERVER_HOST="your_server_hostname.local" # Customize this
INPUT_LEAP_VERSION=${1:-"v3.0.3"} # Default to v3.0.3, or use first argument
DOWNLOAD_URL="https://github.com/input-leap/input-leap/releases/download/${INPUT_LEAP_VERSION}/macOS-Apple_Silicon-debug-${INPUT_LEAP_VERSION}.tar.gz"
INPUTLEAP_REPO="https://github.com/input-leap/input-leap.git"
INSTALL_DIR="$PWD/input-leap"
CONFIG_FILE="$HOME/input-leap.sgc"

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

# === Stop conflicting Synergy processes ===
echo "🛑 Stopping any conflicting Synergy processes on server..."
launchctl unload ~/Library/LaunchAgents/com.symless.synergy3.plist 2>/dev/null || true
pkill -f "synergy-service" 2>/dev/null || true
pkill -f "synergy-core" 2>/dev/null || true
pkill -f "synergy-tray" 2>/dev/null || true
echo "✅ Synergy processes stopped on server."

echo "🛑 Stopping any conflicting Synergy processes on client ($CLIENT_HOST)..."
ssh -o ConnectTimeout=10 "$CLIENT_USER@$CLIENT_HOST" bash <<'EOSSH_SYNERGY_KILL'
  launchctl unload ~/Library/LaunchAgents/com.symless.synergy3.plist 2>/dev/null || true
  pkill -f "synergy-service" 2>/dev/null || true
  pkill -f "synergy-core" 2>/dev/null || true
  pkill -f "synergy-tray" 2>/dev/null || true
EOSSH_SYNERGY_KILL
echo "✅ Synergy processes stopped on client."

# === Install prerequisites (minimal) ===
echo "📦 Installing curl (for downloading)..."
# Most systems have curl already, but just in case
which curl >/dev/null 2>&1 || brew install curl
echo "✅ Prerequisites ready"

# === Download prebuilt Input Leap ===
echo "📥 Ensuring Input Leap is available for Apple Silicon..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

if [ ! -f "input-leap.tar.gz" ]; then
    echo "📥 Downloading prebuilt Input Leap for Apple Silicon..."
    curl -L "$DOWNLOAD_URL" -o input-leap.tar.gz
    check_command_success "Downloading Input Leap"
else
    echo "✅ Input Leap archive already exists."
fi

echo "📦 Extracting Input Leap..."
tar -xzf input-leap.tar.gz
check_command_success "Extracting Input Leap"

# Extract the nested archive
echo "📦 Extracting nested archive..."
cd macOS-Apple_Silicon-debug
tar -xzf InputLeap-macOS-Apple_Silicon.tar.gz
check_command_success "Extracting nested archive"

# Find the binaries
EXTRACTED_DIR="InputLeap.app/Contents/MacOS"

echo "🔍 Found binaries in: $EXTRACTED_DIR"
echo "✅ Input Leap downloaded and extracted successfully"

# === Create config ===
echo "📝 Creating shared config..."
cat > "$CONFIG_FILE" <<EOF
section: screens
  $SERVER_HOST:
  $CLIENT_HOST:
end

section: links
  $SERVER_HOST:
    right = $CLIENT_HOST
  $CLIENT_HOST:
    left = $SERVER_HOST
end

section: options
  clipboardSharing = true
  screenSaverSync = false
end
EOF

# === Start server ===
echo "🚀 Starting Input Leap server..."
pkill input-leaps 2>/dev/null || true

# Verify server binary exists before starting
SERVER_BINARY="$INSTALL_DIR/macOS-Apple_Silicon-debug/InputLeap.app/Contents/MacOS/input-leaps"
if [ ! -f "$SERVER_BINARY" ]; then
    echo "❌ Server binary not found at $SERVER_BINARY"
    exit 1
fi

"$SERVER_BINARY" --no-tray --config "$CONFIG_FILE" --daemon --log "$INSTALL_DIR/input-leaps.log" --address 0.0.0.0 &
sleep 5 # Give the server a moment to start as a daemon

# Verify server is running
if ! ps aux | grep "$SERVER_BINARY" | grep -v grep > /dev/null; then
    echo "❌ Failed to start Input Leap server."
    exit 1
fi
echo "✅ Server started"

# === Prepare client remotely ===
echo "📡 Setting up MacBook Pro client ($CLIENT_HOST)..."
ssh -o ConnectTimeout=30 "$CLIENT_USER@$CLIENT_HOST" bash <<EOSSH
  set -e
  set -u
  set -o pipefail
  
  echo "📦 Installing curl on client (for downloading)..."
  # Most systems have curl already, but just in case
  which curl >/dev/null 2>&1 || brew install curl
  
  echo "📥 Ensuring Input Leap is available on client..."
  mkdir -p ~/input-leap
  cd ~/input-leap
  
  if [ ! -f "input-leap.tar.gz" ]; then
      echo "📥 Downloading prebuilt Input Leap on client..."
      curl -L "${DOWNLOAD_URL}" -o input-leap.tar.gz
  else
      echo "✅ Input Leap archive already exists on client."
  fi
  
  echo "📦 Extracting Input Leap on client..."
  tar -xzf input-leap.tar.gz
  
  # Extract the nested archive
  echo "📦 Extracting nested archive on client..."
  cd macOS-Apple_Silicon-debug
  tar -xzf InputLeap-macOS-Apple_Silicon.tar.gz
  
  # Find the binaries
  EXTRACTED_DIR="InputLeap.app/Contents/MacOS"
  
  echo "🔍 Found client binaries in: $EXTRACTED_DIR"
  echo "✅ Input Leap downloaded and extracted on client"
EOSSH
check_command_success "Remote client setup"

# === Copy config to client ===
echo "📤 Copying config to client..."
scp "$CONFIG_FILE" "$CLIENT_USER@$CLIENT_HOST:~/input-leap.sgc"
check_command_success "Copying config file"

# === Start client ===
echo "🚀 Starting Input Leap client..."
ssh -o ConnectTimeout=10 "$CLIENT_USER@$CLIENT_HOST" bash <<EOF
  set -e
  cd ~/input-leap/macOS-Apple_Silicon-debug
  
  CLIENT_BINARY="\$HOME/input-leap/macOS-Apple_Silicon-debug/InputLeap.app/Contents/MacOS/input-leapc"
  
  echo "🔍 Verifying client binary exists at \$CLIENT_BINARY..."
  if [ ! -f "\$CLIENT_BINARY" ]; then
    echo "❌ Client binary not found at \$CLIENT_BINARY"
    exit 1
  fi
  
  echo "🚀 Starting Input Leap client..."
  pkill input-leapc 2>/dev/null || true
  "\$CLIENT_BINARY" --no-tray --name $CLIENT_HOST $SERVER_HOST &
  sleep 2
  echo "✅ Client started"
EOF
check_command_success "Starting client"

# === Done ===
echo "✅ Input Leap is set up and running. Move your mouse to the right to control the MacBook Pro."