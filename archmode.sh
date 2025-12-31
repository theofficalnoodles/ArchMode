# Complete Updated ArchMode with New Features + AUR Guide

## 1. Complete `archmode.sh` with New Features

```bash
#!/bin/bash

# ArchMode - System Mode Manager for Arch Linux
# Version: 0.2.0

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
TWEAKS_FILE="$CONFIG_DIR/tweaks.conf"
VERSION="0.2.0"

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
STREAMMODE:Streaming Mode:false
EOF
fi

# Initialize tweaks configuration
if [ ! -f "$TWEAKS_FILE" ]; then
    cat > "$TWEAKS_FILE" << 'EOF'
# ArchMode Tweaks Configuration
# Format: TWEAK_NAME:Display Name:Default State (true/false)
SWAPPINESS:Reduce Swappiness:false
NOATIME:Disable Access Time:false
TCPCONGESTION:Optimize TCP:false
IOSCHEDULER:Set I/O Scheduler:false
ZRAM:Enable ZRAM:false
EARLYOOM:Enable Early OOM:false
PRELOAD:Enable Preload:false
IRQBALANCE:Enable IRQ Balance:false
EOF
fi

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Get state (works for both modes and tweaks)
get_state() {
    local item=$1
    if grep -q "^$item=" "$STATE_FILE"; then
        grep "^$item=" "$STATE_FILE" | cut -d= -f2
    else
        echo "false"
    fi
}

# Set state (works for both modes and tweaks)
set_state() {
    local item=$1
    local state=$2
    
    if grep -q "^$item=" "$STATE_FILE"; then
        sed -i "s/^$item=.*/$item=$state/" "$STATE_FILE"
    else
        echo "$item=$state" >> "$STATE_FILE"
    fi
    log "Set $item to $state"
}

# Toggle mode function
toggle_mode() {
    local mode=$1
    local display_name=$2
    local enable_commands=$3
    local disable_commands=$4
    local current_state=$(get_state "$mode")
    
    if [ "$current_state" = "true" ]; then
        echo -e "${YELLOW}➜ Disabling $display_name...${NC}"
        if [ -n "$disable_commands" ]; then
            eval "$disable_commands" 2>/dev/null || true
        fi
        set_state "$mode" "false"
        echo -e "${GREEN}✓ $display_name disabled${NC}"
    else
        echo -e "${CYAN}➜ Enabling $display_name...${NC}"
        eval "$enable_commands" 2>/dev/null || true
        set_state "$mode" "true"
        echo -e "${GREEN}✓ $display_name enabled${NC}"
    fi
}

# Apply tweak function
apply_tweak() {
    local tweak=$1
    local display_name=$2
    local apply_commands=$3
    local revert_commands=$4
    local current_state=$(get_state "$tweak")
    
    if [ "$current_state" = "true" ]; then
        echo -e "${YELLOW}➜ Reverting $display_name...${NC}"
        if [ -n "$revert_commands" ]; then
            eval "$revert_commands" 2>/dev/null || true
        fi
        set_state "$tweak" "false"
        echo -e "${GREEN}✓ $display_name reverted${NC}"
    else
        echo -e "${CYAN}➜ Applying $display_name...${NC}"
        eval "$apply_commands" 2>/dev/null || true
        set_state "$tweak" "true"
        echo -e "${GREEN}✓ $display_name applied${NC}"
    fi
}

# ============================================
# MODE IMPLEMENTATIONS
# ============================================

enable_gamemode() {
    toggle_mode "GAMEMODE" "Gaming Mode" \
        "systemctl --user stop dunst 2>/dev/null || true
         echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
         sudo sysctl -w kernel.sched_latency_ns=4000000 2>/dev/null || true
         sudo sysctl -w kernel.sched_min_granularity_ns=500000 2>/dev/null || true" \
        "systemctl --user start dunst 2>/dev/null || true
         echo schedutil | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
         sudo sysctl -w kernel.sched_latency_ns=6000000 2>/dev/null || true
         sudo sysctl -w kernel.sched_min_granularity_ns=750000 2>/dev/null || true"
}

enable_productivity() {
    toggle_mode "PRODUCTIVITY" "Productivity Mode" \
        "systemctl --user start dunst 2>/dev/null || true
         gsettings set org.gnome.desktop.session idle-delay 0 2>/dev/null || true
         xset s off 2>/dev/null || true
         xset -dpms 2>/dev/null || true" \
        "gsettings set org.gnome.desktop.session idle-delay 300 2>/dev/null || true
         xset s on 2>/dev/null || true
         xset +dpms 2>/dev/null || true"
}

enable_powermode() {
    toggle_mode "POWERMODE" "Power Save Mode" \
        "echo powersave | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
         echo 1 | sudo tee /sys/module/usbcore/parameters/autosuspend >/dev/null 2>&1 || true
         brightnessctl set 50% 2>/dev/null || true
         sudo powertop --auto-tune 2>/dev/null || true" \
        "echo schedutil | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
         echo -1 | sudo tee /sys/module/usbcore/parameters/autosuspend >/dev/null 2>&1 || true
         brightnessctl set 100% 2>/dev/null || true"
}

enable_quietmode() {
    toggle_mode "QUIETMODE" "Quiet Mode" \
        "echo powersave | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
         pactl set-sink-volume @DEFAULT_SINK@ 50% 2>/dev/null || true
         echo 40 | sudo tee /sys/class/hwmon/hwmon*/pwm1 2>/dev/null || true" \
        "echo schedutil | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
         pactl set-sink-volume @DEFAULT_SINK@ 100% 2>/dev/null || true
         echo 255 | sudo tee /sys/class/hwmon/hwmon*/pwm1 2>/dev/null || true"
}

enable_devmode() {
    toggle_mode "DEVMODE" "Development Mode" \
        "sudo systemctl stop packagekit 2>/dev/null || true
         ulimit -c unlimited 2>/dev/null || true
         sudo sysctl -w fs.inotify.max_user_watches=524288 2>/dev/null || true" \
        "sudo systemctl start packagekit 2>/dev/null || true
         sudo sysctl -w fs.inotify.max_user_watches=8192 2>/dev/null || true"
}

enable_streammode() {
    toggle_mode "STREAMMODE" "Streaming Mode" \
        "systemctl --user stop dunst 2>/dev/null || true
         echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
         sudo sysctl -w net.core.rmem_max=134217728 2>/dev/null || true
         sudo sysctl -w net.core.wmem_max=134217728 2>/dev/null || true" \
        "systemctl --user start dunst 2>/dev/null || true
         echo schedutil | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true"
}

# ============================================
# TWEAK IMPLEMENTATIONS
# ============================================

tweak_swappiness() {
    apply_tweak "SWAPPINESS" "Reduce Swappiness (10)" \
        "sudo sysctl -w vm.swappiness=10
         echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.d/99-archmode.conf >/dev/null" \
        "sudo sysctl -w vm.swappiness=60
         sudo sed -i '/vm.swappiness=10/d' /etc/sysctl.d/99-archmode.conf 2>/dev/null || true"
}

tweak_noatime() {
    apply_tweak "NOATIME" "Disable Access Time" \
        "echo 'Add noatime to /etc/fstab manually for your partitions'
         echo 'Example: UUID=xxx / ext4 defaults,noatime 0 1'" \
        "echo 'Remove noatime from /etc/fstab manually'"
}

tweak_tcpcongestion() {
    apply_tweak "TCPCONGESTION" "Optimize TCP (BBR)" \
        "sudo modprobe tcp_bbr
         echo 'tcp_bbr' | sudo tee /etc/modules-load.d/bbr.conf >/dev/null
         sudo sysctl -w net.ipv4.tcp_congestion_control=bbr
         sudo sysctl -w net.core.default_qdisc=fq
         echo 'net.ipv4.tcp_congestion_control=bbr' | sudo tee -a /etc/sysctl.d/99-archmode.conf >/dev/null
         echo 'net.core.default_qdisc=fq' | sudo tee -a /etc/sysctl.d/99-archmode.conf >/dev/null" \
        "sudo sysctl -w net.ipv4.tcp_congestion_control=cubic
         sudo rm /etc/modules-load.d/bbr.conf 2>/dev/null || true
         sudo sed -i '/net.ipv4.tcp_congestion_control=bbr/d' /etc/sysctl.d/99-archmode.conf 2>/dev/null || true
         sudo sed -i '/net.core.default_qdisc=fq/d' /etc/sysctl.d/99-archmode.conf 2>/dev/null || true"
}

tweak_ioscheduler() {
    apply_tweak "IOSCHEDULER" "Set I/O Scheduler (BFQ)" \
        "for dev in /sys/block/sd*/queue/scheduler; do
             echo bfq | sudo tee \$dev >/dev/null 2>&1 || true
         done
         echo 'KERNEL==\"sd[a-z]*\", ATTR{queue/scheduler}=\"bfq\"' | sudo tee /etc/udev/rules.d/60-ioschedulers.rules >/dev/null" \
        "sudo rm /etc/udev/rules.d/60-ioschedulers.rules 2>/dev/null || true
         sudo udevadm control --reload-rules"
}

tweak_zram() {
    apply_tweak "ZRAM" "Enable ZRAM" \
        "if ! command -v zramctl &> /dev/null; then
             echo 'Installing zram-generator...'
             sudo pacman -S --noconfirm zram-generator 2>/dev/null || true
         fi
         sudo modprobe zram
         sudo systemctl enable --now systemd-zram-setup@zram0.service 2>/dev/null || true" \
        "sudo systemctl disable --now systemd-zram-setup@zram0.service 2>/dev/null || true
         sudo modprobe -r zram 2>/dev/null || true"
}

tweak_earlyoom() {
    apply_tweak "EARLYOOM" "Enable Early OOM Killer" \
        "if ! command -v earlyoom &> /dev/null; then
             echo 'Installing earlyoom...'
             sudo pacman -S --noconfirm earlyoom 2>/dev/null || true
         fi
         sudo systemctl enable --now earlyoom 2>/dev/null || true" \
        "sudo systemctl disable --now earlyoom 2>/dev/null || true"
}

tweak_preload() {
    apply_tweak "PRELOAD" "Enable Preload" \
        "if ! command -v preload &> /dev/null; then
             echo 'Installing preload from AUR...'
             echo 'Please install manually: yay -S preload'
         fi
         sudo systemctl enable --now preload 2>/dev/null || true" \
        "sudo systemctl disable --now preload 2>/dev/null || true"
}

tweak_irqbalance() {
    apply_tweak "IRQBALANCE" "Enable IRQ Balance" \
        "if ! command -v irqbalance &> /dev/null; then
             echo 'Installing irqbalance...'
             sudo pacman -S --noconfirm irqbalance 2>/dev/null || true
         fi
         sudo systemctl enable --now irqbalance 2>/dev/null || true" \
        "sudo systemctl disable --now irqbalance 2>/dev/null || true"
}

# ============================================
# DISPLAY FUNCTIONS
# ============================================

show_status() {
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║          ArchMode Status               ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    echo -e "${BOLD}${BLUE}Modes:${NC}"
    while IFS=: read -r mode_name display_name default_state; do
        [[ "$mode_name" =~ ^#.*$ ]] && continue
        [[ -z "$mode_name" ]] && continue
        
        local state=$(get_state "$mode_name")
        if [ "$state" = "true" ]; then
            echo -e "${GREEN}  ✓${NC} $display_name: ${GREEN}${BOLD}ENABLED${NC}"
        else
            echo -e "${RED}  ✗${NC} $display_name: ${RED}DISABLED${NC}"
        fi
    done < "$MODES_FILE"
    
    echo ""
    echo -e "${BOLD}${MAGENTA}Tweaks:${NC}"
    while IFS=: read -r tweak_name display_name default_state; do
        [[ "$tweak_name" =~ ^#.*$ ]] && continue
        [[ -z "$tweak_name" ]] && continue
        
        local state=$(get_state "$tweak_name")
        if [ "$state" = "true" ]; then
            echo -e "${GREEN}  ✓${NC} $display_name: ${GREEN}${BOLD}APPLIED${NC}"
        else
            echo -e "${RED}  ✗${NC} $display_name: ${RED}NOT APPLIED${NC}"
        fi
    done < "$TWEAKS_FILE"
    echo ""
}

list_modes() {
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║        Available Modes                 ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    while IFS=: read -r mode_name display_name default_state; do
        [[ "$mode_name" =~ ^#.*$ ]] && continue
        [[ -z "$mode_name" ]] && continue
        
        echo -e "${CYAN}➜${NC} ${BOLD}$mode_name${NC} - $display_name"
    done < "$MODES_FILE"
    echo ""
}

list_tweaks() {
    echo -e "${MAGENTA}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║       Available Tweaks                 ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    while IFS=: read -r tweak_name display_name default_state; do
        [[ "$tweak_name" =~ ^#.*$ ]] && continue
        [[ -z "$tweak_name" ]] && continue
        
        echo -e "${MAGENTA}➜${NC} ${BOLD}$tweak_name${NC} - $display_name"
    done < "$TWEAKS_FILE"
    echo ""
}

show_version() {
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║            ArchMode v$VERSION            ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${CYAN}A powerful system mode manager for Arch Linux${NC}"
    echo -e "${CYAN}Created by theofficalnoodles${NC}"
    echo ""
}

reset_all() {
    echo -e "${YELLOW}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║         Resetting Everything           ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    # Reset modes
    while IFS=: read -r mode_name display_name default_state; do
        [[ "$mode_name" =~ ^#.*$ ]] && continue
        [[ -z "$mode_name" ]] && continue
        
        local state=$(get_state "$mode_name")
        if [ "$state" = "true" ]; then
            echo -e "${YELLOW}➜ Disabling $display_name...${NC}"
            set_state "$mode_name" "false"
        fi
    done < "$MODES_FILE"
    
    # Restore default settings
    echo schedutil | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
    systemctl --user start dunst 2>/dev/null || true
    
    echo ""
    echo -e "${GREEN}✓ All modes and tweaks reset${NC}"
    log "All reset"
}

update_archmode() {
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║        ArchMode Update Utility         ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    if ! command -v git &> /dev/null; then
        echo -e "${RED}✗ Git is not installed!${NC}"
        echo -e "${YELLOW}➜ Install git: sudo pacman -S git${NC}"
        exit 1
    fi
    
    TEMP_DIR=$(mktemp -d)
    echo -e "${CYAN}➜ Downloading latest version...${NC}"
    
    if git clone https://github.com/theofficalnoodles/ArchMode.git "$TEMP_DIR" &>/dev/null; then
        echo -e "${GREEN}✓ Downloaded successfully${NC}"
        echo ""
        
        cd "$TEMP_DIR"
        chmod +x install.sh
        ./install.sh
        
        cd - > /dev/null
        rm -rf "$TEMP_DIR"
    else
        echo -e "${RED}✗ Failed to download update${NC}"
        echo -e "${YELLOW}➜ Check your internet connection${NC}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
}

show_help() {
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║          ArchMode Help Menu            ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${BOLD}Usage:${NC}"
    echo "  archmode [command] [mode/tweak]"
    echo ""
    echo -e "${BOLD}Mode Commands:${NC}"
    echo "  on, enable      Enable a mode"
    echo "  off, disable    Disable a mode"
    echo "  list            List all available modes"
    echo ""
    echo -e "${BOLD}Tweak Commands:${NC}"
    echo "  tweak           Apply a system tweak"
    echo "  untweak         Revert a system tweak"
    echo "  tweaks          List all available tweaks"
    echo ""
    echo -e "${BOLD}General Commands:${NC}"
    echo "  status          Show current status"
    echo "  reset           Reset all modes and tweaks"
    echo "  update          Update ArchMode"
    echo "  version         Show version"
    echo "  help            Show this help"
    echo ""
    echo -e "${BOLD}Available Modes:${NC}"
    echo "  GAMEMODE        Gaming optimization"
    echo "  PRODUCTIVITY    Stay focused"
    echo "  POWERMODE       Power saving"
    echo "  QUIETMODE       Reduce noise"
    echo "  DEVMODE         Development"
    echo "  STREAMMODE      Streaming/recording"
    echo ""
    echo -e "${BOLD}Available Tweaks:${NC}"
    echo "  SWAPPINESS      Reduce swap usage"
    echo "  NOATIME         Disable access time"
    echo "  TCPCONGESTION   Enable BBR"
    echo "  IOSCHEDULER     Set BFQ scheduler"
    echo "  ZRAM            Enable ZRAM"
    echo "  EARLYOOM        Early OOM killer"
    echo "  PRELOAD         Application preloader"
    echo "  IRQBALANCE      Balance IRQ"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "  archmode on GAMEMODE"
    echo "  archmode tweak SWAPPINESS"
    echo "  archmode status"
    echo "  archmode update"
    echo ""
}

interactive_mode() {
    while true; do
        clear
        echo -e "${CYAN}${BOLD}"
        echo "╔════════════════════════════════════════╗"
        echo "║           ArchMode Manager             ║"
        echo "║              v$VERSION                   ║"
        echo "╚════════════════════════════════════════╝"
        echo -e "${NC}"
        echo ""
        
        echo -e "${BLUE}${BOLD}=== MODES ===${NC}"
        local i=1
        declare -A item_map
        
        while IFS=: read -r mode_name display_name default_state; do
            [[ "$mode_name" =~ ^#.*$ ]] && continue
            [[ -z "$mode_name" ]] && continue
            
            local state=$(get_state "$mode_name")
            item_map[$i]="MODE:$mode_name"
            
            if [ "$state" = "true" ]; then
                echo -e "${GREEN}[$i]${NC} $display_name ${GREEN}[ON]${NC}"
            else
                echo -e "${BLUE}[$i]${NC} $display_name ${RED}[OFF]${NC}"
            fi
            ((i++))
        done < "$MODES_FILE"
        
        echo ""
        echo -e "${MAGENTA}${BOLD}=== TWEAKS ===${NC}"
        
        while IFS=: read -r tweak_name display_name default_state; do
            [[ "$tweak_name" =~ ^#.*$ ]] && continue
            [[ -z "$tweak_name" ]] && continue
            
            local state=$(get_state "$tweak_name")
            item_map[$i]="TWEAK:$tweak_name"
            
            if [ "$state" = "true" ]; then
                echo -e "${GREEN}[$i]${NC} $display_name ${GREEN}[APPLIED]${NC}"
            else
                echo -e "${MAGENTA}[$i]${NC} $display_name ${RED}[NOT APPLIED]${NC}"
            fi
            ((i++))
        done < "$TWEAKS_FILE"
        
        echo ""
        echo -e "${YELLOW}[r]${NC} Reset all"
        echo -e "${YELLOW}[u]${NC} Update"
        echo -e "${YELLOW}[v]${NC} Version"
        echo -e "${YELLOW}[q]${NC} Quit"
        echo ""
        read -p "Select option: " -n 1 -r choice
        echo ""
        
        case $choice in
            [1-9]|1[0-4])
                if [ -n "${item_map[$choice]:-}" ]; then
                    local item_type=$(echo "${item_map[$choice]}" | cut -d: -f1)
                    local item_name=$(echo "${item_map[$choice]}" | cut -d: -f2)
                    
                    if [ "$item_type" = "MODE" ]; then
                        case $item_name in
                            GAMEMODE) enable_gamemode ;;
                            PRODUCTIVITY) enable_productivity ;;
                            POWERMODE) enable_powermode ;;
                            QUIETMODE) enable_quietmode ;;
                            DEVMODE) enable_devmode ;;
                            STREAMMODE) enable_streammode ;;
                        esac
                    else
                        case $item_name in
                            SWAPPINESS) tweak_swappiness ;;
                            NOATIME) tweak_noatime ;;
                            TCPCONGESTION) tweak_tcpcongestion ;;
                            IOSCHEDULER) tweak_ioscheduler ;;
                            ZRAM) tweak_zram ;;
                            EARLYOOM) tweak_earlyoom ;;
                            PRELOAD) tweak_preload ;;
                            IRQBALANCE) tweak_irqbalance ;;
                        esac
                    fi
                    sleep 2
                fi
                ;;
            r|R)
                reset_all
                sleep 2
                ;;
            u|U)
                update_archmode
                exit 0
                ;;
            v|V)
                show_version
                sleep 3
                ;;
            q|Q)
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                sleep 1
                ;;
        esac
    done
}

# ============================================
# MAIN SCRIPT LOGIC
# ============================================

case "${1:-}" in
    on|enable)
        if [ -z "${2:-}" ]; then
            echo -e "${RED}Error: No mode specified${NC}"
            exit 1
        fi
        
        case "${2^^}" in
            GAMEMODE) enable_gamemode ;;
            PRODUCTIVITY) enable_productivity ;;
            POWERMODE) enable_powermode ;;
            QUIETMODE) enable_quietmode ;;
            DEVMODE) enable_devmode ;;
            STREAMMODE) enable_streammode ;;
            *)
                echo -e "${RED}Unknown mode: $2${NC}"
                exit 1
                ;;
        esac
        ;;
        
    off|disable)
        if [ -z "${2:-}" ]; then
            echo -e "${RED}Error: No mode specified${NC}"
            exit 1
        fi
        
        case "${2^^}" in
            GAMEMODE) enable_gamemode ;;
            PRODUCTIVITY) enable_productivity ;;
            POWERMODE) enable_powermode ;;
            QUIETMODE) enable_quietmode ;;
            DEVMODE) enable_devmode ;;
            STREAMMODE) enable_streammode ;;
            *)
                echo -e "${RED}Unknown mode: $2${NC}"
                exit 1
                ;;
        esac
        ;;
        
    tweak)
        if [ -z "${2:-}" ]; then
            echo -e "${RED}Error: No tweak specified${NC}"
            exit 1
        fi
        
        case "${2^^}" in
            SWAPPINESS) tweak_swappiness ;;
            NOATIME) tweak_noatime ;;
            TCPCONGESTION) tweak_tcpcongestion ;;
            IOSCHEDULER) tweak_ioscheduler ;;
            ZRAM) tweak_zram ;;
            EARLYOOM) tweak_earlyoom ;;
            PRELOAD) tweak_preload ;;
            IRQBALANCE) tweak_irqbalance ;;
            *)
                echo -e "${RED}Unknown tweak: $2${NC}"
                exit 1
                ;;
        esac
        ;;
        
    untweak)
        if [ -z "${2:-}" ]; then
            echo -e "${RED}Error: No tweak specified${NC}"
            exit 1
        fi
        
        case "${2^^}" in
            SWAPPINESS) tweak_swappiness ;;
            NOATIME) tweak_noatime ;;
            TCPCONGESTION) tweak_tcpcongestion ;;
            IOSCHEDULER) tweak_ioscheduler ;;
            ZRAM) tweak_zram ;;
            EARLYOOM) tweak_earlyoom ;;
            PRELOAD) tweak_preload ;;
            IRQBALANCE) tweak_irqbalance ;;
            *)
                echo -e "${RED}Unknown tweak: $2${NC}"
                exit 1
                ;;
        esac
        ;;
        
    status)
        show_status
        ;;
        
    list)
        list_modes
        ;;
        
    tweaks)
        list_tweaks
        ;;
        
    reset)
        reset_all
