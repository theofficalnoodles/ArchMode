#!/bin/bash

###############################################################################
# ArchMode Installation Script
###############################################################################

set -e

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

INSTALL_DIR="/usr/local/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "📦 Installing ArchMode..."
echo ""

# Step 1: Copy main script
echo "  → Installing archmode to $INSTALL_DIR"
if [[ !  -f "$SCRIPT_DIR/archmode. sh" ]]; then
    echo "ERROR: archmode.sh not found!"
    exit 1
fi

sudo cp "$SCRIPT_DIR/archmode.sh" "$INSTALL_DIR/archmode"
sudo chmod +x "$INSTALL_DIR/archmode"
echo "     ✓ Script installed"

# Step 2: Create config directories
echo "  → Creating config directories"
mkdir -p ~/. config/archmode
mkdir -p ~/.local/share/archmode
echo "     ✓ Config directories created"

# Step 3: Create initial config file
if [[ ! -f ~/. config/archmode/modes.conf ]]; then
    cat > ~/.config/archmode/modes.conf << 'EOF'
# ArchMode Configuration File
# Format: MODE_NAME|Display Name|Default State (true/false)

GAMEMODE|Gaming Mode|false
PRODUCTIVITY|Productivity Mode|false
POWERMODE|Power Save Mode|false
QUIETMODE|Quiet Mode (Low Fan)|false
DEVMODE|Development Mode|false
EOF
    echo "     ✓ Config file created"
fi

echo ""
echo "╔════════════════════════════════════════╗"
echo "║    ✓ Installation Complete!            ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "🚀 Usage:"
echo "  archmode              - Launch interactive menu"
echo "  archmode on GAMEMODE  - Enable a mode"
echo "  archmode help         - Show help"
echo ""
echo "📂 Config:  ~/.config/archmode/modes. conf"
echo "📝 Logs:    ~/.local/share/archmode/archmode.log"
echo ""
echo "Try it now:"
echo "  archmode"
echo ""
