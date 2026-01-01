#!/bin/bash

# ArchMode - System Mode Manager for Arch Linux
# Version: 0.3.0
# Enhanced with useful features and better functionality

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
CONFIG_DIR="$HOME/.config/archmode"
LOG_DIR="$HOME/.local/share/archmode"
LOG_FILE="$LOG_DIR/archmode.log"
STATE_FILE="$CONFIG_DIR/state.conf"
MODES_FILE="$CONFIG_DIR/modes.conf"
PROFILES_FILE="$CONFIG_DIR/profiles.conf"
BACKUP_DIR="$CONFIG_DIR/backups"
VERSION="0.3.0"

# Create directories
mkdir -p "$CONFIG_DIR" "$LOG_DIR" "$BACKUP_DIR"

# Initialize state file
[ ! -f "$STATE_FILE" ] && touch "$STATE_FILE"

# Initialize modes configuration
if [ ! -f "$MODES_FILE" ]; then
    cat > "$MODES_FILE" << 'EOF'
# ArchMode Configuration
# Format: MODE_NAME:Display Name:Category:Description
GAMEMODE:Gaming Mode:Performance:Max CPU, disable notifications, optimize latency
STREAMMODE:Streaming Mode:Performance:Optimize for OBS/streaming, network tweaks
PRODUCTIVITY:Productivity Mode:Work:Enable notifications, prevent sleep, focus mode
POWERMODE:Power Save Mode:Battery:Reduce power consumption for laptops
QUIETMODE:Quiet Mode:Comfort:Reduce fan noise and system sounds
DEVMODE:Development Mode:Work:Unlimited resources for compilation and testing
NIGHTMODE:Night Mode:Comfort:Reduce blue light, dim screen, quiet mode
TRAVELMODE:Travel Mode:Battery:Maximum battery life for on-the-go
RENDERMODE:Render Mode:Performance:Max CPU/GPU for 3D rendering and video encoding
EOF
fi

# Initialize profiles
if [ ! -f "$PROFILES_FILE" ]; then
    cat > "$PROFILES_FILE" << 'EOF'
# ArchMode Profiles
# Format: PROFILE_NAME:MODES_LIST:DESCRIPTION
GAMER:GAMEMODE:Hardcore gaming session
STREAMER:STREAMMODE,GAMEMODE:Stream and play simultaneously
WORKER:PRODUCTIVITY:Focused work environment
TRAVELER:TRAVELMODE,QUIETMODE:Portable productivity
CREATOR:RENDERMODE,DEVMODE:Content creation and rendering
NIGHT_OWL:NIGHTMODE,QUIETMODE:Late night computing
EOF
fi

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# System info detection
detect_system() {
    local cpu_count=$(nproc)
    local total_mem=$(free -g | awk '/^Mem:/{print $2}')
    local gpu_vendor=$(lspci | grep -i 'vga\|3d' | head -n1)
    
    echo "CPU_CORES=$cpu_count" > "$CONFIG_DIR/system.info"
    echo "TOTAL_RAM=${total_mem}G" >> "$CONFIG_DIR/system.info"
    echo "GPU=$gpu_vendor" >> "$CONFIG_DIR/system.info"
    
    # Detect if laptop
    if [ -d /sys/class/power_supply/BAT0 ] || [ -d /sys/class/power_supply/BAT1 ]; then
        echo "IS_LAPTOP=true" >> "$CONFIG_DIR/system.info"
    else
        echo "IS_LAPTOP=false" >> "$CONFIG_DIR/system.info"
    fi
}

# Get state
get_state() {
    local item=$1
    grep "^$item=" "$STATE_FILE" 2>/dev/null | cut -d= -f2 || echo "false"
}

# Set state
set_state() {
    local item=$1
    local state=$2
    
    if grep -q "^$item=" "$STATE_FILE" 2>/dev/null; then
        sed -i "s/^$item=.*/$item=$state/" "$STATE_FILE"
    else
        echo "$item=$state" >> "$STATE_FILE"
    fi
    log "Set $item to $state"
}

# Backup current configuration
backup_config() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="$BACKUP_DIR/backup_$timestamp.conf"
    
    cp "$STATE_FILE" "$backup_file"
    echo -e "${GREEN}✓ Configuration backed up to: $backup_file${NC}"
    log "Backup created: $backup_file"
}

# Restore from backup
restore_config() {
    local backups=($(ls -t "$BACKUP_DIR"/backup_*.conf 2>/dev/null))
    
    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "${RED}✗ No backups found${NC}"
        return 1
    fi
    
    echo -e "${CYAN}Available backups:${NC}"
    for i in "${!backups[@]}"; do
        local date=$(basename "${backups[$i]}" | sed 's/backup_\(.*\).conf/\1/')
        echo -e "${BLUE}[$((i+1))]${NC} $date"
    done
    
    read -p "Select backup to restore (1-${#backups[@]}): " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#backups[@]}" ]; then
        cp "${backups[$((choice-1))]}" "$STATE_FILE"
        echo -e "${GREEN}✓ Configuration restored${NC}"
        log "Restored from backup: ${backups[$((choice-1))]}"
    else
        echo -e "${RED}✗ Invalid choice${NC}"
    fi
}

# Check dependencies
check_dependencies() {
    local missing=()
    
    # Check optional dependencies
    command -v dunst &>/dev/null || missing+=("dunst")
    command -v brightnessctl &>/dev/null || missing+=("brightnessctl")
    command -v cpupower &>/dev/null || missing+=("cpupower")
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${YELLOW}⚠ Optional dependencies missing:${NC}"
        printf '  - %s\n' "${missing[@]}"
        echo -e "${CYAN}Install with: ${BOLD}sudo pacman -S ${missing[*]}${NC}"
        echo ""
    fi
}

# Monitor system resources
show_stats() {
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║        System Statistics               ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # CPU Usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    echo -e "${BOLD}CPU Usage:${NC} ${cpu_usage}%"
    
    # CPU Frequency
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]; then
        local freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)
        local freq_ghz=$(echo "scale=2; $freq / 1000000" | bc)
        echo -e "${BOLD}CPU Frequency:${NC} ${freq_ghz} GHz"
    fi
    
    # CPU Governor
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
        local governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
        echo -e "${BOLD}CPU Governor:${NC} $governor"
    fi
    
    # Memory
    local mem_info=$(free -h | awk '/^Mem:/{printf "%s / %s (%.1f%%)", $3, $2, ($3/$2)*100}')
    echo -e "${BOLD}Memory:${NC} $mem_info"
    
    # Temperature (if available)
    if command -v sensors &>/dev/null; then
        local temp=$(sensors | grep -i 'Package id 0' | awk '{print $4}' | head -n1)
        [ -n "$temp" ] && echo -e "${BOLD}CPU Temp:${NC} $temp"
    fi
    
    # Battery (if laptop)
    if [ -d /sys/class/power_supply/BAT0 ]; then
        local battery=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null)
        local status=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null)
        [ -n "$battery" ] && echo -e "${BOLD}Battery:${NC} ${battery}% ($status)"
    fi
    
    # Disk usage
    local disk_usage=$(df -h / | awk 'NR==2{printf "%s / %s (%s)", $3, $2, $5}')
    echo -e "${BOLD}Disk Usage:${NC} $disk_usage"
    
    echo ""
}

# ============================================
# MODE IMPLEMENTATIONS
# ============================================

enable_gamemode() {
    local current=$(get_state "GAMEMODE")
    
    if [ "$current" = "true" ]; then
        echo -e "${YELLOW}➜ Disabling Gaming Mode...${NC}"
        
        # Restore normal settings
        systemctl --user start dunst 2>/dev/null || true
        echo schedutil | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
        sudo sysctl -w kernel.sched_latency_ns=6000000 >/dev/null 2>&1 || true
        sudo sysctl -w kernel.sched_min_granularity_ns=750000 >/dev/null 2>&1 || true
        sudo sysctl -w vm.dirty_ratio=20 >/dev/null 2>&1 || true
        
        set_state "GAMEMODE" "false"
        echo -e "${GREEN}✓ Gaming Mode disabled${NC}"
    else
        echo -e "${CYAN}➜ Enabling Gaming Mode...${NC}"
        
        # Disable notifications
        systemctl --user stop dunst 2>/dev/null || true
        
        # Set CPU to performance
        echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
        
        # Optimize scheduler for responsiveness
        sudo sysctl -w kernel.sched_latency_ns=4000000 >/dev/null 2>&1 || true
        sudo sysctl -w kernel.sched_min_granularity_ns=500000 >/dev/null 2>&1 || true
        
        # Disable swapping during gaming
        sudo sysctl -w vm.swappiness=10 >/dev/null 2>&1 || true
        
        # Increase dirty ratio for better I/O
        sudo sysctl -w vm.dirty_ratio=40 >/dev/null 2>&1 || true
        
        # Disable mouse acceleration (if X11)
        if [ -n "$DISPLAY" ]; then
            xinput list | grep -i 'pointer\|mouse' | grep -v 'XTEST' | cut -d= -f2 | cut -f1 | while read id; do
                xinput set-prop "$id" "libinput Accel Speed" 0 2>/dev/null || true
            done
        fi
        
        set_state "GAMEMODE" "true"
        echo -e "${GREEN}✓ Gaming Mode enabled${NC}"
        echo -e "${CYAN}  • Notifications disabled${NC}"
        echo -e "${CYAN}  • CPU set to performance mode${NC}"
        echo -e "${CYAN}  • Scheduler optimized for low latency${NC}"
        echo -e "${CYAN}  • Swapping minimized${NC}"
    fi
}

enable_streammode() {
    local current=$(get_state "STREAMMODE")
    
    if [ "$current" = "true" ]; then
        echo -e "${YELLOW}➜ Disabling Streaming Mode...${NC}"
        
        systemctl --user start dunst 2>/dev/null || true
        sudo sysctl -w net.core.rmem_max=212992 >/dev/null 2>&1 || true
        sudo sysctl -w net.core.wmem_max=212992 >/dev/null 2>&1 || true
        
        set_state "STREAMMODE" "false"
        echo -e "${GREEN}✓ Streaming Mode disabled${NC}"
    else
        echo -e "${CYAN}➜ Enabling Streaming Mode...${NC}"
        
        # Disable notifications
        systemctl --user stop dunst 2>/dev/null || true
        
        # Set CPU to performance
        echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
        
        # Optimize network for streaming
        sudo sysctl -w net.core.rmem_max=134217728 >/dev/null 2>&1 || true
        sudo sysctl -w net.core.wmem_max=134217728 >/dev/null 2>&1 || true
        sudo sysctl -w net.ipv4.tcp_rmem="4096 87380 134217728" >/dev/null 2>&1 || true
        sudo sysctl -w net.ipv4.tcp_wmem="4096 65536 134217728" >/dev/null 2>&1 || true
        
        # Increase process priority for common streaming apps
        pgrep -x obs 2>/dev/null && sudo renice -n -10 -p $(pgrep -x obs) 2>/dev/null || true
        
        set_state "STREAMMODE" "true"
        echo -e "${GREEN}✓ Streaming Mode enabled${NC}"
        echo -e "${CYAN}  • Network buffers increased${NC}"
        echo -e "${CYAN}  • CPU optimized for encoding${NC}"
    fi
}

enable_productivity() {
    local current=$(get_state "PRODUCTIVITY")
    
    if [ "$current" = "true" ]; then
        echo -e "${YELLOW}➜ Disabling Productivity Mode...${NC}"
        
        gsettings set org.gnome.desktop.session idle-delay 300 2>/dev/null || true
        xset s on 2>/dev/null || true
        xset +dpms 2>/dev/null || true
        
        set_state "PRODUCTIVITY" "false"
        echo -e "${GREEN}✓ Productivity Mode disabled${NC}"
    else
        echo -e "${CYAN}➜ Enabling Productivity Mode...${NC}"
        
        # Enable notifications
        systemctl --user start dunst 2>/dev/null || true
        
        # Prevent screen sleep
        gsettings set org.gnome.desktop.session idle-delay 0 2>/dev/null || true
        xset s off 2>/dev/null || true
        xset -dpms 2>/dev/null || true
        
        # Block distracting websites (optional)
        if command -v hostctl &>/dev/null; then
            echo -e "${CYAN}  • To block distracting sites, edit /etc/hosts${NC}"
        fi
        
        set_state "PRODUCTIVITY" "true"
        echo -e "${GREEN}✓ Productivity Mode enabled${NC}"
        echo -e "${CYAN}  • Screen sleep disabled${NC}"
        echo -e "${CYAN}  • Notifications enabled${NC}"
    fi
}

enable_powermode() {
    local current=$(get_state "POWERMODE")
    
    if [ "$current" = "true" ]; then
        echo -e "${YELLOW}➜ Disabling Power Save Mode...${NC}"
        
        echo schedutil | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
        echo -1 | sudo tee /sys/module/usbcore/parameters/autosuspend >/dev/null 2>&1 || true
        brightnessctl set 100% 2>/dev/null || true
        sudo sysctl -w vm.laptop_mode=0 >/dev/null 2>&1 || true
        
        set_state "POWERMODE" "false"
        echo -e "${GREEN}✓ Power Save Mode disabled${NC}"
    else
        echo -e "${CYAN}➜ Enabling Power Save Mode...${NC}"
        
        # Set CPU to powersave
        echo powersave | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
        
        # Enable aggressive USB suspend
        echo 1 | sudo tee /sys/module/usbcore/parameters/autosuspend >/dev/null 2>&1 || true
        
        # Dim screen
        brightnessctl set 50% 2>/dev/null || true
        
        # Enable laptop mode
        sudo sysctl -w vm.laptop_mode=5 >/dev/null 2>&1 || true
        
        # Reduce screen refresh rate (if possible)
        if command -v xrandr &>/dev/null && [ -n "$DISPLAY" ]; then
            xrandr --output $(xrandr | grep " connected" | cut -d" " -f1 | head -n1) --rate 60 2>/dev/null || true
        fi
        
        # Stop unnecessary services
        systemctl --user stop tracker-miner-fs-3.service 2>/dev/null || true
        
        set_state "POWERMODE" "true"
        echo -e "${GREEN}✓ Power Save Mode enabled${NC}"
        echo -e "${CYAN}  • CPU set to powersave${NC}"
        echo -e "${CYAN}  • Screen dimmed to 50%${NC}"
        echo -e "${CYAN}  • USB autosuspend enabled${NC}"
    fi
}

enable_quietmode() {
    local current=$(get_state "QUIETMODE")
    
    if [ "$current" = "true" ]; then
        echo -e "${YELLOW}➜ Disabling Quiet Mode...${NC}"
        
        echo schedutil | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
        pactl set-sink-volume @DEFAULT_SINK@ 100% 2>/dev/null || true
        echo 255 | sudo tee /sys/class/hwmon/hwmon*/pwm1 2>/dev/null || true
        
        set_state "QUIETMODE" "false"
        echo -e "${GREEN}✓ Quiet Mode disabled${NC}"
    else
        echo -e "${CYAN}➜ Enabling Quiet Mode...${NC}"
        
        # Reduce CPU frequency
        echo powersave | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
        
        # Reduce volume
        pactl set-sink-volume @DEFAULT_SINK@ 50% 2>/dev/null || true
        
        # Reduce fan speed (if controllable)
        echo 40 | sudo tee /sys/class/hwmon/hwmon*/pwm1 2>/dev/null || true
        
        set_state "QUIETMODE" "true"
        echo -e "${GREEN}✓ Quiet Mode enabled${NC}"
        echo -e "${CYAN}  • CPU frequency reduced${NC}"
        echo -e "${CYAN}  • Volume lowered to 50%${NC}"
        echo -e "${CYAN}  • Fan speed reduced${NC}"
    fi
}

enable_devmode() {
    local current=$(get_state "DEVMODE")
    
    if [ "$current" = "true" ]; then
        echo -e "${YELLOW}➜ Disabling Development Mode...${NC}"
        
        sudo systemctl start packagekit 2>/dev/null || true
        sudo sysctl -w fs.inotify.max_user_watches=8192 >/dev/null 2>&1 || true
        ulimit -c 0 2>/dev/null || true
        
        set_state "DEVMODE" "false"
        echo -e "${GREEN}✓ Development Mode disabled${NC}"
    else
        echo -e "${CYAN}➜ Enabling Development Mode...${NC}"
        
        # Disable package manager
        sudo systemctl stop packagekit 2>/dev/null || true
        
        # Increase file watchers for IDEs
        sudo sysctl -w fs.inotify.max_user_watches=524288 >/dev/null 2>&1 || true
        
        # Unlimited core dumps
        ulimit -c unlimited 2>/dev/null || true
        
        # Increase shared memory
        sudo sysctl -w kernel.shmmax=68719476736 >/dev/null 2>&1 || true
        
        set_state "DEVMODE" "true"
        echo -e "${GREEN}✓ Development Mode enabled${NC}"
        echo -e "${CYAN}  • File watchers increased (IDEs)${NC}"
        echo -e "${CYAN}  • Core dumps enabled${NC}"
        echo -e "${CYAN}  • Shared memory increased${NC}"
    fi
}

enable_nightmode() {
    local current=$(get_state "NIGHTMODE")
    
    if [ "$current" = "true" ]; then
        echo -e "${YELLOW}➜ Disabling Night Mode...${NC}"
        
        # Restore color temperature
        redshift -x 2>/dev/null || true
        brightnessctl set 100% 2>/dev/null || true
        pactl set-sink-volume @DEFAULT_SINK@ 100% 2>/dev/null || true
        
        set_state "NIGHTMODE" "false"
        echo -e "${GREEN}✓ Night Mode disabled${NC}"
    else
        echo -e "${CYAN}➜ Enabling Night Mode...${NC}"
        
        # Reduce blue light
        if command -v redshift &>/dev/null; then
            redshift -O 3400 2>/dev/null || true
            echo -e "${CYAN}  • Blue light reduced (3400K)${NC}"
        else
            echo -e "${YELLOW}  ⚠ Install redshift for blue light reduction${NC}"
        fi
        
        # Dim screen
        brightnessctl set 30% 2>/dev/null || true
        
        # Lower volume
        pactl set-sink-volume @DEFAULT_SINK@ 40% 2>/dev/null || true
        
        # Enable quiet mode too
        enable_quietmode
        
        set_state "NIGHTMODE" "true"
        echo -e "${GREEN}✓ Night Mode enabled${NC}"
        echo -e "${CYAN}  • Screen dimmed to 30%${NC}"
        echo -e "${CYAN}  • Volume lowered${NC}"
    fi
}

enable_travelmode() {
    local current=$(get_state "TRAVELMODE")
    
    if [ "$current" = "true" ]; then
        echo -e "${YELLOW}➜ Disabling Travel Mode...${NC}"
        
        # Restore normal settings
        echo schedutil | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
        sudo systemctl start bluetooth 2>/dev/null || true
        sudo rfkill unblock wifi 2>/dev/null || true
        brightnessctl set 100% 2>/dev/null || true
        
        set_state "TRAVELMODE" "false"
        echo -e "${GREEN}✓ Travel Mode disabled${NC}"
    else
        echo -e "${CYAN}➜ Enabling Travel Mode...${NC}"
        
        # Maximum power saving
        enable_powermode
        
        # Disable Bluetooth
        sudo systemctl stop bluetooth 2>/dev/null || true
        
        # Reduce WiFi power
        if command -v iw &>/dev/null; then
            for dev in /sys/class/net/wl*/device; do
                [ -e "$dev" ] && sudo iw dev $(basename $(dirname $dev)) set power_save on 2>/dev/null || true
            done
        fi
        
        # Extremely dim screen
        brightnessctl set 20% 2>/dev/null || true
        
        set_state "TRAVELMODE" "true"
        echo -e "${GREEN}✓ Travel Mode enabled${NC}"
        echo -e "${CYAN}  • Maximum battery optimization${NC}"
        echo -e "${CYAN}  • Bluetooth disabled${NC}"
        echo -e "${CYAN}  • WiFi power saving enabled${NC}"
    fi
}

enable_rendermode() {
    local current=$(get_state "RENDERMODE")
    
    if [ "$current" = "true" ]; then
        echo -e "${YELLOW}➜ Disabling Render Mode...${NC}"
        
        echo schedutil | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
        sudo systemctl start thermald 2>/dev/null || true
        
        set_state "RENDERMODE" "false"
        echo -e "${GREEN}✓ Render Mode disabled${NC}"
    else
        echo -e "${CYAN}➜ Enabling Render Mode...${NC}"
        
        # Maximum CPU performance
        echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
        
        # Disable CPU frequency scaling for consistency
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do
            [ -f "$cpu" ] && sudo cat "$cpu" | sudo tee "${cpu/max/min}" >/dev/null 2>&1 || true
        done
        
        # Disable thermal throttling temporarily (use with caution!)
        sudo systemctl stop thermald 2>/dev/null || true
        
        # Increase nice level for rendering processes
        pgrep -x blender 2>/dev/null && sudo renice -n -20 -p $(pgrep -x blender) 2>/dev/null || true
        
        set_state "RENDERMODE" "true"
        echo -e "${GREEN}✓ Render Mode enabled${NC}"
        echo -e "${CYAN}  • CPU locked to maximum frequency${NC}"
        echo -e "${CYAN}  • Thermal throttling disabled${NC}"
        echo -e "${YELLOW}  ⚠ Monitor temperatures closely!${NC}"
    fi
}

# Profile management
apply_profile() {
    local profile=$1
    
    # Find profile in config
    local profile_line=$(grep "^$profile:" "$PROFILES_FILE" 2>/dev/null)
    
    if [ -z "$profile_line" ]; then
        echo -e "${RED}✗ Profile '$profile' not found${NC}"
        return 1
    fi
    
    local modes=$(echo "$profile_line" | cut -d: -f2)
    local description=$(echo "$profile_line" | cut -d: -f3)
    
    echo -e "${CYAN}➜ Applying profile: ${BOLD}$profile${NC}"
    echo -e "${CYAN}  $description${NC}"
    echo ""
    
    # Split modes and enable each
    IFS=',' read -ra MODE_ARRAY <<< "$modes"
    for mode in "${MODE_ARRAY[@]}"; do
        case "$mode" in
            GAMEMODE) enable_gamemode ;;
            STREAMMODE) enable_streammode ;;
            PRODUCTIVITY) enable_productivity ;;
            POWERMODE) enable_powermode ;;
            QUIETMODE) enable_quietmode ;;
            DEVMODE) enable_devmode ;;
            NIGHTMODE) enable_nightmode ;;
            TRAVELMODE) enable_travelmode ;;
            RENDERMODE) enable_rendermode ;;
        esac
    done
    
    echo -e "${GREEN}✓ Profile applied successfully${NC}"
}

# Show status
show_status() {
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║          ArchMode Status               ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    while IFS=: read -r mode_name display_name category description; do
        [[ "$mode_name" =~ ^#.*$ ]] && continue
        [[ -z "$mode_name" ]] && continue
        
        local state=$(get_state "$mode_name")
        if [ "$state" = "true" ]; then
            echo -e "${GREEN}✓${NC} ${BOLD}$display_name${NC} ${GREEN}[ENABLED]${NC}"
        else
            echo -e "${RED}✗${NC} ${BOLD}$display_name${NC} ${RED}[DISABLED]${NC}"
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
    
    local current_category=""
    while IFS=: read -r mode_name display_name category description; do
        [[ "$mode_name" =~ ^#.*$ ]] && continue
        [[ -z "$mode_name" ]] && continue
        
        if [ "$category" != "$current_category" ]; then
            echo -e "${MAGENTA}${BOLD}$category:${NC}"
            current_category="$category"
        fi
        
        echo -e "  ${CYAN}➜${NC} ${BOLD}$mode_name${NC} - $display_name"
        echo -e "    ${description}"
    done < "$MODES_FILE"
    echo ""
}

# List profiles
list_profiles() {
    echo -e "${MAGENTA}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║       Available Profiles               ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    while IFS=: read -r profile_name modes description; do
        [[ "$profile_name" =~ ^#.*$ ]] && continue
        [[ -z "$profile_name" ]] && continue
        
        echo -e "${MAGENTA}➜${NC} ${BOLD}$profile_name${NC}"
        echo -e "  ${description}"
        echo -e "  ${CYAN}Modes: $modes${NC}"
        echo ""
    done < "$PROFILES_FILE"
}

# Reset all
reset_all() {
    echo -e "${YELLOW}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║          Reset All Modes               ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"

    read -p "Are you sure you want to disable ALL modes? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${CYAN}➜ Reset cancelled${NC}"
        return
    fi

    backup_config

    while IFS=: read -r mode_name _; do
        [[ "$mode_name" =~ ^#.*$ ]] && continue
        [[ -z "$mode_name" ]] && continue
        set_state "$mode_name" "false"
    done < "$MODES_FILE"

    echo schedutil | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
    systemctl --user start dunst 2>/dev/null || true
    brightnessctl set 100% 2>/dev/null || true
    pactl set-sink-volume @DEFAULT_SINK@ 100% 2>/dev/null || true
    sudo systemctl start thermald 2>/dev/null || true
    sudo systemctl start bluetooth 2>/dev/null || true
    sudo rfkill unblock wifi 2>/dev/null || true

    echo -e "${GREEN}✓ All modes have been reset to defaults${NC}"
}

# Update ArchMode from GitHub
update_archmode() {
    local GITHUB_REPO="https://github.com/theofficalnoodles/ArchMode"
    local INSTALLED_SCRIPT="/usr/local/bin/archmode"
    local TEMP_DIR=$(mktemp -d)
    local BACKUP_SCRIPT="$INSTALLED_SCRIPT.backup.$(date +%Y%m%d_%H%M%S)"
    
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║         Updating ArchMode              ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    # Check if script is installed
    if [ ! -f "$INSTALLED_SCRIPT" ]; then
        echo -e "${RED}✗ ArchMode not found at $INSTALLED_SCRIPT${NC}"
        echo -e "${YELLOW}  Please install ArchMode first${NC}"
        return 1
    fi
    
    # Check for git or curl/wget
    if command -v git &>/dev/null; then
        echo -e "${CYAN}➜ Using git to download latest version...${NC}"
        
        # Clone the repository
        if git clone "$GITHUB_REPO.git" "$TEMP_DIR/ArchMode" 2>/dev/null; then
            if [ -f "$TEMP_DIR/ArchMode/archmode.sh" ]; then
                local NEW_SCRIPT="$TEMP_DIR/ArchMode/archmode.sh"
            else
                echo -e "${RED}✗ archmode.sh not found in repository${NC}"
                rm -rf "$TEMP_DIR"
                return 1
            fi
        else
            echo -e "${RED}✗ Failed to clone repository${NC}"
            rm -rf "$TEMP_DIR"
            return 1
        fi
    elif command -v curl &>/dev/null; then
        echo -e "${CYAN}➜ Using curl to download latest version...${NC}"
        
        # Download the script directly
        local NEW_SCRIPT="$TEMP_DIR/archmode.sh"
        if curl -sL "$GITHUB_REPO/raw/main/archmode.sh" -o "$NEW_SCRIPT"; then
            if [ ! -f "$NEW_SCRIPT" ] || [ ! -s "$NEW_SCRIPT" ]; then
                echo -e "${RED}✗ Failed to download script${NC}"
                rm -rf "$TEMP_DIR"
                return 1
            fi
        else
            echo -e "${RED}✗ Failed to download from GitHub${NC}"
            rm -rf "$TEMP_DIR"
            return 1
        fi
    elif command -v wget &>/dev/null; then
        echo -e "${CYAN}➜ Using wget to download latest version...${NC}"
        
        # Download the script directly
        local NEW_SCRIPT="$TEMP_DIR/archmode.sh"
        if wget -q "$GITHUB_REPO/raw/main/archmode.sh" -O "$NEW_SCRIPT"; then
            if [ ! -f "$NEW_SCRIPT" ] || [ ! -s "$NEW_SCRIPT" ]; then
                echo -e "${RED}✗ Failed to download script${NC}"
                rm -rf "$TEMP_DIR"
                return 1
            fi
        else
            echo -e "${RED}✗ Failed to download from GitHub${NC}"
            rm -rf "$TEMP_DIR"
            return 1
        fi
    else
        echo -e "${RED}✗ No download tool available (git, curl, or wget required)${NC}"
        echo -e "${YELLOW}  Install one with: sudo pacman -S git${NC}"
        return 1
    fi
    
    # Check if new version is different
    if cmp -s "$INSTALLED_SCRIPT" "$NEW_SCRIPT" 2>/dev/null; then
        echo -e "${GREEN}✓ Already running the latest version${NC}"
        rm -rf "$TEMP_DIR"
        return 0
    fi
    
    # Get new version number
    local NEW_VERSION=$(grep -m1 "^VERSION=" "$NEW_SCRIPT" 2>/dev/null | cut -d'"' -f2 || echo "unknown")
    echo -e "${CYAN}➜ New version found: ${BOLD}$NEW_VERSION${NC}"
    echo -e "${CYAN}  Current version: ${BOLD}$VERSION${NC}"
    echo ""
    
    # Backup current script
    echo -e "${CYAN}➜ Backing up current version...${NC}"
    if sudo cp "$INSTALLED_SCRIPT" "$BACKUP_SCRIPT"; then
        echo -e "${GREEN}✓ Backup created: $BACKUP_SCRIPT${NC}"
        log "Backup created before update: $BACKUP_SCRIPT"
    else
        echo -e "${YELLOW}⚠ Failed to create backup (continuing anyway)${NC}"
    fi
    
    # Install new version
    echo -e "${CYAN}➜ Installing new version...${NC}"
    if sudo cp "$NEW_SCRIPT" "$INSTALLED_SCRIPT" && sudo chmod +x "$INSTALLED_SCRIPT"; then
        echo -e "${GREEN}✓ New version installed successfully${NC}"
        log "Updated to version $NEW_VERSION"
    else
        echo -e "${RED}✗ Failed to install new version${NC}"
        echo -e "${YELLOW}  Restoring from backup...${NC}"
        sudo cp "$BACKUP_SCRIPT" "$INSTALLED_SCRIPT" 2>/dev/null || true
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    # Clean up temporary files
    rm -rf "$TEMP_DIR"
    
    # Optionally remove old backups (keep last 3)
    local backups=($(ls -t "$INSTALLED_SCRIPT".backup.* 2>/dev/null))
    if [ ${#backups[@]} -gt 3 ]; then
        echo -e "${CYAN}➜ Cleaning up old backups...${NC}"
        for ((i=3; i<${#backups[@]}; i++)); do
            sudo rm -f "${backups[$i]}"
        done
    fi
    
    echo ""
    echo -e "${GREEN}✓${NC} ${BOLD}Update complete!${NC}"
    echo -e "${CYAN}  ArchMode has been updated to version $NEW_VERSION${NC}"
    echo -e "${CYAN}  Your configuration and logs have been preserved${NC}"
    echo ""
    echo -e "${YELLOW}Note:${NC} If you're running this update command, you may need to"
    echo -e "      restart your terminal or run: ${BOLD}hash -r${NC}"
}

# Uninstall ArchMode
uninstall_archmode() {
    local INSTALLED_SCRIPT="/usr/local/bin/archmode"
    local SYSTEMD_SERVICE="/etc/systemd/system/archmode.service"
    
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║        Uninstalling ArchMode           ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    # Check if script is installed
    if [ ! -f "$INSTALLED_SCRIPT" ]; then
        echo -e "${YELLOW}⚠ ArchMode not found at $INSTALLED_SCRIPT${NC}"
        echo -e "${CYAN}  It may already be uninstalled${NC}"
    else
        echo -e "${CYAN}➜ Removing ArchMode script...${NC}"
        if sudo rm -f "$INSTALLED_SCRIPT"; then
            echo -e "${GREEN}✓ Script removed${NC}"
            log "ArchMode uninstalled"
        else
            echo -e "${RED}✗ Failed to remove script${NC}"
            return 1
        fi
    fi
    
    # Remove systemd service if it exists
    if [ -f "$SYSTEMD_SERVICE" ]; then
        echo -e "${CYAN}➜ Removing systemd service...${NC}"
        sudo systemctl disable archmode 2>/dev/null || true
        if sudo rm -f "$SYSTEMD_SERVICE"; then
            sudo systemctl daemon-reload 2>/dev/null || true
            echo -e "${GREEN}✓ Systemd service removed${NC}"
        else
            echo -e "${YELLOW}⚠ Failed to remove systemd service${NC}"
        fi
    fi
    
    # Ask about config and data
    echo ""
    echo -e "${YELLOW}Configuration and data files:${NC}"
    echo -e "  ${CYAN}~/.config/archmode${NC}"
    echo -e "  ${CYAN}~/.local/share/archmode${NC}"
    echo ""
    read -p "Do you want to remove configuration and data files? (y/N): " remove_config
    
    if [[ "$remove_config" == "y" || "$remove_config" == "Y" ]]; then
        echo -e "${CYAN}➜ Removing configuration files...${NC}"
        if rm -rf "$CONFIG_DIR"; then
            echo -e "${GREEN}✓ Configuration removed${NC}"
        else
            echo -e "${YELLOW}⚠ Failed to remove configuration${NC}"
        fi
        
        echo -e "${CYAN}➜ Removing data files...${NC}"
        if rm -rf "$LOG_DIR"; then
            echo -e "${GREEN}✓ Data files removed${NC}"
        else
            echo -e "${YELLOW}⚠ Failed to remove data files${NC}"
        fi
    else
        echo -e "${CYAN}➜ Configuration and data files preserved${NC}"
    fi
    
    # Remove backups
    local backups=($(ls -t "$INSTALLED_SCRIPT".backup.* 2>/dev/null))
    if [ ${#backups[@]} -gt 0 ]; then
        echo -e "${CYAN}➜ Removing backup files...${NC}"
        for backup in "${backups[@]}"; do
            sudo rm -f "$backup" 2>/dev/null || true
        done
        echo -e "${GREEN}✓ Backups removed${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}✓${NC} ${BOLD}Uninstallation complete!${NC}"
    echo -e "${CYAN}  ArchMode has been removed from your system${NC}"
    echo ""
}

# Help / usage
show_help() {
    echo -e "${CYAN}${BOLD}"
    echo "ArchMode v$VERSION - System Mode Manager for Arch Linux"
    echo -e "${NC}"
    echo "Usage: archmode <command> [argument]"
    echo ""
    echo -e "${BOLD}Commands:${NC}"
    echo "  status                 Show current mode status"
    echo "  stats                  Show live system statistics"
    echo "  modes                  List available modes"
    echo "  profiles               List available profiles"
    echo "  enable <MODE>           Toggle a specific mode"
    echo "  profile <PROFILE>       Apply a profile"
    echo "  reset                  Disable all modes"
    echo "  backup                 Backup current state"
    echo "  restore                Restore a backup"
    echo "  detect                 Detect system hardware"
    echo "  update                 Update ArchMode to latest version"
    echo "  uninstall              Uninstall ArchMode from system"
    echo "  help                   Show this help message"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "  archmode enable GAMEMODE"
    echo "  archmode profile GAMER"
    echo "  archmode reset"
    echo "  archmode update"
}

# ============================================
# Argument parsing
# ============================================

command="${1:-help}"
argument="${2:-}"

case "$command" in
    status)
        show_status
        ;;
    stats)
        show_stats
        ;;
    modes)
        list_modes
        ;;
    profiles)
        list_profiles
        ;;
    enable)
        case "$argument" in
            GAMEMODE) enable_gamemode ;;
            STREAMMODE) enable_streammode ;;
            PRODUCTIVITY) enable_productivity ;;
            POWERMODE) enable_powermode ;;
            QUIETMODE) enable_quietmode ;;
            DEVMODE) enable_devmode ;;
            NIGHTMODE) enable_nightmode ;;
            TRAVELMODE) enable_travelmode ;;
            RENDERMODE) enable_rendermode ;;
            *)
                echo -e "${RED}✗ Unknown mode: $argument${NC}"
                echo "Use: archmode modes"
                exit 1
                ;;
        esac
        ;;
    profile)
        apply_profile "$argument"
        ;;
    reset)
        reset_all
        ;;
    backup)
        backup_config
        ;;
    restore)
        restore_config
        ;;
    detect)
        detect_system
        echo -e "${GREEN}✓ System information detected${NC}"
        ;;
    update)
        update_archmode
        ;;
    uninstall)
        uninstall_archmode
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}✗ Unknown command: $command${NC}"
        echo "Use: archmode help"
        exit 1
        ;;
esac
