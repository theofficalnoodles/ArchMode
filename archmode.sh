#!/bin/bash

# ArchMode - System Mode Manager for Arch Linux
# Version: 0.3.0

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
PLUGINS_DIR="/usr/lib/archmode/plugins"
HOOKS_DIR="/etc/archmode/hooks"
VERSION="0.3.0"

# Create directories
mkdir -p "$CONFIG_DIR" "$LOG_DIR" "$BACKUP_DIR"
sudo mkdir -p "$PLUGINS_DIR" "$HOOKS_DIR" 2>/dev/null || true

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

# Backup configuration
backup_config() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="$BACKUP_DIR/backup_$timestamp.conf"
    cp "$STATE_FILE" "$backup_file"
    echo -e "${GREEN}✓ Backup created${NC}"
    log "Backup: $backup_file"
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
    
    read -p "Select backup (1-${#backups[@]}): " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#backups[@]}" ]; then
        cp "${backups[$((choice-1))]}" "$STATE_FILE"
        echo -e "${GREEN}✓ Restored${NC}"
        log "Restored: ${backups[$((choice-1))]}"
    fi
}

# Check dependencies
check_dependencies() {
    local missing=()
    command -v dunst &>/dev/null || missing+=("dunst")
    command -v brightnessctl &>/dev/null || missing+=("brightnessctl")
    command -v cpupower &>/dev/null || missing+=("cpupower")
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${YELLOW}⚠ Missing:${NC}"
        printf '  - %s\n' "${missing[@]}"
        echo -e "${CYAN}Install: ${BOLD}sudo pacman -S ${missing[*]}${NC}"
        echo ""
    fi
}

# System stats
show_stats() {
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║        System Statistics               ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    echo -e "${BOLD}CPU Usage:${NC} ${cpu_usage}%"
    
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]; then
        local freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)
        local freq_ghz=$(echo "scale=2; $freq / 1000000" | bc)
        echo -e "${BOLD}CPU Frequency:${NC} ${freq_ghz} GHz"
    fi
    
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
        local governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
        echo -e "${BOLD}CPU Governor:${NC} $governor"
    fi
    
    local mem_info=$(free -h | awk '/^Mem:/{printf "%s / %s", $3, $2}')
    echo -e "${BOLD}Memory:${NC} $mem_info"
    
    if command -v sensors &>/dev/null; then
        local temp=$(sensors 2>/dev/null | grep -i 'Package id 0' | awk '{print $4}' | head -n1)
        [ -n "$temp" ] && echo -e "${BOLD}CPU Temp:${NC} $temp"
    fi
    
    if [ -d /sys/class/power_supply/BAT0 ]; then
        local battery=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null)
        local status=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null)
        [ -n "$battery" ] && echo -e "${BOLD}Battery:${NC} ${battery}% ($status)"
    fi
    
    echo ""
}

# Run hooks
run_hooks() {
    local mode=$1
    local phase=$2  # start or stop
    local hook_dir="$HOOKS_DIR/$mode/${phase}.d"
    
    if [ -d "$hook_dir" ]; then
        for hook in "$hook_dir"/*; do
            if [ -x "$hook" ]; then
                log "Running hook: $hook"
                "$hook" 2>/dev/null || true
            fi
        done
    fi
}

# Plugin management
plugin_list() {
    echo -e "${MAGENTA}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║        Available Plugins               ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    if [ ! -d "$PLUGINS_DIR" ]; then
        echo -e "${YELLOW}No plugins directory found${NC}"
        return
    fi
    
    for plugin in "$PLUGINS_DIR"/*.sh; do
        if [ -f "$plugin" ]; then
            local name=$(basename "$plugin" .sh)
            local status="STOPPED"
            if [ -f "/tmp/archmode_plugin_${name}.pid" ]; then
                status="RUNNING"
            fi
            echo -e "${MAGENTA}➜${NC} ${BOLD}$name${NC} [$status]"
        fi
    done
    echo ""
}

plugin_start() {
    local plugin_name=$1
    local plugin_file="$PLUGINS_DIR/${plugin_name}.sh"
    
    if [ ! -f "$plugin_file" ]; then
        echo -e "${RED}✗ Plugin not found: $plugin_name${NC}"
        return 1
    fi
    
    if [ -f "/tmp/archmode_plugin_${plugin_name}.pid" ]; then
        echo -e "${YELLOW}⚠ Plugin already running${NC}"
        return 0
    fi
    
    bash "$plugin_file" start
    echo $$ > "/tmp/archmode_plugin_${plugin_name}.pid"
    echo -e "${GREEN}✓ Plugin started: $plugin_name${NC}"
    log "Plugin started: $plugin_name"
}

plugin_stop() {
    local plugin_name=$1
    local plugin_file="$PLUGINS_DIR/${plugin_name}.sh"
    
    if [ ! -f "$plugin_file" ]; then
        echo -e "${RED}✗ Plugin not found: $plugin_name${NC}"
        return 1
    fi
    
    bash "$plugin_file" stop
    rm -f "/tmp/archmode_plugin_${plugin_name}.pid"
    echo -e "${GREEN}✓ Plugin stopped: $plugin_name${NC}"
    log "Plugin stopped: $plugin_name"
}

plugin_status() {
    local plugin_name=$1
    local plugin_file="$PLUGINS_DIR/${plugin_name}.sh"
    
    if [ ! -f "$plugin_file" ]; then
        echo -e "${RED}✗ Plugin not found: $plugin_name${NC}"
        return 1
    fi
    
    bash "$plugin_file" status
}

# MODE IMPLEMENTATIONS

enable_gamemode() {
    local current=$(get_state "GAMEMODE")
    
    if [ "$current" = "true" ]; then
        echo -e "${YELLOW}➜ Disabling Gaming Mode...${NC}"
        run_hooks "GAMEMODE" "stop"
        
        systemctl --user start dunst 2>/dev/null || true
        echo schedutil | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
        sudo sysctl -w kernel.sched_latency_ns=6000000 >/dev/null 2>&1 || true
        sudo sysctl -w vm.swappiness=60 >/dev/null 2>&1 || true
        
        set_state "GAMEMODE" "false"
        echo -e "${GREEN}✓ Gaming Mode disabled${NC}"
    else
        echo -e "${CYAN}➜ Enabling Gaming Mode...${NC}"
        run_hooks "GAMEMODE" "start"
        
        systemctl --user stop dunst 2>/dev/null || true
        echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
        sudo sysctl -w kernel.sched_latency_ns=4000000 >/dev/null 2>&1 || true
        sudo sysctl -w kernel.sched_min_granularity_ns=500000 >/dev/null 2>&1 || true
        sudo sysctl -w vm.swappiness=10 >/dev/null 2>&1 || true
        sudo sysctl -w vm.dirty_ratio=40 >/dev/null 2>&1 || true
        
        # Disable mouse acceleration
        if [ -n "${DISPLAY:-}" ]; then
            xinput list 2>/dev/null | grep -i 'pointer\|mouse' | grep -v 'XTEST' | cut -d= -f2 | cut -f1 | while read id; do
                xinput set-prop "$id" "libinput Accel Speed" 0 2>/dev/null || true
            done
        fi
        
        set_state "GAMEMODE" "true"
        echo -e "${GREEN}✓ Gaming Mode enabled${NC}"
        echo -e "${CYAN}  • CPU: performance${NC}"
        echo -e "${CYAN}  • Scheduler: optimized${NC}"
        echo -e "${CYAN}  • Swappiness: 10${NC}"
    fi
}

enable_streammode() {
    local current=$(get_state "STREAMMODE")
    
    if [ "$current" = "true" ]; then
        echo -e "${YELLOW}➜ Disabling Streaming Mode...${NC}"
        run_hooks "STREAMMODE" "stop"
        
        systemctl --user start dunst 2>/dev/null || true
        sudo sysctl -w net.core.rmem_max=212992 >/dev/null 2>&1 || true
        sudo sysctl -w net.core.wmem_max=212992 >/dev/null 2>&1 || true
        
        set_state "STREAMMODE" "false"
        echo -e "${GREEN}✓ Streaming Mode disabled${NC}"
    else
        echo -e "${CYAN}➜ Enabling Streaming Mode...${NC}"
        run_hooks "STREAMMODE" "start"
        
        systemctl --user stop dunst 2>/dev/null || true
        echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
        
        sudo sysctl -w net.core.rmem_max=134217728 >/dev/null 2>&1 || true
        sudo sysctl -w net.core.wmem_max=134217728 >/dev/null 2>&1 || true
        sudo sysctl -w net.ipv4.tcp_rmem="4096 87380 134217728" >/dev/null 2>&1 || true
        sudo sysctl -w net.ipv4.tcp_wmem="4096 65536 134217728" >/dev/null 2>&1 || true
        
        pgrep -x obs 2>/dev/null && sudo renice -n -10 -p $(pgrep -x obs) 2>/dev/null || true
        
        set_state "STREAMMODE" "true"
        echo -e "${GREEN}✓ Streaming Mode enabled${NC}"
        echo -e "${CYAN}  • Network: optimized${NC}"
        echo -e "${CYAN}  • CPU: performance${NC}"
    fi
}

enable_productivity() {
    local current=$(get_state "PRODUCTIVITY")
    
    if [ "$current" = "true" ]; then
        echo -e "${YELLOW}➜ Disabling Productivity Mode...${NC}"
        run_hooks "PRODUCTIVITY" "stop"
        
        gsettings set org.gnome.desktop.session idle-delay 300 2>/dev/null || true
        xset s on 2>/dev/null || true
        xset +dpms 2>/dev/null || true
        
        set_state "PRODUCTIVITY" "false"
        echo -e "${GREEN}✓ Productivity Mode disabled${NC}"
    else
        echo -e "${CYAN}➜ Enabling Productivity Mode...${NC}"
        run_hooks "PRODUCTIVITY" "start"
        
        systemctl --user start dunst 2>/dev/null || true
        gsettings set org.gnome.desktop.session idle-delay 0 2>/dev/null || true
        xset s off 2>/dev/null || true
        xset -dpms 2>/dev/null || true
        
        set_state "PRODUCTIVITY" "true"
        echo -e "${GREEN}✓ Productivity Mode enabled${NC}"
        echo -e "${CYAN}  • Screen sleep: disabled${NC}"
        echo -e "${CYAN}  • Notifications: enabled${NC}"
    fi
}

enable_powermode() {
    local current=$(get_state "POWERMODE")
    
    if [ "$current" = "true" ]; then
        echo -e "${YELLOW}➜ Disabling Power Save Mode...${NC}"
        run_hooks "POWERMODE" "stop"
        
        echo schedutil | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
        echo -1 | sudo tee /sys/module/usbcore/parameters/autosuspend >/dev/null 2>&1 || true
        brightnessctl set 100% 2>/dev/null || true
        sudo sysctl -w vm.laptop_mode=0 >/dev/null 2>&1 || true
        
        set_state "POWERMODE" "false"
        echo -e "${GREEN}✓ Power Save Mode disabled${NC}"
    else
        echo -e "${CYAN}➜ Enabling Power Save Mode...${NC}"
        run_hooks "POWERMODE" "start"
        
        echo powersave | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
        echo 1 | sudo tee /sys/module/usbcore/parameters/autosuspend >/dev/null 2>&1 || true
        brightnessctl set 50% 2>/dev/null || true
        sudo sysctl -w vm.laptop_mode=5 >/dev/null 2>&1 || true
        
        if command -v xrandr &>/dev/null && [ -n "${DISPLAY:-}" ]; then
            xrandr --output $(xrandr | grep " connected" | cut -d" " -f1 | head -n1) --rate 60 2>/dev/null || true
        fi
        
        systemctl --user stop tracker-miner-fs-3.service 2>/dev/null || true
        
        set_state "POWERMODE" "true"
        echo -e "${GREEN}✓ Power Save Mode enabled${NC}"
        echo -e "${CYAN}  • CPU: powersave${NC}"
        echo -e "${CYAN}  • Brightness: 50%${NC}"
        echo -e "${CYAN}  • USB autosuspend: on${NC}"
    fi
}

enable_quietmode() {
    local current=$(get_state "QUIETMODE")
    
    if [ "$current" = "true" ]; then
        echo -e "${YELLOW}➜ Disabling Quiet Mode...${NC}"
        run_hooks "QUIETMODE" "stop"
        
        echo schedutil | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
        pactl set-sink-volume @DEFAULT_SINK@ 100% 2>/dev/null || true
        
        set_state "QUIETMODE" "false"
        echo -e "${GREEN}✓ Quiet Mode disabled${NC}"
    else
        echo -e "${CYAN}➜ Enabling Quiet Mode...${NC}"
        run_hooks "QUIETMODE" "start"
        
        echo powersave | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
        pactl set-sink-volume @DEFAULT_SINK@ 50% 2>/dev/null || true
        
        set_state "QUIETMODE" "true"
        echo -e "${GREEN}✓ Quiet Mode enabled${NC}"
        echo -e "${CYAN}  • CPU: reduced${NC}"
        echo -e "${CYAN}  • Volume: 50%${NC}"
    fi
}

enable_devmode() {
    local current=$(get_state "DEVMODE")
    
    if [ "$current" = "true" ]; then
        echo -e "${YELLOW}➜ Disabling Development Mode...${NC}"
        run_hooks "DEVMODE" "stop"
        
        sudo systemctl start packagekit 2>/dev/null || true
        sudo sysctl -w fs.inotify.max_user_watches=8192 >/dev/null 2>&1 || true
        
        set_state "DEVMODE" "false"
        echo -e "${GREEN}✓ Development Mode disabled${NC}"
    else
        echo -e "${CYAN}➜ Enabling Development Mode...${NC}"
        run_hooks "DEVMODE" "start"
        
        sudo systemctl stop packagekit 2>/dev/null || true
        sudo sysctl -w fs.inotify.max_user_watches=524288 >/dev/null 2>&1 || true
        ulimit -c unlimited 2>/dev/null || true
        sudo sysctl -w kernel.shmmax=68719476736 >/dev/null 2>&1 || true
        
        set_state "DEVMODE" "true"
        echo -e "${GREEN}✓ Development Mode enabled${NC}"
        echo -e "${CYAN}  • File watchers: increased${NC}"
        echo -e "${CYAN}  • Core dumps: enabled${NC}"
    fi
}

enable_nightmode() {
    local current=$(get_state "NIGHTMODE")
    
    if [ "$current" = "true" ]; then
        echo -e "${YELLOW}➜ Disabling Night Mode...${NC}"
        run_hooks "NIGHTMODE" "stop"
        
        redshift -x 2>/dev/null || true
        brightnessctl set 100% 2>/dev/null || true
        pactl set-sink-volume @DEFAULT_SINK@ 100% 2>/dev/null || true
        
        set_state "NIGHTMODE" "false"
        echo -e "${GREEN}✓ Night Mode disabled${NC}"
    else
        echo -e "${CYAN}➜ Enabling Night Mode...${NC}"
        run_hooks "NIGHTMODE" "start"
        
        if command -v redshift &>/dev/null; then
            redshift -O 3400 2>/dev/null || true
        fi
        
        brightnessctl set 30% 2>/dev/null || true
        pactl set-sink-volume @DEFAULT_SINK@ 40% 2>/dev/null || true
        
        set_state "NIGHTMODE" "true"
        echo -e "${GREEN}✓ Night Mode enabled${NC}"
        echo -e "${CYAN}  • Blue light: reduced${NC}"
        echo -e "${CYAN}  • Brightness: 30%${NC}"
    fi
}

enable_travelmode() {
    local current=$(get_state "TRAVELMODE")
    
    if [ "$current" = "true" ]; then
        echo -e "${YELLOW}➜ Disabling Travel Mode...${NC}"
        run_hooks "TRAVELMODE" "stop"
        
        echo schedutil | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
        sudo systemctl start bluetooth 2>/dev/null || true
        brightnessctl set 100% 2>/dev/null || true
        
        set_state "TRAVELMODE" "false"
        echo -e "${GREEN}✓ Travel Mode disabled${NC}"
    else
        echo -e "${CYAN}➜ Enabling Travel Mode...${NC}"
        run_hooks "TRAVELMODE" "start"
        
        enable_powermode
        sudo systemctl stop bluetooth 2>/dev/null || true
        
        if command -v iw &>/dev/null; then
            for dev in /sys/class/net/wl*/device; do
                [ -e "$dev" ] && sudo iw dev $(basename $(dirname $dev)) set power_save on 2>/dev/null || true
            done
        fi
        
        brightnessctl set 20% 2>/dev/null || true
        
        set_state "TRAVELMODE" "true"
        echo -e "${GREEN}✓ Travel Mode enabled${NC}"
        echo -e "${CYAN}  • Battery: maximized${NC}"
        echo -e "${CYAN}  • Bluetooth: off${NC}"
    fi
}

enable_rendermode() {
    local current=$(get_state "RENDERMODE")
    
    if [ "$current" = "true" ]; then
        echo -e "${YELLOW}➜ Disabling Render Mode...${NC}"
        run_hooks "RENDERMODE" "stop"
        
        echo schedutil | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
        
        set_state "RENDERMODE" "false"
        echo -e "${GREEN}✓ Render Mode disabled${NC}"
    else
        echo -e "${CYAN}➜ Enabling Render Mode...${NC}"
        run_hooks "RENDERMODE" "start"
        
        echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
        
        pgrep -x blender 2>/dev/null && sudo renice -n -20 -p $(pgrep -x blender) 2>/dev/null || true
        
        set_state "RENDERMODE" "true"
        echo -e "${GREEN}✓ Render Mode enabled${NC}"
        echo -e "${CYAN}  • CPU: max performance${NC}"
        echo -e "${YELLOW}  ⚠ Monitor temps!${NC}"
    fi
}

# Profile management
apply_profile() {
    local profile=$1
    local profile_line=$(grep "^$profile:" "$PROFILES_FILE" 2>/dev/null)
    
    if [ -z "$profile_line" ]; then
        echo -e "${RED}✗ Profile not found: $profile${NC}"
        return 1
    fi
    
    local modes=$(echo "$profile_line" | cut -d: -f2)
    local description=$(echo "$profile_line" | cut -d: -f3)
    
    echo -e "${CYAN}➜ Applying profile: ${BOLD}$profile${NC}"
    echo -e "${CYAN}  $description${NC}"
    echo ""
    
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
    
    echo -e "${GREEN}✓ Profile applied${NC}"
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
            echo -e "${GREEN}✓${NC} ${BOLD}$display_name${NC} ${GREEN}[ON]${NC}"
        else
            echo -e "${RED}✗${NC} ${BOLD}$display_name${NC} ${RED}[OFF]${NC}"
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
    echo "║         Resetting Everything           ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    backup_config
    
    while IFS=: read -r mode_name display_name category description; do
        [[ "$mode_name" =~ ^#.*$ ]] && continue
        [[ -z "$mode_name" ]] && continue
        set_state "$mode_name" "false"
    done < "$MODES_FILE"
    
    echo schedutil | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
    systemctl --user start dunst 2>/dev/null || true
    redshift -x 2>/dev/null || true
    brightnessctl set 100% 2>/dev/null || true  # ← THIS IS WHERE IT GOES
    sudo systemctl start bluetooth 2>/dev/null || true
    
    echo -e "${GREEN}✓ All reset${NC}"
    log "Full reset"
}
