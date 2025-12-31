#!/bin/bash

###############################################################################
# ArchMode Installation Script
###############################################################################

set -euo pipefail

echo "╔════════════════════════════════════════╗"
echo "║     ArchMode Installation Script       ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Check if running on Arch Linux
if !  grep -qi "arch" /etc/os-release; then
    echo "⚠ Warning: This script is designed for Arch Linux"
    read -p "Continue anyway? (y/N): " continue
    [[ !  "$continue" =~ ^[Yy]$ ]] && exit 0
fi

# Installation paths
INSTALL_DIR="/usr/local/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "📦 Installing ArchMode..."

# Copy main script
echo "  → Copying archmode to $INSTALL_DIR"
sudo cp "$SCRIPT_DIR/archmode. sh" "$INSTALL_DIR/archmode"
sudo chmod +x "$INSTALL_DIR/archmode"

# Create symlink for easier access
if !  command -v archmode &> /dev/null; then
    echo "  → Setting up command alias"
    sudo ln -sf "$INSTALL_DIR/archmode" "$INSTALL_DIR/am" || true
fi

# Create systemd service (optional)
echo "  → Setting up systemd integration"
sudo tee /etc/systemd/system/archmode.service > /dev/null << 'EOF'
[Unit]
Description=ArchMode Daemon
Documentation=https://github.com/theofficalnoodles/archmode

[Service]
Type=simple
User=%i
ExecStart=/usr/local/bin/archmode daemon
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Set up sudoers configuration
echo "  → Configuring sudo permissions"
sudo tee /etc/sudoers. d/archmode > /dev/null << 'EOF'
# ArchMode sudoers configuration
# Allows archmode to run certain commands without password prompt

Defaults! ARCHMODE_CMDS authenticate, timestamp_timeout=15

# Allow certain commands without password
%wheel ALL=(ALL) NOPASSWD: /usr/bin/systemctl
%wheel ALL=(ALL) NOPASSWD: /usr/bin/tee /sys/devices/system/cpu/*
%wheel ALL=(ALL) NOPASSWD: /usr/bin/tee /sys/module/usb_core/*
%wheel ALL=(ALL) NOPASSWD: /usr/bin/nbfc
EOF

sudo chmod 0440 /etc/sudoers. d/archmode

echo ""
echo "✓ Installation complete!"
echo ""
echo "Usage:"
echo "  archmode              - Launch interactive menu"
echo "  archmode on GAMEMODE  - Enable a mode"
echo "  archmode off GAMEMODE - Disable a mode"
echo "  archmode status       - Show current status"
echo "  archmode help         - Show help message"
echo ""
echo "📚 Configuration files:"
echo "  ~/. config/archmode/modes.conf"
echo "  ~/.local/share/archmode/archmode.log"
echo ""
