#!/usr/bin/env bash

# ==============================================================================
# Hierarchical Finite State Machine (HFSM) - Interactive Terminal UI
# ==============================================================================
# Description:
#   A strictly branched conversation tree simulating an AI assistant. The script
#   uses a nested case statement inside a while loop to manage state transitions.
#   States are hierarchical (child states remember their parent state).
#
# Constraints:
#   - Runs completely offline.
#   - Uses only standard GNU/Unix utilities (printf, read, tr, df, ping).
#   - No external dependencies (no bash frameworks, no Python, no curl).
#
# Usage:
#   chmod +x hfsm_ai.sh
#   ./hfsm_ai.sh
# ==============================================================================

# ------------------------------------------------------------------------------
# Strict Mode & Safety
# ------------------------------------------------------------------------------
set -u          # Exit on attempt to use uninitialized variables
set -o pipefail # Return value of a pipeline is the status of the last command to exit with a non-zero status

# ------------------------------------------------------------------------------
# UI Color Definitions (ANSI Escape Codes)
# ------------------------------------------------------------------------------
readonly RESET='\033[0m'
readonly BOLD='\033[1m'
readonly CYAN='\033[0;36m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly DIM='\033[2m'

# ------------------------------------------------------------------------------
# State Variables
# ------------------------------------------------------------------------------
# The primary state tracker, dictating which node of the conversation tree we are in.
CURRENT_STATE="STATE_INITIAL"

# Tracks the parent state to allow hierarchical "back" navigation.
STATE_PARENT="STATE_INITIAL"

# ------------------------------------------------------------------------------
# UI Helper Functions
# ------------------------------------------------------------------------------

# Prints a horizontal divider to separate UI elements
draw_divider() {
    printf "${DIM}%s${RESET}\n" "$(printf '─%.0s' {1..50})"
}

# Displays the main prompt and captures user input
# Usage: prompt_input "Your prompt here"
prompt_input() {
    local prompt_text="${1:-">"}"
    printf "\n${BOLD}${GREEN}%s ${RESET}" "$prompt_text"
    read -r USER_INPUT
}

# Prints a formatted system/AI message
ai_say() {
    local message="$1"
    printf "\n${CYAN}[AI]${RESET} %s\n" "$message"
}

# Prints an error message for invalid inputs
ai_error() {
    local message="$1"
    printf "\n${RED}[ERROR]${RESET} %s\n" "$message"
}

# Clears the screen and draws the header
draw_header() {
    clear
    printf "${BOLD}${CYAN}╔══════════════════════════════════════════╗\n"
    printf "║       HFSM Terminal Assistant v1.0       ║\n"
    printf "╚══════════════════════════════════════════╝${RESET}\n"
    draw_divider
}

# ------------------------------------------------------------------------------
# Main HFSM Engine
# ------------------------------------------------------------------------------
main() {
    # Infinite loop to keep the state machine running
    while true; do
        # The core case statement evaluating the current state
        case "$CURRENT_STATE" in

            # =========================================================================
            # STATE: INITIAL
            # =========================================================================
            # The entry point of the HFSM. Auto-transitions to the main menu.
            STATE_INITIAL)
                draw_header
                ai_say "System initialized. Welcome to the Hierarchical Finite State Machine."
                ai_say "Navigating strictly branched conversation tree..."
                CURRENT_STATE="STATE_MENU"
                ;;

            # =========================================================================
            # STATE: MENU (Root Level)
            # =========================================================================
            STATE_MENU)
                STATE_PARENT="STATE_MENU"
                draw_divider
                printf "${YELLOW}[ Main Menu ]${RESET}\n"
                printf "  1) System Diagnostics\n"
                printf "  2) General Chitchat\n"
                printf "  3) Exit System\n"
                draw_divider

                prompt_input "Select an option (1-3):"

                case "$USER_INPUT" in
                    1) CURRENT_STATE="STATE_DIAGNOSTICS" ;;
                    2) CURRENT_STATE="STATE_CHITCHAT" ;;
                    3) CURRENT_STATE="STATE_EXIT" ;;
                    *) ai_error "Invalid selection. Please choose 1, 2, or 3." ;;
                esac
                ;;

            # =========================================================================
            # STATE: DIAGNOSTICS (Child of MENU - Level 2)
            # =========================================================================
            STATE_DIAGNOSTICS)
                STATE_PARENT="STATE_MENU"
                draw_divider
                printf "${YELLOW}[ Diagnostics Menu ]${RESET}\n"
                printf "  1) Check Network Connectivity\n"
                printf "  2) Check Disk Space\n"
                printf "  3) Back to Main Menu\n"
                draw_divider

                prompt_input "Select a diagnostic (1-3):"

                case "$USER_INPUT" in
                    1) CURRENT_STATE="STATE_DIAG_NETWORK" ;;
                    2) CURRENT_STATE="STATE_DIAG_DISK" ;;
                    3) CURRENT_STATE="$STATE_PARENT" ;;
                    *) ai_error "Invalid selection. Please choose 1, 2, or 3." ;;
                esac
                ;;

            # =========================================================================
            # STATE: DIAG_NETWORK (Child of DIAGNOSTICS - Level 3)
            # =========================================================================
            STATE_DIAG_NETWORK)
                STATE_PARENT="STATE_DIAGNOSTICS"
                draw_divider
                printf "${YELLOW}[ Network Diagnostics ]${RESET}\n"
                printf "  1) Ping localhost (127.0.0.1)\n"
                printf "  2) Back to Diagnostics Menu\n"
                draw_divider

                prompt_input "Select an action (1-2):"

                case "$USER_INPUT" in
                    1)
                        ai_say "Running ping test (1 packet)..."
                        # Standard Unix ping, capturing output cleanly
                        if ping -c 1 127.0.0.1 > /dev/null 2>&1; then
                            ai_say "Success: Localhost is responding to network requests."
                        else
                            ai_error "Failure: Localhost did not respond. Network stack might be down."
                        fi
                        # Remain in STATE_DIAG_NETWORK (loop back to self)
                        CURRENT_STATE="STATE_DIAG_NETWORK"
                        ;;
                    2) CURRENT_STATE="$STATE_PARENT" ;;
                    *) ai_error "Invalid selection." ;;
                esac
                ;;

            # =========================================================================
            # STATE: DIAG_DISK (Child of DIAGNOSTICS - Level 3)
            # =========================================================================
            STATE_DIAG_DISK)
                STATE_PARENT="STATE_DIAGNOSTICS"
                draw_divider
                printf "${YELLOW}[ Disk Diagnostics ]${RESET}\n"
                printf "  1) Show current disk usage\n"
                printf "  2) Back to Diagnostics Menu\n"
                draw_divider

                prompt_input "Select an action (1-2):"

                case "$USER_INPUT" in
                    1)
                        ai_say "Fetching disk usage for current mount..."
                        # Standard Unix df, formatted cleanly
                        df -h . | awk 'NR==1 {printf "%-20s %10s %10s\n", $1, $2, $4} NR==2 {printf "%-20s %10s %10s\n", $1, $2, $4}'
                        # Remain in STATE_DIAG_DISK
                        CURRENT_STATE="STATE_DIAG_DISK"
                        ;;
                    2) CURRENT_STATE="$STATE_PARENT" ;;
                    *) ai_error "Invalid selection." ;;
                esac
                ;;

            # =========================================================================
            # STATE: CHITCHAT (Child of MENU - Level 2)
            # =========================================================================
            STATE_CHITCHAT)
                STATE_PARENT="STATE_MENU"
                draw_divider
                printf "${YELLOW}[ Chitchat Module ]${RESET}\n"
                printf "  1) How are you feeling?\n"
                printf "  2) Tell me a joke\n"
                printf "  3) Back to Main Menu\n"
                draw_divider

                prompt_input "Choose a topic (1-3):"

                case "$USER_INPUT" in
                    1)
                        ai_say "I am a finite state machine. I feel... deterministic."
                        # Remain in STATE_CHITCHAT
                        CURRENT_STATE="STATE_CHITCHAT"
                        ;;
                    2)
                        ai_say "Why did the programmer quit his job?"
                        sleep 1
                        ai_say "Because he didn't get arrays. (Get it? 'A raise')"
                        CURRENT_STATE="STATE_CHITCHAT"
                        ;;
                    3) CURRENT_STATE="$STATE_PARENT" ;;
                    *) ai_error "Invalid selection." ;;
                esac
                ;;

            # =========================================================================
            # STATE: EXIT
            # =========================================================================
            STATE_EXIT)
                draw_header
                ai_say "Shutting down HFSM. Goodbye!"
                printf "\n"
                exit 0
                ;;

            # =========================================================================
            # FALLBACK
            # =========================================================================
            *)
                ai_error "FATAL: Undefined state reached ($CURRENT_STATE). Resetting."
                CURRENT_STATE="STATE_INITIAL"
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# Entry Point
# ------------------------------------------------------------------------------
# Call the main function to start the state machine
main