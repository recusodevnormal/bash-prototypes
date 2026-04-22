#!/bin/bash
# Process Manager TUI - No external dependencies
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
processes=()
filter=""

# Get process list
get_processes() {
    processes=()
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            processes+=("$line")
        fi
    done < <(ps aux 2>/dev/null | tail -n +2)
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
    printf "${BOLD}${CYAN}║${RESET} ${BOLD}${YELLOW}Process Manager${RESET} ${BOLD}${CYAN}                                          ║${RESET}"
    move_cursor 3 1
    printf "${BOLD}${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"
    
    # Filter display
    move_cursor 4 1
    printf "${BOLD}${CYAN}║${RESET} ${GREEN}Filter:${RESET} ${filter:-none}"
    printf '\033[K'
    
    # Table header
    move_cursor 5 1
    printf "${BOLD}${CYAN}║${RESET} ${BOLD}${WHITE}PID  USER    %%CPU %%MEM  TIME     COMMAND${RESET}"
    printf '\033[K'
    
    move_cursor 6 1
    printf "${BOLD}${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"
    
    # Process list
    local line=7
    local display_idx=0
    
    for ((i=start_idx; i<${#processes[@]}; i++)); do
        if [ $line -ge $((LINES - 1)) ]; then
            break
        fi
        
        local proc="${processes[$i]}"
        
        # Apply filter
        if [ -n "$filter" ]; then
            if ! echo "$proc" | grep -qi "$filter"; then
                continue
            fi
        fi
        
        move_cursor $line 1
        printf "${BOLD}${CYAN}║${RESET} "
        
        if [ $i -eq $selected_index ]; then
            printf "${BOLD}${WHITE}> ${RESET}"
        else
            printf "  "
        fi
        
        # Format process line
        local pid=$(echo "$proc" | awk '{print $2}')
        local user=$(echo "$proc" | awk '{print $1}')
        local cpu=$(echo "$proc" | awk '{print $3}')
        local mem=$(echo "$proc" | awk '{print $4}')
        local time=$(echo "$proc" | awk '{print $10}')
        local cmd=$(echo "$proc" | awk '{for(i=11;i<=NF;i++) printf $i" "}')
        
        printf "%-5s %-8s %-4s %-4s %-8s " "$pid" "$user" "$cpu" "$mem" "$time"
        
        # Truncate command if too long
        local cmd_len=${#cmd}
        local max_cmd_len=$((COLUMNS - 45))
        if [ $cmd_len -gt $max_cmd_len ]; then
            printf "${cmd:0:$max_cmd_len}..."
        else
            printf "$cmd"
        fi
        
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
    printf "${BOLD}${CYAN}║${RESET} ${YELLOW}Arrows:${RESET} Move ${YELLOW}k:${RESET} Kill ${YELLOW}f:${RESET} Filter ${YELLOW}c:${RESET} Clear ${YELLOW}r:${RESET} Refresh ${YELLOW}q:${RESET} Quit"
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

# Kill process
kill_process() {
    local proc="${processes[$selected_index]}"
    local pid=$(echo "$proc" | awk '{print $2}')
    
    if [ -z "$pid" ]; then
        return
    fi
    
    clear_screen
    move_cursor 5 1
    printf "${RED}Kill process $pid? (y/n)${RESET}"
    local confirm
    read -r confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        kill "$pid" 2>/dev/null
        get_processes
        if [ $selected_index -ge ${#processes[@]} ]; then
            selected_index=$((${#processes[@]} - 1))
        fi
    fi
}

# Set filter
set_filter() {
    clear_screen
    move_cursor 5 1
    printf "${YELLOW}Enter filter (empty to clear):${RESET} "
    read -r filter
    get_processes
    selected_index=0
}

# Main loop
main() {
    get_processes
    
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
                if [ $selected_index -lt $((${#processes[@]} - 1)) ]; then
                    ((selected_index++))
                fi
                ;;
            "k")
                kill_process
                ;;
            "f")
                set_filter
                ;;
            "c")
                filter=""
                get_processes
                selected_index=0
                ;;
            "r")
                get_processes
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
