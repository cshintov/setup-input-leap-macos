# Input Leap Setup and Start Scripts

This repository provides two scripts to help you set up and start Input Leap (a KVM software) between a server (e.g., a Mac mini) and a client (e.g., a MacBook Pro).

## Scripts

- `setup-input-leap.sh`: Automates the initial setup of Input Leap, including downloading pre-built binaries, extracting them, and configuring the server and client.
- `start-input-leap.sh`: A convenience script to start the Input Leap server and client after the initial setup.

## Prerequisites

- **macOS**: These scripts are designed for macOS.
- **SSH Access**: SSH access must be configured between your server and client machines.
- **Curl**: `curl` must be installed on both machines.
- **Accessibility Permissions**: For Input Leap to control your mouse and keyboard, you must manually grant it permission in macOS System Settings (or System Preferences) on both the server and client machines.
  1. Go to **System Settings** (or System Preferences).
  2. Navigate to **Privacy & Security**.
  3. Click on **Accessibility**.
  4. Enable the toggle switch next to `input-leaps` (for the server) and `input-leapc` (for the client). You may need to click the lock icon and enter your password to make changes.

## Setup

1.  **Clone this repository** to your server machine.
2.  **Customize the scripts**: Open `setup-input-leap.sh` and `start-input-leap.sh` and update the `CLIENT_USER`, `CLIENT_HOST`, and `SERVER_HOST` variables with your specific details.
3.  **Run the setup script**: Execute `./setup-input-leap.sh` on your server machine. This will download and configure Input Leap on both machines.

## Usage

After the initial setup, you can use the `start-input-leap.sh` script to easily start Input Leap:

```bash
./start-input-leap.sh
```

## Troubleshooting

- **Synergy Conflicts**: If you have Synergy installed, it might conflict with Input Leap. The `setup-input-leap.sh` script attempts to stop Synergy processes, but you may need to manually ensure Synergy is not running.
- **Server Exits Immediately**: Ensure you have granted Accessibility permissions to `InputLeap.app` (or `input-leaps`) in your macOS System Settings.
- **Client Not Connecting**: Verify network connectivity between your server and client. Check firewalls and ensure hostnames resolve correctly.
