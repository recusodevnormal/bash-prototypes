#!/usr/bin/env bash
# =============================================================================
# HFSM AI - Hierarchical Finite State Machine Demo
# A strictly branched conversation tree implemented in pure Bash
# Uses only standard GNU/Unix tools: printf, read, case, grep, etc.
# No external dependencies whatsoever.
# =============================================================================

set -uo pipefail

# ----------------------------- State Definitions -----------------------------
readonly STATE_INITIAL="INITIAL"
readonly STATE_MAIN="MAIN"
readonly STATE_GENERAL="GENERAL"
readonly STATE_TECHNICAL="TECHNICAL"
readonly STATE_DEBUG="DEBUG"
readonly STATE_EXIT="EXIT"

# Current state (this is the heart of the HFSM)
CURRENT_STATE="$STATE_INITIAL"

# ----------------------------- Helper Functions -----------------------------
clear_screen() {
    # Pure ANSI clear (works on virtually all terminals)
    printf '\033[2J\033[H'
}

print_header() {
    printf "╔══════════════════════════════════════════════════════════════╗\n"
    printf "║                 HFSM AI Assistant  v1.0                      ║\n"
    printf "║           Hierarchical Finite State Machine Demo             ║\n"
    printf "╚══════════════════════════════════════════════════════════════╝\n"
    printf "Current State → %s\n\n" "$CURRENT_STATE"
}

pause() {
    printf "\nPress Enter to continue..."
    read -r
}

# ----------------------------- Main Program Loop -----------------------------
while true; do
    clear_screen
    print_header

    case "$CURRENT_STATE" in
        # ====================== INITIAL STATE ======================
        "$STATE_INITIAL")
            printf "Welcome! This is a demonstration of a Hierarchical Finite\n"
            printf "State Machine (HFSM) implemented as a strictly branched\n"
            printf "conversation tree.\n\n"
            printf "The AI is always in exactly one state at any time.\n"
            printf "User input can only trigger valid transitions.\n\n"
            printf "Press Enter to begin...\n"
            read -r
            CURRENT_STATE="$STATE_MAIN"
            ;;

        # ====================== MAIN MENU STATE ======================
        "$STATE_MAIN")
            printf "Main Menu\n"
            printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            printf "1. General Conversation\n"
            printf "2. Technical Support\n"
            printf "3. Debug / State Inspector\n"
            printf "4. Exit\n\n"
            
            read -p "Choose (1-4): " choice
            
            case "$choice" in
                1) CURRENT_STATE="$STATE_GENERAL" ;;
                2) CURRENT_STATE="$STATE_TECHNICAL" ;;
                3) CURRENT_STATE="$STATE_DEBUG" ;;
                4|q|Q|exit|quit) CURRENT_STATE="$STATE_EXIT" ;;
                *) printf "Invalid selection.\n"; pause ;;
            esac
            ;;

        # ====================== GENERAL CONVERSATION STATE ======================
        "$STATE_GENERAL")
            printf "General Conversation Mode\n"
            printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            printf "You can ask me simple things. Type 'back' to return.\n\n"
            
            read -p "> " input
            
            # Global exit check
            if [[ "$input" =~ ^(quit|exit|q)$ ]]; then
                CURRENT_STATE="$STATE_EXIT"
            elif [[ "$input" =~ ^(back|menu|main)$ ]]; then
                CURRENT_STATE="$STATE_MAIN"
            elif echo "$input" | grep -qi "joke"; then
                printf "Why do programmers prefer dark mode? Because light attracts bugs.\n"
            elif echo "$input" | grep -qi "weather"; then
                printf "In the terminal, it's always 72°F with a light breeze of electrons.\n"
            elif echo "$input" | grep -qi "how are you"; then
                printf "I'm in state %s and fully operational.\n" "$CURRENT_STATE"
            else
                printf "Interesting. (This is a demo with limited responses)\n"
            fi
            
            [[ "$CURRENT_STATE" != "$STATE_EXIT" ]] && pause
            ;;

        # ====================== TECHNICAL SUPPORT STATE ======================
        "$STATE_TECHNICAL")
            printf "Technical Support Mode\n"
            printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            printf "1. Bash scripting tips\n"
            printf "2. Common Linux commands\n"
            printf "3. Back to Main Menu\n\n"
            
            read -p "Choose (1-3): " choice
            
            case "$choice" in
                1)
                    printf "Best practice: Always start scripts with:\n"
                    printf "set -uo pipefail\n"
                    printf "and use readonly for constants.\n"
                    ;;
                2)
                    printf "Useful commands:\n"
                    printf "  man <command>   - Read the manual\n"
                    printf "  grep -r 'text'  - Recursive search\n"
                    printf "  awk             - Text processing\n"
                    ;;
                3) CURRENT_STATE="$STATE_MAIN" ;;
                *) printf "Invalid option.\n" ;;
            esac
            
            [[ "$CURRENT_STATE" != "$STATE_EXIT" ]] && pause
            ;;

        # ====================== DEBUG / STATE INSPECTOR STATE ======================
        "$STATE_DEBUG")
            printf "DEBUG MODE - HFSM Inspector\n"
            printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            printf "Current State : %s\n" "$CURRENT_STATE"
            printf "Available States: INITIAL, MAIN, GENERAL, TECHNICAL, DEBUG, EXIT\n\n"
            printf "1. Force state to MAIN\n"
            printf "2. Force state to GENERAL\n"
            printf "3. Force state to TECHNICAL\n"
            printf "4. Return to Main Menu\n"
            printf "5. Exit\n\n"
            
            read -p "Debug action: " action
            
            case "$action" in
                1) CURRENT_STATE="$STATE_MAIN" ;;
                2) CURRENT_STATE="$STATE_GENERAL" ;;
                3) CURRENT_STATE="$STATE_TECHNICAL" ;;
                4) CURRENT_STATE="$STATE_MAIN" ;;
                5) CURRENT_STATE="$STATE_EXIT" ;;
                *) printf "Unknown debug command.\n" ;;
            esac
            
            [[ "$CURRENT_STATE" != "$STATE_EXIT" ]] && pause
            ;;

        # ====================== EXIT STATE ======================
        "$STATE_EXIT")
            break
            ;;

        # Fallback (should never happen in correct design)
        *)
            printf "Error: Unknown state '%s'. Resetting to MAIN.\n" "$CURRENT_STATE"
            CURRENT_STATE="$STATE_MAIN"
            ;;
    esac
done

# Final cleanup
clear_screen
printf "Thank you for exploring the Hierarchical Finite State Machine demo.\n"
printf "The AI has reached the EXIT state.\n\n"
printf "Script terminated cleanly.\n"