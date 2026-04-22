#!/bin/bash
# System Monitor TUI - No external dependencies
# Works with standard Alpine Linux busybox

# Terminal control
clear_screen() {
    printf '\033[2J\033[H'
}

move_cursor() {
    printf '\033[%d;%dH' "$1" "$2"
}

hide_cursor() {
    printf '\033[?25l'
}

show_cursor() {
    printf '\033[?25h'
}

# Colors
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
MAGENTA='\033[35m'
CYAN='\033[36m'
WHITE='\033[37m'
BOLD='\033[1m'
RESET='\033[0m'

# Get CPU usage
get_cpu_usage() {
    if [ -f /proc/stat ]; then
        local cpu_line=$(grep '^cpu ' /proc/stat)
        local cpu_values=($cpu_line)
        local idle=${cpu_values[4]}
        local total=0
        for val in "${cpu_values[@]:1}"; do
            total=$((total + val))
        done
        
        if [ -n "$prev_idle" ] && [ -n "$prev_total" ]; then
            local idle_diff=$((idle - prev_idle))
            local total_diff=$((total - prev_total))
            local cpu_usage=$((100 * (total_diff - idle_diff) / total_diff))
            echo "$cpu_usage"
        fi
        
        prev_idle=$idle
        prev_total=$total
    fi
    echo "0"
}

# Get memory info
get_memory_info() {
    if [ -f /proc/meminfo ]; then
        local mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        local mem_available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
        local mem_used=$((mem_total - mem_available))
        local mem_percent=$((mem_used * 100 / mem_total))
        
        echo "${mem_percent}%"
    else
        echo "N/A"
    fi
}

# Get uptime
get_uptime() {
    if [ -f /proc/uptime ]; then
        local uptime=$(cat /proc/uptime | awk '{print int($1)}')
        local days=$((uptime / 86400))
        local hours=$(( (uptime % 86400) / 3600 ))
        local minutes=$(( (uptime % 3600) / 60 ))
        printf "%dd %dh %dm" "$days" "$hours" "$minutes"
    else
        echo "N/A"
    fi
}

# Get load average
get_load_avg() {
    if [ -f /proc/loadavg ]; then
        cat /proc/loadavg | awk '{print $1, $2, $3}'
    else
        echo "N/A N/A N/A"
    fi
}

# Get temperature (if available)
get_temperature() {
    local temp="N/A"
    for zone in /sys/class/thermal/thermal_zone*/temp; do
        if [ -f "$zone" ]; then
            local t=$(cat "$zone" 2>/dev/null)
            if [ -n "$t" ] && [ "$t" != "0" ]; then
                temp=$((t / 1000))"°C"
                break
            fi
        fi
    done
    echo "$temp"
}

# Draw progress bar
draw_bar() {
    local percent=$1
    local width=30
    local filled=$((percent * width / 100))
    local empty=$((width - filled))
    
    printf "["
    for ((i=0; i<filled; i++)); do
        printf "${GREEN}#${RESET}"
    done
    for ((i=0; i<empty; i++)); do
        printf "-"
    done
    printf "] %3d%%" "$percent"
}

# Draw UI
draw_ui() {
    clear_screen
    
    # Header
    move_cursor 1 1
    printf "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${RESET}"
    move_cursor 2 1
    printf "${BOLD}${CYAN}║${RESET} ${BOLD}${YELLOW}System Monitor${RESET} ${BOLD}${CYAN}                                            ║${RESET}"
    move_cursor 3 1
    printf "${BOLD}${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"
    
    # System info
    move_cursor 5 3
    printf "${BOLD}${WHITE}Hostname:${RESET} $(hostname)"
    move_cursor 6 3
    printf "${BOLD}${WHITE}Uptime:${RESET}   $(get_uptime)"
    move_cursor 7 3
    printf "${BOLD}${WHITE}Load Avg:${RESET} $(get_load_avg)"
    move_cursor 8 3
    printf "${BOLD}${WHITE}Temp:${RESET}      $(get_temperature)"
    
    # Separator
    move_cursor 10 1
    printf "${BOLD}${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"
    
    # CPU
    move_cursor 12 3
    printf "${BOLD}${WHITE}CPU Usage:${RESET} "
    local cpu=$(get_cpu_usage)
    draw_bar "$cpu"
    
    # Memory
    move_cursor 14 3
    printf "${BOLD}${WHITE}Memory:${RESET}    "
    local mem=$(get_memory_info)
    local mem_num=${mem%\%}
    draw_bar "$mem_num"
    
    # Disk usage
    move_cursor 16 3
    printf "${BOLD}${WHITE}Disk (/):${RESET}   "
    local disk=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    draw_bar "$disk"
    
    # Separator
    move_cursor 18 1
    printf "${BOLD}${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"
    
    # Process count
    move_cursor 20 3
    printf "${BOLD}${WHITE}Processes:${RESET} $(ps | wc -l)"
    
    # Users
    move_cursor 21 3
    printf "${BOLD}${WHITE}Users:${RESET}     $(who | wc -l)"
    
    # Footer
    move_cursor $((LINES - 1)) 1
    printf "${BOLD}${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"
    move_cursor $LINES 1
    printf "${BOLD}${CYAN}║${RESET} ${YELLOW}Update: 1s${RESET} ${YELLOW}q:${RESET} Quit ${YELLOW}r:${RESET} Refresh"
    printf '\033[K'
}

# Read single key
read_key() {
    local key
    IFS= read -rsn1 -t 1 key
    if [ "$key" = $'\x1b' ]; then
        read -rsn2 -t 1 key
        case "$key" in
            '[A') echo "UP" ;;
            '[B') echo "DOWN" ;;
        esac
    else
        echo "$key"
    fi
}

# Main loop
main() {
    # Initialize CPU tracking
    prev_idle=""
    prev_total=""
    
    while true; do
        draw_ui
        local key
        key=$(read_key)
        
        case "$key" in
            "q")
                clear_screen
                show_cursor
                exit 0
                ;;
            "r")
                # Force refresh
                prev_idle=""
                prev_total=""
                ;;
        esac
    done
}

# Check terminal size
if [ -z "$LINES" ] || [ -z "$COLUMNS" ]; then
    printf "Error: Terminal size not detected. Please run in a proper terminal.\n"
    exit 1
fi

main
