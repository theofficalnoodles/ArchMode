#!/bin/bash

# ArchMode - System Mode Manager for Arch Linux
# Version: 0.9.0
# Ultimate Performance Tool - Advanced system optimizations

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
VERSION="0.9.0"

# Performance: Cache state in memory
declare -A STATE_CACHE
STATE_CACHE_LOADED=false

# Performance: Cache system capabilities
declare -A SYS_CAPABILITIES
SYS_CAPABILITIES_LOADED=false

# Performance: Sudo check cache
SUDO_AVAILABLE=""
SUDO_CHECKED=false

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
ULTIMATE:Ultimate Performance:Performance:Maximum system performance - all optimizations enabled
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
POWER_USER:ULTIMATE:Maximum performance for demanding tasks
EOF
fi

# Logging function with performance optimization
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Load state cache for performance
load_state_cache() {
    if [ "$STATE_CACHE_LOADED" = false ]; then
        while IFS='=' read -r key value; do
            [[ "$key" =~ ^#.*$ ]] && continue
            [[ -z "$key" ]] && continue
            STATE_CACHE["$key"]="$value"
        done < "$STATE_FILE" 2>/dev/null || true
        STATE_CACHE_LOADED=true
    fi
}

# Check sudo availability (cached)
check_sudo() {
    if [ "$SUDO_CHECKED" = false ]; then
        if sudo -n true 2>/dev/null || sudo -v 2>/dev/null; then
            SUDO_AVAILABLE="true"
        else
            SUDO_AVAILABLE="false"
        fi
        SUDO_CHECKED=true
    fi
    [ "$SUDO_AVAILABLE" = "true" ]
}

# System info detection (optimized)
detect_system() {
    local cpu_count=$(nproc 2>/dev/null || echo "unknown")
    local total_mem=$(free -g 2>/dev/null | awk '/^Mem:/{print $2}' || echo "unknown")
    local gpu_vendor=$(lspci 2>/dev/null | grep -i 'vga\|3d' | head -n1 || echo "unknown")

    {
        echo "CPU_CORES=$cpu_count"
        echo "TOTAL_RAM=${total_mem}G"
        echo "GPU=$gpu_vendor"
        if [ -d /sys/class/power_supply/BAT0 ] || [ -d /sys/class/power_supply/BAT1 ]; then
            echo "IS_LAPTOP=true"
        else
            echo "IS_LAPTOP=false"
        fi
    } > "$CONFIG_DIR/system.info"

    log "System detection completed"
}

# Get state (optimized with caching)
get_state() {
    local item=$1
    load_state_cache

    if [[ -n "${STATE_CACHE[$item]:-}" ]]; then
        echo "${STATE_CACHE[$item]}"
    else
        echo "false"
    fi
}

# Set state (optimized with caching)
set_state() {
    local item=$1
    local state=$2

    load_state_cache
    STATE_CACHE["$item"]="$state"

    # Update file efficiently
    if grep -q "^$item=" "$STATE_FILE" 2>/dev/null; then
        sed -i "s/^$item=.*/$item=$state/" "$STATE_FILE"
    else
        echo "$item=$state" >> "$STATE_FILE"
    fi
    log "Set $item to $state"
}

# Batch set multiple states (performance optimization)
batch_set_state() {
    local states=("$@")
    load_state_cache

    for state_pair in "${states[@]}"; do
        local item="${state_pair%%=*}"
        local state="${state_pair#*=}"
        STATE_CACHE["$item"]="$state"
    done

    # Write all at once
    {
        for key in "${!STATE_CACHE[@]}"; do
            echo "$key=${STATE_CACHE[$key]}"
        done
    } > "$STATE_FILE"

    log "Batch state update: ${#states[@]} items"
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
    local backup_count=${#backups[@]}
    
    if [ "$backup_count" -eq 0 ]; then
        echo -e "${RED}✗ No backups found${NC}"
        return 1
    fi
    
    echo -e "${CYAN}Available backups:${NC}"
    for i in "${!backups[@]}"; do
        local date=$(basename "${backups[$i]}" | sed 's/backup_\(.*\).conf/\1/')
        echo -e "${BLUE}[$((i+1))]${NC} $date"
    done
    
    read -p "Select backup to restore (1-$backup_count): " choice
    
    # Check if choice is a number and within range
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$backup_count" ]; then
        local index=$((choice-1))
        cp "${backups[$index]}" "$STATE_FILE"
        STATE_CACHE_LOADED=false  # Invalidate cache
        echo -e "${GREEN}✓ Configuration restored${NC}"
        log "Restored from backup: ${backups[$index]}"
    else
        echo -e "${RED}✗ Invalid choice${NC}"
    fi
}

# Load system capabilities (cached)
load_system_capabilities() {
    if [ "$SYS_CAPABILITIES_LOADED" = false ]; then
        command -v dunst &>/dev/null && SYS_CAPABILITIES["dunst"]="true" || SYS_CAPABILITIES["dunst"]="false"
        command -v brightnessctl &>/dev/null && SYS_CAPABILITIES["brightnessctl"]="true" || SYS_CAPABILITIES["brightnessctl"]="false"
        command -v cpupower &>/dev/null && SYS_CAPABILITIES["cpupower"]="true" || SYS_CAPABILITIES["cpupower"]="false"
        command -v sensors &>/dev/null && SYS_CAPABILITIES["sensors"]="true" || SYS_CAPABILITIES["sensors"]="false"
        command -v xrandr &>/dev/null && SYS_CAPABILITIES["xrandr"]="true" || SYS_CAPABILITIES["xrandr"]="false"
        command -v xinput &>/dev/null && SYS_CAPABILITIES["xinput"]="true" || SYS_CAPABILITIES["xinput"]="false"
        command -v pactl &>/dev/null && SYS_CAPABILITIES["pactl"]="true" || SYS_CAPABILITIES["pactl"]="false"
        command -v redshift &>/dev/null && SYS_CAPABILITIES["redshift"]="true" || SYS_CAPABILITIES["redshift"]="false"
        [ -n "$DISPLAY" ] && SYS_CAPABILITIES["display"]="true" || SYS_CAPABILITIES["display"]="false"
        [ -d /sys/devices/system/cpu/cpu0/cpufreq ] && SYS_CAPABILITIES["cpufreq"]="true" || SYS_CAPABILITIES["cpufreq"]="false"
        [ -d /sys/class/power_supply/BAT0 ] && SYS_CAPABILITIES["battery"]="true" || SYS_CAPABILITIES["battery"]="false"
        SYS_CAPABILITIES_LOADED=true
    fi
}

# Check if system has capability
has_capability() {
    local cap=$1
    load_system_capabilities
    [ "${SYS_CAPABILITIES[$cap]:-false}" = "true" ]
}

# Check dependencies (optimized)
check_dependencies() {
    local missing=()
    load_system_capabilities

    [ "${SYS_CAPABILITIES[dunst]}" = "false" ] && missing+=("dunst")
    [ "${SYS_CAPABILITIES[brightnessctl]}" = "false" ] && missing+=("brightnessctl")
    [ "${SYS_CAPABILITIES[cpupower]}" = "false" ] && missing+=("cpupower")

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${YELLOW}⚠ Optional dependencies missing:${NC}"
        printf '  - %s\n' "${missing[@]}"
        echo -e "${CYAN}Install with: ${BOLD}sudo pacman -S ${missing[*]}${NC}"
        echo ""
    fi
}

# ============================================
# PLUGIN SYSTEM
# ============================================

# List available plugins
plugin_list() {
    echo -e "${MAGENTA}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║        Available Plugins               ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""

    if [ ! -d "$PLUGINS_DIR" ]; then
        echo -e "${YELLOW}No plugins directory found${NC}"
        echo -e "${CYAN}Create plugins in: $PLUGINS_DIR${NC}"
        return
    fi

    local found_plugins=false
    for plugin in "$PLUGINS_DIR"/*.sh; do
        if [ -f "$plugin" ]; then
            found_plugins=true
            local name=$(basename "$plugin" .sh)
            local status="STOPPED"
            if [ -f "/tmp/archmode_plugin_${name}.pid" ]; then
                status="RUNNING"
            fi
            echo -e "${MAGENTA}➜${NC} ${BOLD}$name${NC} [$status]"

            # Show description if available
            local desc=$(grep -m1 "^# Description:" "$plugin" 2>/dev/null | cut -d: -f2- | xargs)
            [ -n "$desc" ] && echo -e "  ${CYAN}$desc${NC}"
        fi
    done

    if [ "$found_plugins" = false ]; then
        echo -e "${YELLOW}No plugins found in $PLUGINS_DIR${NC}"
    fi
    echo ""
}

# Start a plugin
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

    if [ ! -x "$plugin_file" ]; then
        sudo chmod +x "$plugin_file" 2>/dev/null || chmod +x "$plugin_file" 2>/dev/null || true
    fi

    bash "$plugin_file" start 2>&1
    echo $$ > "/tmp/archmode_plugin_${plugin_name}.pid"
    echo -e "${GREEN}✓ Plugin started: $plugin_name${NC}"
    log "Plugin started: $plugin_name"
}

# Stop a plugin
plugin_stop() {
    local plugin_name=$1
    local plugin_file="$PLUGINS_DIR/${plugin_name}.sh"

    if [ ! -f "$plugin_file" ]; then
        echo -e "${RED}✗ Plugin not found: $plugin_name${NC}"
        return 1
    fi

    bash "$plugin_file" stop 2>&1
    rm -f "/tmp/archmode_plugin_${plugin_name}.pid"
    echo -e "${GREEN}✓ Plugin stopped: $plugin_name${NC}"
    log "Plugin stopped: $plugin_name"
}

# Get plugin status
plugin_status() {
    local plugin_name=$1
    local plugin_file="$PLUGINS_DIR/${plugin_name}.sh"

    if [ ! -f "$plugin_file" ]; then
        echo -e "${RED}✗ Plugin not found: $plugin_name${NC}"
        return 1
    fi

    bash "$plugin_file" status 2>&1
}

# ============================================
# HOOKS SYSTEM
# ============================================

# Run hooks for a mode
run_hooks() {
    local mode=$1
    local phase=$2  # start or stop
    local hook_dir="$HOOKS_DIR/$mode/${phase}.d"

    if [ ! -d "$hook_dir" ]; then
        return 0
    fi

    log "Running $phase hooks for $mode"

    for hook in "$hook_dir"/*; do
        if [ -x "$hook" ]; then
            log "Executing hook: $hook"
            "$hook" 2>&1 | while IFS= read -r line; do
                log "Hook output: $line"
            done
        fi
    done
}

# Create example hook
create_example_hooks() {
    local mode=$1

    if [ -z "$mode" ]; then
        echo -e "${RED}✗ No mode specified${NC}"
        return 1
    fi

    local start_dir="$HOOKS_DIR/$mode/start.d"
    local stop_dir="$HOOKS_DIR/$mode/stop.d"

    sudo mkdir -p "$start_dir" "$stop_dir" 2>/dev/null || mkdir -p "$start_dir" "$stop_dir" 2>/dev/null || true

    # Create example start hook
    local start_hook="$start_dir/10-example.sh"
    if [ ! -f "$start_hook" ]; then
        sudo tee "$start_hook" > /dev/null << 'EOF' || tee "$start_hook" > /dev/null << 'EOF'
#!/bin/bash
# Example start hook for mode
echo "Mode starting..."
# Add your custom commands here
EOF
        sudo chmod +x "$start_hook" 2>/dev/null || chmod +x "$start_hook" 2>/dev/null || true
    fi

    # Create example stop hook
    local stop_hook="$stop_dir/10-example.sh"
    if [ ! -f "$stop_hook" ]; then
        sudo tee "$stop_hook" > /dev/null << 'EOF' || tee "$stop_hook" > /dev/null << 'EOF'
#!/bin/bash
# Example stop hook for mode
echo "Mode stopping..."
# Add your custom commands here
EOF
        sudo chmod +x "$stop_hook" 2>/dev/null || chmod +x "$stop_hook" 2>/dev/null || true
    fi

    echo -e "${GREEN}✓ Example hooks created for $mode${NC}"
    echo -e "${CYAN}  Start hooks: $start_dir${NC}"
    echo -e "${CYAN}  Stop hooks: $stop_dir${NC}"
}

# List hooks
list_hooks() {
    echo -e "${MAGENTA}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║           Available Hooks              ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""

    if [ ! -d "$HOOKS_DIR" ]; then
        echo -e "${YELLOW}No hooks directory found${NC}"
        echo -e "${CYAN}Create hooks in: $HOOKS_DIR/<MODE>/start.d/  or stop.d/${NC}"
        return
    fi

    local found_hooks=false
    for mode_dir in "$HOOKS_DIR"/*; do
        if [ -d "$mode_dir" ]; then
            local mode=$(basename "$mode_dir")
            echo -e "${BOLD}$mode:${NC}"

            # List start hooks
            if [ -d "$mode_dir/start.d" ]; then
                for hook in "$mode_dir/start.d"/*; do
                    if [ -f "$hook" ]; then
                        found_hooks=true
                        local name=$(basename "$hook")
                        local exec_status="[NOT EXECUTABLE]"
                        [ -x "$hook" ] && exec_status="[EXECUTABLE]"
                        echo -e "  ${GREEN}➜ start:${NC} $name $exec_status"
                    fi
                done
            fi

            # List stop hooks
            if [ -d "$mode_dir/stop.d" ]; then
                for hook in "$mode_dir/stop.d"/*; do
                    if [ -f "$hook" ]; then
                        found_hooks=true
                        local name=$(basename "$hook")
                        local exec_status="[NOT EXECUTABLE]"
                        [ -x "$hook" ] && exec_status="[EXECUTABLE]"
                        echo -e "  ${RED}➜ stop:${NC} $name $exec_status"
                    fi
                done
            fi
            echo ""
        fi
    done

    if [ "$found_hooks" = false ]; then
        echo -e "${YELLOW}No hooks found${NC}"
    fi
}

# ============================================
# DRY RUN MODE
# ============================================

DRY_RUN=false

# Simulate mode changes
dry_run_mode() {
    local mode=$1

    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║        Dry Run - $mode"                ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${YELLOW}This is a simulation. No changes will be made.${NC}"
    echo ""

    case "$mode" in
        GAMEMODE)
            echo -e "${BOLD}Would apply:${NC}"
            echo "  • Stop dunst service"
            echo "  • Set CPU governor to 'performance'"
            echo "  • Enable CPU boost"
            echo "  • Optimize IRQ balancing"
            echo "  • Set I/O scheduler to 'none'"
            echo "  • Optimize memory for performance"
            echo "  • Optimize network stack"
            echo "  • Disable mouse acceleration"
            echo "  • Prioritize game processes"
            echo "  • Run start hooks from: $HOOKS_DIR/GAMEMODE/start.d/"
            ;;
        STREAMMODE)
            echo -e "${BOLD}Would apply:${NC}"
            echo "  • Stop dunst service"
            echo "  • Set CPU governor to 'performance'"
            echo "  • Enable CPU boost"
            echo "  • Optimize network for streaming"
            echo "  • Set I/O scheduler to 'bfq'"
            echo "  • Prioritize OBS/FFmpeg processes"
            echo "  • Run start hooks from: $HOOKS_DIR/STREAMMODE/start.d/"
            ;;
        ULTIMATE)
            echo -e "${BOLD}Would apply:${NC}"
            echo "  • ALL performance optimizations"
            echo "  • Maximum CPU performance with boost"
            echo "  • Lock CPU to max frequency"
            echo "  • Ultimate I/O optimization"
            echo "  • Ultimate memory optimization"
            echo "  • Ultimate network optimization"
            echo "  • Disable thermal throttling"
            echo "  • Prioritize all user processes"
            echo -e "${RED}  ⚠ Warning: System will run HOT!${NC}"
            ;;
        *)
            echo -e "${YELLOW}Mode not found for dry run${NC}"
            ;;
    esac

    echo ""
    echo -e "${CYAN}Plugins that would be started:${NC}"
    if [ -d "$PLUGINS_DIR" ]; then
        for plugin in "$PLUGINS_DIR"/*.sh; do
            [ -f "$plugin" ] && echo "  • $(basename "$plugin" .sh)"
        done
    else
        echo "  (No plugins available)"
    fi
}

# Monitor system resources (optimized)
show_stats() {
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║        System Statistics               ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"

    # CPU Usage (optimized - use /proc/stat instead of top)
    local cpu_idle cpu_total
    read -r cpu_idle cpu_total < <(awk '/^cpu / {idle=$5+$6; total=idle+$2+$3+$4; print idle, total}' /proc/stat)
    sleep 0.1
    local cpu_idle2 cpu_total2
    read -r cpu_idle2 cpu_total2 < <(awk '/^cpu / {idle=$5+$6; total=idle+$2+$3+$4; print idle, total}' /proc/stat)
    local cpu_usage=$(awk "BEGIN {printf \"%.1f\", (1-($cpu_idle2-$cpu_idle)/($cpu_total2-$cpu_total))*100}")
    echo -e "${BOLD}CPU Usage:${NC} ${cpu_usage}%"

    # CPU Frequency (optimized)
    if has_capability "cpufreq" && [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]; then
        local freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
        if [ -n "$freq" ]; then
            local freq_ghz=$(awk "BEGIN {printf \"%.2f\", $freq / 1000000}")
            echo -e "${BOLD}CPU Frequency:${NC} ${freq_ghz} GHz"
        fi

        if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
            local governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
            [ -n "$governor" ] && echo -e "${BOLD}CPU Governor:${NC} $governor"
        fi
    fi

    # Memory (optimized - single read)
    local mem_info=$(awk '/^MemTotal:/{total=$2} /^MemAvailable:/{avail=$2} END {used=total-avail; printf "%.1fG / %.1fG (%.1f%%)", used/1024/1024, total/1024/1024, (used/total)*100}' /proc/meminfo 2>/dev/null)
    [ -n "$mem_info" ] && echo -e "${BOLD}Memory:${NC} $mem_info"

    # Temperature (if available)
    if has_capability "sensors"; then
        local temp=$(sensors 2>/dev/null | grep -iE 'Package id 0|Tdie|Tctl' | awk '{print $2$3}' | head -n1 | sed 's/+//')
        [ -n "$temp" ] && echo -e "${BOLD}CPU Temp:${NC} $temp"
    fi

    # Battery (if laptop)
    if has_capability "battery" && [ -f /sys/class/power_supply/BAT0/capacity ]; then
        local battery=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null)
        local status=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null)
        [ -n "$battery" ] && echo -e "${BOLD}Battery:${NC} ${battery}% ($status)"
    fi

    # Disk usage (optimized)
    local disk_usage=$(df -h / 2>/dev/null | awk 'NR==2{printf "%s / %s (%s)", $3, $2, $5}')
    [ -n "$disk_usage" ] && echo -e "${BOLD}Disk Usage:${NC} $disk_usage"

    # Active plugins
    echo ""
    echo -e "${BOLD}Active Plugins:${NC}"
    local active_found=false
    for pidfile in /tmp/archmode_plugin_*.pid; do
        if [ -f "$pidfile" ]; then
            active_found=true
            local plugin_name=$(basename "$pidfile" | sed 's/archmode_plugin_\(.*\).pid/\1/')
            echo -e "  ${GREEN}✓${NC} $plugin_name"
        fi
    done
    [ "$active_found" = false ] && echo -e "  ${YELLOW}(none)${NC}"

    echo ""
}

# ============================================
# MODE IMPLEMENTATIONS (keeping your optimized versions)
# ============================================

# Helper: Apply CPU governor (optimized batch operation)
apply_cpu_governor() {
    local governor=$1
    if has_capability "cpufreq" && check_sudo; then
        for cpu_path in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            [ -f "$cpu_path" ] && echo "$governor" | sudo tee "$cpu_path" >/dev/null 2>&1 || true
        done
    fi
}

# Helper: Apply sysctl settings (batch)
apply_sysctl() {
    local settings=("$@")
    if check_sudo; then
        for setting in "${settings[@]}"; do
            sudo sysctl -w "$setting" >/dev/null 2>&1 || true
        done
    fi
}

# Helper: Optimize I/O scheduler (advanced)
apply_io_scheduler() {
    local scheduler=$1
    if check_sudo; then
        for blockdev in /sys/block/sd*/queue/scheduler /sys/block/nvme*/queue/scheduler; do
            if [ -f "$blockdev" ]; then
                echo "$scheduler" | sudo tee "$blockdev" >/dev/null 2>&1 || true
            fi
        done
    fi
}

# Helper: Optimize IRQ balancing (advanced)
optimize_irq_balancing() {
    if check_sudo && [ -f /proc/sys/kernel/sched_irqloadbalance ]; then
        sudo sysctl -w kernel.sched_irqloadbalance=1 >/dev/null 2>&1 || true
    fi
    if [ -d /proc/irq ] && check_sudo; then
        local cpu_count=$(nproc)
        local cpu=0
        for irq_dir in /proc/irq/*/; do
            [ -f "${irq_dir}smp_affinity" ] || continue
            local mask=$(printf "%x" $((1 << cpu)))
            echo "$mask" | sudo tee "${irq_dir}smp_affinity" >/dev/null 2>&1 || true
            cpu=$(((cpu + 1) % cpu_count))
        done
    fi
}

# Helper: Set process priority and scheduling (advanced)
set_process_priority() {
    local pid=$1
    local nice=$2
    local sched=${3:-SCHED_OTHER}

    if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
        return 1
    fi

    if check_sudo; then
        sudo renice -n "$nice" -p "$pid" 2>/dev/null || true
        if [ "$sched" = "SCHED_FIFO" ] || [ "$sched" = "SCHED_RR" ]; then
            local priority=50
            [ "$sched" = "SCHED_FIFO" ] && chrt -f -p "$priority" "$pid" 2>/dev/null || \
            chrt -r -p "$priority" "$pid" 2>/dev/null || true
        fi
    fi
}

# Helper: Optimize memory settings (advanced)
optimize_memory() {
    local mode=$1

    if ! check_sudo; then
        return 1
    fi

    if [ "$mode" = "performance" ]; then
        apply_sysctl \
            "vm.swappiness=1" \
            "vm.vfs_cache_pressure=50" \
            "vm.dirty_ratio=15" \
            "vm.dirty_background_ratio=5" \
            "vm.overcommit_memory=1" \
            "vm.zone_reclaim_mode=0"

        if [ -f /sys/kernel/mm/transparent_hugepage/enabled ]; then
            echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled >/dev/null 2>&1 || true
        fi
        if [ -f /sys/kernel/mm/transparent_hugepage/defrag ]; then
            echo never | sudo tee /sys/kernel/mm/transparent_hugepage/defrag >/dev/null 2>&1 || true
        fi
    else
        apply_sysctl \
            "vm.swappiness=60" \
            "vm.vfs_cache_pressure=100" \
            "vm.dirty_ratio=20" \
            "vm.dirty_background_ratio=10" \
            "vm.overcommit_memory=0" \
            "vm.zone_reclaim_mode=0"

        if [ -f /sys/kernel/mm/transparent_hugepage/enabled ]; then
            echo madvise | sudo tee /sys/kernel/mm/transparent_hugepage/enabled >/dev/null 2>&1 || true
        fi
        if [ -f /sys/kernel/mm/transparent_hugepage/defrag ]; then
            echo madvise | sudo tee /sys/kernel/mm/transparent_hugepage/defrag >/dev/null 2>&1 || true
        fi
    fi
}

# Helper: Optimize network stack (advanced)
optimize_network() {
    local mode=$1

    if ! check_sudo; then
        return 1
    fi

    if [ "$mode" = "performance" ]; then
        apply_sysctl \
            "net.core.rmem_max=134217728" \
            "net.core.wmem_max=134217728" \
            "net.core.netdev_max_backlog=5000" \
            "net.core.netdev_budget=600" \
            "net.ipv4.tcp_rmem=4096 87380 134217728" \
            "net.ipv4.tcp_wmem=4096 65536 134217728" \
            "net.ipv4.tcp_congestion_control=bbr" \
            "net.ipv4.tcp_slow_start_after_idle=0" \
            "net.ipv4.tcp_tw_reuse=1" \
            "net.ipv4.tcp_fin_timeout=15" \
            "net.ipv4.tcp_keepalive_time=300" \
            "net.ipv4.tcp_keepalive_probes=5" \
            "net.ipv4.tcp_keepalive_intvl=15" \
            "net.ipv4.tcp_max_syn_backlog=8192" \
            "net.ipv4.tcp_syncookies=1" \
            "net.ipv4.tcp_timestamps=1" \
            "net.ipv4.tcp_sack=1" \
            "net.ipv4.tcp_window_scaling=1" \
            "net.ipv4.ip_local_port_range=1024 65535" \
            "net.ipv4.tcp_max_tw_buckets=2000000" \
            "net.ipv4.tcp_fastopen=3"
    else
        apply_sysctl \
            "net.core.rmem_max=212992" \
            "net.core.wmem_max=212992" \
            "net.core.netdev_max_backlog=1000" \
            "net.core.netdev_budget=300" \
            "net.ipv4.tcp_congestion_control=cubic" \
            "net.ipv4.tcp_slow_start_after_idle=1"
    fi
}

# Helper: Optimize CPU boost/turbo (advanced)
optimize_cpu_boost() {
    local enable=$1

    if ! check_sudo || ! has_capability "cpufreq"; then
        return 1
    fi

    for boost_file in /sys/devices/system/cpu/cpufreq/boost; do
        if [ -f "$boost_file" ]; then
            if [ "$enable" = "true" ]; then
                echo 1 | sudo tee "$boost_file" >/dev/null 2>&1 || true
            else
                echo 0 | sudo tee "$boost_file" >/dev/null 2>&1 || true
            fi
        fi
    done

    for turbo_file in /sys/devices/system/cpu/intel_pstate/no_turbo; do
        if [ -f "$turbo_file" ]; then
            if [ "$enable" = "true" ]; then
                echo 0 | sudo tee "$turbo_file" >/dev/null 2>&1 || true
            else
                echo 1 | sudo tee "$turbo_file" >/dev/null 2>&1 || true
            fi
        fi
    done
}

enable_gamemode() {
    local current=$(get_state "GAMEMODE")

    if [ "$current" = "true" ]; then
        echo -e "${YELLOW}➜ Disabling Gaming Mode...${NC}"

        run_hooks "GAMEMODE" "stop"

        has_capability "dunst" && systemctl --user start dunst 2>/dev/null || true
        apply_cpu_governor "schedutil"
        optimize_cpu_boost "false"
        apply_io_scheduler "mq-deadline"
        optimize_memory "balanced"
        optimize_network "balanced"
        apply_sysctl \
            "kernel.sched_latency_ns=6000000" \
            "kernel.sched_min_granularity_ns=750000" \
            "vm.dirty_ratio=20"

        set_state "GAMEMODE" "false"
        echo -e "${GREEN}✓ Gaming Mode disabled${NC}"
    else
        echo -e "${CYAN}➜ Enabling Gaming Mode...${NC}"

        run_hooks "GAMEMODE" "start"

        has_capability "dunst" && systemctl --user stop dunst 2>/dev/null || true
        apply_cpu_governor "performance"
        optimize_cpu_boost "true"
        optimize_irq_balancing
        apply_io_scheduler "none"
        optimize_memory "performance"
        optimize_network "performance"

        apply_sysctl \
            "kernel.sched_latency_ns=4000000" \
            "kernel.sched_min_granularity_ns=500000" \
            "kernel.sched_migration_cost_ns=5000000" \
            "kernel.sched_autogroup_enabled=0" \
            "vm.swappiness=1" \
            "vm.dirty_ratio=15" \
            "vm.dirty_background_ratio=5"

        if has_capability "display" && has_capability "xinput"; then
            xinput list 2>/dev/null | grep -iE 'pointer|mouse' | grep -v 'XTEST' | \
            sed -n 's/.*id=\([0-9]*\).*/\1/p' | while read -r id; do
                xinput set-prop "$id" "libinput Accel Speed" 0 2>/dev/null || true
            done
        fi

        for game_pid in $(pgrep -f -i "steam|lutris|wine|proton" 2>/dev/null | head -5); do
            set_process_priority "$game_pid" -15 "SCHED_OTHER" 2>/dev/null || true
        done

        set_state "GAMEMODE" "true"
        echo -e "${GREEN}✓ Gaming Mode enabled${NC}"
        echo -e "${CYAN}  • Notifications disabled${NC}"
        echo -e "${CYAN}  • CPU set to performance mode with boost${NC}"
        echo -e "${CYAN}  • I/O scheduler optimized for low latency${NC}"
        echo -e "${CYAN}  • Memory optimized for performance${NC}"
        echo -e "${CYAN}  • Network stack optimized${NC}"
        echo -e "${CYAN}  • IRQ balancing optimized${NC}"
        echo -e "${CYAN}  • Scheduler tuned for responsiveness${NC}"
        echo -e "${CYAN}  • Game processes prioritized${NC}"
    fi
}

enable_streammode() {
    local current=$(get_state "STREAMMODE")

    if [ "$current" = "true" ]; then
        echo -e "${YELLOW}➜ Disabling Streaming Mode...${NC}"

        run_hooks "STREAMMODE" "stop"

        has_capability "dunst" && systemctl --user start dunst 2>/dev/null || true
        optimize_network "balanced"
        apply_io_scheduler "mq-deadline"

        set_state "STREAMMODE" "false"
        echo -e "${GREEN}✓ Streaming Mode disabled${NC}"
    else
        echo -e "${CYAN}➜ Enabling Streaming Mode...${NC}"

        run_hooks "STREAMMODE" "start"

        has_capability "dunst" && systemctl --user stop dunst 2>/dev/null || true
        apply_cpu_governor "performance"
        optimize_cpu_boost "true"
        optimize_network "performance"
        apply_io_scheduler "bfq"
        optimize_memory "performance"

        for app in obs ffmpeg gstreamer; do
            for pid in $(pgrep -x "$app" 2>/dev/null); do
                set_process_priority "$pid" -15 "SCHED_OTHER" 2>/dev/null || true
            done
        done

        for pid in $(pgrep -f "x264|x265|nvenc|vaapi" 2>/dev/null); do
            set_process_priority "$pid" -10 "SCHED_OTHER" 2>/dev/null || true
        done

        set_state "STREAMMODE" "true"
        echo -e "${GREEN}✓ Streaming Mode enabled${NC}"
        echo -e "${CYAN}  • Network stack fully optimized${NC}"
        echo -e "${CYAN}  • CPU optimized for encoding with boost${NC}"
        echo -e "${CYAN}  • I/O scheduler optimized for streaming${NC}"
        echo -e "${CYAN}  • Streaming processes prioritized${NC}"
        echo -e "${CYAN}  • Memory optimized for performance${NC}"
    fi
}

enable_productivity() {
    local current=$(get_state "PRODUCTIVITY")

    if [ "$current" = "true" ]; then
        echo -e "${YELLOW}➜ Disabling Productivity Mode...${NC}"

        run_hooks "PRODUCTIVITY" "stop"

        if has_capability "display"; then
            command -v gsettings &>/dev/null && gsettings set org.gnome.desktop.session idle-delay 300 2>/dev/null || true
            has_capability "xrandr" && xset s on +dpms 2>/dev/null || true
        fi

        set_state "PRODUCTIVITY" "false"
        echo -e "${GREEN}✓ Productivity Mode disabled${NC}"
    else
        echo -e "${CYAN}➜ Enabling Productivity Mode...${NC}"

        run_hooks "PRODUCTIVITY" "start"

        has_capability "dunst" && systemctl --user start dunst 2>/dev/null || true

        if has_capability "display"; then
            command -v gsettings &>/dev/null && gsettings set org.gnome.desktop.session idle-delay 0 2>/dev/null || true
            has_capability "xrandr" && xset s off -dpms 2>/dev/null || true
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

        run_hooks "POWERMODE" "stop"

        apply_cpu_governor "schedutil"
        if check_sudo && [ -f /sys/module/usbcore/parameters/autosuspend ]; then
            echo -1 | sudo tee /sys/module/usbcore/parameters/autosuspend >/dev/null 2>&1 || true
        fi
        has_capability "brightnessctl" && brightnessctl set 100% 2>/dev/null || true
        apply_sysctl "vm.laptop_mode=0"

        set_state "POWERMODE" "false"
        echo -e "${GREEN}✓ Power Save Mode disabled${NC}"
    else
        echo -e "${CYAN}➜ Enabling Power Save Mode...${NC}"

        run_hooks "POWERMODE" "start"

        apply_cpu_governor "powersave"

        if check_sudo && [ -f /sys/module/usbcore/parameters/autosuspend ]; then
            echo 1 | sudo tee /sys/module/usbcore/parameters/autosuspend >/dev/null 2>&1 || true
        fi

        has_capability "brightnessctl" && brightnessctl set 50% 2>/dev/null || true
        apply_sysctl "vm.laptop_mode=5"

        if has_capability "display" && has_capability "xrandr"; then
            local output=$(xrandr 2>/dev/null | grep " connected" | cut -d" " -f1 | head -n1)
            [ -n "$output" ] && xrandr --output "$output" --rate 60 2>/dev/null || true
        fi

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

        run_hooks "QUIETMODE" "stop"

        apply_cpu_governor "schedutil"
        has_capability "pactl" && pactl set-sink-volume @DEFAULT_SINK@ 100% 2>/dev/null || true
        if check_sudo; then
            for pwm in /sys/class/hwmon/hwmon*/pwm1; do
                [ -f "$pwm" ] && echo 255 | sudo tee "$pwm" >/dev/null 2>&1 || true
            done
        fi

        set_state "QUIETMODE" "false"
        echo -e "${GREEN}✓ Quiet Mode disabled${NC}"
    else
        echo -e "${CYAN}➜ Enabling Quiet Mode...${NC}"

        run_hooks "QUIETMODE" "start"

        apply_cpu_governor "powersave"
        has_capability "pactl" && pactl set-sink-volume @DEFAULT_SINK@ 50% 2>/dev/null || true

        if check_sudo; then
            for pwm in /sys/class/hwmon/hwmon*/pwm1; do
                [ -f "$pwm" ] && echo 40 | sudo tee "$pwm" >/dev/null 2>&1 || true
            done
        fi

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

        run_hooks "DEVMODE" "stop"

        if check_sudo; then
            systemctl is-active packagekit &>/dev/null || sudo systemctl start packagekit 2>/dev/null || true
            apply_sysctl "fs.inotify.max_user_watches=8192"
        fi
        ulimit -c 0 2>/dev/null || true

        set_state "DEVMODE" "false"
        echo -e "${GREEN}✓ Development Mode disabled${NC}"
    else
        echo -e "${CYAN}➜ Enabling Development Mode...${NC}"

        run_hooks "DEVMODE" "start"

        if check_sudo; then
            systemctl is-active packagekit &>/dev/null && sudo systemctl stop packagekit 2>/dev/null || true
            apply_sysctl \
                "fs.inotify.max_user_watches=524288" \
                "kernel.shmmax=68719476736"
        fi

        ulimit -c unlimited 2>/dev/null || true

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

        run_hooks "NIGHTMODE" "stop"

        has_capability "redshift" && redshift -x 2>/dev/null || true
        has_capability "brightnessctl" && brightnessctl set 100% 2>/dev/null || true
        has_capability "pactl" && pactl set-sink-volume @DEFAULT_SINK@ 100% 2>/dev/null || true

        set_state "NIGHTMODE" "false"
        echo -e "${GREEN}✓ Night Mode disabled${NC}"
    else
        echo -e "${CYAN}➜ Enabling Night Mode...${NC}"

        run_hooks "NIGHTMODE" "start"

        if has_capability "redshift"; then
            redshift -O 3400 2>/dev/null || true
            echo -e "${CYAN}  • Blue light reduced (3400K)${NC}"
        else
            echo -e "${YELLOW}  ⚠ Install redshift for blue light reduction${NC}"
        fi

        has_capability "brightnessctl" && brightnessctl set 30% 2>/dev/null || true
        has_capability "pactl" && pactl set-sink-volume @DEFAULT_SINK@ 40% 2>/dev/null || true

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

        run_hooks "TRAVELMODE" "stop"

        apply_cpu_governor "schedutil"
        if check_sudo; then
            systemctl is-enabled bluetooth &>/dev/null && sudo systemctl start bluetooth 2>/dev/null || true
            sudo rfkill unblock wifi 2>/dev/null || true
        fi
        has_capability "brightnessctl" && brightnessctl set 100% 2>/dev/null || true

        set_state "TRAVELMODE" "false"
        echo -e "${GREEN}✓ Travel Mode disabled${NC}"
    else
        echo -e "${CYAN}➜ Enabling Travel Mode...${NC}"

        run_hooks "TRAVELMODE" "start"

        enable_powermode

        if check_sudo; then
            systemctl is-active bluetooth &>/dev/null && sudo systemctl stop bluetooth 2>/dev/null || true
        fi

        if command -v iw &>/dev/null && check_sudo; then
            for dev in /sys/class/net/wl*/device; do
                if [ -e "$dev" ]; then
                    local iface=$(basename "$(dirname "$dev")")
                    sudo iw dev "$iface" set power_save on 2>/dev/null || true
                fi
            done
        fi

        has_capability "brightnessctl" && brightnessctl set 20% 2>/dev/null || true

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

        run_hooks "RENDERMODE" "stop"

        apply_cpu_governor "schedutil"
        optimize_cpu_boost "false"
        apply_io_scheduler "mq-deadline"
        optimize_memory "balanced"
        if check_sudo; then
            systemctl is-enabled thermald &>/dev/null && sudo systemctl start thermald 2>/dev/null || true
        fi

        set_state "RENDERMODE" "false"
        echo -e "${GREEN}✓ Render Mode disabled${NC}"
    else
        echo -e "${CYAN}➜ Enabling Render Mode...${NC}"

        run_hooks "RENDERMODE" "start"

        apply_cpu_governor "performance"
        optimize_cpu_boost "true"

        if has_capability "cpufreq" && check_sudo; then
            for cpu_max in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do
                if [ -f "$cpu_max" ]; then
                    local max_freq=$(cat "$cpu_max" 2>/dev/null)
                    local min_freq="${cpu_max/max/min}"
                    [ -f "$min_freq" ] && echo "$max_freq" | sudo tee "$min_freq" >/dev/null 2>&1 || true
                fi
            done
        fi

        apply_io_scheduler "bfq"
        optimize_memory "performance"

        if check_sudo; then
            systemctl is-active thermald &>/dev/null && sudo systemctl stop thermald 2>/dev/null || true
        fi

        for render_app in blender maya houdini cinema4d; do
            for pid in $(pgrep -x "$render_app" 2>/dev/null); do
                set_process_priority "$pid" -20 "SCHED_OTHER" 2>/dev/null || true
            done
        done

        for pid in $(pgrep -f "ffmpeg|handbrake|makemkv" 2>/dev/null); do
            set_process_priority "$pid" -15 "SCHED_OTHER" 2>/dev/null || true
        done

        set_state "RENDERMODE" "true"
        echo -e "${GREEN}✓ Render Mode enabled${NC}"
        echo -e "${CYAN}  • CPU locked to maximum frequency with boost${NC}"
        echo -e "${CYAN}  • I/O scheduler optimized for throughput${NC}"
        echo -e "${CYAN}  • Memory fully optimized for rendering${NC}"
        echo -e "${CYAN}  • Rendering processes maximally prioritized${NC}"
        echo -e "${CYAN}  • Thermal throttling disabled${NC}"
        echo -e "${YELLOW}  ⚠ Monitor temperatures closely!${NC}"
    fi
}

enable_ultimatemode() {
    local current=$(get_state "ULTIMATE")

    if [ "$current" = "true" ]; then
        echo -e "${YELLOW}➜ Disabling Ultimate Performance Mode...${NC}"

        run_hooks "ULTIMATE" "stop"

        has_capability "dunst" && systemctl --user start dunst 2>/dev/null || true
        apply_cpu_governor "schedutil"
        optimize_cpu_boost "false"
        apply_io_scheduler "mq-deadline"
        optimize_memory "balanced"
        optimize_network "balanced"
        if check_sudo; then
            systemctl is-enabled thermald &>/dev/null && sudo systemctl start thermald 2>/dev/null || true
        fi

        set_state "ULTIMATE" "false"
        echo -e "${GREEN}✓ Ultimate Performance Mode disabled${NC}"
    else
        echo -e "${CYAN}${BOLD}➜ Enabling ULTIMATE Performance Mode...${NC}"
        echo -e "${YELLOW}  This enables ALL performance optimizations!${NC}"
        echo ""

        run_hooks "ULTIMATE" "start"

        has_capability "dunst" && systemctl --user stop dunst 2>/dev/null || true
        apply_cpu_governor "performance"
        optimize_cpu_boost "true"

        if has_capability "cpufreq" && check_sudo; then
            for cpu_max in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do
                if [ -f "$cpu_max" ]; then
                    local max_freq=$(cat "$cpu_max" 2>/dev/null)
                    local min_freq="${cpu_max/max/min}"
                    [ -f "$min_freq" ] && echo "$max_freq" | sudo tee "$min_freq" >/dev/null 2>&1 || true
                fi
            done
        fi

        optimize_irq_balancing
        apply_io_scheduler "none"
        optimize_memory "performance"
        optimize_network "performance"

        apply_sysctl \
            "kernel.sched_latency_ns=3000000" \
            "kernel.sched_min_granularity_ns=400000" \
            "kernel.sched_migration_cost_ns=3000000" \
            "kernel.sched_autogroup_enabled=0" \
            "kernel.sched_cfs_bandwidth_slice_us=1000" \
            "vm.swappiness=1" \
            "vm.vfs_cache_pressure=50" \
            "vm.dirty_ratio=10" \
            "vm.dirty_background_ratio=3" \
            "vm.overcommit_memory=1" \
            "vm.zone_reclaim_mode=0" \
            "vm.min_free_kbytes=65536"

        if check_sudo; then
            systemctl is-active thermald &>/dev/null && sudo systemctl stop thermald 2>/dev/null || true
        fi

        if check_sudo; then
            for pid in $(pgrep -u "$USER" 2>/dev/null | head -20); do
                set_process_priority "$pid" -10 "SCHED_OTHER" 2>/dev/null || true
            done
        fi

        set_state "ULTIMATE" "true"
        echo -e "${GREEN}✓${NC} ${BOLD}ULTIMATE Performance Mode enabled!${NC}"
        echo -e "${CYAN}  • CPU: Maximum performance with boost enabled${NC}"
        echo -e "${CYAN}  • CPU: Locked to maximum frequency${NC}"
        echo -e "${CYAN}  • I/O: Optimized for lowest latency${NC}"
        echo -e "${CYAN}  • Memory: Fully optimized for performance${NC}"
        echo -e "${CYAN}  • Network: Maximum throughput and low latency${NC}"
        echo -e "${CYAN}  • Scheduler: Tuned for maximum responsiveness${NC}"
        echo -e "${CYAN}  • IRQ: Optimally balanced across CPUs${NC}"
        echo -e "${CYAN}  • Processes: All user processes prioritized${NC}"
        echo -e "${CYAN}  • Thermal: Throttling disabled${NC}"
        echo -e "${RED}${BOLD}  ⚠ WARNING: Monitor system temperatures!${NC}"
        echo -e "${RED}${BOLD}  ⚠ This mode maximizes performance at the cost of power/heat${NC}"
    fi
}

# Performance benchmark
benchmark_performance() {
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║      Performance Benchmark             ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""

    local results_file="$LOG_DIR/benchmark_$(date +%Y%m%d_%H%M%S).txt"

    echo -e "${CYAN}Running benchmarks...${NC}"
    echo ""

    echo -e "${BOLD}1. CPU Performance Test${NC}"
    local cpu_start=$(date +%s%N)
    local sum=0
    for i in {1..10000}; do
        sum=$((sum + i))
    done
    local cpu_end=$(date +%s%N)
    local cpu_time=$(awk "BEGIN {printf \"%.3f\", ($cpu_end - $cpu_start) / 1000000000}")
    echo -e "   CPU Test: ${GREEN}${cpu_time}s${NC}"
    echo "CPU: ${cpu_time}s" >> "$results_file"

    echo -e "${BOLD}2. Memory Performance Test${NC}"
    local mem_start=$(date +%s%N)
    dd if=/dev/zero of=/tmp/archmode_benchmark bs=1M count=100 2>/dev/null >/dev/null
    rm -f /tmp/archmode_benchmark 2>/dev/null
    local mem_end=$(date +%s%N)
    local mem_time=$(awk "BEGIN {printf \"%.3f\", ($mem_end - $mem_start) / 1000000000}")
    echo -e "   Memory Test: ${GREEN}${mem_time}s${NC}"
    echo "Memory: ${mem_time}s" >> "$results_file"

    echo -e "${BOLD}3. I/O Performance Test${NC}"
    local io_start=$(date +%s%N)
    local io_result=$(dd if=/dev/zero of=/tmp/archmode_io_test bs=1M count=50 oflag=direct 2>&1 | grep -o '[0-9.]* MB/s' | head -1)
    rm -f /tmp/archmode_io_test 2>/dev/null
    local io_end=$(date +%s%N)
    local io_time=$(awk "BEGIN {printf \"%.3f\", ($io_end - $io_start) / 1000000000}")
    echo -e "   I/O Test: ${GREEN}${io_time}s${NC} ${io_result:+($io_result)}"
    echo "I/O: ${io_time}s" >> "$results_file"

    echo "" >> "$results_file"
    echo "System Info:" >> "$results_file"
    echo "CPU Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo 'N/A')" >> "$results_file"
    echo "CPU Frequency: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null | awk '{printf "%.2f GHz", $1/1000000}' || echo 'N/A')" >> "$results_file"
    echo "I/O Scheduler: $(cat /sys/block/$(lsblk -ndo NAME | head -1)/queue/scheduler 2>/dev/null | grep -o '\[.*\]' || echo 'N/A')" >> "$results_
    echo ""
    echo -e "${GREEN}✓ Benchmark complete!${NC}"
    echo -e "${CYAN}Results saved to: $results_file${NC}"
    log "Performance benchmark completed: $results_file"
local profile_line=$(grep -i "^$profile:" "$PROFILES_FILE" 2>/dev/null | head -1)

if [ -z "$profile_line" ]; then
    echo -e "${RED}✗ Profile '$profile' not found${NC}"
    return 1
fi

local actual_profile=$(echo "$profile_line" | cut -d: -f1)
local modes=$(echo "$profile_line" | cut -d: -f2)
local description=$(echo "$profile_line" | cut -d: -f3)

echo -e "${CYAN}➜ Applying profile: ${BOLD}$actual_profile${NC}"
echo -e "${CYAN}  $description${NC}"
echo ""

IFS=',' read -ra MODE_ARRAY <<< "$modes"
for mode in "${MODE_ARRAY[@]}"; do
    mode=$(echo "$mode" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')
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
        ULTIMATE) enable_ultimatemode ;;
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

# Reset all (optimized)
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

    # Batch reset all states
    local states_to_reset=()
    while IFS=: read -r mode_name _; do
        [[ "$mode_name" =~ ^#.*$ ]] && continue
        [[ -z "$mode_name" ]] && continue
        states_to_reset+=("$mode_name=false")
    done < "$MODES_FILE"

    if [ ${#states_to_reset[@]} -gt 0 ]; then
        batch_set_state "${states_to_reset[@]}"
    fi

    # Restore system defaults (optimized batch operations)
    apply_cpu_governor "schedutil"
    has_capability "dunst" && systemctl --user start dunst 2>/dev/null || true
    has_capability "brightnessctl" && brightnessctl set 100% 2>/dev/null || true
    has_capability "pactl" && pactl set-sink-volume @DEFAULT_SINK@ 100% 2>/dev/null || true

    if check_sudo; then
        systemctl is-enabled thermald &>/dev/null && sudo systemctl start thermald 2>/dev/null || true
        systemctl is-enabled bluetooth &>/dev/null && sudo systemctl start bluetooth 2>/dev/null || true
        sudo rfkill unblock wifi 2>/dev/null || true
    fi

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
    echo "║         Updating ArchMode                                               ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""

    if [ ! -f "$INSTALLED_SCRIPT" ]; then
        echo -e "${RED}✗ ArchMode not found at $INSTALLED_SCRIPT${NC}"
        echo -e "${YELLOW}  Please install ArchMode first${NC}"
        return 1
    fi

    if command -v git &>/dev/null; then
        echo -e "${CYAN}➜ Using git to download latest version...${NC}"

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

    if cmp -s "$INSTALLED_SCRIPT" "$NEW_SCRIPT" 2>/dev/null; then
        echo -e "${GREEN}✓ Already running the latest version${NC}"
        rm -rf "$TEMP_DIR"
        return 0
    fi

    local NEW_VERSION=$(grep -m1 "^VERSION=" "$NEW_SCRIPT" 2>/dev/null | cut -d'"' -f2 || echo "unknown")
    echo -e "${CYAN}➜ New version found: ${BOLD}$NEW_VERSION${NC}"
    echo -e "${CYAN}  Current version: ${BOLD}$VERSION${NC}"
    echo ""

    echo -e "${CYAN}➜ Backing up current version...${NC}"
    if sudo cp "$INSTALLED_SCRIPT" "$BACKUP_SCRIPT"; then
        echo -e "${GREEN}✓ Backup created: $BACKUP_SCRIPT${NC}"
        log "Backup created before update: $BACKUP_SCRIPT"
    else
        echo -e "${YELLOW}⚠ Failed to create backup (continuing anyway)${NC}"
    fi

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

    rm -rf "$TEMP_DIR"

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
}

# Uninstall ArchMode
uninstall_archmode() {
    local INSTALLED_SCRIPT="/usr/local/bin/archmode"
    local SYSTEMD_SERVICE="/etc/systemd/system/archmode.service"

    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║        Uninstalling ArchMode                                           ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""

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

    echo ""
    echo -e "${YELLOW}Configuration and data files:${NC}"
    echo -e "  ${CYAN}~/.config/archmode${NC}"
    echo -e "  ${CYAN}~/.local/share/archmode${NC}"
    echo ""
    read -p "Do you want to remove configuration and data files? (y/N): " remove_config

    if [[ "$remove_config" == "y" || "$remove_config" == "Y" ]]; then
        echo -e "${CYAN}➜ Removing configuration files...${NC}"
        rm -rf "$CONFIG_DIR" && echo -e "${GREEN}✓ Configuration removed${NC}" || echo -e "${YELLOW}⚠ Failed to remove configuration${NC}"

        echo -e "${CYAN}➜ Removing data files...${NC}"
        rm -rf "$LOG_DIR" && echo -e "${GREEN}✓ Data files removed${NC}" || echo -e "${YELLOW}⚠ Failed to remove data files${NC}"
    else
        echo -e "${CYAN}➜ Configuration and data files preserved${NC}"
    fi

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
    echo "  enable <MODE>          Toggle a specific mode"
    echo "  profile <PROFILE>      Apply a profile"
    echo "  reset                  Disable all modes"
    echo "  backup                 Backup current state"
    echo "  restore                Restore a backup"
    echo "  detect                 Detect system hardware"
    echo "  benchmark              Run performance benchmark"
    echo "  update                 Update ArchMode to latest version"
    echo "  uninstall              Uninstall ArchMode from system"
    echo "  check                  Check dependencies"
    echo ""
    echo -e "${BOLD}Plugin Commands:${NC}"
    echo "  plugins list           List all plugins"
    echo "  plugins start <NAME>   Start a plugin"
    echo "  plugins stop <NAME>    Stop a plugin"
    echo "  plugins status <NAME>  Check plugin status"
    echo ""
    echo -e "${BOLD}Hook Commands:${NC}"
    echo "  hooks list             List all hooks"
    echo "  hooks create <MODE>    Create example hooks for mode"
    echo ""
    echo -e "${BOLD}Advanced Commands:${NC}"
    echo "  dry-run <MODE>         Simulate mode changes"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "  archmode enable GAMEMODE"
    echo "  archmode enable gamemode      # Case-insensitive"
    echo "  archmode profile GAMER"
    echo "  archmode profile gamer        # Case-insensitive"
    echo "  archmode plugins start fan"
    echo "  archmode hooks create GAMEMODE"
    echo "  archmode dry-run ULTIMATE"
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
        argument=$(echo "$argument" | tr '[:lower:]' '[:upper:]')
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
            ULTIMATE) enable_ultimatemode ;;
            *)
                echo -e "${RED}✗ Unknown mode: $argument${NC}"
                echo "Use: archmode modes"
                exit 1
                ;;
        esac
        ;;
    profile)
        argument=$(echo "$argument" | tr '[:lower:]' '[:upper:]')
        apply_profile "$argument"
        ;;
    plugins)
        case "${argument,,}" in
            list) plugin_list ;;
            start)
                if [ -z "${3:-}" ]; then
                    echo -e "${RED}✗ No plugin specified${NC}"
                    exit 1
                fi
                plugin_start "$3"
                ;;
            stop)
                if [ -z "${3:-}" ]; then
                    echo -e "${RED}✗ No plugin specified${NC}"
                    exit 1
                fi
                plugin_stop "$3"
                ;;
            status)
                if [ -z "${3:-}" ]; then
                    echo -e "${RED}✗ No plugin specified${NC}"
                    exit 1
                fi
                plugin_status "$3"
                ;;
            *)
                echo -e "${RED}✗ Unknown plugin command${NC}"
                echo "Use: archmode plugins [list|start|stop|status]"
                exit 1
                ;;
        esac
        ;;
    hooks)
        case "${argument,,}" in
            list) list_hooks ;;
            create)
                if [ -z "${3:-}" ]; then
                    echo -e "${RED}✗ No mode specified${NC}"
                    exit 1
                fi
                create_example_hooks "${3^^}"
                ;;
            *)
                echo -e "${RED}✗ Unknown hooks command${NC}"
                echo "Use: archmode hooks [list|create]"
                exit 1
                ;;
        esac
        ;;
    dry-run)
        if [ -z "$argument" ]; then
            echo -e "${RED}✗ No mode specified${NC}"
            exit 1
        fi
        dry_run_mode "${argument^^}"
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
    benchmark)
        benchmark_performance
        ;;
    update)
        update_archmode
        ;;
    uninstall)
        uninstall_archmode
        ;;
    check)
        check_dependencies
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
