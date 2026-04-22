#!/bin/bash
# Disk Usage TUI - No external dependencies
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

# Global variables
selected_index=0
mount_points=()
disk_info=()

# Get disk info
get_disk_info() {
    mount_points=()
    disk_info=()
    
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            mount_points+=("$(echo "$line" | awk '{print $6}')")
            disk_info+=("$line")
        fi
    done < <(df -h 2>/dev/null | tail -n +2)
}

# Draw progress bar
draw_bar() {
    local percent=$1
    local width=20
    local filled=$((percent * width / 100))
    local empty=$((width - filled))
    
    local color="$GREEN"
    if [ $percent -gt 50 ]; then
        color="$YELLOW"
    fi
    if [ $percent -gt 80 ]; then
        color="$RED"
    fi
    
    printf "["
    for ((i=0; i<filled; i++)); do
        printf "${color}#${RESET}"
    done
    for ((i=0; i<empty; i++)); do
        printf "-"
    done
    printf "]"
}

# Draw UI
draw_ui() {
    clear_screen
    local max_lines=$((LINES - 5))
    local start_idx=0
    
    # Adjust start index for scrolling
    if [ $selected_index -ge $max_lines ]; then
        start_idx=$((selected_index - max_lines + 1))
    fi
    
    # Header
    move_cursor 1 1
    printf "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${RESET}"
    move_cursor 2 1
    printf "${BOLD}${CYAN}║${RESET} ${BOLD}${YELLOW}Disk Usage Analyzer${RESET} ${BOLD}${CYAN}                                       ║${RESET}"
    move_cursor 3 1
    printf "${BOLD}${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"
    
    # Table header
    move_cursor 4 1
    printf "${BOLD}${CYAN}║${RESET} ${BOLD}${WHITE}Filesystem      Size   Used   Avail  Use%  Mounted on${RESET}"
    printf '\033[K'
    
    move_cursor 5 1
    printf "${BOLD}${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"
    
    # Disk list
    local line=6
    local display_idx=0
    
    for ((i=start_idx; i<${#disk_info[@]}; i++)); do
        if [ $line -ge $((LINES - 1)) ]; then
            break
        fi
        
        local info="${disk_info[$i]}"
        local mount="${mount_points[$i]}"
        local fs=$(echo "$info" | awk '{print $1}')
        local size=$(echo "$info" | awk '{print $2}')
        local used=$(echo "$info" | awk '{print $3}')
        local avail=$(echo "$info" | awk '{print $4}')
        local use_percent=$(echo "$info" | awk '{print $5}' | sed 's/%//')
        
        move_cursor $line 1
        printf "${BOLD}${CYAN}║${RESET} "
        
        if [ $i -eq $selected_index ]; then
            printf "${BOLD}${WHITE}> ${RESET}"
        else
            printf "  "
        fi
        
        printf "%-15s %-6s %-6s %-6s " "$fs" "$size" "$used" "$avail"
        
        draw_bar "$use_percent"
        printf " %3s%%  %s" "$use_percent" "$mount"
        
        printf '\033[K'
        ((line++))
        ((display_idx++))
    done
    
    # Fill remaining lines
    while [ $line -lt $((LINES - 1)) ]; do
        move_cursor $line 1
        printf "${BOLD}${CYAN}║${RESET} "
        printf '\033[K'
        ((line++))
    done
    
    # Footer
    move_cursor $((LINES - 1)) 1
    printf "${BOLD}${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"
    move_cursor $LINES 1
    printf "${BOLD}${CYAN}║${RESET} ${YELLOW}Arrows:${RESET} Select ${YELLOW}d:${RESET} Du directory ${YELLOW}r:${RESET} Refresh ${YELLOW}q:${RESET} Quit"
    printf '\033[K'
}

# Read single key
read_key() {
    local key
    IFS= read -rsn1 key
    if [ "$key" = $'\x1b' ]; then
        read -rsn2 key
        case "$key" in
            '[A') echo "UP" ;;
            '[B') echo "DOWN" ;;
        esac
    else
        echo "$key"
    fi
}

# Analyze directory
analyze_directory() {
    local mount="${mount_points[$selected_index]}"
    
    if [ -z "$mount" ]; then
        return
    fi
    
    clear_screen
    move_cursor 5 1
    printf "${YELLOW}Analyzing: $mount${RESET}\n\n"
    
    du -sh "$mount"/* 2>/dev/null | sort -hr | head -20
    
    printf "\n\n${YELLOW}Press any key to continue...${RESET}"
    read -rsn1
}

# Main loop
main() {
    get_disk_info
    
    while true; do
        draw_ui
        hide_cursor
        local key
        key=$(read_key)
        show_cursor
        
        case "$key" in
            "UP")
                if [ $selected_index -gt 0 ]; then
                    ((selected_index--))
                fi
                ;;
            "DOWN")
                if [ $selected_index -lt $((${#disk_info[@]} - 1)) ]; then
                    ((selected_index++))
                fi
                ;;
            "d")
                analyze_directory
                ;;
            "r")
                get_disk_info
                ;;
            "q")
                clear_screen
                show_cursor
                exit 0
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
