#!/bin/bash

# ArchMode - System Mode Manager for Arch Linux
# Version: 0.1.0

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
CONFIG_DIR="$HOME/.config/archmode"
LOG_DIR="$HOME/.local/share/archmode"
LOG_FILE="$LOG_DIR/archmode.log"
STATE_FILE="$CONFIG_DIR/state.conf"
MODES_FILE="$CONFIG_DIR/modes.conf"

# Create directories if they don't exist
mkdir -p "$CONFIG_DIR"
mkdir -p "$LOG_DIR"

# Initialize state file
if [ ! -f "$STATE_FILE" ]; then
    touch "$STATE_FILE"
fi

# Initialize modes configuration
if [ ! -f "$MODES_FILE" ]; then
    cat > "$MODES_FILE" << 'EOF'
# ArchMode Configuration
# Format: MODE_NAME:Display Name:Default State (true/false)
GAMEMODE:Gaming Mode:false
PRODUCTIVITY:Productivity Mode:false
POWERMODE:Power Save Mode:false
QUIETMODE:Quiet Mode (Low Fan):false
DEVMODE:Development Mode:false
EOF
fi

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Get mode state
get_mode_state() {
    local mode=$1
    if grep -q "^$mode=" "$STATE_FILE"; then
        grep "^$mode=" "$STATE_FILE" | cut -d= -f2
    else
        echo "false"
    fi
}

# Set mode state
set_mode_state() {
    local mode=$1
    local state=$2
    
    if grep -q "^$mode=" "$STATE_FILE"; then
        sed -i "s/^$mode=.*/$mode=$state/" "$STATE_FILE"
    else
        echo "$mode=$state" >> "$STATE_FILE"
    fi
    log "Set $mode to $state"
}

# Toggle mode function
toggle_mode() {
    local mode=$1
    local display_name=$2
    local commands=$3
    local current_state=$(get_mode_state "$mode")
    
    if [ "$current_state" = "true" ]; then
        echo -e "${YELLOW}➜ Disabling $display_name...${NC}"
        set_mode_state "$mode" "false"
        echo -e "${GREEN}✓ $display_name disabled${NC}"
    else
        echo -e "${CYAN}➜ Enabling $display_name...${NC}"
        eval "$commands" 2>/dev/null || true
        set_mode_state "$mode" "true"
        echo -e "${GREEN}✓ $display_name enabled${NC}"
    fi
}

# Mode implementations
enable_gamemode() {
    toggle_mode "GAMEMODE" "Gaming Mode" "
        systemctl --user stop dunst 2>/dev/null || true
        echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
    "
}

enable_productivity() {
    toggle_mode "PRODUCTIVITY" "Productivity Mode" "
        systemctl --user start dunst 2>/dev/null || true
        gsettings set org.gnome.desktop.session idle-delay 0 2>/dev/null || true
    "
}

enable_powermode() {
    toggle_mode "POWERMODE" "Power Save Mode" "
        echo powersave | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
        echo 1 | sudo tee /sys/module/usbcore/parameters/autosuspend >/dev/null 2>&1 || true
        brightnessctl set 50% 2>/dev/null || true
    "
}

enable_quietmode() {
    toggle_mode "QUIETMODE" "Quiet Mode (Low Fan)" "
        echo powersave | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
        pactl set-sink-volume @DEFAULT_SINK@ 50% 2>/dev/null || true
    "
}

enable_devmode() {
    toggle_mode "DEVMODE" "Development Mode" "
        sudo systemctl stop packagekit 2>/dev/null || true
        ulimit -c unlimited 2>/dev/null || true
    "
}

# Show status
show_status() {
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║          ArchMode Status               ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    while IFS=: read -r mode_name display_name default_state; do
        # Skip comments and empty lines
        [[ "$mode_name" =~ ^#.*$ ]] && continue
        [[ -z "$mode_name" ]] && continue
        
        local state=$(get_mode_state "$mode_name")
        if [ "$state" = "true" ]; then
            echo -e "${GREEN}✓${NC} $display_name: ${GREEN}${BOLD}ENABLED${NC}"
        else
            echo -e "${RED}✗${NC} $display_name: ${RED}DISABLED${NC}"
        fi
    done < "$MODES_FILE"
    echo ""
}

# List modes
list_modes() {
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║        Available Modes                 ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    while IFS=: read -r mode_name display_name default_state; do
        # Skip comments and empty lines
        [[ "$mode_name" =~ ^#.*$ ]] && continue
        [[ -z "$mode_name" ]] && continue
        
        echo -e "${CYAN}➜${NC} ${BOLD}$mode_name${NC} - $display_name"
    done < "$MODES_FILE"
    echo ""
}

# Reset all modes
reset_modes() {
    echo -e "${YELLOW}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║         Resetting All Modes            ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    while IFS=: read -r mode_name display_name default_state; do
        # Skip comments and empty lines
        [[ "$mode_name" =~ ^#.*$ ]] && continue
        [[ -z "$mode_name" ]] && continue
        
        local state=$(get_mode_state "$mode_name")
        if [ "$state" = "true" ]; then
            echo -e "${YELLOW}➜ Disabling $display_name...${NC}"
            set_mode_state "$mode_name" "false"
        fi
    done < "$MODES_FILE"
    
    # Restore default settings
    echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
    systemctl --user start dunst 2>/dev/null || true
    
    echo ""
    echo -e "${GREEN}✓ All modes reset to default${NC}"
    log "All modes reset"
}

# Update function
update_archmode() {
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║        ArchMode Update Utility         ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    # Check if git is installed
    if ! command -v git &> /dev/null; then
        echo -e "${RED}✗ Git is not installed!${NC}"
        echo -e "${YELLOW}➜ Install git: sudo pacman -S git${NC}"
        exit 1
    fi
    
    # Create temp directory
    TEMP_DIR=$(mktemp -d)
    echo -e "${CYAN}➜ Downloading latest version...${NC}"
    
    # Clone repository
    if git clone https://github.com/theofficalnoodles/ArchMode.git "$TEMP_DIR" &>/dev/null; then
        echo -e "${GREEN}✓ Downloaded successfully${NC}"
        echo ""
        
        # Run installer
        cd "$TEMP_DIR"
        chmod +x install.sh
        ./install.sh
        
        # Cleanup
        cd - > /dev/null
        rm -rf "$TEMP_DIR"
    else
        echo -e "${RED}✗ Failed to download update${NC}"
        echo -e "${YELLOW}➜ Check your internet connection${NC}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
}

# Show help
show_help() {
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║          ArchMode Help Menu            ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${BOLD}Usage:${NC}"
    echo "  archmode [command] [mode]"
    echo ""
    echo -e "${BOLD}Commands:${NC}"
    echo "  on, enable      Enable a mode"
    echo "  off, disable    Disable a mode"
    echo "  status          Show current mode status"
    echo "  list            List all available modes"
    echo "  reset           Disable all modes"
    echo "  update          Update ArchMode to latest version"
    echo "  help            Show this help message"
    echo ""
    echo -e "${BOLD}Available Modes:${NC}"
    echo "  GAMEMODE        Gaming optimization"
    echo "  PRODU
