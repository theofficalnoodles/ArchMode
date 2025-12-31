#!/bin/bash

###############################################################################
# ArchMode - System Mode Manager for Arch Linux
# A utility to toggle system services and features on/off
###############################################################################

set -euo pipefail

# Configuration
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/archmode"
STATE_FILE="$CONFIG_DIR/modes.state"
CONFIG_FILE="$CONFIG_DIR/modes.conf"
LOG_FILE="${XDG_LOG_HOME:-$HOME/.local/share}/archmode/archmode.log"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

###############################################################################
# Logging Functions
###############################################################################

log_msg() {
    local level="$1"
    local msg="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "[$timestamp] [$level] $msg" >> "$LOG_FILE"
}

log_info() {
    log_msg "INFO" "$1"
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    log_msg "SUCCESS" "$1"
    echo -e "${GREEN}✓${NC} $1"
}

log_error() {
    log_msg "ERROR" "$1"
    echo -e "${RED}✗${NC} $1" >&2
}

log_warning() {
    log_msg "WARNING" "$1"
    echo -e "${YELLOW}⚠${NC} $1"
}

###############################################################################
# Initialization Functions
###############################################################################

init_config() {
    mkdir -p "$CONFIG_DIR" "$(dirname "$LOG_FILE")"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << 'EOF'
# ArchMode Configuration File
# Format: MODE_NAME|Display Name|Default State (true/false)

GAMEMODE|Gaming Mode|false
PRODUCTIVITY|Productivity Mode|false
POWERMODE|Power Save Mode|false
QUIETMODE|Quiet Mode (Low Fan)|false
DEVMODE|Development Mode|false
EOF
        log_info "Created configuration file at $CONFIG_FILE"
    fi
    
    if [[ ! -f "$STATE_FILE" ]]; then
        touch "$STATE_FILE"
        log_info "Created state file at $STATE_FILE"
    fi
}

check_requirements() {
    local missing_deps=()
    
    # Check for required commands
    for cmd in sudo systemctl grep sed; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        return 1
    fi
    
    # Check if user can use sudo without password for certain commands
    if ! sudo -n systemctl status &> /dev/null 2>&1; then
        log_warning "sudo password may be required for system operations"
    fi
    
    return 0
}

###############################################################################
# State Management Functions
###############################################################################

get_mode_state() {
    local mode="$1"
    grep "^${mode}=" "$STATE_FILE" 2>/dev/null | cut -d'=' -f2 || echo "false"
}

set_mode_state() {
    local mode="$1"
    local state="$2"
    
    if grep -q "^${mode}=" "$STATE_FILE" 2>/dev/null; then
        sed -i "s/^${mode}=.*/${mode}=${state}/" "$STATE_FILE"
    else
        echo "${mode}=${state}" >> "$STATE_FILE"
    fi
}

###############################################################################
# Mode-Specific Functions
###############################################################################

# GAMEMODE: Optimize for gaming
apply_gamemode() {
    log_info "Applying GameMode..."
    
    # Disable notifications
    if command -v dunst &> /dev/null; then
        pkill -SIGUSR1 dunst 2>/dev/null || true
        log_success "Notifications disabled"
    fi
    
    # Disable system sounds
    if command -v pactl &> /dev/null; then
        pactl set-sink-volume @DEFAULT_SINK@ 0 2>/dev/null || true
        log_success "System audio muted"
    fi
    
    # Set CPU governor to performance
    if [[ -d /sys/devices/system/cpu/cpu0/cpufreq ]]; then
        for cpu in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor; do
            echo "performance" | sudo tee "$cpu" > /dev/null 2>&1 || true
        done
        log_success "CPU governor set to performance"
    fi
    
    # Disable system updates
    sudo systemctl stop --no-block reflector.timer 2>/dev/null || true
    sudo systemctl mask --now reflector.timer 2>/dev/null || true
    log_success "System updates disabled"
    
    # Disable power management
    sudo systemctl stop power-profiles-daemon 2>/dev/null || true
    log_success "Power management disabled"
    
    set_mode_state "GAMEMODE" "true"
    log_success "GameMode enabled!"
}

disable_gamemode() {
    log_info "Disabling GameMode..."
    
    # Enable notifications
    if command -v dunst &> /dev/null; then
        pkill -SIGUSR2 dunst 2>/dev/null || true
        log_success "Notifications re-enabled"
    fi
    
    # Restore system sounds
    if command -v pactl &> /dev/null; then
        pactl set-sink-volume @DEFAULT_SINK@ 65536 2>/dev/null || true
        log_success "System audio restored"
    fi
    
    # Set CPU governor back to schedutil (default)
    if [[ -d /sys/devices/system/cpu/cpu0/cpufreq ]]; then
        for cpu in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor; do
            echo "schedutil" | sudo tee "$cpu" > /dev/null 2>&1 || true
        done
        log_success "CPU governor set to schedutil"
    fi
    
    # Re-enable system updates
    sudo systemctl unmask reflector.timer 2>/dev/null || true
    sudo systemctl start reflector.timer 2>/dev/null || true
    log_success "System updates re-enabled"
    
    # Re-enable power management
    sudo systemctl start power-profiles-daemon 2>/dev/null || true
    log_success "Power management re-enabled"
    
    set_mode_state "GAMEMODE" "false"
    log_success "GameMode disabled!"
}

# PRODUCTIVITY: Maximize focus
apply_productivity() {
    log_info "Applying Productivity Mode..."
    
    # Enable notifications
    if command -v dunst &> /dev/null; then
        pkill -SIGUSR2 dunst 2>/dev/null || true
        log_success "Notifications enabled"
    fi
    
    # Enable system sounds
    if command -v pactl &> /dev/null; then
        pactl set-sink-volume @DEFAULT_SINK@ 65536 2>/dev/null || true
        log_success "System audio enabled"
    fi
    
    # Disable auto-suspend
    sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target 2>/dev/null || true
    log_success "Auto-suspend disabled"
    
    set_mode_state "PRODUCTIVITY" "true"
    log_success "Productivity Mode enabled!"
}

disable_productivity() {
    log_info "Disabling Productivity Mode..."
    
    sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target 2>/dev/null || true
    log_success "Auto-suspend restored"
    
    set_mode_state "PRODUCTIVITY" "false"
    log_success "Productivity Mode disabled!"
}

# POWERMODE: Power saving
apply_powermode() {
    log_info "Applying Power Save Mode..."
    
    # Set CPU governor to powersave
    if [[ -d /sys/devices/system/cpu/cpu0/cpufreq ]]; then
        for cpu in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor; do
            echo "powersave" | sudo tee "$cpu" > /dev/null 2>&1 || true
        done
        log_success "CPU governor set to powersave"
    fi
    
    # Enable USB autosuspend
    echo 1 | sudo tee /sys/module/usb_core/parameters/autosuspend 2>/dev/null || true
    log_success "USB autosuspend enabled"
    
    # Reduce screen brightness to 40%
    if command -v brightnessctl &> /dev/null; then
        brightnessctl set 40% 2>/dev/null || true
        log_success "Screen brightness reduced to 40%"
    fi
    
    set_mode_state "POWERMODE" "true"
    log_success "Power Save Mode enabled!"
}

disable_powermode() {
    log_info "Disabling Power Save Mode..."
    
    # Set CPU governor back to default
    if [[ -d /sys/devices/system/cpu/cpu0/cpufreq ]]; then
        for cpu in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor; do
            echo "schedutil" | sudo tee "$cpu" > /dev/null 2>&1 || true
        done
        log_success "CPU governor set to schedutil"
    fi
    
    # Disable USB autosuspend
    echo 0 | sudo tee /sys/module/usb_core/parameters/autosuspend 2>/dev/null || true
    log_success "USB autosuspend disabled"
    
    # Restore screen brightness to 100%
    if command -v brightnessctl &> /dev/null; then
        brightnessctl set 100% 2>/dev/null || true
        log_success "Screen brightness restored to 100%"
    fi
    
    set_mode_state "POWERMODE" "false"
    log_success "Power Save Mode disabled!"
}

# QUIETMODE: Reduce noise
apply_quietmode() {
    log_info "Applying Quiet Mode..."
    
    # Reduce fan speed
    if command -v nbfc &> /dev/null; then
        sudo nbfc set --speed 30 2>/dev/null || true
        log_success "Fan speed reduced"
    fi
    
    # Mute audio
    if command -v pactl &> /dev/null; then
        pactl set-sink-mute @DEFAULT_SINK@ 1 2>/dev/null || true
        log_success "Audio muted"
    fi
    
    # Set CPU governor to powersave
    if [[ -d /sys/devices/system/cpu/cpu0/cpufreq ]]; then
        for cpu in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor; do
            echo "powersave" | sudo tee "$cpu" > /dev/null 2>&1 || true
        done
        log_success "CPU set to powersave"
    fi
    
    set_mode_state "QUIETMODE" "true"
    log_success "Quiet Mode enabled!"
}

disable_quietmode() {
    log_info "Disabling Quiet Mode..."
    
    # Restore fan speed
    if command -v nbfc &> /dev/null; then
        sudo nbfc set --speed auto 2>/dev/null || true
        log_success "Fan speed restored"
    fi
    
    # Restore audio
    if command -v pactl &> /dev/null; then
        pactl set-sink-mute @DEFAULT_SINK@ 0 2>/dev/null || true
        log_success "Audio restored"
    fi
    
    # Set CPU governor back to default
    if [[ -d /sys/devices/system/cpu/cpu0/cpufreq ]]; then
        for cpu in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor; do
            echo "schedutil" | sudo tee "$cpu" > /dev/null 2>&1 || true
        done
        log_success "CPU set to schedutil"
    fi
    
    set_mode_state "QUIETMODE" "false"
    log_success "Quiet Mode disabled!"
}

# DEVMODE: Development optimizations
apply_devmode() {
    log_info "Applying Development Mode..."
    
    # Disable automatic updates during development
    sudo systemctl mask --now reflector.timer 2>/dev/null || true
    log_success "Auto-updates disabled"
    
    # Enable core dumps for debugging
    ulimit -c unlimited 2>/dev/null || true
    log_success "Core dumps enabled"
    
    set_mode_state "DEVMODE" "true"
    log_success "Development Mode enabled!"
}

disable_devmode() {
    log_info "Disabling Development Mode..."
    
    # Re-enable automatic updates
    sudo systemctl unmask reflector.timer 2>/dev/null || true
    log_success "Auto-updates re-enabled"
    
    # Reset core dumps
    ulimit -c 0 2>/dev/null || true
    log_success "Core dumps reset"
    
    set_mode_state "DEVMODE" "false"
    log_success "Development Mode disabled!"
}

###############################################################################
# UI Functions
###############################################################################

show_banner() {
    clear
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════╗"
    echo "║         🎮 ArchMode v1.1.0 🎮          ║"
    echo "║    System Mode Manager for Arch Linux   ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
}

show_menu() {
    show_banner
    
    echo -e "${YELLOW}Current Modes:${NC}\n"
    
    local counter=1
    while IFS='|' read -r mode display_name default_state; do
        # Skip empty lines and comments
        [[ -z "$mode" || "$mode" == \#* ]] && continue
        
        # Trim whitespace
        mode=$(echo "$mode" | xargs)
        display_name=$(echo "$display_name" | xargs)
        
        local state=$(get_mode_state "$mode")
        local status_symbol="${GREEN}✓${NC}"
        local status_text="ON"
        
        if [[ "$state" == "false" ]]; then
            status_symbol="${RED}✗${NC}"
            status_text="OFF"
        fi
        
        printf "%2d) ${status_symbol} %-30s [${BLUE}%s${NC}]\n" "$counter" "$display_name" "$status_text"
        ((counter++))
    done < "$CONFIG_FILE"
    
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo "  s) Status Report"
    echo "  r) Reset All Modes"
    echo "  q) Quit"
    echo ""
}

interactive_mode() {
    while true; do
        show_menu
        
        read -p "Select an option: " choice
        
        case "$choice" in
            1|2|3|4|5)
                toggle_mode "$choice"
                read -p "Press Enter to continue..."
                ;;
            s|S)
                show_status
                read -p "Press Enter to continue..."
                ;;
            r|R)
                read -p "Are you sure you want to reset all modes? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    reset_all_modes
                fi
                read -p "Press Enter to continue..."
                ;;
            q|Q)
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                log_error "Invalid option. Please try again."
                sleep 1
                ;;
        esac
    done
}

toggle_mode() {
    local choice="$1"
    local counter=1
    
    while IFS='|' read -r mode display_name default_state; do
        [[ -z "$mode" || "$mode" == \#* ]] && continue
        mode=$(echo "$mode" | xargs)
        
        if [[ "$counter" == "$choice" ]]; then
            local state=$(get_mode_state "$mode")
            local mode_lower=$(echo "$mode" | tr '[:upper:]' '[:lower:]')
            
            if [[ "$state" == "false" ]]; then
                "apply_${mode_lower}"
            else
                "disable_${mode_lower}"
            fi
            return
        fi
        ((counter++))
    done < "$CONFIG_FILE"
}

show_status() {
    clear
    show_banner
    
    echo -e "${YELLOW}System Status Report:${NC}\n"
    
    while IFS='|' read -r mode display_name default_state; do
        [[ -z "$mode" || "$mode" == \#* ]] && continue
        mode=$(echo "$mode" | xargs)
        display_name=$(echo "$display_name" | xargs)
        
        local state=$(get_mode_state "$mode")
        local status_symbol="${GREEN}ON${NC}"
        
        if [[ "$state" == "false" ]]; then
            status_symbol="${RED}OFF${NC}"
        fi
        
        printf "%-30s:  %b\n" "$display_name" "$status_symbol"
    done < "$CONFIG_FILE"
    
    echo ""
    echo -e "${YELLOW}Log File:${NC} $LOG_FILE"
    echo -e "${YELLOW}Config File:${NC} $CONFIG_FILE"
    echo ""
}

reset_all_modes() {
    log_info "Resetting all modes to default state..."
    
    while IFS='|' read -r mode display_name default_state; do
        [[ -z "$mode" || "$mode" == \#* ]] && continue
        mode=$(echo "$mode" | xargs)
        
        local current_state=$(get_mode_state "$mode")
        
        if [[ "$current_state" == "true" ]]; then
            local mode_lower=$(echo "$mode" | tr '[:upper:]' '[:lower:]')
            "disable_${mode_lower}"
            sleep 1
        fi
    done < "$CONFIG_FILE"
    
    log_success "All modes reset to default!"
}

###############################################################################
# CLI Functions
###############################################################################

cli_mode() {
    local cmd="$1"
    
    case "$cmd" in
        status)
            show_status
            ;;
        reset)
            reset_all_modes
            ;;
        on|enable)
            if [[ -z "${2:-}" ]]; then
                log_error "Usage: archmode on <mode>"
                exit 1
            fi
            local mode_lower=$(echo "$2" | tr '[:upper:]' '[:lower:]')
            "apply_${mode_lower}"
            ;;
        off|disable)
            if [[ -z "${2:-}" ]]; then
                log_error "Usage: archmode off <mode>"
                exit 1
            fi
            local mode_lower=$(echo "$2" | tr '[:upper:]' '[:lower:]')
            "disable_${mode_lower}"
            ;;
        list)
            echo "Available modes:"
            while IFS='|' read -r mode display_name default_state; do
                [[ -z "$mode" || "$mode" == \#* ]] && continue
                mode=$(echo "$mode" | xargs)
                display_name=$(echo "$display_name" | xargs)
                echo "  - $mode: $display_name"
            done < "$CONFIG_FILE"
            ;;
        help)
            show_help
            ;;
        *)
            log_error "Unknown command: $cmd"
            show_help
            exit 1
            ;;
    esac
}

show_help() {
    cat << EOF
${BLUE}ArchMode v1.1.0${NC} - System Mode Manager for Arch Linux

${YELLOW}Usage:${NC}
  archmode                         # Interactive menu
  archmode <command> [options]     # Command mode

${YELLOW}Commands:${NC}
  on|enable <mode>                 # Enable a specific mode
  off|disable <mode>               # Disable a specific mode
  status                           # Show current status of all modes
  list                             # List available modes
  reset                            # Reset all modes to default state
  help                             # Show this help message

${YELLOW}Available Modes:${NC}
  GAMEMODE        - Optimize system for gaming
  PRODUCTIVITY    - Maximize productivity
  POWERMODE       - Reduce power consumption
  QUIETMODE       - Reduce system noise
  DEVMODE         - Development optimizations

${YELLOW}Examples:${NC}
  archmode on GAMEMODE             # Enable gaming mode
  archmode off POWERMODE           # Disable power save mode
  archmode status                  # Show all mode statuses
  archmode reset                   # Reset everything to defaults

${YELLOW}Configuration:${NC}
  Config:   $CONFIG_FILE
  Logs:     $LOG_FILE

${YELLOW}For more information, visit:${NC}
  https://github.com/theofficalnoodles/archmode

EOF
}

###############################################################################
# Main Entry Point
###############################################################################

main() {
    # Initialize
    init_config
    check_requirements || exit 1
    
    # Check if running as root (we'll use sudo instead)
    if [[ "$EUID" == "0" ]]; then
        log_error "Please do not run ArchMode as root"
        exit 1
    fi
    
    # Route based on arguments
    if [[ $# -eq 0 ]]; then
        interactive_mode
    else
        cli_mode "$@"
    fi
}

# Run main
main "$@"
