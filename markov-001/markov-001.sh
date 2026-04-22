#!/usr/bin/env bash

################################################################################
# Markov Chain Personality Mimic
# 
# A simple text generator that learns from your writing style using Markov chains.
# Feed it a corpus of text (emails, chat logs, etc.) and it will generate
# sentences that mimic your writing style based on word probability patterns.
#
# Usage: ./markov_mimic.sh [corpus_file]
#
# Requirements: Standard GNU/Unix utilities only (bash, awk, sed, grep, shuf)
################################################################################

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly CHAIN_ORDER=2  # Number of words to consider for next word prediction
readonly MIN_SENTENCE_LENGTH=5
readonly MAX_SENTENCE_LENGTH=20
readonly TEMP_DIR="/tmp/markov_$$"
readonly CHAIN_FILE="${TEMP_DIR}/chain.dat"
readonly WORDS_FILE="${TEMP_DIR}/words.dat"
readonly STARTS_FILE="${TEMP_DIR}/starts.dat"

# Colors for terminal UI
readonly C_RESET='\033[0m'
readonly C_BOLD='\033[1m'
readonly C_GREEN='\033[0;32m'
readonly C_BLUE='\033[0;34m'
readonly C_YELLOW='\033[0;33m'
readonly C_RED='\033[0;31m'
readonly C_CYAN='\033[0;36m'

################################################################################
# Utility Functions
################################################################################

# Print colored output
print_color() {
    local color="$1"
    shift
    printf "${color}%s${C_RESET}\n" "$*"
}

# Print header
print_header() {
    clear
    print_color "$C_BOLD$C_CYAN" "╔════════════════════════════════════════════════════════════════╗"
    print_color "$C_BOLD$C_CYAN" "║          Markov Chain Personality Mimic v1.0                  ║"
    print_color "$C_BOLD$C_CYAN" "║          Learn and speak in your writing style                ║"
    print_color "$C_BOLD$C_CYAN" "╚════════════════════════════════════════════════════════════════╝"
    echo
}

# Print error and exit
error_exit() {
    print_color "$C_RED" "ERROR: $*" >&2
    cleanup
    exit 1
}

# Cleanup temporary files
cleanup() {
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Setup trap for cleanup
trap cleanup EXIT INT TERM

################################################################################
# Markov Chain Building Functions
################################################################################

# Preprocess the corpus text
preprocess_corpus() {
    local corpus_file="$1"
    
    # Convert to lowercase, normalize whitespace, preserve sentence boundaries
    sed 's/[.!?]/&\n/g' "$corpus_file" | \
    tr '[:upper:]' '[:lower:]' | \
    sed 's/[^a-z0-9'\''.,!? \n-]/ /g' | \
    sed 's/  */ /g' | \
    sed '/^[[:space:]]*$/d'
}

# Build the Markov chain from preprocessed text
build_chain() {
    local corpus_file="$1"
    
    print_color "$C_YELLOW" "Building Markov chain from corpus..."
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    
    # Build the chain using awk
    preprocess_corpus "$corpus_file" | awk -v order="$CHAIN_ORDER" -v starts="$STARTS_FILE" '
    BEGIN {
        srand()
    }
    
    # Process each line
    {
        # Skip empty lines
        if (NF == 0) next
        
        # Remove leading/trailing spaces
        gsub(/^[[:space:]]+|[[:space:]]+$/, "")
        
        # Store sentence starts (first word or two words)
        if (NF >= order) {
            start_key = ""
            for (i = 1; i <= order; i++) {
                start_key = start_key (i > 1 ? " " : "") $i
            }
            sentence_starts[start_key]++
        }
        
        # Build the chain
        for (i = 1; i <= NF - order; i++) {
            # Build the key from current words
            key = ""
            for (j = 0; j < order; j++) {
                key = key (j > 0 ? " " : "") $(i + j)
            }
            
            # The next word
            next_word = $(i + order)
            
            # Store the transition
            chain[key, ++count[key]] = next_word
        }
    }
    
    END {
        # Output the chain
        for (key in count) {
            for (i = 1; i <= count[key]; i++) {
                print key "|" chain[key, i]
            }
        }
        
        # Output sentence starts to separate file
        for (start in sentence_starts) {
            for (i = 1; i <= sentence_starts[start]; i++) {
                print start >> starts
            }
        }
    }
    ' > "$CHAIN_FILE"
    
    # Count statistics
    local total_transitions=$(wc -l < "$CHAIN_FILE")
    local unique_states=$(cut -d'|' -f1 "$CHAIN_FILE" | sort -u | wc -l)
    
    print_color "$C_GREEN" "✓ Chain built successfully!"
    print_color "$C_BLUE" "  Total transitions: $total_transitions"
    print_color "$C_BLUE" "  Unique states: $unique_states"
    echo
}

# Generate a sentence using the Markov chain
generate_sentence() {
    local length="${1:-$MAX_SENTENCE_LENGTH}"
    
    # Pick a random starting point
    local current_state
    if [[ -f "$STARTS_FILE" ]] && [[ -s "$STARTS_FILE" ]]; then
        current_state=$(shuf -n 1 "$STARTS_FILE")
    else
        current_state=$(cut -d'|' -f1 "$CHAIN_FILE" | shuf -n 1)
    fi
    
    # Start building the sentence
    local sentence="$current_state"
    local word_count=$CHAIN_ORDER
    
    # Generate words
    while [[ $word_count -lt $length ]]; do
        # Find all possible next words for current state
        local next_words=$(grep -F "${current_state}|" "$CHAIN_FILE" 2>/dev/null | cut -d'|' -f2)
        
        if [[ -z "$next_words" ]]; then
            break
        fi
        
        # Pick a random next word
        local next_word=$(echo "$next_words" | shuf -n 1)
        
        # Check for sentence endings
        if [[ "$next_word" =~ [.!?]$ ]]; then
            sentence="$sentence $next_word"
            break
        fi
        
        sentence="$sentence $next_word"
        ((word_count++))
        
        # Update current state (shift window)
        if [[ $CHAIN_ORDER -eq 1 ]]; then
            current_state="$next_word"
        else
            # Take the last N-1 words from current state plus new word
            current_state=$(echo "$current_state $next_word" | awk '{for(i=2;i<=NF;i++) printf "%s%s", $i, (i<NF?" ":"")}')
        fi
    done
    
    # Ensure sentence ends with punctuation
    if [[ ! "$sentence" =~ [.!?]$ ]]; then
        sentence="${sentence}."
    fi
    
    # Capitalize first letter
    sentence=$(echo "$sentence" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')
    
    echo "$sentence"
}

################################################################################
# Interactive UI Functions
################################################################################

# Show the main menu
show_menu() {
    print_color "$C_BOLD" "Options:"
    echo "  [G] Generate a sentence"
    echo "  [5] Generate 5 sentences"
    echo "  [10] Generate 10 sentences"
    echo "  [C] Continuous mode (keep generating)"
    echo "  [S] Show statistics"
    echo "  [Q] Quit"
    echo
}

# Show statistics about the chain
show_statistics() {
    print_header
    print_color "$C_BOLD$C_YELLOW" "Chain Statistics:"
    echo
    
    local total_transitions=$(wc -l < "$CHAIN_FILE")
    local unique_states=$(cut -d'|' -f1 "$CHAIN_FILE" | sort -u | wc -l)
    local unique_words=$(cut -d'|' -f2 "$CHAIN_FILE" | tr ' ' '\n' | sort -u | wc -l)
    
    printf "  Total transitions:  %'d\n" "$total_transitions"
    printf "  Unique states:      %'d\n" "$unique_states"
    printf "  Unique words:       %'d\n" "$unique_words"
    printf "  Chain order:        %d\n" "$CHAIN_ORDER"
    echo
    
    print_color "$C_CYAN" "Most common word pairs:"
    cut -d'|' -f1 "$CHAIN_FILE" | sort | uniq -c | sort -rn | head -5 | \
        awk '{printf "  %5d × %s\n", $1, substr($0, index($0,$2))}'
    echo
    
    print_color "$C_CYAN" "Press Enter to continue..."
    read -r
}

# Interactive mode
interactive_mode() {
    while true; do
        print_header
        show_menu
        
        printf "%s" "$(print_color "$C_GREEN" "Enter your choice: ")"
        read -r choice
        echo
        
        case "${choice^^}" in
            G)
                print_color "$C_CYAN" "Generated sentence:"
                print_color "$C_BOLD" "$(generate_sentence)"
                echo
                print_color "$C_YELLOW" "Press Enter to continue..."
                read -r
                ;;
            5)
                print_color "$C_CYAN" "Generated sentences:"
                for i in {1..5}; do
                    printf "%s" "$(print_color "$C_BOLD" "$i. ")"
                    generate_sentence
                done
                echo
                print_color "$C_YELLOW" "Press Enter to continue..."
                read -r
                ;;
            10)
                print_color "$C_CYAN" "Generated sentences:"
                for i in {1..10}; do
                    printf "%s" "$(print_color "$C_BOLD" "$i. ")"
                    generate_sentence
                done
                echo
                print_color "$C_YELLOW" "Press Enter to continue..."
                read -r
                ;;
            C)
                print_header
                print_color "$C_CYAN" "Continuous mode - Press Ctrl+C to stop"
                echo
                local count=1
                while true; do
                    printf "%s" "$(print_color "$C_BOLD" "$count. ")"
                    generate_sentence
                    ((count++))
                    sleep 0.5
                done
                ;;
            S)
                show_statistics
                ;;
            Q)
                print_color "$C_GREEN" "Goodbye!"
                exit 0
                ;;
            *)
                print_color "$C_RED" "Invalid choice. Please try again."
                sleep 1
                ;;
        esac
    done
}

################################################################################
# Main Program
################################################################################

main() {
    # Check if corpus file is provided
    if [[ $# -eq 0 ]]; then
        print_header
        print_color "$C_RED" "Usage: $SCRIPT_NAME <corpus_file>"
        echo
        echo "Example: $SCRIPT_NAME my_emails.txt"
        echo
        echo "The corpus file should contain text samples in your writing style."
        echo "The more text you provide, the better the results will be."
        exit 1
    fi
    
    local corpus_file="$1"
    
    # Validate corpus file
    if [[ ! -f "$corpus_file" ]]; then
        error_exit "Corpus file not found: $corpus_file"
    fi
    
    if [[ ! -r "$corpus_file" ]]; then
        error_exit "Cannot read corpus file: $corpus_file"
    fi
    
    if [[ ! -s "$corpus_file" ]]; then
        error_exit "Corpus file is empty: $corpus_file"
    fi
    
    print_header
    
    # Build the Markov chain
    build_chain "$corpus_file"
    
    # Verify chain was built
    if [[ ! -s "$CHAIN_FILE" ]]; then
        error_exit "Failed to build Markov chain. Corpus may be too small or malformed."
    fi
    
    # Enter interactive mode
    interactive_mode
}

# Run main program
main "$@"