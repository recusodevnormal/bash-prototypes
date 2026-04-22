#!/usr/bin/env bash
#
#  slot_filler.sh — Regex-Based "Slot Filler" (NER Lite)
#
#  A deterministic, regex-driven Named Entity Recognition tool that extracts
#  structured data (slots) from short natural-language commands.
#
#  Uses Bash's built-in regex engine ([[ $input =~ $pattern ]]) to capture
#  groups. No external dependencies — only standard GNU/Unix utilities.
#
#  Usage:
#      ./slot_filler.sh                              # interactive mode
#      ./slot_filler.sh "Move backup.tar to /tmp"    # one-shot mode
#

# ═══════════════════════════════════════════════════════════════════════════
#  Terminal Colours
# ═══════════════════════════════════════════════════════════════════════════
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[32m'
CYAN='\033[36m'
YELLOW='\033[33m'
MAGENTA='\033[35m'
RED='\033[31m'
BLUE='\033[34m'
WHITE='\033[37m'
RESET='\033[0m'

# ═══════════════════════════════════════════════════════════════════════════
#  Pattern Definitions
# ═══════════════════════════════════════════════════════════════════════════
#
#  Each pattern is stored as TWO consecutive array elements:
#      [2n]   POSIX Extended Regex with capture groups ()
#      [2n+1] Pipe-delimited slot names, mapping 1-to-1 to the groups
#
#  • Slot name "skip" / "skip2" = ignored group (e.g. filler prepositions).
#  • Patterns are tried top-to-bottom; first match wins.
#    → More-specific patterns must appear before generic fallbacks.
#  • ^ anchors to start; no $ anchor so trailing words are tolerated.
#
declare -a PATTERN_DEFS

# 1) Move / Copy / Transfer  <object>  to|into|->  <destination>
#    e.g. "Move backup.tar to /external/drive"
PATTERN_DEFS+=(
    "^(move|copy|transfer|mv|cp)[[:space:]]+([^[:space:]]+)[[:space:]]+(to|into|->)[[:space:]]+([^[:space:]]+)"
    "action|object|skip|destination"
)

# 2) Delete / Remove  <object>  from  <source>
#    e.g. "Delete old.log from /var/tmp"
PATTERN_DEFS+=(
    "^(delete|remove|rm|erase)[[:space:]]+([^[:space:]]+)[[:space:]]+from[[:space:]]+([^[:space:]]+)"
    "action|object|source"
)

# 3) Delete / Remove  <object>  (no source)
#    e.g. "Delete old.log"
PATTERN_DEFS+=(
    "^(delete|remove|rm|erase)[[:space:]]+([^[:space:]]+)"
    "action|object"
)

# 4) Rename  <object>  to|as  <new_name>
#    e.g. "Rename draft.txt to final.txt"
PATTERN_DEFS+=(
    "^(rename|ren)[[:space:]]+([^[:space:]]+)[[:space:]]+(to|as)[[:space:]]+([^[:space:]]+)"
    "action|object|skip|new_name"
)

# 5) Send / Email  <object>  to  <recipient>
#    e.g. "Send report.pdf to alice"
PATTERN_DEFS+=(
    "^(send|email|mail)[[:space:]]+([^[:space:]]+)[[:space:]]+to[[:space:]]+([^[:space:]]+)"
    "action|object|recipient"
)

# 6) Schedule / Run  <object>  at|on|by|every  <time>
#    e.g. "Run backup.sh at midnight"
#    e.g. "Schedule sync every 2 hours"
PATTERN_DEFS+=(
    "^(schedule|run|execute|launch)[[:space:]]+([^[:space:]]+)[[:space:]]+(at|on|by|every)[[:space:]]+([^[:space:]]+([[:space:]]+[^[:space:]]+)?)"
    "action|object|skip|time|skip2"
)

# 7) Create / Make  <object>  [in|at|under  <destination>]
#    e.g. "Create project in /home/user/projects"
#    e.g. "Make notes.txt"
PATTERN_DEFS+=(
    "^(create|make|mkdir|touch)[[:space:]]+([^[:space:]]+)([[:space:]]+(in|at|under)[[:space:]]+([^[:space:]]+))?"
    "action|object|skip|skip2|destination"
)

# 8) Download / Fetch  <object>  from  <source>
#    e.g. "Download archive.tar.gz from https://example.com/files"
PATTERN_DEFS+=(
    "^(download|fetch|pull|wget|curl)[[:space:]]+([^[:space:]]+)[[:space:]]+from[[:space:]]+([^[:space:]]+)"
    "action|object|source"
)

# 9) Generic fallback:  <verb>  [the]  <object>  <prep>  <target>
#    e.g. "Archive the logs to /backup"
PATTERN_DEFS+=(
    "^([a-zA-Z]+)[[:space:]]+(the[[:space:]]+)?([^[:space:]]+)[[:space:]]+(to|at|for|in|from)[[:space:]]+([^[:space:]]+)"
    "action|skip|object|skip2|target"
)

# ═══════════════════════════════════════════════════════════════════════════
#  Helper: Map a raw action keyword → present-participle verb
# ═══════════════════════════════════════════════════════════════════════════
action_to_verb() {
    case "$1" in
        move|mv)            printf "Moving" ;;
        copy|cp)            printf "Copying" ;;
        transfer)           printf "Transferring" ;;
        delete)             printf "Deleting" ;;
        remove|rm)          printf "Removing" ;;
        erase)              printf "Erasing" ;;
        rename|ren)         printf "Renaming" ;;
        send)               printf "Sending" ;;
        email)              printf "Emailing" ;;
        mail)               printf "Mailing" ;;
        schedule)           printf "Scheduling" ;;
        run)                printf "Running" ;;
        execute)            printf "Executing" ;;
        launch)             printf "Launching" ;;
        create|touch)       printf "Creating" ;;
        make)               printf "Making" ;;
        mkdir)              printf "Creating directory" ;;
        download|wget|curl) printf "Downloading" ;;
        fetch)              printf "Fetching" ;;
        pull)               printf "Pulling" ;;
        archive)            printf "Archiving" ;;
        push)               printf "Pushing" ;;
        backup)             printf "Backing up" ;;
        sync)               printf "Syncing" ;;
        upload)             printf "Uploading" ;;
        install)            printf "Installing" ;;
        *)                  printf "Processing" ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════════
#  Helper: Trim leading and trailing whitespace (pure Bash, no subshell)
# ═══════════════════════════════════════════════════════════════════════════
trim() {
    local var="$1"
    # Remove leading whitespace
    var="${var#"${var%%[![:space:]]*}"}"
    # Remove trailing whitespace
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

# ═══════════════════════════════════════════════════════════════════════════
#  UI Helpers
# ═══════════════════════════════════════════════════════════════════════════

# Draw a horizontal rule (pure Bash, no seq)
print_rule() {
    local rule=""
    for (( _i = 0; _i < 60; _i++ )); do
        rule+="─"
    done
    printf "${DIM}%s${RESET}\n" "$rule"
}

# Display the welcome banner
print_banner() {
    clear
    printf "\n"
    printf "${BOLD}${CYAN}  ╔══════════════════════════════════════════════╗${RESET}\n"
    printf "${BOLD}${CYAN}  ║${RESET}  ${BOLD}Slot Filler  —  NER Lite${RESET}                     ${BOLD}${CYAN}║${RESET}\n"
    printf "${BOLD}${CYAN}  ╠══════════════════════════════════════════════╣${RESET}\n"
    printf "${BOLD}${CYAN}  ║${RESET}  ${DIM}Regex-based entity extraction${RESET}                ${BOLD}${CYAN}║${RESET}\n"
    printf "${BOLD}${CYAN}  ╚══════════════════════════════════════════════╝${RESET}\n"
    printf "\n"
    printf "  ${DIM}Type a command in natural language, e.g.:${RESET}\n"
    printf "  ${YELLOW}  Move backup.tar to /external/drive${RESET}\n"
    printf "  ${YELLOW}  Delete old.log from /var/tmp${RESET}\n"
    printf "  ${YELLOW}  Rename draft.txt to final.txt${RESET}\n"
    printf "  ${YELLOW}  Send report.pdf to alice${RESET}\n"
    printf "  ${YELLOW}  Run backup.sh at midnight${RESET}\n"
    printf "\n"
    printf "  ${DIM}Type ${BOLD}help${RESET}${DIM} for patterns  ·  ${BOLD}quit${RESET}${DIM} to exit${RESET}\n"
    print_rule
    printf "\n"
}

# Show help text listing all supported patterns
print_help() {
    printf "\n  ${BOLD}Supported patterns:${RESET}\n"
    printf "  ${DIM}──────────────────────────────────────────────────${RESET}\n"
    printf "  ${YELLOW}%-14s${RESET}  %s\n" "Move/Copy"    "<object> to <destination>"
    printf "  ${YELLOW}%-14s${RESET}  %s\n" "Delete"       "<object> from <source>"
    printf "  ${YELLOW}%-14s${RESET}  %s\n" "Delete"       "<object>"
    printf "  ${YELLOW}%-14s${RESET}  %s\n" "Rename"       "<object> to <new_name>"
    printf "  ${YELLOW}%-14s${RESET}  %s\n" "Send/Email"   "<object> to <recipient>"
    printf "  ${YELLOW}%-14s${RESET}  %s\n" "Run"          "<object> at <time>"
    printf "  ${YELLOW}%-14s${RESET}  %s\n" "Create/Make"  "<object> [in <destination>]"
    printf "  ${YELLOW}%-14s${RESET}  %s\n" "Download"     "<object> from <source>"
    printf "  ${YELLOW}%-14s${RESET}  %s\n" "<any verb>"   "[the] <object> <prep> <target>"
    printf "\n"
}

# ═══════════════════════════════════════════════════════════════════════════
#  Core: Extract slots from a single input string
# ═══════════════════════════════════════════════════════════════════════════
#
#  Normalises the input (lowercase, collapsed whitespace), then tries each
#  regex pattern in order.  On the first match, walks BASH_REMATCH capture
#  groups and maps them to slot names.  Returns 0 on success, 1 otherwise.
#
extract_slots() {
    local input="$1"

    # ── Normalise: trim edges, collapse internal whitespace, lower-case ──
    local normalized
    normalized=$(printf '%s' "$input" \
        | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/[[:space:]]\{1,\}/ /g' \
        | tr '[:upper:]' '[:lower:]')

    # Bail out on blank input
    [[ -z "$normalized" ]] && return 1

    local found=0

    # ── Iterate over pattern definitions (step by 2: regex, then slots) ──
    local i
    for (( i = 0; i < ${#PATTERN_DEFS[@]}; i += 2 )); do
        local regex="${PATTERN_DEFS[$i]}"
        local slots_str="${PATTERN_DEFS[$((i + 1))]}"

        # ── Attempt the regex match via Bash's built-in engine ──
        if [[ "$normalized" =~ $regex ]]; then
            found=1

            # Split slot names on '|'
            local -a slot_names
            IFS='|' read -ra slot_names <<< "$slots_str"

            # Collect extracted slots for display and confirmation
            local -a found_names=()
            local -a found_values=()

            # Walk capture groups (BASH_REMATCH[0] = entire match, [1]+ = groups)
            local group_idx=1
            local slot_name
            for slot_name in "${slot_names[@]}"; do
                local value="${BASH_REMATCH[$group_idx]:-}"

                # Trim whitespace from the captured value
                value=$(trim "$value")

                # Record non-empty, non-skip slots
                if [[ -n "$value" && "$slot_name" != skip && "$slot_name" != skip2 ]]; then
                    found_names+=("$slot_name")
                    found_values+=("$value")
                fi

                ((group_idx++))
            done

            # ── Display extracted slots ──
            if [[ ${#found_names[@]} -gt 0 ]]; then
                printf "\n  ${GREEN}${BOLD}✓ Match found${RESET}\n\n"

                local j
                for (( j = 0; j < ${#found_names[@]}; j++ )); do
                    printf "  ${BOLD}${BLUE}%-14s${RESET} → ${BOLD}${MAGENTA}%s${RESET}\n" \
                        "${found_names[$j]}" "${found_values[$j]}"
                done

                # ── Build a human-readable confirmation sentence ──
                local action_word="" object_word="" target_word=""
                for (( j = 0; j < ${#found_names[@]}; j++ )); do
                    case "${found_names[$j]}" in
                        action) action_word="${found_values[$j]}"   ;;
                        object) object_word="${found_values[$j]}"   ;;
                        *)      target_word="${found_values[$j]}"   ;;
                    esac
                done

                local verb
                verb=$(action_to_verb "$action_word")

                printf "\n  ${DIM}⟶${RESET} "
                if [[ -n "$object_word" && -n "$target_word" ]]; then
                    printf "${BOLD}${WHITE}%s${RESET} ${CYAN}\"%s\"${RESET} → ${CYAN}\"%s\"${RESET}\n" \
                        "$verb" "$object_word" "$target_word"
                elif [[ -n "$object_word" ]]; then
                    printf "${BOLD}${WHITE}%s${RESET} ${CYAN}\"%s\"${RESET}\n" \
                        "$verb" "$object_word"
                else
                    printf "${BOLD}${WHITE}%s${RESET}\n" "$verb"
                fi
            else
                printf "\n  ${YELLOW}${BOLD}⚠ Pattern matched but no slots captured.${RESET}\n"
            fi

            printf "\n"
            break  # first match wins
        fi
    done

    # ── No pattern matched ──
    if [[ $found -eq 0 ]]; then
        printf "\n  ${RED}${BOLD}✗ No match${RESET}\n"
        printf "  ${DIM}Could not extract slots from that input.${RESET}\n"
        printf "  ${DIM}Try: ${YELLOW}Move file.txt to /destination${RESET}${DIM} or type ${BOLD}help${RESET}${DIM}.${RESET}\n\n"
        return 1
    fi

    return 0
}

# ═══════════════════════════════════════════════════════════════════════════
#  Main
# ═══════════════════════════════════════════════════════════════════════════
main() {
    # ── CLI help flag ──
    if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        printf "Usage: %s [\"command string\"]\n" "$0"
        printf "       %s --help\n\n" "$0"
        printf "Regex-based slot filler (NER Lite).\n"
        printf "Pass a quoted command as argument for one-shot mode,\n"
        printf "or run without arguments for interactive mode.\n\n"
        print_help
        exit 0
    fi

    # ── One-shot mode: argument supplied ──
    if [[ $# -gt 0 ]]; then
        extract_slots "$*"
        exit $?
    fi

    # ── Interactive mode ──
    print_banner

    local count=0
    local user_input

    while true; do
        # Prompt
        printf "  ${BOLD}${GREEN}▸${RESET} "

        # Handle Ctrl-D (EOF) gracefully
        if ! read -r user_input; then
            printf "\n\n  ${DIM}Goodbye! (%d extraction(s) performed)${RESET}\n\n" "$count"
            exit 0
        fi

        # Skip blank lines
        [[ -z "$user_input" ]] && continue

        # Quit command
        if [[ "$user_input" =~ ^[Qq](uit)?$ ]]; then
            printf "\n  ${DIM}Goodbye! (%d extraction(s) performed)${RESET}\n\n" "$count"
            exit 0
        fi

        # Help command
        if [[ "$user_input" =~ ^[Hh](elp)?$ ]]; then
            print_help
            continue
        fi

        # Attempt extraction
        if extract_slots "$user_input"; then
            ((count++))
        fi

        print_rule
    done
}

main "$@"