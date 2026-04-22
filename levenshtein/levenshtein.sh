#!/usr/bin/env bash
# =============================================================================
# FILE:        did_you_mean.sh
# DESCRIPTION: A "Did you mean?" tool using the Levenshtein edit-distance
#              algorithm to suggest corrections for mistyped commands/words.
#
# ALGORITHM:   Classic dynamic-programming Levenshtein distance.
#              For two strings a (length m) and b (length n), we build an
#              (m+1)×(n+1) matrix D where:
#
#              D[0][j] = j          (cost of inserting j chars)
#              D[i][0] = i          (cost of deleting i chars)
#              D[i][j] = min(
#                  D[i-1][j]   + 1,          -- deletion
#                  D[i][j-1]   + 1,          -- insertion
#                  D[i-1][j-1] + (a[i]≠b[j]) -- substitution (0 if equal)
#              )
#
#              The final answer is D[m][n].
#
# USAGE:       bash did_you_mean.sh
#              bash did_you_mean.sh --word <word>          (non-interactive)
#              bash did_you_mean.sh --dict /path/to/file   (custom dictionary)
#              bash did_you_mean.sh --help
#
# DEPENDENCIES: Bash ≥ 4.0, standard GNU/Unix utilities only (printf, grep,
#               sort, tput). No external programs required.
# =============================================================================

# ---------------------------------------------------------------------------
# Strict mode — catch errors early
# ---------------------------------------------------------------------------
set -euo pipefail

# ---------------------------------------------------------------------------
# ANSI colour / style helpers (gracefully degrade if no colour support)
# ---------------------------------------------------------------------------
if [[ -t 1 ]] && tput colors &>/dev/null && (( $(tput colors) >= 8 )); then
    BOLD=$(tput bold)
    DIM=$(tput dim   2>/dev/null || printf '')
    RESET=$(tput sgr0)
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    CYAN=$(tput setaf 6)
    MAGENTA=$(tput setaf 5)
    WHITE=$(tput setaf 7)
    BG_DARK=$(tput setab 0 2>/dev/null || printf '')
else
    BOLD='' DIM='' RESET='' RED='' GREEN='' YELLOW=''
    CYAN='' MAGENTA='' WHITE='' BG_DARK=''
fi

# ---------------------------------------------------------------------------
# Default configuration (overridable via CLI flags)
# ---------------------------------------------------------------------------
MAX_DISTANCE=3          # suggestions with distance > this are discarded
MAX_SUGGESTIONS=5       # maximum number of suggestions to display
DICT_FILE=""            # custom dictionary path (empty = built-in list)
SINGLE_WORD=""          # non-interactive single-word mode

# ---------------------------------------------------------------------------
# Built-in command dictionary
# Sourced when no --dict file is provided. Add or remove entries freely.
# ---------------------------------------------------------------------------
readonly -a BUILTIN_DICT=(
    # Shell / navigation
    cd ls pwd mkdir rmdir cp mv rm ln touch cat less more head tail
    find grep sed awk cut sort uniq wc tr tee xargs file stat
    # Text / editors
    nano vim vi emacs diff patch echo printf read
    # System / process
    ps top htop kill pkill pgrep nice renice jobs fg bg
    uname hostname uptime who whoami id groups
    # Network
    ping curl wget ssh scp rsync nc netcat nmap ifconfig ip
    # Archive / compression
    tar gzip gunzip zip unzip bzip2 bunzip2 xz
    # Permissions / ownership
    chmod chown chgrp umask sudo su
    # Package managers
    apt apt-get yum dnf pacman brew pip pip3 npm yarn cargo
    # Development
    git make gcc g++ clang python python3 ruby perl node java javac
    bash sh zsh fish dash
    # Disk / filesystem
    df du mount umount fdisk lsblk blkid fsck mkfs dd
    # Misc utilities
    date cal bc expr sleep wait true false yes tput clear reset
    history alias unalias export env set unset source
    man info help which type whereis locate updatedb
    cron crontab at watch
    # Common typos / near-misses people make (kept in list intentionally)
    exit quit logout reboot shutdown halt poweroff
)

# ---------------------------------------------------------------------------
# UI: print the header banner
# ---------------------------------------------------------------------------
ui_banner() {
    local width=62
    local title=" Levenshtein  \"Did You Mean?\"  Engine "
    local sub=" Edit-distance typo corrector — pure Bash "

    printf '\n'
    printf '%s%s%s\n' "${CYAN}${BOLD}" \
        "$(printf '═%.0s' $(seq 1 $width))" "${RESET}"
    printf '%s%s%-*s%s\n' "${BG_DARK}${CYAN}${BOLD}" \
        "║" $(( width - 1 )) "${title}" "${RESET}"
    printf '%s%s%-*s%s\n' "${BG_DARK}${DIM}" \
        "║" $(( width - 1 )) "${sub}" "${RESET}"
    printf '%s%s%s\n' "${CYAN}${BOLD}" \
        "$(printf '═%.0s' $(seq 1 $width))" "${RESET}"
    printf '\n'
}

# ---------------------------------------------------------------------------
# UI: print a labelled section divider
# ---------------------------------------------------------------------------
ui_section() {
    local label="${1:-}"
    printf '%s── %s %s\n' "${CYAN}" "${label}" \
        "${CYAN}$(printf '─%.0s' $(seq 1 $(( 55 - ${#label} ))))${RESET}"
}

# ---------------------------------------------------------------------------
# UI: show help / usage
# ---------------------------------------------------------------------------
show_help() {
    ui_banner
    printf '%sUSAGE%s\n' "${BOLD}" "${RESET}"
    printf '  %s%s%s [OPTIONS]\n\n' "${GREEN}" "$0" "${RESET}"
    printf '%sOPTIONS%s\n' "${BOLD}" "${RESET}"
    printf '  %-28s %s\n' \
        "${YELLOW}--word  <word>${RESET}"    "Check a single word and exit" \
        "${YELLOW}--dict  <file>${RESET}"    "Use a plain-text dictionary (one word per line)" \
        "${YELLOW}--max-dist  <n>${RESET}"   "Max edit distance to show (default: ${MAX_DISTANCE})" \
        "${YELLOW}--max-sugg  <n>${RESET}"   "Max suggestions to display (default: ${MAX_SUGGESTIONS})" \
        "${YELLOW}--help${RESET}"            "Show this help message"
    printf '\n%sEXAMPLES%s\n' "${BOLD}" "${RESET}"
    printf '  %s\n' \
        "bash did_you_mean.sh" \
        "bash did_you_mean.sh --word grpe" \
        "bash did_you_mean.sh --dict /usr/share/dict/words --max-dist 2"
    printf '\n'
    exit 0
}

# ---------------------------------------------------------------------------
# Parse CLI arguments
# ---------------------------------------------------------------------------
parse_args() {
    while (( $# )); do
        case "$1" in
            --help|-h)        show_help ;;
            --word|-w)        SINGLE_WORD="${2:?'--word requires a value'}"; shift ;;
            --dict|-d)        DICT_FILE="${2:?'--dict requires a file path'}";  shift ;;
            --max-dist|-D)    MAX_DISTANCE="${2:?'--max-dist requires a number'}"; shift ;;
            --max-sugg|-S)    MAX_SUGGESTIONS="${2:?'--max-sugg requires a number'}"; shift ;;
            *)  printf '%sUnknown option: %s%s\n' "${RED}" "$1" "${RESET}" >&2
                exit 1 ;;
        esac
        shift
    done

    # Validate numeric options
    if ! [[ "$MAX_DISTANCE"    =~ ^[0-9]+$ ]]; then
        printf '%s--max-dist must be a non-negative integer%s\n' "${RED}" "${RESET}" >&2
        exit 1
    fi
    if ! [[ "$MAX_SUGGESTIONS" =~ ^[0-9]+$ ]]; then
        printf '%s--max-sugg must be a non-negative integer%s\n' "${RED}" "${RESET}" >&2
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Load the word list into a global array DICTIONARY[]
# ---------------------------------------------------------------------------
load_dictionary() {
    if [[ -n "$DICT_FILE" ]]; then
        # Custom file: one word per line; strip blank lines and comments (#)
        if [[ ! -r "$DICT_FILE" ]]; then
            printf '%sError: cannot read dictionary file "%s"%s\n' \
                "${RED}" "${DICT_FILE}" "${RESET}" >&2
            exit 1
        fi
        mapfile -t DICTIONARY < <(
            grep -v '^\s*#' "$DICT_FILE" | grep -v '^\s*$' | tr '[:upper:]' '[:lower:]'
        )
    else
        # Use the built-in list
        DICTIONARY=("${BUILTIN_DICT[@]}")
    fi

    if (( ${#DICTIONARY[@]} == 0 )); then
        printf '%sError: dictionary is empty.%s\n' "${RED}" "${RESET}" >&2
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Soundex phonetic encoding (simplified American Soundex)
# Returns a 4-character code representing the sound of the word
# ---------------------------------------------------------------------------
soundex() {
    local word="${1,,}"  # lowercase
    word=$(echo "$word" | sed 's/[^a-z]//g')  # remove non-letters
    [[ -z "$word" ]] && { printf '0000'; return; }
    
    # Keep first letter
    local first="${word:0:1}"
    local rest="${word:1}"
    
    # Convert letters to numbers per Soundex rules
    # b,p,f,v -> 1; c,s,g,j,k,q,x,z -> 2; d,t -> 3; l -> 4; m,n -> 5; r -> 6
    local coded=$(echo "$rest" | sed \
        -e 's/[aeiouhwy]//g' \
        -e 's/[bfpv]/1/g' \
        -e 's/[cskgjxqz]/2/g' \
        -e 's/[dt]/3/g' \
        -e 's/[l]/4/g' \
        -e 's/[mn]/5/g' \
        -e 's/[r]/6/g')
    
    # Remove consecutive duplicates
    local prev=""
    local result=""
    for ((i=0; i<${#coded}; i++)); do
        local ch="${coded:$i:1}"
        [[ "$ch" == "$prev" ]] && continue
        result="${result}${ch}"
        prev="$ch"
    done
    
    # Pad or truncate to 3 digits, prepend first letter
    result="${first}${result}"
    result=$(echo "$result" | sed 's/^[a-z]//' | head -c 3)
    while [[ ${#result} -lt 3 ]]; do
        result="${result}0"
    done
    
    printf '%s%s' "$first" "$result"
}

# Calculate phonetic distance between two words (0 = same soundex, 1 = different)
phonetic_distance() {
    local a="$1"
    local b="$2"
    local sx_a=$(soundex "$a")
    local sx_b=$(soundex "$b")
    [[ "$sx_a" == "$sx_b" ]] && { printf '0'; return; }
    # Count character differences in soundex codes
    local diff=0
    for ((i=0; i<4; i++)); do
        local ca="${sx_a:$i:1}"
        local cb="${sx_b:$i:1}"
        [[ "$ca" != "$cb" ]] && ((diff++))
    done
    printf '%d' "$diff"
}

# ---------------------------------------------------------------------------
# levenshtein <string_a> <string_b>
#
# Prints the Levenshtein edit distance between the two strings.
#
# Implementation notes
# ─────────────────────
# We store only TWO rows of the DP matrix at a time (space optimisation):
#   prev_row  →  D[i-1][*]
#   curr_row  →  D[i][*]
#
# For each character a[i] (i = 1..m) we iterate over b[j] (j = 1..n) and
# apply the recurrence:
#
#   curr_row[j] = min(
#       prev_row[j]   + 1,          ← deletion   (remove a[i])
#       curr_row[j-1] + 1,          ← insertion  (insert b[j])
#       prev_row[j-1] + cost        ← substitution / match
#   )   where cost = 0 if a[i] == b[j], else 1
#
# All array indices are 0-based in Bash; prev_row[0] / curr_row[0] hold the
# "left border" values (pure insertions).
# ---------------------------------------------------------------------------
levenshtein() {
    local a="${1,,}"   # normalise to lower-case
    local b="${2,,}"

    local m=${#a}
    local n=${#b}

    # ── Fast-path: identical strings ─────────────────────────────────────
    [[ "$a" == "$b" ]] && { printf '0'; return; }

    # ── Fast-path: one string is empty ───────────────────────────────────
    (( m == 0 )) && { printf '%d' "$n"; return; }
    (( n == 0 )) && { printf '%d' "$m"; return; }

    # ── Initialise prev_row: D[0][j] = j for j = 0..n ───────────────────
    local -a prev_row curr_row
    local i j cost sub_cost

    for (( j = 0; j <= n; j++ )); do
        prev_row[j]=$j
    done

    # ── Fill row by row ──────────────────────────────────────────────────
    for (( i = 1; i <= m; i++ )); do

        # Left border: D[i][0] = i  (delete all chars of a[1..i])
        curr_row[0]=$i

        for (( j = 1; j <= n; j++ )); do

            # Substitution cost: 0 when characters match, 1 otherwise
            if [[ "${a:i-1:1}" == "${b:j-1:1}" ]]; then
                cost=0
            else
                cost=1
            fi

            # Deletion  : prev_row[j]   + 1
            # Insertion : curr_row[j-1] + 1
            # Sub/match : prev_row[j-1] + cost
            local del=$(( prev_row[j]   + 1 ))
            local ins=$(( curr_row[j-1] + 1 ))
            local sub=$(( prev_row[j-1] + cost ))

            # curr_row[j] = min(del, ins, sub)
            curr_row[j]=$del
            (( ins < curr_row[j] )) && curr_row[j]=$ins
            (( sub < curr_row[j] )) && curr_row[j]=$sub

        done

        # Slide: current row becomes previous row for next iteration
        prev_row=("${curr_row[@]}")
    done

    printf '%d' "${curr_row[n]}"
}

# ---------------------------------------------------------------------------
# find_suggestions <query>
#
# Iterates over DICTIONARY[], computes Levenshtein distance for each word,
# keeps entries with distance <= MAX_DISTANCE OR phonetically similar words,
# then prints them sorted by ascending distance (closest match first).
#
# Phonetic bonus: if words sound alike (Soundex match), reduce effective distance
#
# Output format (one line per candidate):
#   <distance> <word> [<phonetic_match>]
# ---------------------------------------------------------------------------
find_suggestions() {
    local query="${1,,}"      # normalise query to lower-case
    local -a results=()
    local word dist phonetic_adj is_phonetic

    for word in "${DICTIONARY[@]}"; do
        # Exact match — distance 0
        if [[ "${word,,}" == "$query" ]]; then
            results+=("0 ${word}")
            continue
        fi

        dist=$(levenshtein "$query" "$word")
        
        # Check phonetic similarity (Soundex)
        is_phonetic=""
        local pdist=$(phonetic_distance "$query" "$word")
        if (( pdist == 0 )); then
            # Same soundex - boost significantly (reduce effective distance)
            phonetic_adj=$(( dist > 1 ? dist - 2 : 0 ))
            is_phonetic="*"
            dist=$phonetic_adj
        fi

        if (( dist <= MAX_DISTANCE )); then
            results+=("${dist} ${word}${is_phonetic}")
        fi
    done

    # Sort numerically by distance (ascending), then alphabetically
    # Use printf | sort rather than an external sort on an array
    if (( ${#results[@]} > 0 )); then
        printf '%s\n' "${results[@]}" | sort -k1,1n -k2,2
    fi
}

# ---------------------------------------------------------------------------
# display_results <query> <sorted_results_string>
#
# Pretty-prints the suggestions table.
# ---------------------------------------------------------------------------
display_results() {
    local query="$1"
    local results="$2"

    # Count total lines in results
    local total
    total=$(printf '%s\n' "$results" | grep -c '.' || true)

    if [[ -z "$results" ]] || (( total == 0 )); then
        printf '\n  %s✗  No suggestions found within distance %d.%s\n\n' \
            "${RED}" "${MAX_DISTANCE}" "${RESET}"
        return
    fi

    # Exact match check (distance == 0)
    local first_dist
    first_dist=$(printf '%s\n' "$results" | awk 'NR==1{print $1}')

    printf '\n'
    if (( first_dist == 0 )); then
        local exact_word
        exact_word=$(printf '%s\n' "$results" | awk 'NR==1{print $2}')
        printf '  %s✔  "%s" is an exact match: %s%s%s\n\n' \
            "${GREEN}" "${query}" "${BOLD}" "${exact_word}" "${RESET}"
        # Remove the exact match from the remaining list
        results=$(printf '%s\n' "$results" | tail -n +2)
        total=$(( total - 1 ))
        (( total == 0 )) && return
        printf '  %sDid you also mean one of these?%s\n\n' "${DIM}" "${RESET}"
    else
        printf '  %s?  Did you mean…%s\n\n' "${YELLOW}${BOLD}" "${RESET}"
    fi

    # Table header
    printf '  %s%-6s  %-26s  %s%s\n' \
        "${BOLD}" "DIST" "SUGGESTION" "CLOSENESS" "${RESET}"
    printf '  %s%s%s\n' "${DIM}" "$(printf '─%.0s' $(seq 1 54))" "${RESET}"

    # Print up to MAX_SUGGESTIONS rows
    local count=0
    while IFS=' ' read -r dist word && (( count < MAX_SUGGESTIONS )); do

        # Check for phonetic match indicator (* suffix)
        local phonetic_mark=""
        if [[ "$word" == *\* ]]; then
            word="${word%\*}"  # Remove asterisk
            phonetic_mark="${MAGENTA}♪${RESET} "
        fi

        # Colour by distance
        local colour
        case "$dist" in
            0) colour="${GREEN}${BOLD}" ;;
            1) colour="${GREEN}"        ;;
            2) colour="${YELLOW}"       ;;
            *) colour="${RED}"          ;;
        esac

        # Visual closeness bar  (MAX_DISTANCE - dist filled blocks)
        local bar_filled=$(( MAX_DISTANCE - dist + 1 ))
        local bar_empty=$(( MAX_DISTANCE - bar_filled + 1 ))
        local bar
        bar="${GREEN}$(printf '█%.0s' $(seq 1 $bar_filled))${DIM}$(printf '░%.0s' $(seq 1 $bar_empty))${RESET}"

        printf '  %s%-6d%s  %s%-24s%s  %b\n' \
            "${colour}" "$dist" "${RESET}" \
            "${colour}${BOLD}" "${phonetic_mark}${word}" "${RESET}" \
            "$bar"

        (( count++ ))

    done < <(printf '%s\n' "$results")

    printf '\n'
    if (( total > MAX_SUGGESTIONS )); then
        printf '  %s  … and %d more (increase --max-sugg to see all)%s\n\n' \
            "${DIM}" "$(( total - MAX_SUGGESTIONS ))" "${RESET}"
    fi
}

# ---------------------------------------------------------------------------
# show_matrix_demo <word_a> <word_b>
#
# Optional visualisation: print the DP matrix for two short words so the
# user can see the algorithm working. Only shown in interactive mode when
# both words are ≤ 12 characters (to keep the table readable).
# ---------------------------------------------------------------------------
show_matrix_demo() {
    local a="${1,,}"
    local b="${2,,}"
    local m=${#a} n=${#b}

    # Build the full matrix (m+1 rows × n+1 cols)
    local -a M   # M[i*(n+1)+j]  — flat 1-D storage

    # Initialise borders
    local i j
    for (( i = 0; i <= m; i++ )); do M[i*(n+1)+0]=$i; done
    for (( j = 0; j <= n; j++ )); do M[0*(n+1)+j]=$j; done

    # Fill interior
    local cost del ins sub
    for (( i = 1; i <= m; i++ )); do
        for (( j = 1; j <= n; j++ )); do
            [[ "${a:i-1:1}" == "${b:j-1:1}" ]] && cost=0 || cost=1
            del=$(( M[(i-1)*(n+1)+j]   + 1 ))
            ins=$(( M[i*(n+1)+(j-1)]   + 1 ))
            sub=$(( M[(i-1)*(n+1)+(j-1)] + cost ))
            M[i*(n+1)+j]=$del
            (( ins < M[i*(n+1)+j] )) && M[i*(n+1)+j]=$ins
            (( sub < M[i*(n+1)+j] )) && M[i*(n+1)+j]=$sub
        done
    done

    # ── Print matrix ─────────────────────────────────────────────────────
    printf '\n'
    ui_section "DP Matrix  ( \"${a}\" → \"${b}\" )"
    printf '\n'

    # Header row: column labels (characters of b)
    printf '  %s    ε ' "${BOLD}"
    for (( j = 0; j < n; j++ )); do printf '%2s ' "${b:j:1}"; done
    printf '%s\n' "${RESET}"
    printf '  %s' "${DIM}"
    printf '─%.0s' $(seq 1 $(( (n + 2) * 3 + 4 )))
    printf '%s\n' "${RESET}"

    # Data rows: row label (character of a or ε), then cell values
    for (( i = 0; i <= m; i++ )); do
        # Row label
        if (( i == 0 )); then
            printf '  %sε%s │' "${BOLD}" "${RESET}"
        else
            printf '  %s%s%s │' "${BOLD}" "${a:i-1:1}" "${RESET}"
        fi

        for (( j = 0; j <= n; j++ )); do
            local val=${M[i*(n+1)+j]}
            # Highlight the final answer cell
            if (( i == m && j == n )); then
                printf ' %s%s%s' "${MAGENTA}${BOLD}" "$val" "${RESET}"
            elif (( val == 0 )); then
                printf ' %s%s%s' "${GREEN}" "$val" "${RESET}"
            else
                printf ' %s%2d%s' "${DIM}" "$val" "${RESET}"
            fi
        done
        printf '\n'
    done

    printf '\n  %sEdit distance = %s%s%s%s\n\n' \
        "${WHITE}" "${MAGENTA}${BOLD}" "${M[m*(n+1)+n]}" "${RESET}" "${WHITE}${RESET}"
}

# ---------------------------------------------------------------------------
# interactive_loop
#
# Runs the REPL: prompt → lookup → display → repeat.
# ---------------------------------------------------------------------------
interactive_loop() {
    local query

    printf '%sDictionary loaded: %s%d words%s\n' \
        "${DIM}" "${BOLD}" "${#DICTIONARY[@]}" "${RESET}"
    printf '%sSettings: max-dist=%s%d%s, max-sugg=%s%d%s\n\n' \
        "${DIM}" "${CYAN}" "$MAX_DISTANCE" "${DIM}" \
        "${CYAN}" "$MAX_SUGGESTIONS" "${RESET}"
    printf 'Type a word (or command) to check. '
    printf 'Special commands:\n'
    printf '  %s:matrix <a> <b>%s  — show DP matrix for two words\n' \
        "${YELLOW}" "${RESET}"
    printf '  %s:dict%s            — list dictionary words\n' \
        "${YELLOW}" "${RESET}"
    printf '  %s:settings%s        — show current settings\n' \
        "${YELLOW}" "${RESET}"
    printf '  %s:quit%s  or %s:exit%s  — leave\n\n' \
        "${YELLOW}" "${RESET}" "${YELLOW}" "${RESET}"

    while true; do
        # Prompt
        printf '%s❯ %s' "${CYAN}${BOLD}" "${RESET}"

        # Read input; handle EOF (Ctrl-D) gracefully
        if ! IFS= read -r query; then
            printf '\n'
            break
        fi

        # Strip leading/trailing whitespace
        query=$(printf '%s' "$query" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # Skip empty input
        [[ -z "$query" ]] && continue

        # ── Special REPL commands ─────────────────────────────────────
        case "$query" in
            :quit|:exit|:q)
                printf '\n%sGoodbye!%s\n\n' "${GREEN}${BOLD}" "${RESET}"
                break
                ;;
            :dict)
                ui_section "Dictionary (${#DICTIONARY[@]} words)"
                printf '%s\n' "${DICTIONARY[@]}" | sort | \
                    awk 'BEGIN{i=0} {printf "  %-18s", $0; if(++i%4==0) print ""}
                         END{if(i%4!=0) print ""}'
                printf '\n'
                continue
                ;;
            :settings)
                ui_section "Current Settings"
                printf '  max-dist  = %s%d%s\n' \
                    "${CYAN}" "$MAX_DISTANCE"    "${RESET}"
                printf '  max-sugg  = %s%d%s\n' \
                    "${CYAN}" "$MAX_SUGGESTIONS" "${RESET}"
                printf '  dict-src  = %s%s%s\n\n' \
                    "${CYAN}" "${DICT_FILE:-built-in}" "${RESET}"
                continue
                ;;
            :matrix*)
                # Extract the two words after ":matrix"
                local ma mb
                ma=$(printf '%s' "$query" | awk '{print $2}')
                mb=$(printf '%s' "$query" | awk '{print $3}')
                if [[ -z "$ma" || -z "$mb" ]]; then
                    printf '  %sUsage: :matrix <word_a> <word_b>%s\n\n' \
                        "${RED}" "${RESET}"
                elif (( ${#ma} > 12 || ${#mb} > 12 )); then
                    printf '  %sWords must be ≤ 12 characters for display.%s\n\n' \
                        "${YELLOW}" "${RESET}"
                else
                    show_matrix_demo "$ma" "$mb"
                fi
                continue
                ;;
        esac

        # ── Main lookup ───────────────────────────────────────────────
        ui_section "Query: \"${query}\""

        local results
        results=$(find_suggestions "$query")

        display_results "$query" "$results"

    done
}

# ---------------------------------------------------------------------------
# single_word_mode <word>
#
# Non-interactive: print results and exit. Suitable for scripting / pipes.
# ---------------------------------------------------------------------------
single_word_mode() {
    local word="$1"

    ui_section "Query: \"${word}\""
    local results
    results=$(find_suggestions "$word")
    display_results "$word" "$results"

    # Exit code: 0 if exact match found, 1 if suggestions only, 2 if nothing
    if printf '%s\n' "$results" | grep -q '^0 '; then
        exit 0
    elif [[ -n "$results" ]]; then
        exit 1
    else
        exit 2
    fi
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
main() {
    parse_args "$@"

    # Load word list before any output that depends on it
    load_dictionary

    ui_banner

    if [[ -n "$SINGLE_WORD" ]]; then
        single_word_mode "$SINGLE_WORD"
    else
        interactive_loop
    fi
}

# Entry point
main "$@"