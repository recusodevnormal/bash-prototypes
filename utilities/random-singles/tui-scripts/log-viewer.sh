#!/bin/bash
# Log Viewer TUI - No external dependencies
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
current_file=""
lines=()
scroll_offset=0
line_count=0
follow_mode=false

# Common log files
log_files=(
    "/var/log/messages"
    "/var/log/syslog"
    "/var/log/auth.log"
    "/var/log/kern.log"
    "/var/log/dmesg"
)

# Get available log files
get_available_logs() {
    local available=()
    for log in "${log_files[@]}"; do
        if [ -f "$log" ]; then
            available+=("$log")
        fi
    done
    echo "${available[@]}"
}

# Load file
load_file() {
    if [ ! -f "$current_file" ]; then
        return 1
    fi
    
    lines=()
    while IFS= read -r line; do
        lines+=("$line")
    done < "$current_file"
    
    line_count=${#lines[@]}
    scroll_offset=0
}

# Highlight log levels
highlight_line() {
    local line="$1"
    local highlighted="$line"
    
    # Colorize common log levels
    if echo "$line" | grep -qi "error"; then
        highlighted=$(echo "$line" | sed 's/\([Ee][Rr][Rr][Oo][Rr]\)/'"${RED}"'\1'"${RESET}"'/g')
    fi
    if echo "$line" | grep -qi "warn"; then
        highlighted=$(echo "$highlighted" | sed 's/\([Ww][Aa][Rr][Nn]\)/'"${YELLOW}"'\1'"${RESET}"'/g')
    fi
    if echo "$line" | grep -qi "info"; then
        highlighted=$(echo "$highlighted" | sed 's/\([Ii][Nn][Ff][Oo]\)/'"${GREEN}"'\1'"${RESET}"'/g')
    fi
    if echo "$line" | grep -qi "debug"; then
        highlighted=$(echo "$highlighted" | sed 's/\([Dd][Ee][Bb][Uu][Gg]\)/'"${CYAN}"'\1'"${RESET}"'/g')
    fi
    if echo "$line" | grep -qi "fatal"; then
        highlighted=$(echo "$highlighted" | sed 's/\([Ff][Aa][Tt][Aa][Ll]\)/'"${RED}${BOLD}"'\1'"${RESET}"'/g')
    fi
    
    echo "$highlighted"
}

# Draw UI
draw_ui() {
    clear_screen
    
    # Header
    move_cursor 1 1
    printf "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${RESET}"
    move_cursor 2 1
    printf "${BOLD}${CYAN}║${RESET} ${BOLD}${YELLOW}Log Viewer${RESET} ${BOLD}${CYAN}                                              ║${RESET}"
    move_cursor 3 1
    printf "${BOLD}${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"
    
    # File info
    move_cursor 4 1
    printf "${BOLD}${CYAN}║${RESET} ${GREEN}File:${RESET} ${current_file:-none}"
    printf '\033[K'
    
    move_cursor 5 1
    printf "${BOLD}${CYAN}║${RESET} ${GREEN}Lines:${RESET} $line_count ${GREEN}Follow:${RESET} $([ "$follow_mode" = true ] && echo "${GREEN}ON${RESET}" || echo "${RED}OFF${RESET}")"
    printf '\033[K'
    
    move_cursor 6 1
    printf "${BOLD}${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"
    
    # Content
    local max_lines=$((LINES - 8))
    local line_num=7
    
    for ((i=scroll_offset; i<line_count && line_num<max_lines; i++)); do
        move_cursor $line_num 1
        printf "${BOLD}${CYAN}║${RESET} "
        
        local line="${lines[$i]}"
        local highlighted=$(highlight_line "$line")
        
        # Truncate if too long
        local max_len=$((COLUMNS - 3))
        if [ ${#highlighted} -gt $max_len ]; then
            printf "%s..." "${highlighted:0:$((max_len - 3))}"
        else
            printf "%s" "$highlighted"
        fi
        
        printf '\033[K'
        ((line_num++))
    done
    
    # Fill remaining lines
    while [ $line_num -lt $((LINES - 1)) ]; do
        move_cursor $line_num 1
        printf "${BOLD}${CYAN}║${RESET} "
        printf '\033[K'
        ((line_num++))
    done
    
    # Footer
    move_cursor $((LINES - 1)) 1
    printf "${BOLD}${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"
    move_cursor $LINES 1
    printf "${BOLD}${CYAN}║${RESET} ${YELLOW}Arrows:${RESET} Scroll ${YELLOW}o:${RESET} Open ${YELLOW}f:${RESET} Follow ${YELLOW}r:${RESET} Refresh ${YELLOW}/:${RESET} Search ${YELLOW}q:${RESET} Quit"
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
            '[5~') echo "PGUP" ;;
            '[6~') echo "PGDN" ;;
        esac
    else
        echo "$key"
    fi
}

# Open file
open_file() {
    clear_screen
    move_cursor 5 1
    printf "${YELLOW}Enter file path:${RESET} "
    read -r path
    
    if [ -n "$path" ] && [ -f "$path" ]; then
        current_file="$path"
        load_file
    else
        move_cursor 7 1
        printf "${RED}File not found${RESET}"
        sleep 1
    fi
}

# Select from available logs
select_log() {
    local available=($(get_available_logs))
    
    if [ ${#available[@]} -eq 0 ]; then
        clear_screen
        move_cursor 5 1
        printf "${RED}No common log files found${RESET}"
        sleep 2
        return
    fi
    
    clear_screen
    move_cursor 5 1
    printf "${YELLOW}Select log file:${RESET}\n"
    
    local i=1
    for log in "${available[@]}"; do
        printf "  %d) %s\n" "$i" "$log"
        ((i++))
    done
    
    printf "\n${YELLOW}Enter number:${RESET} "
    read -r choice
    
    if [ "$choice" -ge 1 ] && [ "$choice" -le ${#available[@]} ]; then
        current_file="${available[$((choice - 1))]}"
        load_file
    fi
}

# Search in log
search_log() {
    clear_screen
    move_cursor 5 1
    printf "${YELLOW}Enter search term:${RESET} "
    read -r term
    
    if [ -z "$term" ]; then
        return
    fi
    
    local found=0
    for ((i=0; i<line_count; i++)); do
        if echo "${lines[$i]}" | grep -qi "$term"; then
            scroll_offset=$i
            found=1
            break
        fi
    done
    
    if [ $found -eq 0 ]; then
        clear_screen
        move_cursor 7 1
        printf "${RED}Not found: $term${RESET}"
        sleep 1
    fi
}

# Main loop
main() {
    # Try to open first available log
    local available=($(get_available_logs))
    if [ ${#available[@]} -gt 0 ]; then
        current_file="${available[0]}"
        load_file
    fi
    
    while true; do
        draw_ui
        hide_cursor
        local key
        key=$(read_key)
        show_cursor
        
        case "$key" in
            "UP")
                if [ $scroll_offset -gt 0 ]; then
                    ((scroll_offset--))
                fi
                ;;
            "DOWN")
                if [ $scroll_offset -lt $((line_count - 1)) ]; then
                    ((scroll_offset++))
                fi
                ;;
            "PGUP")
                scroll_offset=$((scroll_offset - 20))
                if [ $scroll_offset -lt 0 ]; then
                    scroll_offset=0
                fi
                ;;
            "PGDN")
                scroll_offset=$((scroll_offset + 20))
                if [ $scroll_offset -gt $((line_count - 1)) ]; then
                    scroll_offset=$((line_count - 1))
                fi
                ;;
            "o")
                open_file
                ;;
            "f")
                if [ "$follow_mode" = true ]; then
                    follow_mode=false
                else
                    follow_mode=true
                fi
                ;;
            "r")
                load_file
                ;;
            "/")
                search_log
                ;;
            "l")
                select_log
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
