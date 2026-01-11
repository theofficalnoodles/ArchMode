#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}Don't run this script as root. Use sudo when needed.${NC}"
   exit 1
fi

# Fancy header
clear
echo -e "${CYAN}${BOLD}"
echo "╔════════════════════════════════════════╗"
echo "║     ArchMode Installation Script       ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Check if this is an update
if [ -f "/usr/local/bin/archmode" ]; then
    echo -e "${YELLOW}╔════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║     Existing Installation Detected     ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}This will update your existing ArchMode installation.${NC}"
    echo -e "${CYAN}Your configuration and logs will be preserved.${NC}"
    echo ""
    read -p "Continue with update? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Update cancelled.${NC}"
        exit 1
    fi
    UPDATING=true
else
    UPDATING=false
fi

# Check if archmode.sh exists
if [ ! -f "archmode.sh" ]; then
    echo -e "${RED}╔════════════════════════════════════════╗${NC}"
    echo -e "${RED}║           ERROR DETECTED!              ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${RED}✗ archmode.sh not found!${NC}"
    echo -e "${YELLOW}➜ Make sure you're running this script from the ArchMode directory.${NC}"
    echo -e "${YELLOW}➜ Current directory: ${BLUE}$(pwd)${NC}"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ Found archmode.sh${NC}"
echo ""

# Make archmode.sh executable
echo -e "${CYAN}┌─────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│  ${BOLD}Step 1: Setting permissions${NC}${CYAN}           │${NC}"
echo -e "${CYAN}└─────────────────────────────────────────┘${NC}"
chmod +x archmode.sh
echo -e "${GREEN}✓ Made archmode.sh executable${NC}"
echo ""

# Install the script
echo -e "${CYAN}┌─────────────────────────────────────────┐${NC}"
if [ "$UPDATING" = true ]; then
    echo -e "${CYAN}│  ${BOLD}Step 2: Updating system installation${NC}${CYAN}  │${NC}"
else
    echo -e "${CYAN}│  ${BOLD}Step 2: Installing to system${NC}${CYAN}          │${NC}"
fi
echo -e "${CYAN}└─────────────────────────────────────────┘${NC}"
sudo cp archmode.sh /usr/local/bin/archmode
sudo chmod +x /usr/local/bin/archmode
if [ "$UPDATING" = true ]; then
    echo -e "${GREEN}✓ Updated /usr/local/bin/archmode${NC}"
else
    echo -e "${GREEN}✓ Installed to /usr/local/bin/archmode${NC}"
fi
echo ""

# Create config directory
echo -e "${CYAN}┌─────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│  ${BOLD}Step 3: Creating directories${NC}${CYAN}          │${NC}"
echo -e "${CYAN}└─────────────────────────────────────────┘${NC}"
mkdir -p ~/.config/archmode
mkdir -p ~/.local/share/archmode
echo -e "${GREEN}✓ Created ~/.config/archmode${NC}"
echo -e "${GREEN}✓ Created ~/.local/share/archmode${NC}"
echo ""

# Install systemd service if it exists
if [ -f "archmode.service" ]; then
    echo -e "${CYAN}┌─────────────────────────────────────────┐${NC}"
    if [ "$UPDATING" = true ]; then
        echo -e "${CYAN}│  ${BOLD}Step 4: Updating systemd service${NC}${CYAN}      │${NC}"
    else
        echo -e "${CYAN}│  ${BOLD}Step 4: Installing systemd service${NC}${CYAN}    │${NC}"
    fi
    echo -e "${CYAN}└─────────────────────────────────────────┘${NC}"
    sudo cp archmode.service /etc/systemd/system/
    sudo systemctl daemon-reload
    if [ "$UPDATING" = true ]; then
        echo -e "${GREEN}✓ Systemd service updated${NC}"
    else
        echo -e "${GREEN}✓ Systemd service installed${NC}"
    fi
    echo ""
fi

# Success message
echo ""
if [ "$UPDATING" = true ]; then
    echo -e "${GREEN}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║       Update Complete! 🎉              ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${CYAN}➜ Your ArchMode has been updated successfully!${NC}"
else
    echo -e "${GREEN}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║     Installation Complete! 🎉          ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${CYAN}➜ Run:${NC} ${BOLD}archmode${NC} ${CYAN}to start${NC}"
    echo -e "${CYAN}➜ Run:${NC} ${BOLD}archmode help${NC} ${CYAN}for usage info${NC}"
fi
echo ""
echo -e "${YELLOW}╭────────────────────────────────────────╮${NC}"
echo -e "${YELLOW}│  Enjoy tweaking your Arch Linux! 🚀   │${NC}"
echo -e "${YELLOW}╰────────────────────────────────────────╯${NC}"
echo ""
