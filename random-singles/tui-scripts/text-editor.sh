#!/bin/bash
# Text Editor TUI - No external dependencies
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
cursor_line=0
cursor_col=0
scroll_line=0
modified=false

# Load file
load_file() {
    lines=()
    if [ -f "$current_file" ]; then
        while IFS= read -r line; do
            lines+=("$line")
        done < "$current_file"
    fi
    if [ ${#lines[@]} -eq 0 ]; then
        lines+=("")
    fi
    cursor_line=0
    cursor_col=0
    scroll_line=0
    modified=false
}

# Save file
save_file() {
    if [ -z "$current_file" ]; then
        clear_screen
        move_cursor 5 1
        printf "${YELLOW}Enter filename to save:${RESET} "
        read -r current_file
    fi
    
    if [ -n "$current_file" ]; then
        printf "%s\n" "${lines[@]}" > "$current_file"
        modified=false
        clear_screen
        move_cursor 5 1
        printf "${GREEN}Saved to: $current_file${RESET}"
        sleep 1
    fi
}

# Draw UI
draw_ui() {
    clear_screen
    
    # Header
    move_cursor 1 1
    printf "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${RESET}"
    move_cursor 2 1
    printf "${BOLD}${CYAN}║${RESET} ${BOLD}${YELLOW}Text Editor${RESET} ${BOLD}${CYAN}                                                  ║${RESET}"
    move_cursor 3 1
    printf "${BOLD}${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"
    
    # File info
    move_cursor 4 1
    printf "${BOLD}${CYAN}║${RESET} ${GREEN}File:${RESET} ${current_file:-unsaved} ${GREEN}Lines:${RESET} ${#lines[@]} ${GREEN}Modified:${RESET} $([ "$modified" = true ] && echo "${YELLOW}Yes${RESET}" || echo "${GREEN}No${RESET}")"
    printf '\033[K'
    
    move_cursor 5 1
    printf "${BOLD}${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"
    
    # Content area
    local max_lines=$((LINES - 7))
    local line_num=6
    
    for ((i=scroll_line; i<${#lines[@]} && line_num<max_lines; i++)); do
        move_cursor $line_num 1
        printf "${BOLD}${CYAN}║${RESET} "
        
        local line="${lines[$i]}"
        local display_line="$line"
        
        # Highlight current line
        if [ $i -eq $cursor_line ]; then
            printf "${BOLD}${WHITE}"
        fi
        
        # Truncate if too long
        local max_len=$((COLUMNS - 4))
        if [ ${#display_line} -gt $max_len ]; then
            printf "%s" "${display_line:0:$max_len}"
        else
            printf "%s" "$display_line"
        fi
        
        printf "${RESET}"
        printf '\033[K'
        ((line_num++))
    done
    
    # Fill remaining lines
    while [ $line_num -lt $max_lines ]; do
        move_cursor $line_num 1
        printf "${BOLD}${CYAN}║${RESET} "
        printf '\033[K'
        ((line_num++))
    done
    
    # Footer
    move_cursor $((LINES - 1)) 1
    printf "${BOLD}${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"
    move_cursor $LINES 1
    printf "${BOLD}${CYAN}║${RESET} ${YELLOW}Arrows:${RESET} Move ${YELLOW}Enter:${RESET} New line ${YELLOW}Backspace:${RESET} Delete ${YELLOW}s:${RESET} Save ${YELLOW}o:${RESET} Open ${YELLOW}q:${RESET} Quit"
    printf '\033[K'
    
    # Position cursor
    local display_line=$((cursor_line - scroll_line + 6))
    local display_col=$((cursor_col + 3))
    move_cursor $display_line $display_col
    show_cursor
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

# Open file
open_file() {
    clear_screen
    move_cursor 5 1
    printf "${YELLOW}Enter filename to open:${RESET} "
    read -r path
    
    if [ -n "$path" ] && [ -f "$path" ]; then
        current_file="$path"
        load_file
    elif [ -n "$path" ]; then
        current_file="$path"
        lines=("")
        modified=true
    fi
}

# Insert character
insert_char() {
    local char="$1"
    local line="${lines[$cursor_line]}"
    lines[$cursor_line]="${line:0:$cursor_col}${char}${line:$cursor_col}"
    ((cursor_col++))
    modified=true
}

# Delete character
delete_char() {
    if [ $cursor_col -gt 0 ]; then
        local line="${lines[$cursor_line]}"
        lines[$cursor_line]="${line:0:$((cursor_col - 1))}${line:$cursor_col}"
        ((cursor_col--))
        modified=true
    elif [ $cursor_line -gt 0 ]; then
        # Join with previous line
        local prev_line="${lines[$((cursor_line - 1))]}"
        local curr_line="${lines[$cursor_line]}"
        lines[$((cursor_line - 1))]="${prev_line}${curr_line}"
        unset "lines[$cursor_line]"
        lines=("${lines[@]}")
        ((cursor_line--))
        cursor_col=${#prev_line}
        modified=true
    fi
}

# New line
new_line() {
    local line="${lines[$cursor_line]}"
    local before="${line:0:$cursor_col}"
    local after="${line:$cursor_col}"
    
    lines[$cursor_line]="$before"
    lines=("${lines[@]:0:$((cursor_line + 1))}" "$after" "${lines[@]:$((cursor_line + 1))}")
    
    ((cursor_line++))
    cursor_col=0
    modified=true
}

# Main loop
main() {
    while true; do
        draw_ui
        local key
        key=$(read_key)
        hide_cursor
        
        case "$key" in
            "UP")
                if [ $cursor_line -gt 0 ]; then
                    ((cursor_line--))
                    local line_len=${#lines[$cursor_line]}
                    if [ $cursor_col -gt $line_len ]; then
                        cursor_col=$line_len
                    fi
                fi
                ;;
            "DOWN")
                if [ $cursor_line -lt $((${#lines[@]} - 1)) ]; then
                    ((cursor_line++))
                    local line_len=${#lines[$cursor_line]}
                    if [ $cursor_col -gt $line_len ]; then
                        cursor_col=$line_len
                    fi
                fi
                ;;
            "LEFT")
                if [ $cursor_col -gt 0 ]; then
                    ((cursor_col--))
                fi
                ;;
            "RIGHT")
                local line_len=${#lines[$cursor_line]}
                if [ $cursor_col -lt $line_len ]; then
                    ((cursor_col++))
                fi
                ;;
            "")
                new_line
                ;;
            $'\x7f')
                delete_char
                ;;
            "s")
                save_file
                ;;
            "o")
                open_file
                ;;
            "q")
                if [ "$modified" = true ]; then
                    clear_screen
                    move_cursor 5 1
                    printf "${YELLOW}Unsaved changes. Quit anyway? (y/n)${RESET}"
                    local confirm
                    read -r confirm
                    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
                        continue
                    fi
                fi
                clear_screen
                show_cursor
                exit 0
                ;;
            *)
                if [ ${#key} -eq 1 ] && [ "$key" != $'\x1b' ]; then
                    insert_char "$key"
                fi
                ;;
        esac
        
        # Adjust scroll
        local max_lines=$((LINES - 7))
        if [ $cursor_line -lt $scroll_line ]; then
            scroll_line=$cursor_line
        elif [ $cursor_line -ge $((scroll_line + max_lines)) ]; then
            scroll_line=$((cursor_line - max_lines + 1))
        fi
    done
}

# Check terminal size
if [ -z "$LINES" ] || [ -z "$COLUMNS" ]; then
    printf "Error: Terminal size not detected. Please run in a proper terminal.\n"
    exit 1
fi

# Check for file argument
if [ -n "$1" ]; then
    current_file="$1"
    load_file
fi

main
