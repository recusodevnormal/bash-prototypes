#!/usr/bin/env bash

################################################################################
# Sentiment-Regex Mood Loop
# A real-time sentiment analyzer that monitors stdin or a log file
# and adjusts its mood/persona based on positive vs negative tokens
#
# Usage:
#   ./mood_loop.sh                    # Interactive mode (type messages)
#   ./mood_loop.sh <logfile>          # Monitor existing log file
#   tail -f app.log | ./mood_loop.sh  # Pipe from stream
################################################################################

set -o pipefail

################################################################################
# CONFIGURATION
################################################################################

# Negative keywords (lowercase for case-insensitive matching)
NEGATIVE_WORDS=(
    "fail" "failed" "failure" "error" "broken" "crash" "crashed"
    "bug" "issue" "problem" "wrong" "bad" "terrible" "worst"
    "down" "timeout" "denied" "reject" "rejected" "critical"
    "warning" "exception" "panic" "dead" "stuck" "slow"
)

# Positive keywords (lowercase for case-insensitive matching)
POSITIVE_WORDS=(
    "success" "successful" "fixed" "resolved" "working" "thanks"
    "great" "good" "excellent" "perfect" "awesome" "improved"
    "fast" "better" "complete" "completed" "happy" "love"
    "win" "won" "achievement" "healthy" "up" "stable"
)

# Mood thresholds
MOOD_MIN=-10
MOOD_MAX=10
MOOD_CURRENT=0

# Update interval for file monitoring (seconds)
UPDATE_INTERVAL=1

################################################################################
# COLOR CODES
################################################################################

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

################################################################################
# UI FUNCTIONS
################################################################################

# Clear screen and reset cursor
clear_screen() {
    clear
}

# Draw header based on current mood
draw_header() {
    local mood=$1
    local color persona emoji status
    
    if [ "$mood" -le -5 ]; then
        color="$RED"
        persona="CRITICAL-BOT"
        emoji="😡"
        status="HIGHLY NEGATIVE"
    elif [ "$mood" -lt 0 ]; then
        color="$YELLOW"
        persona="Warning-Bot"
        emoji="😟"
        status="Somewhat Negative"
    elif [ "$mood" -eq 0 ]; then
        color="$CYAN"
        persona="Neutral-Bot"
        emoji="😐"
        status="Neutral"
    elif [ "$mood" -le 5 ]; then
        color="$BLUE"
        persona="Helper-Bot"
        emoji="🙂"
        status="Somewhat Positive"
    else
        color="$GREEN"
        persona="SUPER-BOT"
        emoji="😄"
        status="HIGHLY POSITIVE"
    fi
    
    printf "${BOLD}╔════════════════════════════════════════════════════════════════════╗${RESET}\n"
    printf "${BOLD}║${color}                    %s %s                          ${RESET}${BOLD}║${RESET}\n" "$emoji" "$persona"
    printf "${BOLD}╠════════════════════════════════════════════════════════════════════╣${RESET}\n"
    printf "${BOLD}║${RESET}  Mood Score: ${color}%3d${RESET} / %d to %d  │  Status: ${color}%-18s${RESET} ${BOLD}║${RESET}\n" \
        "$mood" "$MOOD_MIN" "$MOOD_MAX" "$status"
    printf "${BOLD}╚════════════════════════════════════════════════════════════════════╝${RESET}\n"
    printf "\n"
}

# Draw mood meter (visual bar)
draw_mood_meter() {
    local mood=$1
    local bar_width=50
    local filled=$(( (mood - MOOD_MIN) * bar_width / (MOOD_MAX - MOOD_MIN) ))
    
    [ "$filled" -lt 0 ] && filled=0
    [ "$filled" -gt "$bar_width" ] && filled=$bar_width
    
    printf "  Mood Meter: ["
    
    # Determine color gradient
    for ((i=0; i<bar_width; i++)); do
        if [ "$i" -lt "$filled" ]; then
            if [ "$mood" -le -5 ]; then
                printf "${RED}█${RESET}"
            elif [ "$mood" -lt 0 ]; then
                printf "${YELLOW}█${RESET}"
            elif [ "$mood" -eq 0 ]; then
                printf "${CYAN}█${RESET}"
            elif [ "$mood" -le 5 ]; then
                printf "${BLUE}█${RESET}"
            else
                printf "${GREEN}█${RESET}"
            fi
        else
            printf "${DIM}░${RESET}"
        fi
    done
    
    printf "]\n\n"
}

# Display bot response based on mood
get_bot_message() {
    local mood=$1
    
    if [ "$mood" -le -5 ]; then
        echo "🚨 ${RED}${BOLD}ALERT!${RESET} Sentiment critical! Multiple issues detected!"
    elif [ "$mood" -lt 0 ]; then
        echo "⚠️  ${YELLOW}Hmm, I'm detecting some problems...${RESET}"
    elif [ "$mood" -eq 0 ]; then
        echo "ℹ️  ${CYAN}Everything seems balanced. Monitoring...${RESET}"
    elif [ "$mood" -le 5 ]; then
        echo "✅ ${BLUE}Things are looking good!${RESET}"
    else
        echo "🎉 ${GREEN}${BOLD}EXCELLENT!${RESET} Everything is running smoothly!"
    fi
}

################################################################################
# SENTIMENT ANALYSIS
################################################################################

# Analyze a single line of text and return sentiment delta
analyze_line() {
    local line="$1"
    local delta=0
    
    # Convert to lowercase for case-insensitive matching
    local line_lower
    line_lower=$(echo "$line" | tr '[:upper:]' '[:lower:]')
    
    # Count negative matches
    for word in "${NEGATIVE_WORDS[@]}"; do
        if echo "$line_lower" | grep -qw "$word"; then
            ((delta--))
        fi
    done
    
    # Count positive matches
    for word in "${POSITIVE_WORDS[@]}"; do
        if echo "$line_lower" | grep -qw "$word"; then
            ((delta++))
        fi
    done
    
    echo "$delta"
}

# Update mood with bounds checking
update_mood() {
    local delta=$1
    MOOD_CURRENT=$((MOOD_CURRENT + delta))
    
    # Clamp to min/max
    [ "$MOOD_CURRENT" -lt "$MOOD_MIN" ] && MOOD_CURRENT=$MOOD_MIN
    [ "$MOOD_CURRENT" -gt "$MOOD_MAX" ] && MOOD_CURRENT=$MOOD_MAX
}

################################################################################
# DISPLAY UPDATE
################################################################################

# Refresh the entire display
refresh_display() {
    local recent_lines="$1"
    
    clear_screen
    draw_header "$MOOD_CURRENT"
    draw_mood_meter "$MOOD_CURRENT"
    get_bot_message "$MOOD_CURRENT"
    printf "\n${BOLD}${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
    printf "${BOLD}Recent Messages:${RESET}\n\n"
    
    # Display last 10 lines with sentiment indicators
    echo "$recent_lines" | tail -10 | while IFS= read -r line; do
        [ -z "$line" ] && continue
        
        local delta
        delta=$(analyze_line "$line")
        
        if [ "$delta" -lt 0 ]; then
            printf "  ${RED}▼${RESET} %s\n" "$line"
        elif [ "$delta" -gt 0 ]; then
            printf "  ${GREEN}▲${RESET} %s\n" "$line"
        else
            printf "  ${DIM}─${RESET} %s\n" "$line"
        fi
    done
    
    printf "\n${BOLD}${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
    printf "${DIM}Press Ctrl+C to exit${RESET}\n"
}

################################################################################
# MAIN PROCESSING LOOP
################################################################################

# Process input line by line
process_stream() {
    local all_lines=""
    local line_count=0
    
    while IFS= read -r line; do
        # Skip empty lines
        [ -z "$line" ] && continue
        
        # Analyze sentiment
        local delta
        delta=$(analyze_line "$line")
        update_mood "$delta"
        
        # Add to history
        all_lines="${all_lines}${line}"$'\n'
        ((line_count++))
        
        # Refresh display
        refresh_display "$all_lines"
    done
}

# Interactive mode
interactive_mode() {
    clear_screen
    draw_header "$MOOD_CURRENT"
    draw_mood_meter "$MOOD_CURRENT"
    
    printf "\n${BOLD}${CYAN}Interactive Sentiment Monitor${RESET}\n"
    printf "${DIM}Type messages to analyze sentiment (Ctrl+C to exit)${RESET}\n\n"
    
    local all_lines=""
    
    while true; do
        printf "> "
        read -r line || break
        
        [ -z "$line" ] && continue
        
        # Analyze sentiment
        local delta
        delta=$(analyze_line "$line")
        update_mood "$delta"
        
        # Add to history
        all_lines="${all_lines}${line}"$'\n'
        
        # Refresh display
        refresh_display "$all_lines"
        printf "\n> "
    done
}

################################################################################
# MAIN
################################################################################

main() {
    # Check if input is from a pipe or file
    if [ -t 0 ]; then
        # stdin is a terminal (interactive mode)
        if [ -n "$1" ] && [ -f "$1" ]; then
            # File provided as argument - tail it
            printf "${CYAN}Monitoring file: %s${RESET}\n" "$1"
            sleep 1
            tail -f "$1" | process_stream
        else
            # Pure interactive mode
            interactive_mode
        fi
    else
        # stdin is a pipe
        process_stream
    fi
}

# Trap Ctrl+C for clean exit
trap 'printf "\n\n${CYAN}Mood Monitor Terminated. Final mood: %d${RESET}\n" "$MOOD_CURRENT"; exit 0' INT TERM

main "$@"
