#!/usr/bin/env bash
# =============================================================================
# Regex-Based Slot Filler (NER Lite)
# A lightweight, deterministic named entity recognizer for file commands
# Uses only standard GNU/Unix tools + Bash built-ins
#
# DEPENDENCIES: bash (>=4), sed, printf, read
#               All standard GNU/Unix utilities. No network access.
#
# USAGE:  chmod +x slot-filler-002.sh && ./slot-filler-002.sh
# =============================================================================

# ---------------------------------------------------------------------------
# STRICT MODE — catch errors early
# ---------------------------------------------------------------------------
set -euo pipefail
IFS=$'\n\t'

# Enable case-insensitive matching for regex
shopt -s nocasematch

# ----------------------------- Colors ----------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ----------------------------- Banner ----------------------------------------
print_banner() {
    printf "\n${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════╗
║        Regex Slot Filler (NER Lite)          ║
║          Deterministic Command Parser        ║
╚══════════════════════════════════════════════╝
EOF
    printf "${NC}\n"
}

# ----------------------------- Parsing Function ------------------------------
parse_input() {
    local input="$1"
    local cleaned action object dest

    # Remove polite prefixes and trim
    # Use sed -r for GNU sed compatibility, fallback to sed -E for BSD sed
    if sed --version >/dev/null 2>&1; then
        cleaned=$(printf '%s' "$input" | sed -r 's/^[[:space:]]*(please|can you|could you|would you|hey|ok|now)[[:space:]]+//i')
    else
        cleaned=$(printf '%s' "$input" | sed -E 's/^[[:space:]]*(please|can you|could you|would you|hey|ok|now)[[:space:]]+//i')
    fi
    cleaned=$(printf '%s' "$cleaned" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    action=""
    object=""
    dest=""

    # Move / Transfer patterns
    if [[ $cleaned =~ (move|mv|transfer|relocate|send)[[:space:]]+(.+)[[:space:]]+to[[:space:]]+(.+) ]]; then
        action="move"
        object="${BASH_REMATCH[2]}"
        dest="${BASH_REMATCH[3]}"

    # Copy patterns
    elif [[ $cleaned =~ (copy|cp)[[:space:]]+(.+)[[:space:]]+to[[:space:]]+(.+) ]]; then
        action="copy"
        object="${BASH_REMATCH[2]}"
        dest="${BASH_REMATCH[3]}"

    # Delete patterns
    elif [[ $cleaned =~ (delete|rm|remove|erase|del)[[:space:]]+(.+) ]]; then
        action="delete"
        object="${BASH_REMATCH[2]}"

    # Rename patterns
    elif [[ $cleaned =~ (rename|ren)[[:space:]]+(.+)[[:space:]]+to[[:space:]]+(.+) ]]; then
        action="rename"
        object="${BASH_REMATCH[2]}"
        dest="${BASH_REMATCH[3]}"
    fi

    # Final trim
    object=$(printf '%s' "$object" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    dest=$(printf '%s' "$dest" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    printf '%s|%s|%s' "$action" "$object" "$dest"
}

# ----------------------------- Main UI Loop ----------------------------------
main() {
    print_banner
    
    printf "${YELLOW}Type your command below (or 'exit' to quit)${NC}\n\n"

    while true; do
        printf "${BLUE}→${NC} "
        read -r input

        # Trim input
        input=$(printf '%s' "$input" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # Exit conditions
        if [[ -z "$input" ]]; then
            continue
        fi
        if [[ "$input" =~ ^(exit|quit|bye|q)$ ]]; then
            printf "\n${GREEN}Goodbye!${NC}\n\n"
            break
        fi

        # Input length validation
        if [[ ${#input} -gt 500 ]]; then
            printf "${RED}Error: Input too long (max 500 characters)${NC}\n\n"
            continue
        fi

        # Parse the command
        IFS='|' read -r action object dest <<< "$(parse_input "$input")"

        if [[ -n "$action" && -n "$object" ]]; then
            printf "\n${GREEN}✅ Successfully extracted slots:${NC}\n\n"
            printf "   ${PURPLE}Action${NC}      : %s\n" "$action"
            printf "   ${PURPLE}Object${NC}      : %s\n" "$object"
            
            if [[ -n "$dest" ]]; then
                printf "   ${PURPLE}Destination${NC} : %s\n" "$dest"
            fi

            printf "\n${YELLOW}Is this correct? (y/n): ${NC}"
            read -r confirm

            if [[ "$confirm" =~ ^[Yy] ]]; then
                printf "\n${GREEN}✓ Confirmed!${NC}\n"
                case "$action" in
                    move|copy)
                        printf "${CYAN}Would run:${NC} %s '%s' '%s'\n" "$action" "$object" "$dest"
                        ;;
                    delete)
                        printf "${CYAN}Would run:${NC} rm -f '%s'\n" "$object"
                        ;;
                    rename)
                        printf "${CYAN}Would run:${NC} mv '%s' '%s'\n" "$object" "$dest"
                        ;;
                esac
            else
                printf "${RED}✗ Let's try rephrasing it.${NC}\n"
            fi
        else
            printf "${RED}✗ Could not parse command.${NC}\n"
            printf "   Try examples:\n"
            printf "     • move backup.tar to /external/drive\n"
            printf "     • copy report.pdf to ~/Documents/\n"
            printf "     • delete old.log\n"
            printf "     • rename draft.txt to final.txt\n"
        fi

        printf "\n"
    done
}

# Run the program
main