#!/usr/bin/env bash

# ==============================================================================
# Contextual History Buffer Chatbot
# ==============================================================================
# A pseudo-intelligent offline script that remembers the last N topics discussed.
# If the user types "tell me more", it looks at the circular buffer to determine
# what "it" refers to, providing conversational continuity.
#
# DEPENDENCIES: bash (>=4), grep, sed, tr, printf, read
#               All standard GNU/Unix utilities. No network access.
#
# USAGE:  chmod +x history-buffer.sh && ./history-buffer.sh
# ==============================================================================

# ---------------------------------------------------------------------------
# STRICT MODE — catch errors early
# ---------------------------------------------------------------------------
set -euo pipefail
IFS=$'\n\t'

# ---------------------------------------------------------------------------
# BASH VERSION CHECK
# ---------------------------------------------------------------------------
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    printf "Error: Bash 4.0 or higher required for associative arrays\n" >&2
    exit 1
fi

# --- Configuration ---
N=3 # Size of the circular memory buffer (remembers last 3 topics)

# Validate buffer size
if [[ ! "$N" =~ ^[0-9]+$ ]] || [[ "$N" -lt 1 ]] || [[ "$N" -gt 10 ]]; then
    printf "Error: Buffer size N must be between 1 and 10\n" >&2
    exit 1
fi

# --- ANSI Color Codes for Clean Terminal UI ---
RESET="\033[0m"
BOLD="\033[1m"
CYAN="\033[1;36m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
DIM="\033[2m"

# --- State Variables ---
# Circular array (buffer) and index pointer
buffer=("" "" "")
buf_idx=0

# --- Stop Words ---
# Common words to ignore when extracting topics from user input.
stop_words="a an the is are was were be been being have has had do does did \
           will would shall should can could may might must i you he she it we \
           they me him her us them my your his its our their this that these \
           those tell more about what how who when where why let talk"

# --- Knowledge Base (Offline) ---
# Associative array mapping keywords to responses.
declare -A knowledge
knowledge[space]="Space is a vast, empty vacuum. It contains stars, planets, and galaxies."
knowledge[planet]="A planet is a celestial body orbiting a star. Earth is the only one known to harbor life."
knowledge[ocean]="Oceans cover about 71% of Earth's surface and contain 97% of the planet's water."
knowledge[computer]="A computer is a machine that takes data as input, processes it, and produces output."
knowledge[linux]="Linux is an open-source Unix-like operating system kernel first released in 1991."
knowledge[bash]="Bash is a Unix shell and command language written by Brian Fox for the GNU Project."
knowledge[time]="Time is a continuous progression of existence. Physicists treat it as a fourth dimension."
knowledge[math]="Mathematics is the science of numbers, quantities, and shapes."
knowledge[history]="History is the study of past events, particularly in human affairs."
knowledge[default]="I find that fascinating, but my memory banks are limited. Try asking about space, linux, bash, or ocean!"

# ==============================================================================
# Functions
# ==============================================================================

# Function: extract_keyword
# Description: Parses user input, filters out stop words, and returns the 
#              longest significant word as the "topic".
extract_keyword() {
    local input="$1"
    local word best_word=""
    
    # Convert to lowercase and remove punctuation using standard tr/sed
    input=$(echo "$input" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z ]//g')
    
    for word in $input; do
        # Check if the word is a stop word
        if ! echo "$stop_words" | grep -qw "$word"; then
            # Keep the longest significant word found
            if [[ ${#word} -gt ${#best_word} ]]; then
                best_word="$word"
            fi
        fi
    done
    
    echo "$best_word"
}

# Function: push_buffer
# Description: Adds a topic to the circular array, overwriting the oldest entry.
push_buffer() {
    local item="$1"
    buffer[$buf_idx]="$item"
    # Wrap around using modulo arithmetic
    ((buf_idx = (buf_idx + 1) % N))
}

# Function: get_recent_topic
# Description: Retrieves the most recent valid topic from the circular buffer.
#              Falls back through the buffer until it finds a topic it "knows".
get_recent_topic() {
    local i idx temp
    for (( i=1; i<=N; i++ )); do
        # Calculate index walking backwards from most recent
        idx=$(( (buf_idx - i + N) % N ))
        temp="${buffer[$idx]}"
        
        # If the buffer slot is not empty, check if we know about it
        if [[ -n "$temp" ]]; then
            # Return the first valid topic we find (most recent)
            echo "$temp"
            return
        fi
    done
    echo ""
}

# Function: print_buffer_status
# Description: Displays the current state of the short-term memory buffer.
print_buffer_status() {
    printf "${DIM}  [ Memory: "
    local i idx
    for (( i=1; i<=N; i++ )); do
        idx=$(( (buf_idx - i + N) % N ))
        if [[ -n "${buffer[$idx]}" ]]; then
            printf "%s" "${buffer[$idx]}"
        else
            printf "%s" "empty"
        fi
        if (( i < N )); then
            printf " -> "
        fi
    done
    printf " ]${RESET}\n"
}

# Function: is_tell_more
# Description: Checks if the user input matches continuity phrases.
is_tell_more() {
    local input="$1"
    input=$(echo "$input" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z ]//g')
    
    # Match phrases like "tell me more", "more about it", "continue", "go on"
    if echo "$input" | grep -qE "tell me more|more about (it|that)|continue|go on|elaborate|expand"; then
        return 0 # True
    fi
    return 1 # False
}

# ==============================================================================
# Main Execution & Terminal UI
# ==============================================================================

clear
printf "${CYAN}${BOLD}========================================\n"
printf "  Contextual History Buffer Chatbot\n"
printf "========================================${RESET}\n"
printf " Discuss topics (e.g., space, bash, ocean).\n"
printf " Type ${GREEN}'tell me more'${RESET} to recall the last topic.\n"
printf " Type ${YELLOW}'exit'${RESET} to quit.\n"
printf "${CYAN}========================================${RESET}\n\n"

# --- Main Loop ---
main_loop() {
    while true; do
        printf "${CYAN}You${RESET}: "
        read -r user_input

        # Trim
        user_input=$(printf '%s' "$user_input" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # Exit
        if [[ "$user_input" =~ ^(quit|exit|bye)$ ]]; then
            printf "${GREEN}Goodbye!${RESET}\n\n"
            break
        fi

        # Skip empty
        [[ -z "$user_input" ]] && continue

        # Input length validation
        if [[ ${#user_input} -gt 500 ]]; then
            printf "${RED}Error: Input too long (max 500 characters)${RESET}\n\n"
            continue
        fi

        # Special command: "tell me more"
        if [[ "$user_input" =~ (tell me more|more about it) ]]; then
            topic=$(get_recent_topic)

            if [[ -z "$topic" ]]; then
                printf "${YELLOW}  Bot:${RESET} I don't have anything in my memory to discuss yet.\n"
            else
                # Retrieve knowledge; use default if topic is known but detail is missing
                response="${knowledge[$topic]:-${knowledge[default]}}"
                printf "${YELLOW}  Bot:${RESET} (Recalling '${BOLD}${topic}${RESET}') ${response}\n"
            fi
        else
        # Standard input: Extract keyword and store in buffer
        keyword=$(extract_keyword "$user_input")
        
        if [[ -n "$keyword" ]]; then
            # Push to circular buffer
            push_buffer "$keyword"
            
            # Retrieve response
            response="${knowledge[$keyword]:-${knowledge[default]}}"
            printf "${YELLOW}  Bot:${RESET} (Noted '${BOLD}${keyword}${RESET}') ${response}\n"
        else
            # Fallback if no significant words are found
            printf "${YELLOW}  Bot:${RESET} ${knowledge[default]}\n"
        fi
    fi
    
    # Display the current buffer state
    print_buffer_status
    echo ""
done