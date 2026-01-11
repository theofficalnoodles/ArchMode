#!/bin/bash

# ArchMode - System Mode Manager for Arch Linux
# Version: 2.0.0 - ULTIMATE EDITION
# THE BEST SYSTEM MANAGEMENT TOOL - Complete System Control
# With Mods, Plugins, Security, Privacy, Monitoring, Automation & More!
#
# Features:
# - System Mode Management (Gaming, Productivity, Power Save, etc.)
# - Real-Time Monitoring Dashboard
# - System Health Checks
# - Process Management
# - Network Analysis
# - GPU Management
# - System Cleanup & Optimization
# - Automation & Scheduling
# - Temperature Monitoring
# - Mods & Plugins System
# - Security & Privacy Controls
# - Interactive Dashboard

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
MODS_DIR="$CONFIG_DIR/mods"
PLUGINS_DIR="$CONFIG_DIR/plugins"
SECURITY_FILE="$CONFIG_DIR/security.conf"
PRIVACY_FILE="$CONFIG_DIR/privacy.conf"
SCHEDULE_FILE="$CONFIG_DIR/schedule.conf"
MONITOR_FILE="$CONFIG_DIR/monitor.conf"
HEALTH_FILE="$LOG_DIR/health_report.txt"
TEMP_ALERT_FILE="$CONFIG_DIR/temp_alerts.conf"
VERSION="2.0.0"

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
mkdir -p "$CONFIG_DIR" "$LOG_DIR" "$BACKUP_DIR" "$MODS_DIR" "$PLUGINS_DIR"

# Initialize additional config files
[ ! -f "$SCHEDULE_FILE" ] && touch "$SCHEDULE_FILE"
[ ! -f "$MONITOR_FILE" ] && touch "$MONITOR_FILE"
[ ! -f "$TEMP_ALERT_FILE" ] && touch "$TEMP_ALERT_FILE"

# Initialize state file
[ ! -f "$STATE_FILE" ] && touch "$STATE_FILE"

# Initialize security and privacy files
[ ! -f "$SECURITY_FILE" ] && touch "$SECURITY_FILE"
[ ! -f "$PRIVACY_FILE" ] && touch "$PRIVACY_FILE"

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
EOF
fi

# Logging function with performance optimization
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# ============================================
# MODS AND PLUGINS SYSTEM (Early Loading)
# ============================================

# Load all mods
load_mods() {
    if [ ! -d "$MODS_DIR" ]; then
        mkdir -p "$MODS_DIR"
        return 0
    fi
    
    # Use nullglob to handle empty directories
    shopt -s nullglob 2>/dev/null || true
    for mod_file in "$MODS_DIR"/*.sh; do
        [ -f "$mod_file" ] || continue
        [ -x "$mod_file" ] || chmod +x "$mod_file"
        
        # Source the mod (safely)
        if [ -r "$mod_file" ]; then
            source "$mod_file" 2>/dev/null && log "Loaded mod: $(basename "$mod_file")" || log "Failed to load mod: $(basename "$mod_file")"
        fi
    done
    shopt -u nullglob 2>/dev/null || true
}

# Load all plugins
load_plugins() {
    if [ ! -d "$PLUGINS_DIR" ]; then
        mkdir -p "$PLUGINS_DIR"
        return 0
    fi
    
    # Use nullglob to handle empty directories
    shopt -s nullglob 2>/dev/null || true
    for plugin_file in "$PLUGINS_DIR"/*.sh; do
        [ -f "$plugin_file" ] || continue
        [ -x "$plugin_file" ] || chmod +x "$plugin_file"
        
        # Source the plugin (safely)
        if [ -r "$plugin_file" ]; then
            source "$plugin_file" 2>/dev/null && log "Loaded plugin: $(basename "$plugin_file")" || log "Failed to load plugin: $(basename "$plugin_file")"
        fi
    done
    shopt -u nullglob 2>/dev/null || true
}

# Load mods and plugins (called after function definitions)
load_mods
load_plugins

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
    
    echo ""
}

# ============================================
# MODE IMPLEMENTATIONS
# ============================================

# Helper: Apply CPU governor (optimized batch operation)
apply_cpu_governor() {
    local governor=$1
    if has_capability "cpufreq" && check_sudo; then
        # Batch operation - write to all CPUs at once
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
        for blockdev in /sys/block/sd*/queue/scheduler; do
            if [ -f "$blockdev" ]; then
                echo "$scheduler" | sudo tee "$blockdev" >/dev/null 2>&1 || true
            fi
        done
        for blockdev in /sys/block/nvme*/queue/scheduler; do
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
    # Distribute IRQs across CPUs
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
        # Set nice value
        sudo renice -n "$nice" -p "$pid" 2>/dev/null || true
        
        # Set real-time scheduling if requested
        if [ "$sched" = "SCHED_FIFO" ] || [ "$sched" = "SCHED_RR" ]; then
            local priority=50
            [ "$sched" = "SCHED_FIFO" ] && chrt -f -p "$priority" "$pid" 2>/dev/null || \
            chrt -r -p "$priority" "$pid" 2>/dev/null || true
        fi
    fi
}

# Helper: Optimize memory settings (advanced)
optimize_memory() {
    local mode=$1  # performance or balanced
    
    if ! check_sudo; then
        return 1
    fi
    
    if [ "$mode" = "performance" ]; then
        # Performance: Disable THP, optimize for speed
        apply_sysctl \
            "vm.swappiness=1" \
            "vm.vfs_cache_pressure=50" \
            "vm.dirty_ratio=15" \
            "vm.dirty_background_ratio=5" \
            "vm.overcommit_memory=1" \
            "vm.zone_reclaim_mode=0"
        
        # Disable transparent huge pages for lower latency
        if [ -f /sys/kernel/mm/transparent_hugepage/enabled ]; then
            echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled >/dev/null 2>&1 || true
        fi
        if [ -f /sys/kernel/mm/transparent_hugepage/defrag ]; then
            echo never | sudo tee /sys/kernel/mm/transparent_hugepage/defrag >/dev/null 2>&1 || true
        fi
    else
        # Balanced: Restore defaults
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
    local mode=$1  # performance or balanced
    
    if ! check_sudo; then
        return 1
    fi
    
    if [ "$mode" = "performance" ]; then
        # Advanced network optimizations
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
        # Balanced: Restore defaults
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
    local enable=$1  # true or false
    
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
    
    # Intel Turbo Boost
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

# ============================================
# MODS AND PLUGINS SYSTEM (Management Functions)
# ============================================

# List installed mods
list_mods() {
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║        Installed Mods                  ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    if [ ! -d "$MODS_DIR" ]; then
        echo -e "${YELLOW}No mods installed${NC}"
        echo -e "${CYAN}Create one with: archmode create-mod <name>${NC}"
        echo ""
        return 0
    fi
    
    # Use nullglob to handle empty directories
    shopt -s nullglob 2>/dev/null || true
    local mod_files=("$MODS_DIR"/*.sh)
    shopt -u nullglob 2>/dev/null || true
    
    if [ ${#mod_files[@]} -eq 0 ]; then
        echo -e "${YELLOW}No mods installed${NC}"
        echo -e "${CYAN}Create one with: archmode create-mod <name>${NC}"
        echo ""
        return 0
    fi
    
    for mod_file in "${mod_files[@]}"; do
        [ -f "$mod_file" ] || continue
        local mod_name=$(basename "$mod_file" .sh)
        echo -e "${GREEN}✓${NC} ${BOLD}$mod_name${NC}"
        echo -e "  ${CYAN}Location: $mod_file${NC}"
        echo ""
    done
}

# List installed plugins
list_plugins() {
    echo -e "${MAGENTA}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║      Installed Plugins                 ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    if [ ! -d "$PLUGINS_DIR" ]; then
        echo -e "${YELLOW}No plugins installed${NC}"
        echo -e "${CYAN}Create one with: archmode create-plugin <name>${NC}"
        echo ""
        return 0
    fi
    
    # Use nullglob to handle empty directories
    shopt -s nullglob 2>/dev/null || true
    local plugin_files=("$PLUGINS_DIR"/*.sh)
    shopt -u nullglob 2>/dev/null || true
    
    if [ ${#plugin_files[@]} -eq 0 ]; then
        echo -e "${YELLOW}No plugins installed${NC}"
        echo -e "${CYAN}Create one with: archmode create-plugin <name>${NC}"
        echo ""
        return 0
    fi
    
    for plugin_file in "${plugin_files[@]}"; do
        [ -f "$plugin_file" ] || continue
        local plugin_name=$(basename "$plugin_file" .sh)
        echo -e "${GREEN}✓${NC} ${BOLD}$plugin_name${NC}"
        echo -e "  ${CYAN}Location: $plugin_file${NC}"
        echo ""
    done
}

# Create a new mod
create_mod() {
    local mod_name=$1
    
    if [ -z "$mod_name" ]; then
        echo -e "${RED}✗ Mod name required${NC}"
        echo "Usage: archmode create-mod <name>"
        return 1
    fi
    
    # Sanitize mod name
    mod_name=$(echo "$mod_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]//g')
    
    if [ -z "$mod_name" ]; then
        echo -e "${RED}✗ Invalid mod name${NC}"
        return 1
    fi
    
    local mod_file="$MODS_DIR/${mod_name}.sh"
    
    if [ -f "$mod_file" ]; then
        echo -e "${YELLOW}⚠ Mod already exists: $mod_name${NC}"
        read -p "Overwrite? (y/N): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo -e "${CYAN}➜ Cancelled${NC}"
            return 0
        fi
    fi
    
    # Create mod template
    cat > "$mod_file" << EOF
#!/bin/bash
# ArchMode Mod: $mod_name
# Created: $(date '+%Y-%m-%d %H:%M:%S')
# Description: Add your mod description here

# Mod metadata
MOD_NAME="$mod_name"
MOD_VERSION="1.0.0"
MOD_DESCRIPTION="Custom mod for ArchMode"

# Mod enable function (called when mod is activated)
enable_${mod_name}() {
    echo -e "\${GREEN}✓ Enabling mod: $mod_name\${NC}"
    # Add your mod logic here
    log "Mod $mod_name enabled"
}

# Mod disable function (called when mod is deactivated)
disable_${mod_name}() {
    echo -e "\${YELLOW}➜ Disabling mod: $mod_name\${NC}"
    # Add your mod logic here
    log "Mod $mod_name disabled"
}

# Mod initialization (called when ArchMode loads)
init_${mod_name}() {
    # Add initialization logic here
    log "Mod $mod_name initialized"
}

# Call init on load
init_${mod_name}
EOF
    
    chmod +x "$mod_file"
    
    echo -e "${GREEN}✓ Mod created: $mod_name${NC}"
    echo -e "${CYAN}  Location: $mod_file${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo -e "  1. Edit the mod: ${BOLD}$mod_file${NC}"
    echo -e "  2. Or use: ${BOLD}archmode edit-mod $mod_name${NC}"
    echo ""
    
    # Ask if user wants to edit now
    read -p "Open in editor? (y/N): " edit_now
    if [[ "$edit_now" == "y" || "$edit_now" == "Y" ]]; then
        edit_mod "$mod_name"
    fi
}

# Create a new plugin
create_plugin() {
    local plugin_name=$1
    
    if [ -z "$plugin_name" ]; then
        echo -e "${RED}✗ Plugin name required${NC}"
        echo "Usage: archmode create-plugin <name>"
        return 1
    fi
    
    # Sanitize plugin name
    plugin_name=$(echo "$plugin_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]//g')
    
    if [ -z "$plugin_name" ]; then
        echo -e "${RED}✗ Invalid plugin name${NC}"
        return 1
    fi
    
    local plugin_file="$PLUGINS_DIR/${plugin_name}.sh"
    
    if [ -f "$plugin_file" ]; then
        echo -e "${YELLOW}⚠ Plugin already exists: $plugin_name${NC}"
        read -p "Overwrite? (y/N): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo -e "${CYAN}➜ Cancelled${NC}"
            return 0
        fi
    fi
    
    # Create plugin template
    cat > "$plugin_file" << EOF
#!/bin/bash
# ArchMode Plugin: $plugin_name
# Created: $(date '+%Y-%m-%d %H:%M:%S')
# Description: Add your plugin description here

# Plugin metadata
PLUGIN_NAME="$plugin_name"
PLUGIN_VERSION="1.0.0"
PLUGIN_DESCRIPTION="Custom plugin for ArchMode"

# Plugin hooks (called at various ArchMode events)
on_mode_enable() {
    local mode=\$1
    # Called when any mode is enabled
    # Add your logic here
}

on_mode_disable() {
    local mode=\$1
    # Called when any mode is disabled
    # Add your logic here
}

on_startup() {
    # Called when ArchMode starts
    log "Plugin $plugin_name started"
}

on_shutdown() {
    # Called when ArchMode shuts down
    log "Plugin $plugin_name stopped"
}

# Call on_startup when loaded
on_startup
EOF
    
    chmod +x "$plugin_file"
    
    echo -e "${GREEN}✓ Plugin created: $plugin_name${NC}"
    echo -e "${CYAN}  Location: $plugin_file${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo -e "  1. Edit the plugin: ${BOLD}$plugin_file${NC}"
    echo -e "  2. Or use: ${BOLD}archmode edit-plugin $plugin_name${NC}"
    echo ""
    
    # Ask if user wants to edit now
    read -p "Open in editor? (y/N): " edit_now
    if [[ "$edit_now" == "y" || "$edit_now" == "Y" ]]; then
        edit_plugin "$plugin_name"
    fi
}

# Edit a mod
edit_mod() {
    local mod_name=$1
    local editor=${2:-${EDITOR:-vim}}
    
    if [ -z "$mod_name" ]; then
        echo -e "${RED}✗ Mod name required${NC}"
        echo "Usage: archmode edit-mod <name> [editor]"
        return 1
    fi
    
    mod_name=$(echo "$mod_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]//g')
    local mod_file="$MODS_DIR/${mod_name}.sh"
    
    if [ ! -f "$mod_file" ]; then
        echo -e "${RED}✗ Mod not found: $mod_name${NC}"
        echo -e "${CYAN}Create it with: archmode create-mod $mod_name${NC}"
        return 1
    fi
    
    echo -e "${CYAN}➜ Opening mod in $editor...${NC}"
    "$editor" "$mod_file"
    echo -e "${GREEN}✓ Mod edited${NC}"
}

# Edit a plugin
edit_plugin() {
    local plugin_name=$1
    local editor=${2:-${EDITOR:-vim}}
    
    if [ -z "$plugin_name" ]; then
        echo -e "${RED}✗ Plugin name required${NC}"
        echo "Usage: archmode edit-plugin <name> [editor]"
        return 1
    fi
    
    plugin_name=$(echo "$plugin_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]//g')
    local plugin_file="$PLUGINS_DIR/${plugin_name}.sh"
    
    if [ ! -f "$plugin_file" ]; then
        echo -e "${RED}✗ Plugin not found: $plugin_name${NC}"
        echo -e "${CYAN}Create it with: archmode create-plugin $plugin_name${NC}"
        return 1
    fi
    
    echo -e "${CYAN}➜ Opening plugin in $editor...${NC}"
    "$editor" "$plugin_file"
    echo -e "${GREEN}✓ Plugin edited${NC}"
}

# ============================================
# SECURITY AND PRIVACY SETTINGS
# ============================================

# Get security setting
get_security_setting() {
    local setting=$1
    local default=${2:-false}
    
    if [ -f "$SECURITY_FILE" ]; then
        local value=$(grep "^$setting=" "$SECURITY_FILE" 2>/dev/null | cut -d'=' -f2)
        echo "${value:-$default}"
    else
        echo "$default"
    fi
}

# Set security setting
set_security_setting() {
    local setting=$1
    local value=$2
    
    if grep -q "^$setting=" "$SECURITY_FILE" 2>/dev/null; then
        sed -i "s/^$setting=.*/$setting=$value/" "$SECURITY_FILE"
    else
        echo "$setting=$value" >> "$SECURITY_FILE"
    fi
    log "Security setting $setting set to $value"
}

# Get privacy setting
get_privacy_setting() {
    local setting=$1
    local default=${2:-false}
    
    if [ -f "$PRIVACY_FILE" ]; then
        local value=$(grep "^$setting=" "$PRIVACY_FILE" 2>/dev/null | cut -d'=' -f2)
        echo "${value:-$default}"
    else
        echo "$default"
    fi
}

# Set privacy setting
set_privacy_setting() {
    local setting=$1
    local value=$2
    
    if grep -q "^$setting=" "$PRIVACY_FILE" 2>/dev/null; then
        sed -i "s/^$setting=.*/$setting=$value/" "$PRIVACY_FILE"
    else
        echo "$setting=$value" >> "$PRIVACY_FILE"
    fi
    log "Privacy setting $setting set to $value"
}

# Show security settings
show_security() {
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║        Security Settings              ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    local secure_logging=$(get_security_setting "secure_logging" "false")
    local require_sudo=$(get_security_setting "require_sudo" "true")
    local validate_mods=$(get_security_setting "validate_mods" "true")
    local validate_plugins=$(get_security_setting "validate_plugins" "true")
    local sandbox_mods=$(get_security_setting "sandbox_mods" "false")
    local audit_mode=$(get_security_setting "audit_mode" "false")
    
    echo -e "${BOLD}Secure Logging:${NC} $secure_logging"
    echo -e "${BOLD}Require Sudo:${NC} $require_sudo"
    echo -e "${BOLD}Validate Mods:${NC} $validate_mods"
    echo -e "${BOLD}Validate Plugins:${NC} $validate_plugins"
    echo -e "${BOLD}Sandbox Mods:${NC} $sandbox_mods"
    echo -e "${BOLD}Audit Mode:${NC} $audit_mode"
    echo ""
    echo -e "${CYAN}Configure with: archmode security <setting> <value>${NC}"
}

# Show privacy settings
show_privacy() {
    echo -e "${MAGENTA}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║        Privacy Settings                ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    local anonymize_logs=$(get_privacy_setting "anonymize_logs" "false")
    local no_telemetry=$(get_privacy_setting "no_telemetry" "true")
    local local_only=$(get_privacy_setting "local_only" "true")
    local encrypt_config=$(get_privacy_setting "encrypt_config" "false")
    local hide_sensitive=$(get_privacy_setting "hide_sensitive" "true")
    
    echo -e "${BOLD}Anonymize Logs:${NC} $anonymize_logs"
    echo -e "${BOLD}No Telemetry:${NC} $no_telemetry"
    echo -e "${BOLD}Local Only:${NC} $local_only"
    echo -e "${BOLD}Encrypt Config:${NC} $encrypt_config"
    echo -e "${BOLD}Hide Sensitive:${NC} $hide_sensitive"
    echo ""
    echo -e "${CYAN}Configure with: archmode privacy <setting> <value>${NC}"
}

# Configure security setting
configure_security() {
    local setting=$1
    local value=$2
    
    if [ -z "$setting" ]; then
        show_security
        return 0
    fi
    
    if [ -z "$value" ]; then
        echo -e "${RED}✗ Value required${NC}"
        echo "Usage: archmode security <setting> <value>"
        return 1
    fi
    
    set_security_setting "$setting" "$value"
    echo -e "${GREEN}✓ Security setting updated: $setting=$value${NC}"
}

# Configure privacy setting
configure_privacy() {
    local setting=$1
    local value=$2
    
    if [ -z "$setting" ]; then
        show_privacy
        return 0
    fi
    
    if [ -z "$value" ]; then
        echo -e "${RED}✗ Value required${NC}"
        echo "Usage: archmode privacy <setting> <value>"
        return 1
    fi
    
    set_privacy_setting "$setting" "$value"
    echo -e "${GREEN}✓ Privacy setting updated: $setting=$value${NC}"
}

enable_gamemode() {
    local current=$(get_state "GAMEMODE")
    
    if [ "$current" = "true" ]; then
        echo -e "${YELLOW}➜ Disabling Gaming Mode...${NC}"
        
        # Restore normal settings (batch operations)
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
        
        # Disable notifications
        has_capability "dunst" && systemctl --user stop dunst 2>/dev/null || true
        
        # Advanced CPU optimizations
        apply_cpu_governor "performance"
        optimize_cpu_boost "true"
        optimize_irq_balancing
        
        # Advanced I/O optimizations (none scheduler for lowest latency)
        apply_io_scheduler "none"
        
        # Advanced memory optimizations
        optimize_memory "performance"
        
        # Advanced network optimizations
        optimize_network "performance"
        
        # Optimize scheduler for responsiveness (batch)
        apply_sysctl \
            "kernel.sched_latency_ns=4000000" \
            "kernel.sched_min_granularity_ns=500000" \
            "kernel.sched_migration_cost_ns=5000000" \
            "kernel.sched_autogroup_enabled=0" \
            "vm.swappiness=1" \
            "vm.dirty_ratio=15" \
            "vm.dirty_background_ratio=5"
        
        # Disable mouse acceleration (if X11) - optimized
        if has_capability "display" && has_capability "xinput"; then
            xinput list 2>/dev/null | grep -iE 'pointer|mouse' | grep -v 'XTEST' | \
            sed -n 's/.*id=\([0-9]*\).*/\1/p' | while read -r id; do
                xinput set-prop "$id" "libinput Accel Speed" 0 2>/dev/null || true
            done
        fi
        
        # Optimize game processes (find and prioritize)
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
        
        has_capability "dunst" && systemctl --user start dunst 2>/dev/null || true
        optimize_network "balanced"
        apply_io_scheduler "mq-deadline"
        
        set_state "STREAMMODE" "false"
        echo -e "${GREEN}✓ Streaming Mode disabled${NC}"
    else
        echo -e "${CYAN}➜ Enabling Streaming Mode...${NC}"
        
        # Disable notifications
        has_capability "dunst" && systemctl --user stop dunst 2>/dev/null || true
        
        # Set CPU to performance with boost
        apply_cpu_governor "performance"
        optimize_cpu_boost "true"
        
        # Advanced network optimizations for streaming
        optimize_network "performance"
        
        # I/O scheduler for streaming (bfq for better fairness)
        apply_io_scheduler "bfq"
        
        # Memory optimizations
        optimize_memory "performance"
        
        # Increase process priority for common streaming apps (advanced)
        for app in obs ffmpeg gstreamer; do
            for pid in $(pgrep -x "$app" 2>/dev/null); do
                set_process_priority "$pid" -15 "SCHED_OTHER" 2>/dev/null || true
            done
        done
        
        # Optimize encoding processes
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
        
        if has_capability "display"; then
            command -v gsettings &>/dev/null && gsettings set org.gnome.desktop.session idle-delay 300 2>/dev/null || true
            has_capability "xrandr" && xset s on +dpms 2>/dev/null || true
        fi
        
        set_state "PRODUCTIVITY" "false"
        echo -e "${GREEN}✓ Productivity Mode disabled${NC}"
    else
        echo -e "${CYAN}➜ Enabling Productivity Mode...${NC}"
        
        # Enable notifications
        has_capability "dunst" && systemctl --user start dunst 2>/dev/null || true
        
        # Prevent screen sleep (optimized)
        if has_capability "display"; then
            command -v gsettings &>/dev/null && gsettings set org.gnome.desktop.session idle-delay 0 2>/dev/null || true
            has_capability "xrandr" && xset s off -dpms 2>/dev/null || true
        fi
        
        # Block distracting websites (optional)
        command -v hostctl &>/dev/null && echo -e "${CYAN}  • To block distracting sites, edit /etc/hosts${NC}" || true
        
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
        
        # Set CPU to powersave
        apply_cpu_governor "powersave"
        
        # Enable aggressive USB suspend
        if check_sudo && [ -f /sys/module/usbcore/parameters/autosuspend ]; then
            echo 1 | sudo tee /sys/module/usbcore/parameters/autosuspend >/dev/null 2>&1 || true
        fi
        
        # Dim screen
        has_capability "brightnessctl" && brightnessctl set 50% 2>/dev/null || true
        
        # Enable laptop mode
        apply_sysctl "vm.laptop_mode=5"
        
        # Reduce screen refresh rate (if possible)
        if has_capability "display" && has_capability "xrandr"; then
            local output=$(xrandr 2>/dev/null | grep " connected" | cut -d" " -f1 | head -n1)
            [ -n "$output" ] && xrandr --output "$output" --rate 60 2>/dev/null || true
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
        
        # Reduce CPU frequency
        apply_cpu_governor "powersave"
        
        # Reduce volume
        has_capability "pactl" && pactl set-sink-volume @DEFAULT_SINK@ 50% 2>/dev/null || true
        
        # Reduce fan speed (if controllable)
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
        
        if check_sudo; then
            systemctl is-active packagekit &>/dev/null || sudo systemctl start packagekit 2>/dev/null || true
            apply_sysctl "fs.inotify.max_user_watches=8192"
        fi
        ulimit -c 0 2>/dev/null || true
        
        set_state "DEVMODE" "false"
        echo -e "${GREEN}✓ Development Mode disabled${NC}"
    else
        echo -e "${CYAN}➜ Enabling Development Mode...${NC}"
        
        # Disable package manager
        if check_sudo; then
            systemctl is-active packagekit &>/dev/null && sudo systemctl stop packagekit 2>/dev/null || true
            # Increase file watchers for IDEs and shared memory (batch)
            apply_sysctl \
                "fs.inotify.max_user_watches=524288" \
                "kernel.shmmax=68719476736"
        fi
        
        # Unlimited core dumps
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
        
        # Restore color temperature
        has_capability "redshift" && redshift -x 2>/dev/null || true
        has_capability "brightnessctl" && brightnessctl set 100% 2>/dev/null || true
        has_capability "pactl" && pactl set-sink-volume @DEFAULT_SINK@ 100% 2>/dev/null || true
        
        set_state "NIGHTMODE" "false"
        echo -e "${GREEN}✓ Night Mode disabled${NC}"
    else
        echo -e "${CYAN}➜ Enabling Night Mode...${NC}"
        
        # Reduce blue light
        if has_capability "redshift"; then
            redshift -O 3400 2>/dev/null || true
            echo -e "${CYAN}  • Blue light reduced (3400K)${NC}"
        else
            echo -e "${YELLOW}  ⚠ Install redshift for blue light reduction${NC}"
        fi
        
        # Dim screen
        has_capability "brightnessctl" && brightnessctl set 30% 2>/dev/null || true
        
        # Lower volume
        has_capability "pactl" && pactl set-sink-volume @DEFAULT_SINK@ 40% 2>/dev/null || true
        
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
        
        # Maximum power saving
        enable_powermode
        
        # Disable Bluetooth
        if check_sudo; then
            systemctl is-active bluetooth &>/dev/null && sudo systemctl stop bluetooth 2>/dev/null || true
        fi
        
        # Reduce WiFi power (optimized)
        if command -v iw &>/dev/null && check_sudo; then
            for dev in /sys/class/net/wl*/device; do
                if [ -e "$dev" ]; then
                    local iface=$(basename "$(dirname "$dev")")
                    sudo iw dev "$iface" set power_save on 2>/dev/null || true
                fi
            done
        fi
        
        # Extremely dim screen
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
        
        # Maximum CPU performance with boost
        apply_cpu_governor "performance"
        optimize_cpu_boost "true"
        
        # Disable CPU frequency scaling for consistency (optimized)
        if has_capability "cpufreq" && check_sudo; then
            for cpu_max in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do
                if [ -f "$cpu_max" ]; then
                    local max_freq=$(cat "$cpu_max" 2>/dev/null)
                    local min_freq="${cpu_max/max/min}"
                    [ -f "$min_freq" ] && echo "$max_freq" | sudo tee "$min_freq" >/dev/null 2>&1 || true
                fi
            done
        fi
        
        # Advanced I/O optimization for rendering (bfq for better throughput)
        apply_io_scheduler "bfq"
        
        # Advanced memory optimization
        optimize_memory "performance"
        
        # Disable thermal throttling temporarily (use with caution!)
        if check_sudo; then
            systemctl is-active thermald &>/dev/null && sudo systemctl stop thermald 2>/dev/null || true
        fi
        
        # Increase priority for rendering processes (advanced)
        for render_app in blender maya houdini cinema4d; do
            for pid in $(pgrep -x "$render_app" 2>/dev/null); do
                set_process_priority "$pid" -20 "SCHED_OTHER" 2>/dev/null || true
            done
        done
        
        # Optimize video encoding processes
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
        
        # Restore all settings
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
        
        # Disable notifications
        has_capability "dunst" && systemctl --user stop dunst 2>/dev/null || true
        
        # Maximum CPU performance
        apply_cpu_governor "performance"
        optimize_cpu_boost "true"
        
        # Lock CPU to max frequency
        if has_capability "cpufreq" && check_sudo; then
            for cpu_max in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do
                if [ -f "$cpu_max" ]; then
                    local max_freq=$(cat "$cpu_max" 2>/dev/null)
                    local min_freq="${cpu_max/max/min}"
                    [ -f "$min_freq" ] && echo "$max_freq" | sudo tee "$min_freq" >/dev/null 2>&1 || true
                fi
            done
        fi
        
        # Advanced IRQ balancing
        optimize_irq_balancing
        
        # Ultimate I/O optimization (none for absolute lowest latency)
        apply_io_scheduler "none"
        
        # Ultimate memory optimization
        optimize_memory "performance"
        
        # Ultimate network optimization
        optimize_network "performance"
        
        # Ultimate scheduler tuning
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
        
        # Disable thermal throttling (EXTREME - monitor temps!)
        if check_sudo; then
            systemctl is-active thermald &>/dev/null && sudo systemctl stop thermald 2>/dev/null || true
        fi
        
        # Prioritize ALL user processes
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
    
    # CPU benchmark (simple calculation)
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
    
    # Memory benchmark
    echo -e "${BOLD}2. Memory Performance Test${NC}"
    local mem_start=$(date +%s%N)
    local test_data=$(dd if=/dev/zero of=/tmp/archmode_benchmark bs=1M count=100 2>/dev/null)
    rm -f /tmp/archmode_benchmark 2>/dev/null
    local mem_end=$(date +%s%N)
    local mem_time=$(awk "BEGIN {printf \"%.3f\", ($mem_end - $mem_start) / 1000000000}")
    echo -e "   Memory Test: ${GREEN}${mem_time}s${NC}"
    echo "Memory: ${mem_time}s" >> "$results_file"
    
    # I/O benchmark
    echo -e "${BOLD}3. I/O Performance Test${NC}"
    local io_start=$(date +%s%N)
    local io_result=$(dd if=/dev/zero of=/tmp/archmode_io_test bs=1M count=50 oflag=direct 2>&1 | grep -o '[0-9.]* MB/s' | head -1)
    rm -f /tmp/archmode_io_test 2>/dev/null
    local io_end=$(date +%s%N)
    local io_time=$(awk "BEGIN {printf \"%.3f\", ($io_end - $io_start) / 1000000000}")
    echo -e "   I/O Test: ${GREEN}${io_time}s${NC} ${io_result:+($io_result)}"
    echo "I/O: ${io_time}s" >> "$results_file"
    
    # System info
    echo "" >> "$results_file"
    echo "System Info:" >> "$results_file"
    echo "CPU Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo 'N/A')" >> "$results_file"
    echo "CPU Frequency: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null | awk '{printf "%.2f GHz", $1/1000000}' || echo 'N/A')" >> "$results_file"
    echo "I/O Scheduler: $(cat /sys/block/$(lsblk -ndo NAME | head -1)/queue/scheduler 2>/dev/null | grep -o '\[.*\]' || echo 'N/A')" >> "$results_file"
    
    echo ""
    echo -e "${GREEN}✓ Benchmark complete!${NC}"
    echo -e "${CYAN}Results saved to: $results_file${NC}"
    log "Performance benchmark completed: $results_file"
}

# Profile management
apply_profile() {
    local profile=$1
    # Convert to uppercase for case-insensitive matching
    profile=$(echo "$profile" | tr '[:lower:]' '[:upper:]')
    
    # Find profile in config (case-insensitive)
    local profile_line=$(grep -i "^$profile:" "$PROFILES_FILE" 2>/dev/null | head -1)
    
    if [ -z "$profile_line" ]; then
        echo -e "${RED}✗ Profile '$profile' not found${NC}"
        return 1
    fi
    
    # Extract actual profile name from line (first field)
    local actual_profile=$(echo "$profile_line" | cut -d: -f1)
    local modes=$(echo "$profile_line" | cut -d: -f2)
    local description=$(echo "$profile_line" | cut -d: -f3)
    
    echo -e "${CYAN}➜ Applying profile: ${BOLD}$actual_profile${NC}"
    echo -e "${CYAN}  $description${NC}"
    echo ""
    
    # Split modes and enable each (already uppercase in config)
    IFS=',' read -ra MODE_ARRAY <<< "$modes"
    for mode in "${MODE_ARRAY[@]}"; do
        # Trim whitespace and ensure uppercase
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

# Update ArchMode from GitHub - ULTIMATE UPDATE SYSTEM
update_archmode() {
    local GITHUB_REPO="https://github.com/theofficalnoodles/ArchMode"
    local INSTALLED_SCRIPT="/usr/local/bin/archmode"
    local TEMP_DIR=$(mktemp -d)
    local BACKUP_SCRIPT="$INSTALLED_SCRIPT.backup.$(date +%Y%m%d_%H%M%S)"
    local UPDATE_LOG="$LOG_DIR/update_$(date +%Y%m%d_%H%M%S).log"
    
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║    ArchMode ULTIMATE Update System     ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    # Check if script is installed
    if [ ! -f "$INSTALLED_SCRIPT" ]; then
        echo -e "${RED}✗ ArchMode not found at $INSTALLED_SCRIPT${NC}"
        echo -e "${YELLOW}  Please install ArchMode first${NC}"
        return 1
    fi
    
    # System information
    echo -e "${CYAN}${BOLD}System Information:${NC}"
    echo -e "  Current Version: ${BOLD}$VERSION${NC}"
    echo -e "  System: $(uname -s) $(uname -r)"
    echo -e "  Architecture: $(uname -m)"
    echo -e "  User: $USER"
    echo ""
    
    # Check internet connectivity
    echo -e "${CYAN}➜ Checking internet connectivity...${NC}"
    if ! ping -c 1 -W 2 github.com &>/dev/null && ! ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        echo -e "${RED}✗ No internet connection${NC}"
        return 1
    fi
    echo -e "${GREEN}✓ Internet connection available${NC}"
    echo ""
    
    # Check for git or curl/wget
    local download_method=""
    if command -v git &>/dev/null; then
        download_method="git"
        echo -e "${CYAN}➜ Using git to download latest version...${NC}"
        
        # Clone the repository
        if git clone --depth 1 "$GITHUB_REPO.git" "$TEMP_DIR/ArchMode" 2>/dev/null; then
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
        download_method="curl"
        echo -e "${CYAN}➜ Using curl to download latest version...${NC}"
        
        # Try multiple branches/tags
        local branches=("main" "master" "v1.0.0" "latest")
        local NEW_SCRIPT="$TEMP_DIR/archmode.sh"
        local downloaded=false
        
        for branch in "${branches[@]}"; do
            if curl -sLf "$GITHUB_REPO/raw/$branch/archmode.sh" -o "$NEW_SCRIPT" && [ -f "$NEW_SCRIPT" ] && [ -s "$NEW_SCRIPT" ]; then
                downloaded=true
                break
            fi
        done
        
        if [ "$downloaded" = false ]; then
            echo -e "${RED}✗ Failed to download script${NC}"
            rm -rf "$TEMP_DIR"
            return 1
        fi
    elif command -v wget &>/dev/null; then
        download_method="wget"
        echo -e "${CYAN}➜ Using wget to download latest version...${NC}"
        
        local branches=("main" "master" "v1.0.0" "latest")
        local NEW_SCRIPT="$TEMP_DIR/archmode.sh"
        local downloaded=false
        
        for branch in "${branches[@]}"; do
            if wget -q "$GITHUB_REPO/raw/$branch/archmode.sh" -O "$NEW_SCRIPT" 2>/dev/null && [ -f "$NEW_SCRIPT" ] && [ -s "$NEW_SCRIPT" ]; then
                downloaded=true
                break
            fi
        done
        
        if [ "$downloaded" = false ]; then
            echo -e "${RED}✗ Failed to download from GitHub${NC}"
            rm -rf "$TEMP_DIR"
            return 1
        fi
    else
        echo -e "${RED}✗ No download tool available (git, curl, or wget required)${NC}"
        echo -e "${YELLOW}  Install one with: sudo pacman -S git${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Download complete using $download_method${NC}"
    echo ""
    
    # Validate downloaded script
    echo -e "${CYAN}➜ Validating downloaded script...${NC}"
    if [ ! -f "$NEW_SCRIPT" ] || [ ! -s "$NEW_SCRIPT" ]; then
        echo -e "${RED}✗ Invalid script file${NC}"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    # Check if it's a valid bash script
    if ! bash -n "$NEW_SCRIPT" 2>/dev/null; then
        echo -e "${RED}✗ Script validation failed${NC}"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    echo -e "${GREEN}✓ Script validation passed${NC}"
    echo ""
    
    # Get new version number
    local NEW_VERSION=$(grep -m1 "^VERSION=" "$NEW_SCRIPT" 2>/dev/null | cut -d'"' -f2 || echo "unknown")
    
    # Check if new version is different
    if cmp -s "$INSTALLED_SCRIPT" "$NEW_SCRIPT" 2>/dev/null; then
        echo -e "${GREEN}✓ Already running the latest version ($NEW_VERSION)${NC}"
        rm -rf "$TEMP_DIR"
        return 0
    fi
    
    echo -e "${CYAN}${BOLD}Version Information:${NC}"
    echo -e "  Current Version: ${BOLD}$VERSION${NC}"
    echo -e "  New Version: ${BOLD}$NEW_VERSION${NC}"
    echo ""
    
    # Show what's new (if changelog exists)
    if [ -f "$TEMP_DIR/ArchMode/CHANGELOG.md" ] || [ -f "$TEMP_DIR/ArchMode/README.md" ]; then
        echo -e "${CYAN}➜ Checking for updates and new features...${NC}"
        echo -e "${GREEN}✓ Update available${NC}"
    fi
    echo ""
    
    # Backup current script and configuration
    echo -e "${CYAN}${BOLD}Backup Phase:${NC}"
    echo -e "${CYAN}➜ Creating comprehensive backup...${NC}"
    
    # Backup script
    if sudo cp "$INSTALLED_SCRIPT" "$BACKUP_SCRIPT"; then
        echo -e "${GREEN}✓ Script backed up: $BACKUP_SCRIPT${NC}"
        log "Backup created before update: $BACKUP_SCRIPT"
    else
        echo -e "${YELLOW}⚠ Failed to create backup (continuing anyway)${NC}"
    fi
    
    # Backup configuration
    local config_backup="$BACKUP_DIR/config_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    if tar -czf "$config_backup" -C "$CONFIG_DIR" . 2>/dev/null; then
        echo -e "${GREEN}✓ Configuration backed up: $config_backup${NC}"
    else
        echo -e "${YELLOW}⚠ Failed to backup configuration${NC}"
    fi
    
    # Backup mods and plugins
    if [ -d "$MODS_DIR" ] && [ -n "$(ls -A "$MODS_DIR"/*.sh 2>/dev/null)" ]; then
        local mods_backup="$BACKUP_DIR/mods_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
        tar -czf "$mods_backup" -C "$MODS_DIR" . 2>/dev/null && echo -e "${GREEN}✓ Mods backed up${NC}" || true
    fi
    
    if [ -d "$PLUGINS_DIR" ] && [ -n "$(ls -A "$PLUGINS_DIR"/*.sh 2>/dev/null)" ]; then
        local plugins_backup="$BACKUP_DIR/plugins_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
        tar -czf "$plugins_backup" -C "$PLUGINS_DIR" . 2>/dev/null && echo -e "${GREEN}✓ Plugins backed up${NC}" || true
    fi
    
    echo ""
    
    # Install new version
    echo -e "${CYAN}${BOLD}Installation Phase:${NC}"
    echo -e "${CYAN}➜ Installing new version...${NC}"
    if sudo cp "$NEW_SCRIPT" "$INSTALLED_SCRIPT" && sudo chmod +x "$INSTALLED_SCRIPT"; then
        echo -e "${GREEN}✓ New version installed successfully${NC}"
        log "Updated to version $NEW_VERSION"
        
        # Verify installation
        if [ -f "$INSTALLED_SCRIPT" ] && [ -x "$INSTALLED_SCRIPT" ]; then
            echo -e "${GREEN}✓ Installation verified${NC}"
        else
            echo -e "${RED}✗ Installation verification failed${NC}"
            echo -e "${YELLOW}  Restoring from backup...${NC}"
            sudo cp "$BACKUP_SCRIPT" "$INSTALLED_SCRIPT" 2>/dev/null || true
            rm -rf "$TEMP_DIR"
            return 1
        fi
    else
        echo -e "${RED}✗ Failed to install new version${NC}"
        echo -e "${YELLOW}  Restoring from backup...${NC}"
        sudo cp "$BACKUP_SCRIPT" "$INSTALLED_SCRIPT" 2>/dev/null || true
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    echo ""
    
    # Post-update tasks
    echo -e "${CYAN}${BOLD}Post-Update Tasks:${NC}"
    
    # Reload mods and plugins
    echo -e "${CYAN}➜ Reloading mods and plugins...${NC}"
    load_mods
    load_plugins
    echo -e "${GREEN}✓ Mods and plugins reloaded${NC}"
    
    # Clean up temporary files
    rm -rf "$TEMP_DIR"
    echo -e "${GREEN}✓ Temporary files cleaned${NC}"
    
    # Optionally remove old backups (keep last 5)
    local backups=($(ls -t "$INSTALLED_SCRIPT".backup.* 2>/dev/null))
    if [ ${#backups[@]} -gt 5 ]; then
        echo -e "${CYAN}➜ Cleaning up old backups (keeping last 5)...${NC}"
        for ((i=5; i<${#backups[@]}; i++)); do
            sudo rm -f "${backups[$i]}"
        done
        echo -e "${GREEN}✓ Old backups cleaned${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║      Update Complete! 🎉              ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${CYAN}  ArchMode has been updated to version ${BOLD}$NEW_VERSION${NC}"
    echo -e "${CYAN}  Your configuration, mods, plugins, and logs have been preserved${NC}"
    echo -e "${CYAN}  All backups are stored in: $BACKUP_DIR${NC}"
    echo ""
    echo -e "${YELLOW}Note:${NC} If you're running this update command, you may need to"
    echo -e "      restart your terminal or run: ${BOLD}hash -r${NC}"
    echo ""
    echo -e "${GREEN}Enjoy the new features! 🚀${NC}"
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
    
    # Confirm uninstallation
    read -p "Are you sure you want to uninstall ArchMode? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${CYAN}➜ Uninstallation cancelled${NC}"
        return 0
    fi
    
    # Check if script is installed
    if [ ! -f "$INSTALLED_SCRIPT" ]; then
        echo -e "${YELLOW}⚠ ArchMode not found at $INSTALLED_SCRIPT${NC}"
        echo -e "${CYAN}  It may already be uninstalled${NC}"
    else
        echo -e "${CYAN}➜ Removing ArchMode script...${NC}"
        if sudo rm -f "$INSTALLED_SCRIPT"; then
            echo -e "${GREEN}✓ Script removed${NC}"
            [ -f "$LOG_FILE" ] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] ArchMode uninstalled" >> "$LOG_FILE" || true
        else
            echo -e "${RED}✗ Failed to remove script${NC}"
            return 1
        fi
    fi
    
    # Remove systemd service if it exists
    if [ -f "$SYSTEMD_SERVICE" ]; then
        echo -e "${CYAN}➜ Removing systemd service...${NC}"
        sudo systemctl disable archmode 2>/dev/null || true
        sudo systemctl stop archmode 2>/dev/null || true
        if sudo rm -f "$SYSTEMD_SERVICE"; then
            sudo systemctl daemon-reload 2>/dev/null || true
            echo -e "${GREEN}✓ Systemd service removed${NC}"
        else
            echo -e "${YELLOW}⚠ Failed to remove systemd service${NC}"
        fi
    fi
    
    # Ask about mods and plugins
    if [ -d "$MODS_DIR" ] && [ -n "$(ls -A "$MODS_DIR"/*.sh 2>/dev/null)" ]; then
        echo ""
        echo -e "${YELLOW}Installed mods found:${NC}"
        ls -1 "$MODS_DIR"/*.sh 2>/dev/null | xargs -n1 basename | sed 's/^/  - /'
        echo ""
        read -p "Remove all mods? (y/N): " remove_mods
        if [[ "$remove_mods" == "y" || "$remove_mods" == "Y" ]]; then
            rm -rf "$MODS_DIR"/*.sh 2>/dev/null || true
            echo -e "${GREEN}✓ Mods removed${NC}"
        fi
    fi
    
    if [ -d "$PLUGINS_DIR" ] && [ -n "$(ls -A "$PLUGINS_DIR"/*.sh 2>/dev/null)" ]; then
        echo ""
        echo -e "${YELLOW}Installed plugins found:${NC}"
        ls -1 "$PLUGINS_DIR"/*.sh 2>/dev/null | xargs -n1 basename | sed 's/^/  - /'
        echo ""
        read -p "Remove all plugins? (y/N): " remove_plugins
        if [[ "$remove_plugins" == "y" || "$remove_plugins" == "Y" ]]; then
            rm -rf "$PLUGINS_DIR"/*.sh 2>/dev/null || true
            echo -e "${GREEN}✓ Plugins removed${NC}"
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

# ============================================
# SYSTEM HEALTH CHECK - Comprehensive Diagnostics
# ============================================

system_health_check() {
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║      System Health Check               ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    local health_score=100
    local issues=()
    local warnings=()
    
    # Check disk space
    echo -e "${BOLD}1. Disk Space Check${NC}"
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt 90 ]; then
        echo -e "  ${RED}✗ Critical: Disk usage at ${disk_usage}%${NC}"
        issues+=("Disk usage critical: ${disk_usage}%")
        health_score=$((health_score - 20))
    elif [ "$disk_usage" -gt 80 ]; then
        echo -e "  ${YELLOW}⚠ Warning: Disk usage at ${disk_usage}%${NC}"
        warnings+=("Disk usage high: ${disk_usage}%")
        health_score=$((health_score - 10))
    else
        echo -e "  ${GREEN}✓ Disk usage: ${disk_usage}%${NC}"
    fi
    
    # Check memory
    echo -e "${BOLD}2. Memory Check${NC}"
    local mem_usage=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')
    if [ "$mem_usage" -gt 90 ]; then
        echo -e "  ${RED}✗ Critical: Memory usage at ${mem_usage}%${NC}"
        issues+=("Memory usage critical: ${mem_usage}%")
        health_score=$((health_score - 15))
    elif [ "$mem_usage" -gt 80 ]; then
        echo -e "  ${YELLOW}⚠ Warning: Memory usage at ${mem_usage}%${NC}"
        warnings+=("Memory usage high: ${mem_usage}%")
        health_score=$((health_score - 5))
    else
        echo -e "  ${GREEN}✓ Memory usage: ${mem_usage}%${NC}"
    fi
    
    # Check CPU temperature
    echo -e "${BOLD}3. Temperature Check${NC}"
    if has_capability "sensors"; then
        local temp=$(sensors 2>/dev/null | grep -iE 'Package id 0|Tdie|Tctl' | awk '{print $2}' | sed 's/+//;s/°C//;s/°F//' | head -1)
        if [ -n "$temp" ]; then
            local temp_num=$(echo "$temp" | grep -oE '[0-9]+' | head -1)
            if [ -n "$temp_num" ] && [ "$temp_num" -gt 85 ]; then
                echo -e "  ${RED}✗ Critical: CPU temperature ${temp}${NC}"
                issues+=("CPU temperature critical: ${temp}")
                health_score=$((health_score - 15))
            elif [ -n "$temp_num" ] && [ "$temp_num" -gt 75 ]; then
                echo -e "  ${YELLOW}⚠ Warning: CPU temperature ${temp}${NC}"
                warnings+=("CPU temperature high: ${temp}")
                health_score=$((health_score - 5))
            else
                echo -e "  ${GREEN}✓ CPU temperature: ${temp}${NC}"
            fi
        else
            echo -e "  ${YELLOW}⚠ Temperature sensors not available${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠ Install 'lm_sensors' for temperature monitoring${NC}"
    fi
    
    # Check system load
    echo -e "${BOLD}4. System Load Check${NC}"
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local cpu_cores=$(nproc)
    local load_threshold=$(echo "$cpu_cores * 1.5" | bc 2>/dev/null || echo "4")
    if (( $(echo "$load_avg > $load_threshold" | bc -l 2>/dev/null || echo "0") )); then
        echo -e "  ${YELLOW}⚠ Warning: High system load: ${load_avg}${NC}"
        warnings+=("High system load: ${load_avg}")
        health_score=$((health_score - 5))
    else
        echo -e "  ${GREEN}✓ System load: ${load_avg}${NC}"
    fi
    
    # Check for updates
    echo -e "${BOLD}5. System Updates Check${NC}"
    if command -v checkupdates &>/dev/null; then
        local updates=$(checkupdates 2>/dev/null | wc -l)
        if [ "$updates" -gt 50 ]; then
            echo -e "  ${YELLOW}⚠ ${updates} packages need updates${NC}"
            warnings+=("Many packages need updates: ${updates}")
        else
            echo -e "  ${GREEN}✓ Updates: ${updates} packages${NC}"
        fi
    else
        echo -e "  ${CYAN}ℹ Install 'pacman-contrib' for update checking${NC}"
    fi
    
    # Check disk health (if smartctl available)
    echo -e "${BOLD}6. Disk Health Check${NC}"
    if command -v smartctl &>/dev/null && check_sudo; then
        local disk=$(lsblk -ndo NAME | head -1)
        if [ -n "$disk" ]; then
            local smart_status=$(sudo smartctl -H "/dev/$disk" 2>/dev/null | grep -i "SMART overall-health" | awk -F: '{print $2}' | xargs)
            if [ "$smart_status" = "PASSED" ]; then
                echo -e "  ${GREEN}✓ Disk health: PASSED${NC}"
            else
                echo -e "  ${YELLOW}⚠ Disk health: ${smart_status}${NC}"
                warnings+=("Disk health: ${smart_status}")
            fi
        fi
    else
        echo -e "  ${CYAN}ℹ Install 'smartmontools' for disk health monitoring${NC}"
    fi
    
    # Check network connectivity
    echo -e "${BOLD}7. Network Connectivity${NC}"
    if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        echo -e "  ${GREEN}✓ Network: Connected${NC}"
    else
        echo -e "  ${RED}✗ Network: No internet connection${NC}"
        issues+=("No internet connection")
        health_score=$((health_score - 10))
    fi
    
    # Summary
    echo ""
    echo -e "${CYAN}${BOLD}Health Score: ${NC}"
    if [ "$health_score" -ge 90 ]; then
        echo -e "${GREEN}${BOLD}  $health_score/100 - EXCELLENT${NC}"
    elif [ "$health_score" -ge 70 ]; then
        echo -e "${YELLOW}${BOLD}  $health_score/100 - GOOD${NC}"
    elif [ "$health_score" -ge 50 ]; then
        echo -e "${YELLOW}${BOLD}  $health_score/100 - FAIR${NC}"
    else
        echo -e "${RED}${BOLD}  $health_score/100 - POOR${NC}"
    fi
    
    if [ ${#issues[@]} -gt 0 ]; then
        echo ""
        echo -e "${RED}${BOLD}Critical Issues:${NC}"
        for issue in "${issues[@]}"; do
            echo -e "  ${RED}• $issue${NC}"
        done
    fi
    
    if [ ${#warnings[@]} -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}${BOLD}Warnings:${NC}"
        for warning in "${warnings[@]}"; do
            echo -e "  ${YELLOW}• $warning${NC}"
        done
    fi
    
    # Save report
    {
        echo "System Health Report - $(date)"
        echo "Health Score: $health_score/100"
        echo ""
        echo "Issues:"
        printf '%s\n' "${issues[@]}"
        echo ""
        echo "Warnings:"
        printf '%s\n' "${warnings[@]}"
    } > "$HEALTH_FILE"
    
    echo ""
    echo -e "${CYAN}Report saved to: $HEALTH_FILE${NC}"
    log "System health check completed - Score: $health_score/100"
}

# ============================================
# REAL-TIME MONITORING DASHBOARD
# ============================================

monitor_dashboard() {
    local refresh_rate=${1:-2}
    
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║    Real-Time System Monitor            ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${YELLOW}Press Ctrl+C to exit${NC}"
    echo ""
    
    while true; do
        clear
        echo -e "${CYAN}${BOLD}"
        echo "╔════════════════════════════════════════╗"
        echo "║    Real-Time System Monitor            ║"
        echo "╚════════════════════════════════════════╝"
        echo -e "${NC}"
        echo ""
        
        # CPU Usage
        local cpu_idle cpu_total
        read -r cpu_idle cpu_total < <(awk '/^cpu / {idle=$5+$6; total=idle+$2+$3+$4; print idle, total}' /proc/stat)
        sleep 0.1
        local cpu_idle2 cpu_total2
        read -r cpu_idle2 cpu_total2 < <(awk '/^cpu / {idle=$5+$6; total=idle+$2+$3+$4; print idle, total}' /proc/stat)
        local cpu_usage=$(awk "BEGIN {printf \"%.1f\", (1-($cpu_idle2-$cpu_idle)/($cpu_total2-$cpu_total))*100}")
        
        # Memory
        local mem_info=$(awk '/^MemTotal:/{total=$2} /^MemAvailable:/{avail=$2} END {used=total-avail; printf "%.1fG / %.1fG (%.1f%%)", used/1024/1024, total/1024/1024, (used/total)*100}' /proc/meminfo 2>/dev/null)
        
        # Temperature
        local temp="N/A"
        if has_capability "sensors"; then
            temp=$(sensors 2>/dev/null | grep -iE 'Package id 0|Tdie|Tctl' | awk '{print $2$3}' | head -n1 | sed 's/+//' || echo "N/A")
        fi
        
        # Disk I/O
        local disk_io=$(iostat -x 1 2 2>/dev/null | tail -1 | awk '{print $10}' || echo "N/A")
        
        # Network
        local net_rx=$(cat /sys/class/net/*/statistics/rx_bytes 2>/dev/null | awk '{sum+=$1} END {printf "%.2f MB", sum/1024/1024}' || echo "N/A")
        local net_tx=$(cat /sys/class/net/*/statistics/tx_bytes 2>/dev/null | awk '{sum+=$1} END {printf "%.2f MB", sum/1024/1024}' || echo "N/A")
        
        # Display
        echo -e "${BOLD}CPU Usage:${NC} ${cpu_usage}%"
        echo -e "${BOLD}Memory:${NC} $mem_info"
        echo -e "${BOLD}Temperature:${NC} $temp"
        echo -e "${BOLD}Disk I/O:${NC} $disk_io"
        echo -e "${BOLD}Network RX:${NC} $net_rx"
        echo -e "${BOLD}Network TX:${NC} $net_tx"
        echo ""
        echo -e "${CYAN}Refreshing every ${refresh_rate}s...${NC}"
        
        sleep "$refresh_rate"
    done
}

# ============================================
# AUTOMATION & SCHEDULING
# ============================================

schedule_mode() {
    local time=$1
    local mode=$2
    
    if [ -z "$time" ] || [ -z "$mode" ]; then
        echo -e "${RED}✗ Time and mode required${NC}"
        echo "Usage: archmode schedule <time> <mode>"
        echo "Example: archmode schedule 22:00 NIGHTMODE"
        return 1
    fi
    
    # Validate time format (HH:MM)
    if ! [[ "$time" =~ ^([0-1][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
        echo -e "${RED}✗ Invalid time format. Use HH:MM (24-hour)${NC}"
        return 1
    fi
    
    mode=$(echo "$mode" | tr '[:lower:]' '[:upper:]')
    
    # Add to schedule
    echo "$time:$mode" >> "$SCHEDULE_FILE"
    echo -e "${GREEN}✓ Scheduled: $mode at $time${NC}"
    log "Scheduled $mode at $time"
    
    # Create cron job if not exists
    if ! crontab -l 2>/dev/null | grep -q "archmode schedule-run"; then
        (crontab -l 2>/dev/null; echo "* * * * * /usr/local/bin/archmode schedule-run") | crontab -
        echo -e "${CYAN}✓ Cron job created${NC}"
    fi
}

list_schedule() {
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║        Scheduled Modes                 ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    if [ ! -s "$SCHEDULE_FILE" ]; then
        echo -e "${YELLOW}No scheduled modes${NC}"
        echo -e "${CYAN}Schedule one with: archmode schedule <time> <mode>${NC}"
        return 0
    fi
    
    while IFS=: read -r time mode; do
        [[ -z "$time" ]] && continue
        echo -e "${GREEN}✓${NC} ${BOLD}$mode${NC} at ${CYAN}$time${NC}"
    done < "$SCHEDULE_FILE"
    echo ""
}

schedule_run() {
    local current_time=$(date +%H:%M)
    
    while IFS=: read -r time mode; do
        [[ -z "$time" ]] && continue
        if [ "$time" = "$current_time" ]; then
            log "Running scheduled mode: $mode"
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
        fi
    done < "$SCHEDULE_FILE"
}

# ============================================
# PROCESS MANAGER
# ============================================

process_manager() {
    local action=$1
    local target=$2
    
    case "$action" in
        list|"")
            echo -e "${CYAN}${BOLD}"
            echo "╔════════════════════════════════════════╗"
            echo "║        Top Processes                   ║"
            echo "╚════════════════════════════════════════╝"
            echo -e "${NC}"
            echo ""
            ps aux --sort=-%cpu | head -11 | awk 'NR==1 {printf "%-8s %-8s %-6s %-6s %s\n", $1, $2, $3, $4, $11} NR>1 {printf "%-8s %-8s %-6s %-6s %s\n", $1, $2, $3"%", $4"%", substr($0, index($0,$11))}'
            echo ""
            ;;
        kill)
            if [ -z "$target" ]; then
                echo -e "${RED}✗ Process name or PID required${NC}"
                return 1
            fi
            if [[ "$target" =~ ^[0-9]+$ ]]; then
                kill "$target" 2>/dev/null && echo -e "${GREEN}✓ Process $target killed${NC}" || echo -e "${RED}✗ Failed to kill process${NC}"
            else
                pkill "$target" && echo -e "${GREEN}✓ Process $target killed${NC}" || echo -e "${RED}✗ Failed to kill process${NC}"
            fi
            ;;
        priority)
            if [ -z "$target" ]; then
                echo -e "${RED}✗ Process name or PID required${NC}"
                return 1
            fi
            local pid=$target
            if ! [[ "$pid" =~ ^[0-9]+$ ]]; then
                pid=$(pgrep -x "$target" | head -1)
            fi
            if [ -n "$pid" ]; then
                set_process_priority "$pid" -10 "SCHED_OTHER"
                echo -e "${GREEN}✓ Process $pid prioritized${NC}"
            else
                echo -e "${RED}✗ Process not found${NC}"
            fi
            ;;
        *)
            echo -e "${RED}✗ Unknown action: $action${NC}"
            echo "Usage: archmode process [list|kill|priority] [target]"
            return 1
            ;;
    esac
}

# ============================================
# SYSTEM CLEANUP
# ============================================

system_cleanup() {
    local type=${1:-all}
    local freed_space=0
    
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║        System Cleanup                   ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    case "$type" in
        cache|all)
            echo -e "${CYAN}➜ Cleaning package cache...${NC}"
            if check_sudo; then
                local cache_size=$(du -sh /var/cache/pacman/pkg 2>/dev/null | awk '{print $1}' || echo "0")
                sudo pacman -Sc --noconfirm 2>/dev/null && echo -e "${GREEN}✓ Package cache cleaned (${cache_size})${NC}" || echo -e "${YELLOW}⚠ Cache cleanup skipped${NC}"
            fi
            ;;
        temp|all)
            echo -e "${CYAN}➜ Cleaning temporary files...${NC}"
            local temp_size=$(du -sh /tmp 2>/dev/null | awk '{print $1}' || echo "0")
            find /tmp -type f -atime +7 -delete 2>/dev/null && echo -e "${GREEN}✓ Temp files cleaned${NC}" || true
            ;;
        logs|all)
            echo -e "${CYAN}➜ Cleaning old logs...${NC}"
            if check_sudo; then
                find /var/log -type f -name "*.log" -mtime +30 -delete 2>/dev/null && echo -e "${GREEN}✓ Old logs cleaned${NC}" || true
            fi
            ;;
        home|all)
            echo -e "${CYAN}➜ Cleaning home directory...${NC}"
            # Clean common cache directories
            for dir in ~/.cache ~/.thumbnails ~/.local/share/Trash; do
                if [ -d "$dir" ]; then
                    local size=$(du -sh "$dir" 2>/dev/null | awk '{print $1}' || echo "0")
                    find "$dir" -type f -atime +30 -delete 2>/dev/null && echo -e "${GREEN}✓ Cleaned $dir (${size})${NC}" || true
                fi
            done
            ;;
        *)
            echo -e "${RED}✗ Unknown cleanup type: $type${NC}"
            echo "Usage: archmode cleanup [cache|temp|logs|home|all]"
            return 1
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}✓ Cleanup complete!${NC}"
    log "System cleanup performed: $type"
}

# ============================================
# TEMPERATURE MONITORING & ALERTS
# ============================================

temp_monitor() {
    local threshold=${1:-80}
    
    if ! has_capability "sensors"; then
        echo -e "${RED}✗ Install 'lm_sensors' for temperature monitoring${NC}"
        return 1
    fi
    
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║    Temperature Monitor                 ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${YELLOW}Monitoring temperature (threshold: ${threshold}°C)${NC}"
    echo -e "${YELLOW}Press Ctrl+C to exit${NC}"
    echo ""
    
    while true; do
        local temp=$(sensors 2>/dev/null | grep -iE 'Package id 0|Tdie|Tctl' | awk '{print $2}' | sed 's/+//;s/°C//' | grep -oE '[0-9]+' | head -1)
        if [ -n "$temp" ] && [ "$temp" -gt "$threshold" ]; then
            echo -e "${RED}${BOLD}⚠ ALERT: Temperature ${temp}°C exceeds threshold ${threshold}°C!${NC}"
            if command -v notify-send &>/dev/null; then
                notify-send "Temperature Alert" "CPU temperature: ${temp}°C" -u critical
            fi
        else
            echo -e "${GREEN}✓ Temperature: ${temp}°C${NC}"
        fi
        sleep 5
    done
}

# ============================================
# NETWORK ANALYZER
# ============================================

network_analyzer() {
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║        Network Analysis                ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    # Network interfaces
    echo -e "${BOLD}Network Interfaces:${NC}"
    ip -br addr show | while read -r line; do
        echo -e "  ${CYAN}$line${NC}"
    done
    echo ""
    
    # Connection speed test (if speedtest-cli available)
    if command -v speedtest-cli &>/dev/null; then
        echo -e "${BOLD}Internet Speed Test:${NC}"
        echo -e "${CYAN}Running speed test...${NC}"
        speedtest-cli --simple 2>/dev/null || echo -e "${YELLOW}Speed test failed${NC}"
    else
        echo -e "${YELLOW}Install 'speedtest-cli' for speed testing${NC}"
    fi
    echo ""
    
    # Active connections
    echo -e "${BOLD}Active Connections:${NC}"
    ss -tun | head -10
    echo ""
    
    # Network statistics
    echo -e "${BOLD}Network Statistics:${NC}"
    for iface in /sys/class/net/*; do
        local name=$(basename "$iface")
        [ "$name" = "lo" ] && continue
        local rx=$(cat "$iface/statistics/rx_bytes" 2>/dev/null || echo "0")
        local tx=$(cat "$iface/statistics/tx_bytes" 2>/dev/null || echo "0")
        local rx_mb=$(awk "BEGIN {printf \"%.2f\", $rx/1024/1024}")
        local tx_mb=$(awk "BEGIN {printf \"%.2f\", $tx/1024/1024}")
        echo -e "  ${CYAN}$name:${NC} RX: ${rx_mb} MB, TX: ${tx_mb} MB"
    done
    echo ""
}

# ============================================
# GPU MANAGER
# ============================================

gpu_manager() {
    local action=${1:-info}
    
    case "$action" in
        info)
            echo -e "${CYAN}${BOLD}"
            echo "╔════════════════════════════════════════╗"
            echo "║        GPU Information                 ║"
            echo "╚════════════════════════════════════════╝"
            echo -e "${NC}"
            echo ""
            
            # NVIDIA
            if command -v nvidia-smi &>/dev/null; then
                echo -e "${BOLD}NVIDIA GPU:${NC}"
                nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader | while read -r line; do
                    echo -e "  ${GREEN}$line${NC}"
                done
            fi
            
            # AMD
            if command -v rocm-smi &>/dev/null; then
                echo -e "${BOLD}AMD GPU:${NC}"
                rocm-smi 2>/dev/null | head -20
            fi
            
            # Generic
            lspci | grep -i vga
            echo ""
            ;;
        monitor)
            if command -v nvidia-smi &>/dev/null; then
                watch -n 1 nvidia-smi
            else
                echo -e "${YELLOW}NVIDIA GPU monitoring requires nvidia-smi${NC}"
            fi
            ;;
        *)
            echo -e "${RED}✗ Unknown action: $action${NC}"
            echo "Usage: archmode gpu [info|monitor]"
            return 1
            ;;
    esac
}

# ============================================
# SYSTEM OPTIMIZER (One-Click Optimization)
# ============================================

system_optimizer() {
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║        System Optimizer                ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${CYAN}➜ Running comprehensive system optimization...${NC}"
    echo ""
    
    # Clean package cache
    echo -e "${CYAN}1. Cleaning package cache...${NC}"
    if check_sudo; then
        sudo pacman -Sc --noconfirm 2>/dev/null && echo -e "${GREEN}✓ Cache cleaned${NC}" || echo -e "${YELLOW}⚠ Cache cleanup skipped${NC}"
    fi
    
    # Optimize database
    echo -e "${CYAN}2. Optimizing package database...${NC}"
    if check_sudo; then
        sudo pacman-optimize --noconfirm 2>/dev/null && echo -e "${GREEN}✓ Database optimized${NC}" || echo -e "${YELLOW}⚠ Database optimization skipped${NC}"
    fi
    
    # Update file database
    echo -e "${CYAN}3. Updating file database...${NC}"
    if check_sudo; then
        sudo updatedb 2>/dev/null && echo -e "${GREEN}✓ File database updated${NC}" || echo -e "${YELLOW}⚠ File database update skipped${NC}"
    fi
    
    # Clear systemd journal
    echo -e "${CYAN}4. Cleaning systemd journal...${NC}"
    if check_sudo; then
        sudo journalctl --vacuum-time=7d 2>/dev/null && echo -e "${GREEN}✓ Journal cleaned${NC}" || echo -e "${YELLOW}⚠ Journal cleanup skipped${NC}"
    fi
    
    # Optimize filesystems
    echo -e "${CYAN}5. Optimizing filesystems...${NC}"
    if check_sudo; then
        for fs in / /home; do
            if mountpoint -q "$fs" 2>/dev/null; then
                sudo fstrim "$fs" 2>/dev/null && echo -e "${GREEN}✓ Trimmed $fs${NC}" || true
            fi
        done
    fi
    
    echo ""
    echo -e "${GREEN}✓${NC} ${BOLD}System optimization complete!${NC}"
    log "System optimizer completed"
}

# ============================================
# INTERACTIVE DASHBOARD
# ============================================

interactive_dashboard() {
    while true; do
        clear
        echo -e "${CYAN}${BOLD}"
        echo "╔════════════════════════════════════════╗"
        echo "║     ArchMode Interactive Dashboard     ║"
        echo "╚════════════════════════════════════════╝"
        echo -e "${NC}"
        echo ""
        echo -e "${BOLD}1.${NC} System Status"
        echo -e "${BOLD}2.${NC} Enable Mode"
        echo -e "${BOLD}3.${NC} System Health Check"
        echo -e "${BOLD}4.${NC} Real-Time Monitor"
        echo -e "${BOLD}5.${NC} Process Manager"
        echo -e "${BOLD}6.${NC} System Cleanup"
        echo -e "${BOLD}7.${NC} Network Analyzer"
        echo -e "${BOLD}8.${NC} GPU Manager"
        echo -e "${BOLD}9.${NC} System Optimizer"
        echo -e "${BOLD}10.${NC} Schedule Mode"
        echo -e "${BOLD}11.${NC} Mods & Plugins"
        echo -e "${BOLD}12.${NC} Security & Privacy"
        echo -e "${BOLD}0.${NC} Exit"
        echo ""
        read -p "Select option: " choice
        
        case "$choice" in
            1) show_status; read -p "Press Enter to continue..."; ;;
            2) 
                list_modes
                read -p "Enter mode name: " mode
                [ -n "$mode" ] && archmode enable "$mode"
                read -p "Press Enter to continue..."
                ;;
            3) system_health_check; read -p "Press Enter to continue..."; ;;
            4) monitor_dashboard 2; ;;
            5) process_manager list; read -p "Press Enter to continue..."; ;;
            6) system_cleanup all; read -p "Press Enter to continue..."; ;;
            7) network_analyzer; read -p "Press Enter to continue..."; ;;
            8) gpu_manager info; read -p "Press Enter to continue..."; ;;
            9) system_optimizer; read -p "Press Enter to continue..."; ;;
            10) 
                read -p "Enter time (HH:MM): " time
                read -p "Enter mode: " mode
                [ -n "$time" ] && [ -n "$mode" ] && schedule_mode "$time" "$mode"
                read -p "Press Enter to continue..."
                ;;
            11) 
                list_mods
                list_plugins
                read -p "Press Enter to continue..."
                ;;
            12) 
                show_security
                show_privacy
                read -p "Press Enter to continue..."
                ;;
            0) echo -e "${GREEN}Goodbye!${NC}"; exit 0; ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 1; ;;
        esac
    done
}

# Help / usage
show_help() {
    echo -e "${CYAN}${BOLD}"
    echo "ArchMode v$VERSION - ULTIMATE EDITION"
    echo "System Mode Manager for Arch Linux"
    echo -e "${NC}"
    echo "Usage: archmode <command> [argument]"
    echo ""
    echo -e "${BOLD}Core Commands:${NC}"
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
    echo "  benchmark              Run performance benchmark"
    echo ""
    echo -e "${BOLD}Mods & Plugins:${NC}"
    echo "  mods                   List installed mods"
    echo "  plugins                List installed plugins"
    echo "  create-mod <name>       Create a new mod"
    echo "  create-plugin <name>    Create a new plugin"
    echo "  edit-mod <name> [editor] Edit a mod (default: vim)"
    echo "  edit-plugin <name> [editor] Edit a plugin (default: vim)"
    echo ""
    echo -e "${BOLD}Security & Privacy:${NC}"
    echo "  security               Show security settings"
    echo "  security <setting> <value> Configure security setting"
    echo "  privacy                Show privacy settings"
    echo "  privacy <setting> <value> Configure privacy setting"
    echo ""
    echo -e "${BOLD}Monitoring & Health:${NC}"
    echo "  health                 Run comprehensive system health check"
    echo "  monitor [refresh]      Real-time monitoring dashboard (default: 2s)"
    echo "  temp [threshold]       Monitor temperature with alerts (default: 80°C)"
    echo ""
    echo -e "${BOLD}Automation:${NC}"
    echo "  schedule <time> <mode> Schedule mode activation (HH:MM format)"
    echo "  schedule-list          List scheduled modes"
    echo ""
    echo -e "${BOLD}Process Management:${NC}"
    echo "  process [list|kill|priority] [target] Manage processes"
    echo ""
    echo -e "${BOLD}System Tools:${NC}"
    echo "  cleanup [type]         Clean system (cache|temp|logs|home|all)"
    echo "  network                Network analyzer and diagnostics"
    echo "  gpu [info|monitor]     GPU information and monitoring"
    echo "  optimize               One-click system optimization"
    echo "  dashboard              Interactive dashboard menu"
    echo ""
    echo -e "${BOLD}System Commands:${NC}"
    echo "  update                 Update ArchMode (ULTIMATE update system)"
    echo "  uninstall              Uninstall ArchMode from system"
    echo "  help                   Show this help message"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "  archmode enable GAMEMODE"
    echo "  archmode enable gamemode    # Case-insensitive"
    echo "  archmode profile GAMER"
    echo "  archmode create-mod mymod"
    echo "  archmode create-plugin myplugin"
    echo "  archmode edit-mod mymod vim"
    echo "  archmode security validate_mods true"
    echo "  archmode privacy anonymize_logs true"
    echo "  archmode reset"
    echo "  archmode update"
}

# ============================================
# Argument parsing
# ============================================

command="${1:-dashboard}"
argument="${2:-}"
argument2="${3:-}"

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
        # Convert to uppercase for case-insensitive matching
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
        # Convert to uppercase for case-insensitive matching
        argument=$(echo "$argument" | tr '[:lower:]' '[:upper:]')
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
    benchmark)
        benchmark_performance
        ;;
    health)
        system_health_check
        ;;
    monitor)
        monitor_dashboard "${argument:-2}"
        ;;
    temp)
        temp_monitor "${argument:-80}"
        ;;
    schedule)
        schedule_mode "$argument" "$argument2"
        ;;
    schedule-list)
        list_schedule
        ;;
    schedule-run)
        schedule_run
        ;;
    process)
        process_manager "$argument" "$argument2"
        ;;
    cleanup)
        system_cleanup "${argument:-all}"
        ;;
    network)
        network_analyzer
        ;;
    gpu)
        gpu_manager "$argument"
        ;;
    optimize)
        system_optimizer
        ;;
    dashboard)
        interactive_dashboard
        ;;
    mods)
        list_mods
        ;;
    plugins)
        list_plugins
        ;;
    create-mod)
        create_mod "$argument"
        ;;
    create-plugin)
        create_plugin "$argument"
        ;;
    edit-mod)
        edit_mod "$argument" "$argument2"
        ;;
    edit-plugin)
        edit_plugin "$argument" "$argument2"
        ;;
    security)
        if [ -z "$argument" ]; then
            show_security
        else
            configure_security "$argument" "$argument2"
        fi
        ;;
    privacy)
        if [ -z "$argument" ]; then
            show_privacy
        else
            configure_privacy "$argument" "$argument2"
        fi
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
