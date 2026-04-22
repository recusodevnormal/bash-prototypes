#!/usr/bin/env bash
# =============================================================================
# markov_mimic.sh - Static Markov Chain "Personality" Mimic
# =============================================================================
# Feed this script a local corpus (text file of emails, chat logs, notes, etc.)
# It builds a bigram probability table using only awk, then lets you "chat"
# with a version of yourself generated from pure local word frequency.
#
# Usage:
#   chmod +x markov_mimic.sh
#   ./markov_mimic.sh [corpus_file]
#   ./markov_mimic.sh                  # uses built-in demo corpus
#
# Dependencies: bash, awk, sed, grep, printf, tr, cut, wc, date, tput
#               (all standard GNU/Unix utilities - zero external packages)
# =============================================================================

# ---------------------------------------------------------------------------
# TERMINAL UI HELPERS
# ---------------------------------------------------------------------------

# Detect terminal capabilities gracefully - fall back if tput isn't available
if command -v tput &>/dev/null && tput colors &>/dev/null 2>&1; then
    C_RESET=$(tput sgr0)
    C_BOLD=$(tput bold)
    C_DIM=$(tput dim 2>/dev/null || printf "")
    C_CYAN=$(tput setaf 6)
    C_GREEN=$(tput setaf 2)
    C_YELLOW=$(tput setaf 3)
    C_MAGENTA=$(tput setaf 5)
    C_RED=$(tput setaf 1)
    C_BLUE=$(tput setaf 4)
    C_WHITE=$(tput setaf 7)
    TERM_WIDTH=$(tput cols)
else
    # No color support - degrade cleanly
    C_RESET="" C_BOLD="" C_DIM="" C_CYAN="" C_GREEN=""
    C_YELLOW="" C_MAGENTA="" C_RED="" C_BLUE="" C_WHITE=""
    TERM_WIDTH=80
fi

# Clamp terminal width between 60 and 120 for readability
[[ "$TERM_WIDTH" -lt 60 ]] && TERM_WIDTH=60
[[ "$TERM_WIDTH" -gt 120 ]] && TERM_WIDTH=120

# ---------------------------------------------------------------------------
# draw_line - Draw a horizontal rule using a repeated character
# Args: $1 = character (default ─), $2 = color
# ---------------------------------------------------------------------------
draw_line() {
    local char="${1:-─}"
    local color="${2:-$C_DIM}"
    local line=""
    for ((i = 0; i < TERM_WIDTH; i++)); do
        line+="$char"
    done
    printf "%s%s%s\n" "$color" "$line" "$C_RESET"
}

# ---------------------------------------------------------------------------
# center_text - Center a string in the terminal width
# ---------------------------------------------------------------------------
center_text() {
    local text="$1"
    local color="${2:-$C_WHITE}"
    # Strip ANSI codes for length calculation
    local plain
    plain=$(printf "%s" "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local len=${#plain}
    local pad=$(( (TERM_WIDTH - len) / 2 ))
    printf "%*s%s%s%s\n" "$pad" "" "$color" "$text" "$C_RESET"
}

# ---------------------------------------------------------------------------
# print_banner - Draw the application header
# ---------------------------------------------------------------------------
print_banner() {
    clear
    printf "\n"
    draw_line "═" "$C_CYAN"
    center_text "🧠  MARKOV CHAIN PERSONALITY MIMIC" "$C_BOLD$C_CYAN"
    center_text "Offline • Private • Pure Bash" "$C_DIM"
    draw_line "═" "$C_CYAN"
    printf "\n"
}

# ---------------------------------------------------------------------------
# status_msg - Print a formatted status line
# Args: $1 = icon, $2 = label, $3 = value, $4 = color
# ---------------------------------------------------------------------------
status_msg() {
    local icon="$1" label="$2" value="$3" color="${4:-$C_WHITE}"
    printf "  %s  %s%-20s%s %s%s%s\n" \
        "$icon" "$C_BOLD" "$label" "$C_RESET" "$color" "$value" "$C_RESET"
}

# ---------------------------------------------------------------------------
# spinner - Show an animated spinner while a background task runs
# Args: $1 = PID to watch, $2 = message
# ---------------------------------------------------------------------------
spinner() {
    local pid="$1" msg="$2"
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    # Hide cursor
    tput civis 2>/dev/null
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  %s%s%s  %s" \
            "$C_CYAN" "${frames[$((i % ${#frames[@]}))]}" "$C_RESET" "$msg"
        sleep 0.08
        ((i++))
    done
    printf "\r  %s✓%s  %-50s\n" "$C_GREEN" "$C_RESET" "$msg"
    # Restore cursor
    tput cnorm 2>/dev/null
}

# =============================================================================
# CORPUS HANDLING
# =============================================================================

# ---------------------------------------------------------------------------
# Built-in demo corpus - used when no file is provided
# A short, stylistically distinctive block of text so the demo is self-contained
# ---------------------------------------------------------------------------
DEMO_CORPUS='
Sometimes I think the best ideas come from nowhere in particular.
Sometimes the best code is the code you never write at all.
I think the simplest solution is usually the most elegant solution.
I think code should read like prose and prose should think like code.
The best way to learn something is to build it yourself from scratch.
The best debugging technique is a good nights sleep and fresh eyes.
I always start with the simplest possible version that could possibly work.
I always think about edge cases first because edge cases become the common case.
When in doubt leave it out and ship the simpler thing first.
When in doubt write a test and let the test tell you what the code needs.
Good systems are boring systems and boring systems are reliable systems.
Good code tells a story and the story should be obvious to any reader.
Complexity is the enemy of reliability and reliability is the goal.
Complexity is easy to add but almost impossible to remove later on.
Every abstraction is a bet that the thing will not need to change.
Every line of code is a liability and every feature is a future bug.
Simple things should be simple and complex things should be possible.
Simple solutions to hard problems are usually hiding a deeper insight.
I find that walking away from a problem often solves the problem faster.
I find that talking through a problem out loud reveals the solution quickly.
The most important skill is knowing when to stop and ship it.
The most important thing is not the technology but the problem you solve.
Nothing is more permanent than a temporary solution that actually works.
Nothing clarifies thinking like trying to explain it to someone else.
'

# ---------------------------------------------------------------------------
# load_corpus - Read corpus from file or fall back to built-in demo
# Sets global: CORPUS_TEXT, CORPUS_SOURCE, WORD_COUNT
# ---------------------------------------------------------------------------
load_corpus() {
    local filepath="${1:-}"

    if [[ -n "$filepath" ]]; then
        # Validate the provided file
        if [[ ! -f "$filepath" ]]; then
            printf "\n  %s⚠%s  File not found: %s\n" "$C_YELLOW" "$C_RESET" "$filepath"
            printf "      Falling back to built-in demo corpus.\n\n"
            CORPUS_TEXT="$DEMO_CORPUS"
            CORPUS_SOURCE="Built-in demo"
        elif [[ ! -r "$filepath" ]]; then
            printf "\n  %s⚠%s  Cannot read file: %s\n" "$C_YELLOW" "$C_RESET" "$filepath"
            printf "      Falling back to built-in demo corpus.\n\n"
            CORPUS_TEXT="$DEMO_CORPUS"
            CORPUS_SOURCE="Built-in demo"
        else
            CORPUS_TEXT=$(cat "$filepath")
            CORPUS_SOURCE=$(basename "$filepath")
        fi
    else
        CORPUS_TEXT="$DEMO_CORPUS"
        CORPUS_SOURCE="Built-in demo"
    fi

    # Count words for stats display
    WORD_COUNT=$(printf "%s" "$CORPUS_TEXT" | wc -w | tr -d ' ')
}

# =============================================================================
# MARKOV CHAIN CORE - Pure awk implementation
# =============================================================================
#
# ALGORITHM OVERVIEW
# ──────────────────
# 1. TOKENIZE: Strip punctuation (mostly), lowercase everything, split to words.
# 2. BIGRAM TABLE: For each consecutive pair (word_A, word_B), record word_B
#    as a possible successor to word_A. Store as:
#      table[word_A] = "word_B1 word_B2 word_B3 ..."  (space-separated list)
#    Duplicates are kept - higher-frequency successors appear more often,
#    giving us weighted random selection for free.
# 3. SENTENCE START TABLE: Track which words begin sentences so generated
#    text can start naturally.
# 4. GENERATION: Pick a random start word, then repeatedly pick a random
#    word from table[current_word] until we hit a terminal word or max length.
#
# The entire model lives in awk's associative arrays - no temp files needed.
# =============================================================================

# ---------------------------------------------------------------------------
# build_model - Pre-process corpus into the awk model script
# We write the awk program to a variable (heredoc) to keep it readable.
# The model is stored in a temp file so the generator can reference it.
# ---------------------------------------------------------------------------

# We store the serialized model in a temp file for reuse across queries
MODEL_FILE=""

build_model() {
    # Create a secure temp file
    MODEL_FILE=$(mktemp /tmp/markov_model_XXXXXX)
    # Register cleanup on exit
    trap 'rm -f "$MODEL_FILE"' EXIT INT TERM

    # Run the model builder as a background process so we can show a spinner
    {
        printf "%s" "$CORPUS_TEXT" | awk '
        # ─────────────────────────────────────────────────────────────────
        # awk Markov model builder
        # Reads stdin word by word across all lines.
        # Outputs a serialized model: one record per key word.
        # Format:  KEY<TAB>word1 word2 word3 ...
        # Prefix S: for sentence-start words, T: for bigram table.
        # ─────────────────────────────────────────────────────────────────
        BEGIN {
            RS = "\n"   # process line by line
        }

        {
            # ── Clean and tokenize the current line ──────────────────────
            line = $0

            # Lowercase everything for consistent key matching
            line = tolower(line)

            # Remove characters we do not want to index on.
            # Keep apostrophes (contractions), hyphens, and basic letters.
            gsub(/[^a-z0-9'"'"' \t-]/, " ", line)

            # Collapse multiple spaces
            gsub(/[ \t]+/, " ", line)

            # Trim leading/trailing whitespace
            sub(/^ /, "", line)
            sub(/ $/, "", line)

            if (length(line) == 0) next

            # Split line into words array
            n = split(line, words, " ")
            if (n == 0) next

            # ── Record sentence-start word ───────────────────────────────
            # Any word that starts a line is eligible as a sentence starter
            if (words[1] != "") {
                starts[words[1]] = starts[words[1]] " " words[1]
            }

            # ── Build bigram table ───────────────────────────────────────
            # For each adjacent pair (words[i], words[i+1]):
            #   table[words[i]] grows by appending words[i+1]
            for (i = 1; i < n; i++) {
                w1 = words[i]
                w2 = words[i + 1]
                if (w1 == "" || w2 == "") continue
                # Append successor - duplicates increase its weight naturally
                table[w1] = table[w1] " " w2
            }

            # Mark last word of each line as a potential terminal
            # (we use this to allow natural sentence endings)
            terminals[words[n]] = 1
        }

        END {
            # ── Serialize sentence-start words ───────────────────────────
            for (w in starts) {
                printf "S:\t%s\t%s\n", w, starts[w]
            }

            # ── Serialize bigram table ───────────────────────────────────
            for (w in table) {
                printf "T:\t%s\t%s\n", w, table[w]
            }

            # ── Serialize terminal markers ───────────────────────────────
            for (w in terminals) {
                printf "X:\t%s\n", w
            }
        }
        ' > "$MODEL_FILE"
    } &

    local build_pid=$!
    spinner "$build_pid" "Building Markov model from corpus..."
    wait "$build_pid"
}

# ---------------------------------------------------------------------------
# generate_sentence - Generate a sentence using the pre-built model
# Args:
#   $1 = minimum word count (default 8)
#   $2 = maximum word count (default 25)
#   $3 = random seed hint (default: seconds since epoch)
# Outputs the generated sentence to stdout.
# ---------------------------------------------------------------------------
generate_sentence() {
    local min_words="${1:-8}"
    local max_words="${2:-25}"
    # Use current time + nanoseconds as seed for variety
    local seed="${3:-$(date +%s%N 2>/dev/null || date +%s)}"

    [[ ! -f "$MODEL_FILE" ]] && {
        printf "Error: model not built yet.\n" >&2
        return 1
    }

    awk -v seed="$seed" -v min_w="$min_words" -v max_w="$max_words" '
    # ─────────────────────────────────────────────────────────────────────
    # awk sentence generator
    # Reads the serialized model from MODEL_FILE, then walks the bigram
    # table to produce a sentence.
    # ─────────────────────────────────────────────────────────────────────
    BEGIN {
        srand(seed)
        start_count = 0
    }

    # Load model records
    /^S:\t/ {
        # Sentence-start word record
        # Format: S: <TAB> word <TAB> word word word ...
        n = split($0, parts, "\t")
        word = parts[2]
        starts[++start_count] = word
        next
    }

    /^T:\t/ {
        # Bigram table record
        # Format: T: <TAB> key_word <TAB> succ1 succ2 succ3 ...
        # We need to extract from position of second tab onward
        line = $0
        sub(/^T:\t[^\t]*\t/, "", line)   # strip prefix + key + tab
        # Extract key word between first and second tab
        match($0, /^T:\t([^\t]+)\t/, arr)
        key = arr[1]
        if (key == "") next
        # Store successors list
        table[key] = line
        next
    }

    /^X:\t/ {
        # Terminal word record
        n = split($0, parts, "\t")
        terminals[parts[2]] = 1
        next
    }

    END {
        # ── Sanity check ─────────────────────────────────────────────────
        if (start_count == 0) {
            print "Could not build model - corpus may be too small."
            exit 1
        }

        # ── Pick a random sentence-start word ────────────────────────────
        idx = int(rand() * start_count) + 1
        current = starts[idx]
        sentence = current

        word_count = 1
        max_attempts = max_w * 3   # guard against infinite loops

        # ── Walk the bigram table ─────────────────────────────────────────
        for (attempt = 0; attempt < max_attempts; attempt++) {

            # Look up successors for current word
            successors = table[current]
            if (successors == "") {
                # Dead end - if we have minimum words, stop; else pick new start
                if (word_count >= min_w) break
                idx = int(rand() * start_count) + 1
                current = starts[idx]
                sentence = sentence " " current
                word_count++
                continue
            }

            # Split successors into an array and pick one at random
            n = split(successors, succ_arr, " ")

            # Filter empty entries (from leading spaces in our format)
            real_count = 0
            for (i = 1; i <= n; i++) {
                if (succ_arr[i] != "") {
                    real_succs[++real_count] = succ_arr[i]
                }
            }

            if (real_count == 0) break

            pick = int(rand() * real_count) + 1
            next_word = real_succs[pick]

            sentence = sentence " " next_word
            word_count++
            current = next_word

            # ── Natural stopping conditions ───────────────────────────────
            # Stop if we are past minimum length AND current word is a terminal
            if (word_count >= min_w && current in terminals) break

            # Hard stop at maximum length
            if (word_count >= max_w) break
        }

        # ── Capitalize first letter ───────────────────────────────────────
        first = substr(sentence, 1, 1)
        rest  = substr(sentence, 2)
        # Uppercase first character (works for a-z)
        if (first >= "a" && first <= "z") {
            first = sprintf("%c", ord(first) - 32)
        }
        sentence = first rest

        # ── Add terminal punctuation ──────────────────────────────────────
        # Alternate between period and period based on randomness
        r = rand()
        if (r < 0.7)       sentence = sentence "."
        else if (r < 0.9)  sentence = sentence "."
        else               sentence = sentence "."

        print sentence
    }

    # Helper: ASCII ordinal value of a single character
    function ord(c) {
        return index("abcdefghijklmnopqrstuvwxyz", c) + 96
    }
    ' "$MODEL_FILE"
}

# =============================================================================
# MODEL STATISTICS
# =============================================================================

# ---------------------------------------------------------------------------
# show_stats - Display information about the built model
# ---------------------------------------------------------------------------
show_stats() {
    local total_keys unique_words start_words

    [[ ! -f "$MODEL_FILE" ]] && return

    total_keys=$(grep -c "^T:" "$MODEL_FILE" 2>/dev/null || printf "0")
    start_words=$(grep -c "^S:" "$MODEL_FILE" 2>/dev/null || printf "0")
    unique_words="$total_keys"  # each T: line = one unique key word

    printf "\n"
    draw_line "─" "$C_DIM"
    printf "  %s📊 Model Statistics%s\n" "$C_BOLD" "$C_RESET"
    draw_line "─" "$C_DIM"
    status_msg "📄" "Corpus source:"    "$CORPUS_SOURCE"        "$C_CYAN"
    status_msg "📝" "Words in corpus:"  "$WORD_COUNT"           "$C_GREEN"
    status_msg "🔑" "Unique key words:" "$unique_words"         "$C_YELLOW"
    status_msg "🚀" "Sentence starters:" "$start_words"         "$C_MAGENTA"
    draw_line "─" "$C_DIM"
    printf "\n"
}

# =============================================================================
# WORD-WRAP HELPER
# =============================================================================

# ---------------------------------------------------------------------------
# wrap_text - Wrap text at terminal width with an indent prefix
# Args: $1 = text, $2 = indent (default 4), $3 = color
# ---------------------------------------------------------------------------
wrap_text() {
    local text="$1"
    local indent="${2:-4}"
    local color="${3:-$C_WHITE}"
    local wrap_width=$(( TERM_WIDTH - indent - 2 ))

    # Use awk to wrap at word boundaries
    printf "%s" "$text" | awk -v width="$wrap_width" -v pad="$indent" '
    BEGIN { line = "" }
    {
        n = split($0, words, " ")
        for (i = 1; i <= n; i++) {
            test = (line == "") ? words[i] : line " " words[i]
            if (length(test) > width && line != "") {
                # Print current line with indent
                printf "%*s%s\n", pad, "", line
                line = words[i]
            } else {
                line = test
            }
        }
    }
    END {
        if (line != "") printf "%*s%s\n", pad, "", line
    }
    ' | while IFS= read -r wrapped_line; do
        printf "%s%s%s\n" "$color" "$wrapped_line" "$C_RESET"
    done
}

# =============================================================================
# CHAT INTERFACE
# =============================================================================

# ---------------------------------------------------------------------------
# print_response - Format and display a generated response
# Args: $1 = the generated sentence
# ---------------------------------------------------------------------------
print_response() {
    local sentence="$1"
    local timestamp
    timestamp=$(date '+%H:%M:%S')

    printf "\n"
    printf "  %s🤖 Mimic%s %s[%s]%s\n" \
        "$C_BOLD$C_MAGENTA" "$C_RESET" \
        "$C_DIM" "$timestamp" "$C_RESET"
    draw_line "╌" "$C_DIM"
    wrap_text "$sentence" 4 "$C_WHITE"
    printf "\n"
}

# ---------------------------------------------------------------------------
# print_user_prompt - Show the user input prompt
# ---------------------------------------------------------------------------
print_user_prompt() {
    printf "  %s💬 You%s %s(type a topic/word, or a command)%s\n" \
        "$C_BOLD$C_CYAN" "$C_RESET" \
        "$C_DIM" "$C_RESET"
    printf "  %s▶%s " "$C_GREEN" "$C_RESET"
}

# ---------------------------------------------------------------------------
# print_help - Display available commands
# ---------------------------------------------------------------------------
print_help() {
    printf "\n"
    draw_line "─" "$C_DIM"
    printf "  %s📖 Commands%s\n\n" "$C_BOLD$C_YELLOW" "$C_RESET"
    printf "  %s%-18s%s %s\n" "$C_GREEN"  "<any word>"  "$C_RESET" "Generate a sentence containing or starting near that word"
    printf "  %s%-18s%s %s\n" "$C_GREEN"  "<Enter>"     "$C_RESET" "Generate a random sentence"
    printf "  %s%-18s%s %s\n" "$C_CYAN"   "more"        "$C_RESET" "Generate 5 sentences in a burst"
    printf "  %s%-18s%s %s\n" "$C_CYAN"   "stats"       "$C_RESET" "Show model statistics"
    printf "  %s%-18s%s %s\n" "$C_CYAN"   "reload"      "$C_RESET" "Reload and rebuild the model"
    printf "  %s%-18s%s %s\n" "$C_YELLOW" "help"        "$C_RESET" "Show this help"
    printf "  %s%-18s%s %s\n" "$C_RED"    "quit / exit" "$C_RESET" "Exit the program"
    draw_line "─" "$C_DIM"
    printf "\n"
}

# ---------------------------------------------------------------------------
# generate_seeded_from_word - Try to generate a sentence that starts with
# or uses a word supplied by the user as a hint.
# Strategy: look up whether that word exists as a key in the model.
# If yes, use it as the starting point instead of a random start word.
# We do this by temporarily prepending the word as a forced start.
# ---------------------------------------------------------------------------
generate_seeded_from_word() {
    local hint
    hint=$(printf "%s" "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g')
    local min_words="${2:-8}"
    local max_words="${3:-25}"
    local seed
    seed=$(date +%s%N 2>/dev/null || date +%s)

    # Check if hint word exists in the model's bigram table
    local exists
    exists=$(grep -c "^T:	${hint}	" "$MODEL_FILE" 2>/dev/null || printf "0")

    if [[ "$exists" -gt 0 ]]; then
        # Feed a modified seed into the generator via env override
        # We inject the hint as a forced-start via a special awk call
        awk -v seed="$seed" -v min_w="$min_words" -v max_w="$max_words" \
            -v force_start="$hint" '
        BEGIN { srand(seed); start_count = 0 }

        /^S:\t/ {
            n = split($0, parts, "\t")
            starts[++start_count] = parts[2]
            next
        }
        /^T:\t/ {
            line = $0
            match($0, /^T:\t([^\t]+)\t/, arr)
            key = arr[1]
            if (key == "") next
            sub(/^T:\t[^\t]*\t/, "", line)
            table[key] = line
            next
        }
        /^X:\t/ {
            n = split($0, parts, "\t")
            terminals[parts[2]] = 1
            next
        }

        END {
            if (start_count == 0) { print "Model empty."; exit 1 }

            # Use forced start word if provided and valid
            if (force_start != "" && force_start in table) {
                current = force_start
            } else {
                # Fall back to random start
                idx = int(rand() * start_count) + 1
                current = starts[idx]
            }

            sentence = current
            word_count = 1
            max_attempts = max_w * 3

            for (attempt = 0; attempt < max_attempts; attempt++) {
                successors = table[current]
                if (successors == "") {
                    if (word_count >= min_w) break
                    idx = int(rand() * start_count) + 1
                    current = starts[idx]
                    sentence = sentence " " current
                    word_count++
                    continue
                }
                n = split(successors, succ_arr, " ")
                real_count = 0
                for (i = 1; i <= n; i++) {
                    if (succ_arr[i] != "") real_succs[++real_count] = succ_arr[i]
                }
                if (real_count == 0) break
                pick = int(rand() * real_count) + 1
                next_word = real_succs[pick]
                sentence = sentence " " next_word
                word_count++
                current = next_word
                if (word_count >= min_w && current in terminals) break
                if (word_count >= max_w) break
            }

            # Capitalize first letter
            first = substr(sentence, 1, 1)
            rest  = substr(sentence, 2)
            if (first >= "a" && first <= "z")
                first = sprintf("%c", index("abcdefghijklmnopqrstuvwxyz", first) + 64)
            sentence = first rest "."
            print sentence
        }
        ' "$MODEL_FILE"
    else
        # Word not in model - just generate randomly and note it
        printf "  %s(Word '%s' not in model - generating randomly)%s\n" \
            "$C_DIM" "$hint" "$C_RESET"
        generate_sentence "$min_words" "$max_words" "$seed"
    fi
}

# =============================================================================
# MAIN CHAT LOOP
# =============================================================================

# ---------------------------------------------------------------------------
# run_chat - The main interactive session
# ---------------------------------------------------------------------------
run_chat() {
    print_help

    # Generate one opening sentence automatically to show it works
    printf "  %sGenerating an opening line...%s\n" "$C_DIM" "$C_RESET"
    local opening
    opening=$(generate_sentence 8 20)
    print_response "$opening"

    # Main read loop
    while true; do
        print_user_prompt

        # Read user input (with readline if available)
        local input
        if ! IFS= read -r input; then
            # EOF (Ctrl-D)
            printf "\n\n  %sBye!%s\n\n" "$C_BOLD$C_CYAN" "$C_RESET"
            break
        fi

        # Trim leading/trailing whitespace from input
        input=$(printf "%s" "$input" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # ── Command dispatch ─────────────────────────────────────────────
        case "${input,,}" in   # ${input,,} = lowercase (bash 4+)

            "quit" | "exit" | "q")
                printf "\n  %s👋 Goodbye!%s\n\n" "$C_BOLD$C_CYAN" "$C_RESET"
                break
                ;;

            "help" | "?" | "h")
                print_help
                ;;

            "stats")
                show_stats
                ;;

            "more")
                printf "\n  %sGenerating 5 sentences...%s\n" "$C_DIM" "$C_RESET"
                for i in {1..5}; do
                    local s
                    # Vary seed slightly for each iteration
                    s=$(generate_sentence 8 22 "$(date +%s%N)${i}")
                    print_response "$s"
                    # Small delay so seeds differ even on systems with low clock res
                    sleep 0.05
                done
                ;;

            "reload")
                printf "\n  %sReloading...%s\n" "$C_DIM" "$C_RESET"
                rm -f "$MODEL_FILE"
                build_model
                show_stats
                ;;

            "")
                # Empty input - just generate a random sentence
                local s
                s=$(generate_sentence 8 25)
                print_response "$s"
                ;;

            *)
                # User typed a word/topic - try to seed generation from it
                local s
                s=$(generate_seeded_from_word "$input" 8 25)
                print_response "$s"
                ;;

        esac
    done
}

# =============================================================================
# ENTRY POINT
# =============================================================================

main() {
    local corpus_file="${1:-}"

    # ── Draw banner ──────────────────────────────────────────────────────
    print_banner

    # ── Load corpus ──────────────────────────────────────────────────────
    printf "  %sLoading corpus...%s\n" "$C_DIM" "$C_RESET"
    load_corpus "$corpus_file"

    # ── Validate corpus has enough words ─────────────────────────────────
    if [[ "$WORD_COUNT" -lt 20 ]]; then
        printf "\n  %s⚠ Corpus is very small (%s words). Results may be poor.%s\n\n" \
            "$C_YELLOW" "$WORD_COUNT" "$C_RESET"
    fi

    # ── Build Markov model ───────────────────────────────────────────────
    build_model

    # ── Show model statistics ────────────────────────────────────────────
    show_stats

    # ── Enter interactive chat loop ──────────────────────────────────────
    run_chat
}

# Run main with all passed arguments
main "$@"
