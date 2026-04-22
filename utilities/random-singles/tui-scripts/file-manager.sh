#!/bin/bash
# File Manager TUI - No external dependencies
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
current_dir="${PWD}"
selected_index=0
items=()
file_types=()

# Get file list
get_files() {
    items=()
    file_types=()
    
    # Add parent directory if not root
    if [ "$current_dir" != "/" ]; then
        items+=("..")
        file_types+=("dir")
    fi
    
    # List directories first
    while IFS= read -r -d '' item; do
        items+=("$(basename "$item")")
        file_types+=("dir")
    done < <(find "$current_dir" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)
    
    # Then files
    while IFS= read -r -d '' item; do
        items+=("$(basename "$item")")
        file_types+=("file")
    done < <(find "$current_dir" -mindepth 1 -maxdepth 1 -type f -print0 2>/dev/null | sort -z)
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
    printf "${BOLD}${CYAN}║${RESET} ${BOLD}${YELLOW}File Manager${RESET} ${BOLD}${CYAN}                                           ║${RESET}"
    move_cursor 3 1
    printf "${BOLD}${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"
    
    # Current path
    move_cursor 4 1
    printf "${BOLD}${CYAN}║${RESET} ${GREEN}Path:${RESET} ${current_dir}"
    printf '\033[K'
    
    # File list
    local line=5
    local display_idx=0
    
    for ((i=start_idx; i<${#items[@]}; i++)); do
        if [ $line -ge $((LINES - 1)) ]; then
            break
        fi
        
        move_cursor $line 1
        printf "${BOLD}${CYAN}║${RESET} "
        
        if [ $i -eq $selected_index ]; then
            printf "${BOLD}${WHITE}> ${RESET}"
        else
            printf "  "
        fi
        
        local item="${items[$i]}"
        local type="${file_types[$i]}"
        
        if [ "$type" = "dir" ]; then
            printf "${BLUE}${BOLD}${item}/${RESET}"
        else
            printf "${WHITE}${item}${RESET}"
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
    printf "${BOLD}${CYAN}║${RESET} ${YELLOW}Arrows:${RESET} Move ${YELLOW}Enter:${RESET} Open ${YELLOW}q:${RESET} Quit ${YELLOW}d:${RESET} Delete ${YELLOW}m:${RESET} mkdir ${YELLOW}t:${RESET} touch"
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
            '[C') echo "RIGHT" ;;
            '[D') echo "LEFT" ;;
        esac
    else
        echo "$key"
    fi
}

# Navigate
navigate() {
    local item="${items[$selected_index]}"
    local type="${file_types[$selected_index]}"
    local path="${current_dir}/${item}"
    
    if [ "$type" = "dir" ]; then
        if [ "$item" = ".." ]; then
            current_dir="$(dirname "$current_dir")"
        else
            current_dir="$path"
        fi
        selected_index=0
        get_files
    fi
}

# Delete file/directory
delete_item() {
    local item="${items[$selected_index]}"
    local type="${file_types[$selected_index]}"
    local path="${current_dir}/${item}"
    
    if [ "$item" = ".." ]; then
        return
    fi
    
    clear_screen
    move_cursor 5 1
    printf "${RED}Delete: ${item}? (y/n)${RESET}"
    local confirm
    read -r confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        if [ "$type" = "dir" ]; then
            rm -rf "$path"
        else
            rm -f "$path"
        fi
        get_files
        if [ $selected_index -ge ${#items[@]} ]; then
            selected_index=$((${#items[@]} - 1))
        fi
    fi
}

# Create directory
create_dir() {
    clear_screen
    move_cursor 5 1
    printf "${YELLOW}Enter directory name:${RESET} "
    local name
    read -r name
    
    if [ -n "$name" ]; then
        mkdir -p "${current_dir}/${name}"
        get_files
    fi
}

# Create file
create_file() {
    clear_screen
    move_cursor 5 1
    printf "${YELLOW}Enter file name:${RESET} "
    local name
    read -r name
    
    if [ -n "$name" ]; then
        touch "${current_dir}/${name}"
        get_files
    fi
}

# View file
view_file() {
    local item="${items[$selected_index]}"
    local type="${file_types[$selected_index]}"
    local path="${current_dir}/${item}"
    
    if [ "$type" = "file" ]; then
        clear_screen
        move_cursor 1 1
        printf "${BOLD}${CYAN}Viewing: ${item}${RESET}\n\n"
        cat "$path" 2>/dev/null || printf "${RED}Cannot read file${RESET}"
        printf "\n\n${YELLOW}Press any key to continue...${RESET}"
        read -rsn1
    fi
}

# Main loop
main() {
    get_files
    
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
                if [ $selected_index -lt $((${#items[@]} - 1)) ]; then
                    ((selected_index++))
                fi
                ;;
            "")
                navigate
                ;;
            "q")
                clear_screen
                show_cursor
                exit 0
                ;;
            "d")
                delete_item
                ;;
            "m")
                create_dir
                ;;
            "t")
                create_file
                ;;
            "v")
                view_file
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
