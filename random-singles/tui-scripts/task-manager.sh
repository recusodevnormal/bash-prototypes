#!/bin/bash
# Task Manager TUI - No external dependencies
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
tasks=()
task_file="$HOME/.tui-tasks.txt"

# Load tasks
load_tasks() {
    tasks=()
    if [ -f "$task_file" ]; then
        while IFS='|' read -r status description; do
            tasks+=("$status|$description")
        done < "$task_file"
    fi
}

# Save tasks
save_tasks() {
    printf "%s\n" "${tasks[@]}" > "$task_file"
}

# Add task
add_task() {
    clear_screen
    move_cursor 5 1
    printf "${YELLOW}Enter task description:${RESET} "
    read -r description
    
    if [ -n "$description" ]; then
        tasks+=("0|$description")
        save_tasks
    fi
}

# Toggle task
toggle_task() {
    if [ $selected_index -ge 0 ] && [ $selected_index -lt ${#tasks[@]} ]; then
        local task="${tasks[$selected_index]}"
        local status="${task%%|*}"
        local description="${task#*|}"
        
        if [ "$status" = "0" ]; then
            tasks[$selected_index]="1|$description"
        else
            tasks[$selected_index]="0|$description"
        fi
        save_tasks
    fi
}

# Delete task
delete_task() {
    if [ $selected_index -ge 0 ] && [ $selected_index -lt ${#tasks[@]} ]; then
        clear_screen
        move_cursor 5 1
        printf "${RED}Delete task? (y/n)${RESET}"
        local confirm
        read -r confirm
        
        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            unset "tasks[$selected_index]"
            tasks=("${tasks[@]}")
            if [ $selected_index -ge ${#tasks[@]} ]; then
                selected_index=$((${#tasks[@]} - 1))
            fi
            save_tasks
        fi
    fi
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
    printf "${BOLD}${CYAN}║${RESET} ${BOLD}${YELLOW}Task Manager${RESET} ${BOLD}${CYAN}                                               ║${RESET}"
    move_cursor 3 1
    printf "${BOLD}${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"
    
    # Stats
    local total=${#tasks[@]}
    local completed=0
    for task in "${tasks[@]}"; do
        local status="${task%%|*}"
        if [ "$status" = "1" ]; then
            ((completed++))
        fi
    done
    local pending=$((total - completed))
    
    move_cursor 4 1
    printf "${BOLD}${CYAN}║${RESET} ${GREEN}Total:${RESET} $total ${GREEN}Done:${RESET} $completed ${GREEN}Pending:${RESET} $pending"
    printf '\033[K'
    
    move_cursor 5 1
    printf "${BOLD}${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"
    
    # Task list
    local line=6
    local display_idx=0
    
    for ((i=start_idx; i<${#tasks[@]}; i++)); do
        if [ $line -ge $((LINES - 1)) ]; then
            break
        fi
        
        local task="${tasks[$i]}"
        local status="${task%%|*}"
        local description="${task#*|}"
        
        move_cursor $line 1
        printf "${BOLD}${CYAN}║${RESET} "
        
        if [ $i -eq $selected_index ]; then
            printf "${BOLD}${WHITE}>${RESET} "
        else
            printf "  "
        fi
        
        if [ "$status" = "1" ]; then
            printf "${GREEN}[X]${RESET} "
        else
            printf "${YELLOW}[ ]${RESET} "
        fi
        
        printf "$description"
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
    printf "${BOLD}${CYAN}║${RESET} ${YELLOW}Arrows:${RESET} Move ${YELLOW}Space:${RESET} Toggle ${YELLOW}a:${RESET} Add ${YELLOW}d:${RESET} Delete ${YELLOW}q:${RESET} Quit"
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

# Main loop
main() {
    load_tasks
    
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
                if [ $selected_index -lt $((${#tasks[@]} - 1)) ]; then
                    ((selected_index++))
                fi
                ;;
            " ")
                toggle_task
                ;;
            "a")
                add_task
                ;;
            "d")
                delete_task
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
