#!/usr/bin/env bash
# =============================================================================
# FILE:    intent_scorer.sh
# DESC:    Weighted Keyword Intent Scorer with domain-adaptive terminal UI.
#          Scans user input, sums keyword weights, and shifts the bot's entire
#          personality to the highest-scoring domain when a threshold is met.
#
# USAGE:   chmod +x intent_scorer.sh && ./intent_scorer.sh
# DEPS:    bash 4.0+, standard GNU/Unix utils only (grep, awk, sed, printf)
# AUTHOR:  Written as a standalone offline demonstration script
# =============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 0: STRICT MODE
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
IFS=$'\n\t'

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 1: GLOBAL CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

# Minimum total weight needed to trigger a domain personality shift (configurable via -t)
THRESHOLD=10

# How many recent inputs to keep in session history (configurable via -l)
HISTORY_LIMIT=5

# Debug mode flag (configurable via -v)
DEBUG_MODE=false

# Session file path for save/load (configurable via -s)
SESSION_FILE="$HOME/.keyword_scorer_session.txt"

# Version tag shown in the header
readonly VERSION="1.4.0"

# Session history array (stores last N user inputs)
SESSION_HISTORY=()

# Currently active domain (default = "general")
ACTIVE_DOMAIN="general"

# Cumulative session scores per domain (carry-over across turns)
declare -A SESSION_SCORES
SESSION_SCORES=(
    [networking]=0
    [security]=0
    [hardware]=0
    [software]=0
    [general]=0
)

# ─────────────────────────────────────────────────────────────────────────────
# COMMAND-LINE ARGUMENT PARSING
# ─────────────────────────────────────────────────────────────────────────────

# ── print_usage ─────────────────────────────────────────────────────────────
# Prints usage information and available options.
print_usage() {
    printf "%bUsage:%b %s [OPTIONS]%b\n" "$BOLD_CYAN" "$0" "$RST"
    printf "\n"
    printf "%bOptions:%b\n" "$BOLD_WHITE" "$RST"
    printf "  %b-t <number>%b  Set threshold for domain shift (default: 10)\n" "$CYAN" "$RST"
    printf "  %b-l <number>%b  Set history limit (default: 5)\n" "$CYAN" "$RST"
    printf "  %b-v%b          Enable debug/verbose mode\n" "$CYAN" "$RST"
    printf "  %b-s <file>%b    Set session file path (default: ~/.keyword_scorer_session.txt)\n" "$CYAN" "$RST"
    printf "  %b-h%b          Show this help message\n" "$CYAN" "$RST"
    printf "\n"
    printf "%bExample:%b\n" "$BOLD_WHITE" "$RST"
    printf "  %s -t 15 -l 10 -v%b\n" "$0" "$RST"
}

# ── parse_arguments ──────────────────────────────────────────────────────────
# Parses command-line arguments and updates global configuration.
parse_arguments() {
    while getopts ":t:l:vs:h" opt; do
        case $opt in
            t)
                if [[ "$OPTARG" =~ ^[0-9]+$ ]] && (( OPTARG > 0 )); then
                    THRESHOLD="$OPTARG"
                else
                    printf "%b[ERROR] Threshold must be a positive integer.%b\n" "$RED" "$RST" >&2
                    exit 1
                fi
                ;;
            l)
                if [[ "$OPTARG" =~ ^[0-9]+$ ]] && (( OPTARG > 0 )); then
                    HISTORY_LIMIT="$OPTARG"
                else
                    printf "%b[ERROR] History limit must be a positive integer.%b\n" "$RED" "$RST" >&2
                    exit 1
                fi
                ;;
            v)
                DEBUG_MODE=true
                ;;
            s)
                SESSION_FILE="$OPTARG"
                ;;
            h)
                print_usage
                exit 0
                ;;
            \?)
                printf "%b[ERROR] Invalid option: -%b%s%b\n" "$RED" "$BOLD_RED" "$OPTARG" "$RST" >&2
                print_usage >&2
                exit 1
                ;;
            :)
                printf "%b[ERROR] Option -%b%s%b requires an argument.%b\n" "$RED" "$BOLD_RED" "$OPTARG" "$RST" >&2
                exit 1
                ;;
        esac
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 2: ANSI COLOR & STYLE DEFINITIONS
# ─────────────────────────────────────────────────────────────────────────────

# Reset
RST="\033[0m"

# Standard colors
BLACK="\033[0;30m"
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
MAGENTA="\033[0;35m"
CYAN="\033[0;36m"
WHITE="\033[0;37m"

# Bold variants
BOLD="\033[1m"
BOLD_RED="\033[1;31m"
BOLD_GREEN="\033[1;32m"
BOLD_YELLOW="\033[1;33m"
BOLD_BLUE="\033[1;34m"
BOLD_MAGENTA="\033[1;35m"
BOLD_CYAN="\033[1;36m"
BOLD_WHITE="\033[1;37m"

# Background colors (used for domain banners)
BG_BLUE="\033[44m"
BG_RED="\033[41m"
BG_GREEN="\033[42m"
BG_MAGENTA="\033[45m"
BG_BLACK="\033[40m"

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 3: DOMAIN PERSONALITY DEFINITIONS
#
# Each domain is defined as an associative array with the following keys:
#   COLOR       - primary ANSI color code for that personality
#   ICON        - ASCII/Unicode symbol used in prompts
#   LABEL       - human-readable domain name
#   PROMPT_TAG  - the string shown in the input prompt
#   BANNER_1    - first line printed when the domain becomes active
#   BANNER_2    - second line printed when the domain becomes active
#   RESPONSE_PREFIX - prefix shown in bot responses
# ─────────────────────────────────────────────────────────────────────────────

# ── NETWORKING ──────────────────────────────────────────────────────────────
declare -A DOMAIN_networking
DOMAIN_networking=(
    [COLOR]="$BOLD_CYAN"
    [ICON]="⇄"
    [LABEL]="Networking"
    [PROMPT_TAG]="NET"
    [BANNER_1]=" Switched to NETWORKING mode"
    [BANNER_2]=" Topics: routing, packets, protocols, subnets, DNS"
    [RESPONSE_PREFIX]="[NET-BOT]"
)

# ── SECURITY ────────────────────────────────────────────────────────────────
declare -A DOMAIN_security
DOMAIN_security=(
    [COLOR]="$BOLD_RED"
    [ICON]="⚠"
    [LABEL]="Security"
    [PROMPT_TAG]="SEC"
    [BANNER_1]=" Switched to SECURITY mode"
    [BANNER_2]=" Topics: encryption, CVEs, firewalls, auth, exploits"
    [RESPONSE_PREFIX]="[SEC-BOT]"
)

# ── HARDWARE ────────────────────────────────────────────────────────────────
declare -A DOMAIN_hardware
DOMAIN_hardware=(
    [COLOR]="$BOLD_YELLOW"
    [ICON]="⚙"
    [LABEL]="Hardware"
    [PROMPT_TAG]="HW"
    [BANNER_1]=" Switched to HARDWARE mode"
    [BANNER_2]=" Topics: CPU, RAM, disks, PCIe, voltage, cooling"
    [RESPONSE_PREFIX]="[HW-BOT]"
)

# ── SOFTWARE ────────────────────────────────────────────────────────────────
declare -A DOMAIN_software
DOMAIN_software=(
    [COLOR]="$BOLD_GREEN"
    [ICON]="</>"
    [LABEL]="Software"
    [PROMPT_TAG]="SW"
    [BANNER_1]=" Switched to SOFTWARE mode"
    [BANNER_2]=" Topics: code, APIs, compilers, debugging, packages"
    [RESPONSE_PREFIX]="[SW-BOT]"
)

# ── GENERAL (fallback) ───────────────────────────────────────────────────────
declare -A DOMAIN_general
DOMAIN_general=(
    [COLOR]="$BOLD_WHITE"
    [ICON]="?"
    [LABEL]="General"
    [PROMPT_TAG]="GEN"
    [BANNER_1]=" General mode active"
    [BANNER_2]=" No dominant domain detected yet"
    [RESPONSE_PREFIX]="[BOT]"
)

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 4: KEYWORD WEIGHT TABLES
#
# Format per domain: "keyword=weight" stored in an associative array.
# Higher weight = stronger signal for that domain.
# Words intentionally overlap across domains (e.g., "port" is in both
# networking and security) to test real-world ambiguity resolution.
# ─────────────────────────────────────────────────────────────────────────────

# ── NETWORKING KEYWORDS ──────────────────────────────────────────────────────
declare -A NET_WEIGHTS
NET_WEIGHTS=(
    [network]=5      [networking]=6   [router]=5      [switch]=4
    [packet]=5       [subnet]=6       [mask]=4        [gateway]=5
    [dns]=6          [dhcp]=6         [ip]=4          [tcp]=5
    [udp]=5          [icmp]=4         [ping]=4        [traceroute]=5
    [arp]=5          [mac]=3          [vlan]=6        [ospf]=7
    [bgp]=7          [nat]=5          [vpn]=5         [tunnel]=4
    [bandwidth]=4    [latency]=4      [throughput]=4  [socket]=4
    [port]=3         [interface]=4    [ethernet]=5    [wifi]=4
    [wireless]=4     [ssid]=5         [osi]=6         [layer]=3
    [protocol]=4     [http]=4         [https]=4       [ftp]=4
    [smtp]=5         [imap]=5         [pop3]=5        [snmp]=6
    [netmask]=6      [cidr]=6         [route]=5       [hop]=4
    [topology]=5     [mesh]=4         [star]=3        [bus]=3
)

# ── SECURITY KEYWORDS ────────────────────────────────────────────────────────
declare -A SEC_WEIGHTS
SEC_WEIGHTS=(
    [security]=5     [secure]=4       [encrypt]=6     [encryption]=7
    [decrypt]=6      [hash]=5         [cipher]=6      [ssl]=6
    [tls]=6          [certificate]=6  [vulnerability]=7 [exploit]=7
    [cve]=7          [malware]=7      [virus]=6       [ransomware]=7
    [phishing]=6     [injection]=6    [sqli]=8        [xss]=7
    [csrf]=7         [mitm]=7         [firewall]=6    [ids]=6
    [ips]=5          [siem]=7         [pen]=4         [pentest]=8
    [audit]=5        [compliance]=5   [password]=4    [auth]=5
    [authentication]=6 [authorization]=6 [token]=5   [jwt]=7
    [oauth]=7        [2fa]=7          [mfa]=7         [privilege]=5
    [escalation]=6   [rootkit]=8      [backdoor]=8    [payload]=6
    [shellcode]=8    [buffer]=5       [overflow]=6    [patch]=4
    [zero-day]=9     [zeroday]=9      [threat]=5      [risk]=4
    [port]=3         [scan]=4         [nmap]=8        [metasploit]=9
)

# ── HARDWARE KEYWORDS ────────────────────────────────────────────────────────
declare -A HW_WEIGHTS
HW_WEIGHTS=(
    [hardware]=5     [cpu]=6          [processor]=6   [core]=4
    [thread]=3       [clock]=4        [ghz]=5         [mhz]=4
    [ram]=6          [memory]=4       [ddr]=6         [dimm]=7
    [cache]=5        [l1]=6           [l2]=6          [l3]=6
    [disk]=5         [ssd]=6          [hdd]=6         [nvme]=7
    [sata]=6         [pcie]=7         [pci]=5         [m2]=7
    [gpu]=6          [vram]=7         [motherboard]=8 [bios]=7
    [uefi]=7         [firmware]=5     [driver]=4      [thermal]=5
    [cooling]=5      [heatsink]=7     [fan]=4         [voltage]=6
    [psu]=7          [watt]=5         [overclocking]=8 [overclock]=8
    [benchmark]=5    [socket]=4       [chipset]=7     [northbridge]=8
    [southbridge]=8  [usb]=4          [hdmi]=5        [displayport]=6
    [thunderbolt]=7  [raid]=6         [nas]=6         [san]=6
    [ecc]=7          [register]=4     [interrupt]=5   [dma]=6
)

# ── SOFTWARE KEYWORDS ────────────────────────────────────────────────────────
declare -A SW_WEIGHTS
SW_WEIGHTS=(
    [software]=5     [code]=4         [coding]=5      [program]=4
    [programming]=5  [script]=4       [scripting]=5   [function]=4
    [variable]=4     [loop]=4         [array]=4       [object]=5
    [class]=5        [method]=5       [api]=6         [library]=5
    [framework]=6    [module]=5       [package]=5     [dependency]=6
    [compiler]=6     [interpreter]=6  [runtime]=6     [debug]=5
    [debugger]=6     [bug]=4          [error]=4       [exception]=5
    [stack]=4        [heap]=5         [memory]=3      [pointer]=6
    [reference]=4    [git]=6          [github]=6      [commit]=5
    [branch]=5       [merge]=5        [pull]=4        [push]=4
    [docker]=7       [container]=6    [kubernetes]=8  [devops]=7
    [ci]=5           [cd]=4           [pipeline]=5    [deploy]=5
    [database]=5     [sql]=6          [nosql]=6       [orm]=6
    [regex]=6        [algorithm]=6    [datastructure]=7 [recursion]=6
    [refactor]=6     [unittest]=7     [tdd]=7         [agile]=6
)

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 5: UTILITY FUNCTIONS
# ─────────────────────────────────────────────────────────────────────────────

# ── get_terminal_width ───────────────────────────────────────────────────────
# Returns the current terminal column count (fallback: 80)
get_terminal_width() {
    local width
    width=$(tput cols 2>/dev/null) || width=80
    echo "$width"
}

# ── draw_separator ───────────────────────────────────────────────────────────
# Draws a horizontal rule using the given character and color.
# Usage: draw_separator <char> <color_code>
draw_separator() {
    local char="${1:─}"       # default to em-dash
    local color="${2:-$RST}"
    local width
    width=$(get_terminal_width)
    local line
    # Build a line of 'width' repetitions of char using printf + sed
    line=$(printf "%${width}s" | sed "s/ /${char}/g")
    printf "%b%s%b\n" "$color" "$line" "$RST"
}

# ── center_text ──────────────────────────────────────────────────────────────
# Centers a string within the terminal width.
# Usage: center_text "string" [color_code]
center_text() {
    local text="$1"
    local color="${2:-$RST}"
    local width
    width=$(get_terminal_width)
    # Strip ANSI codes from text to get printable length
    local plain_text
    plain_text=$(printf "%s" "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local text_len=${#plain_text}
    local pad=$(( (width - text_len) / 2 ))
    printf "%${pad}s"          # left padding spaces
    printf "%b%s%b\n" "$color" "$text" "$RST"
}

# ── domain_var ───────────────────────────────────────────────────────────────
# Helper: returns the value of a domain-specific attribute by name.
# Usage: domain_var <domain> <attribute>
# Example: domain_var "networking" "COLOR"  →  prints the color code
domain_var() {
    local domain="$1"
    local attr="$2"
    local -n domain_array="DOMAIN_${domain}"
    printf "%s" "${domain_array[$attr]}"
}

# ── lowercase ────────────────────────────────────────────────────────────────
# Converts a string to lowercase using tr (POSIX-safe).
lowercase() {
    printf "%s" "$1" | tr '[:upper:]' '[:lower:]'
}

# ── strip_punctuation ────────────────────────────────────────────────────────
# Removes punctuation from input, leaving words and spaces.
strip_punctuation() {
    printf "%s" "$1" | sed 's/[^a-zA-Z0-9 ]/ /g'
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 6: SCORING ENGINE
# ─────────────────────────────────────────────────────────────────────────────

# ── score_input ──────────────────────────────────────────────────────────────
# Main scoring function.
# Tokenises the input string, looks each token up in all four domain weight
# tables, accumulates per-domain totals, then outputs results to stdout as
# "domain:score" lines (one per domain, sorted descending).
#
# Usage: score_input "user input string"
# Prints: "networking:14\nsecurity:3\nhardware:0\nsoftware:2"  (example)
score_input() {
    local input="$1"

    # Normalise: lowercase, strip punctuation
    local normalised
    normalised=$(lowercase "$(strip_punctuation "$input")")

    # Debug: show normalised input
    if [[ "$DEBUG_MODE" == true ]]; then
        printf "%b[DEBUG] Original input: %b%s%b\n" "$BOLD_YELLOW" "$WHITE" "$input" "$RST"
        printf "%b[DEBUG] Normalised: %b%s%b\n" "$BOLD_YELLOW" "$WHITE" "$normalised" "$RST"
    fi

    # Declare local score counters
    local score_net=0
    local score_sec=0
    local score_hw=0
    local score_sw=0

    # Debug: track matched keywords per domain
    local -a matched_net=()
    local -a matched_sec=()
    local -a matched_hw=()
    local -a matched_sw=()

    # Tokenise by splitting on whitespace (use read with IFS)
    local token
    for token in $normalised; do
        # Skip very short tokens (1–2 chars are usually noise)
        [[ ${#token} -lt 2 ]] && continue

        # ── Networking lookup ──────────────────────────────────────────────
        if [[ -n "${NET_WEIGHTS[$token]+_}" ]]; then
            local weight="${NET_WEIGHTS[$token]}"
            score_net=$(( score_net + weight ))
            matched_net+=("$token($weight)")
            if [[ "$DEBUG_MODE" == true ]]; then
                printf "%b[DEBUG] Matched networking: %b%s%b (weight: %d)%b\n" \
                    "$BOLD_YELLOW" "$CYAN" "$token" "$CYAN" "$weight" "$RST"
            fi
        fi

        # ── Security lookup ────────────────────────────────────────────────
        if [[ -n "${SEC_WEIGHTS[$token]+_}" ]]; then
            local weight="${SEC_WEIGHTS[$token]}"
            score_sec=$(( score_sec + weight ))
            matched_sec+=("$token($weight)")
            if [[ "$DEBUG_MODE" == true ]]; then
                printf "%b[DEBUG] Matched security: %b%s%b (weight: %d)%b\n" \
                    "$BOLD_YELLOW" "$RED" "$token" "$RED" "$weight" "$RST"
            fi
        fi

        # ── Hardware lookup ────────────────────────────────────────────────
        if [[ -n "${HW_WEIGHTS[$token]+_}" ]]; then
            local weight="${HW_WEIGHTS[$token]}"
            score_hw=$(( score_hw + weight ))
            matched_hw+=("$token($weight)")
            if [[ "$DEBUG_MODE" == true ]]; then
                printf "%b[DEBUG] Matched hardware: %b%s%b (weight: %d)%b\n" \
                    "$BOLD_YELLOW" "$YELLOW" "$token" "$YELLOW" "$weight" "$RST"
            fi
        fi

        # ── Software lookup ────────────────────────────────────────────────
        if [[ -n "${SW_WEIGHTS[$token]+_}" ]]; then
            local weight="${SW_WEIGHTS[$token]}"
            score_sw=$(( score_sw + weight ))
            matched_sw+=("$token($weight)")
            if [[ "$DEBUG_MODE" == true ]]; then
                printf "%b[DEBUG] Matched software: %b%s%b (weight: %d)%b\n" \
                    "$BOLD_YELLOW" "$GREEN" "$token" "$GREEN" "$weight" "$RST"
            fi
        fi
    done

    # Debug: show matched keywords summary
    if [[ "$DEBUG_MODE" == true ]]; then
        printf "%b[DEBUG] Matched keywords:%b\n" "$BOLD_YELLOW" "$RST"
        [[ ${#matched_net[@]} -gt 0 ]] && printf "%b[DEBUG]   Networking: %b%s%b\n" "$BOLD_YELLOW" "$CYAN" "${matched_net[*]}" "$RST"
        [[ ${#matched_sec[@]} -gt 0 ]] && printf "%b[DEBUG]   Security: %b%s%b\n" "$BOLD_YELLOW" "$RED" "${matched_sec[*]}" "$RST"
        [[ ${#matched_hw[@]} -gt 0 ]] && printf "%b[DEBUG]   Hardware: %b%s%b\n" "$BOLD_YELLOW" "$YELLOW" "${matched_hw[*]}" "$RST"
        [[ ${#matched_sw[@]} -gt 0 ]] && printf "%b[DEBUG]   Software: %b%s%b\n" "$BOLD_YELLOW" "$GREEN" "${matched_sw[*]}" "$RST"
        printf "%b[DEBUG] Final scores: NET=%d SEC=%d HW=%d SW=%b%d%b\n\n" \
            "$BOLD_YELLOW" "$score_net" "$score_sec" "$score_hw" "$GREEN" "$score_sw" "$RST"
    fi

    # Emit results; caller will parse and sort these
    printf "networking:%d\n" "$score_net"
    printf "security:%d\n"   "$score_sec"
    printf "hardware:%d\n"   "$score_hw"
    printf "software:%d\n"   "$score_sw"
}

# ── determine_domain ─────────────────────────────────────────────────────────
# Given scored output from score_input(), picks the winning domain.
# Applies the THRESHOLD: if the top score is below it, returns "general".
# Also updates SESSION_SCORES for cumulative carry-over.
#
# Usage: determine_domain "networking:14\nsecurity:3\nhardware:0\nsoftware:2"
# Prints: the winning domain string (e.g., "networking")
#
# Side effect: updates global SESSION_SCORES array
determine_domain() {
    local scored_output="$1"

    local top_domain="general"
    local top_score=0

    # Parse each "domain:score" line
    while IFS=: read -r domain score; do
        [[ -z "$domain" || -z "$score" ]] && continue

        # Accumulate into session totals
        SESSION_SCORES[$domain]=$(( SESSION_SCORES[$domain] + score ))

        # Track the best score from THIS input alone (not session total)
        if (( score > top_score )); then
            top_score=$score
            top_domain=$domain
        fi
    done <<< "$scored_output"

    # Apply threshold: must meet or exceed THRESHOLD to shift domain
    if (( top_score < THRESHOLD )); then
        # Check if any session total now qualifies (slow burn detection)
        local session_top_domain="general"
        local session_top_score=0
        for d in networking security hardware software; do
            if (( SESSION_SCORES[$d] > session_top_score )); then
                session_top_score=${SESSION_SCORES[$d]}
                session_top_domain=$d
            fi
        done

        # Session total must be at least 2x the threshold to trigger
        if (( session_top_score >= THRESHOLD * 2 )); then
            top_domain="$session_top_domain"
        else
            top_domain="general"
        fi
    fi

    printf "%s" "$top_domain"
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 7: UI RENDERING FUNCTIONS
# ─────────────────────────────────────────────────────────────────────────────

# ── draw_main_header ─────────────────────────────────────────────────────────
# Prints the application title block (shown once at startup).
draw_main_header() {
    clear
    local width
    width=$(get_terminal_width)
    local color="$BOLD_CYAN"

    draw_separator "═" "$color"
    center_text "WEIGHTED KEYWORD INTENT SCORER" "$color"
    center_text "Version ${VERSION}  │  Offline Mode  │  Bash-native" "$CYAN"
    draw_separator "═" "$color"
    printf "\n"
}

# ── draw_domain_banner ───────────────────────────────────────────────────────
# Prints a styled banner whenever the active domain changes.
# Usage: draw_domain_banner <domain>
draw_domain_banner() {
    local domain="$1"
    local color
    local label
    local banner1
    local banner2
    local icon

    color=$(domain_var "$domain" "COLOR")
    label=$(domain_var "$domain" "LABEL")
    banner1=$(domain_var "$domain" "BANNER_1")
    banner2=$(domain_var "$domain" "BANNER_2")
    icon=$(domain_var "$domain" "ICON")

    printf "\n"
    draw_separator "─" "$color"
    printf "%b  %s  %s  %s  %b\n" \
        "$color" "$icon" "$banner1" "$icon" "$RST"
    printf "%b  %s%b\n" "$color" "$banner2" "$RST"
    draw_separator "─" "$color"
    printf "\n"
}

# ── draw_score_breakdown ─────────────────────────────────────────────────────
# Renders a visual bar chart of per-domain scores for the current input.
# Usage: draw_score_breakdown <scored_output_string>
draw_score_breakdown() {
    local scored_output="$1"
    local width
    width=$(get_terminal_width)
    # Reserve chars for label + brackets + score
    local bar_area=$(( width - 22 ))
    [[ $bar_area -lt 10 ]] && bar_area=10

    # Find the maximum score for proportional bar scaling
    local max_score=1   # avoid div-by-zero
    while IFS=: read -r domain score; do
        (( score > max_score )) && max_score=$score
    done <<< "$scored_output"

    printf "%b  ┌─ Score Breakdown ──────────────────────────%b\n" \
        "$BOLD_WHITE" "$RST"

    # Define display order and colors per domain
    local domains=("networking" "security" "hardware" "software")
    local domain_colors=(
        "$BOLD_CYAN" "$BOLD_RED" "$BOLD_YELLOW" "$BOLD_GREEN"
    )

    local i=0
    for domain in "${domains[@]}"; do
        # Extract this domain's score from the scored_output string
        local score
        score=$(printf "%s" "$scored_output" \
            | grep "^${domain}:" \
            | awk -F: '{print $2}')
        score="${score:-0}"

        # Calculate bar length proportional to max
        local bar_len=0
        if (( max_score > 0 )); then
            bar_len=$(( score * bar_area / max_score ))
        fi

        # Build the bar string using printf + sed
        local bar=""
        if (( bar_len > 0 )); then
            bar=$(printf "%${bar_len}s" | sed 's/ /█/g')
        fi

        # Pad remaining space with dots for visual clarity
        local empty_len=$(( bar_area - bar_len ))
        local empty=""
        if (( empty_len > 0 )); then
            empty=$(printf "%${empty_len}s" | sed 's/ /·/g')
        fi

        local dc="${domain_colors[$i]}"
        local label
        label=$(domain_var "$domain" "LABEL")

        # Format: "  │ LABEL      [████·····] score"
        printf "%b  │ %-12s [%b%s%b%s] %b%d%b\n" \
            "$BOLD_WHITE" "$label" \
            "$dc" "$bar" \
            "$WHITE" "$empty" \
            "$dc" "$score" "$RST"

        (( i++ ))
    done

    printf "%b  └────────────────────────────────────────────%b\n\n" \
        "$BOLD_WHITE" "$RST"
}

# ── draw_session_summary ─────────────────────────────────────────────────────
# Prints cumulative session scores and recent history.
draw_session_summary() {
    local color="$BOLD_WHITE"

    printf "%b┌──────────── SESSION SUMMARY ───────────────┐%b\n" \
        "$color" "$RST"

    # Cumulative scores
    printf "%b│%b %-44s %b│%b\n" \
        "$color" "$RST" "Cumulative domain totals:" "$color" "$RST"

    for domain in networking security hardware software; do
        local dc
        dc=$(domain_var "$domain" "COLOR")
        local label
        label=$(domain_var "$domain" "LABEL")
        printf "%b│%b   %-15s : %b%-5d%b %b│%b\n" \
            "$color" "$RST" "$label" \
            "$dc" "${SESSION_SCORES[$domain]}" "$RST" \
            "$color" "$RST"
    done

    # Recent history
    printf "%b│%b %-44s %b│%b\n" \
        "$color" "$RST" "" "$color" "$RST"
    printf "%b│%b %-44s %b│%b\n" \
        "$color" "$RST" "Recent inputs:" "$color" "$RST"

    local hist_count=${#SESSION_HISTORY[@]}
    local start=0
    if (( hist_count > 3 )); then
        start=$(( hist_count - 3 ))
    fi

    local idx=$start
    while (( idx < hist_count )); do
        local entry="${SESSION_HISTORY[$idx]}"
        # Truncate long entries for display
        local display="${entry:0:40}"
        [[ ${#entry} -gt 40 ]] && display="${display}..."
        printf "%b│%b   [%d] %-41s %b│%b\n" \
            "$color" "$RST" \
            "$(( idx + 1 ))" "$display" \
            "$color" "$RST"
        (( idx++ ))
    done

    printf "%b└────────────────────────────────────────────┘%b\n\n" \
        "$color" "$RST"
}

# ── draw_bot_response ────────────────────────────────────────────────────────
# Prints a domain-flavoured response to the user's input.
# In a real bot this would call an NLP backend; here we use canned messages
# that adapt to the detected domain.
#
# Usage: draw_bot_response <domain> <user_input>
draw_bot_response() {
    local domain="$1"
    local user_input="$2"
    local color
    color=$(domain_var "$domain" "COLOR")
    local prefix
    prefix=$(domain_var "$domain" "RESPONSE_PREFIX")

    # Canned contextual responses per domain
    local response
    case "$domain" in
        networking)
            response="I detected networking context in your query. \
I can help with IP addressing, routing protocols (OSPF/BGP), \
VLANs, DNS resolution, packet analysis, and network topology design."
            ;;
        security)
            response="Security context detected. I can assist with \
vulnerability assessment, CVE analysis, encryption algorithms, \
penetration testing methodology, authentication flows, and threat modelling."
            ;;
        hardware)
            response="Hardware context identified. Topics I can cover: \
CPU architecture, memory hierarchies, storage interfaces (NVMe/SATA), \
PCIe lanes, thermal design, BIOS/UEFI configuration, and benchmarking."
            ;;
        software)
            response="Software development context recognised. I'm ready \
to discuss algorithms, data structures, APIs, debugging strategies, \
containerisation, CI/CD pipelines, and software architecture patterns."
            ;;
        general)
            response="I haven't detected a strong domain signal yet. \
Keep talking — once your input crosses the scoring threshold, I'll \
shift into a specialised mode. Try mentioning specific technical terms."
            ;;
    esac

    printf "%b%s%b %s\n\n" "$color" "$prefix" "$RST" "$response"
}

# ── draw_prompt ──────────────────────────────────────────────────────────────
# Renders the input prompt styled to the active domain.
# Usage: draw_prompt <domain>  (does NOT read input — just prints prompt)
draw_prompt() {
    local domain="$1"
    local color
    color=$(domain_var "$domain" "COLOR")
    local tag
    tag=$(domain_var "$domain" "PROMPT_TAG")
    local icon
    icon=$(domain_var "$domain" "ICON")

    printf "%b[%s]%b %b%s%b » " \
        "$color" "$tag" "$RST" \
        "$BOLD_WHITE" "$icon" "$RST"
}

# ── draw_help_panel ──────────────────────────────────────────────────────────
# Shows the available commands.
draw_help_panel() {
    local c="$BOLD_CYAN"
    printf "\n%b┌──────────── COMMANDS ───────────────────────┐%b\n" \
        "$c" "$RST"
    printf "%b│%b  %-12s - %-30s %b│%b\n" \
        "$c" "$RST" ":help"    "Show this panel"          "$c" "$RST"
    printf "%b│%b  %-12s - %-30s %b│%b\n" \
        "$c" "$RST" ":history" "Show session history"     "$c" "$RST"
    printf "%b│%b  %-12s - %-30s %b│%b\n" \
        "$c" "$RST" ":scores"  "Show session score totals" "$c" "$RST"
    printf "%b│%b  %-12s - %-30s %b│%b\n" \
        "$c" "$RST" ":save"    "Save session to file"     "$c" "$RST"
    printf "%b│%b  %-12s - %-30s %b│%b\n" \
        "$c" "$RST" ":load"    "Load session from file"   "$c" "$RST"
    printf "%b│%b  %-12s - %-30s %b│%b\n" \
        "$c" "$RST" ":reset"   "Reset all scores/history" "$c" "$RST"
    printf "%b│%b  %-12s - %-30s %b│%b\n" \
        "$c" "$RST" ":demo"    "Run a demo sequence"      "$c" "$RST"
    printf "%b│%b  %-12s - %-30s %b│%b\n" \
        "$c" "$RST" ":debug"   "Toggle debug mode"        "$c" "$RST"
    printf "%b│%b  %-12s - %-30s %b│%b\n" \
        "$c" "$RST" ":quit"    "Exit the program"         "$c" "$RST"
    printf "%b└─────────────────────────────────────────────┘%b\n\n" \
        "$c" "$RST"
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 8: COMMAND HANDLERS
# ─────────────────────────────────────────────────────────────────────────────

# ── handle_reset ─────────────────────────────────────────────────────────────
handle_reset() {
    ACTIVE_DOMAIN="general"
    SESSION_HISTORY=()
    for d in networking security hardware software general; do
        SESSION_SCORES[$d]=0
    done
    printf "%b[SYSTEM] All scores and history cleared. Domain reset to General.%b\n\n" \
        "$BOLD_YELLOW" "$RST"
}

# ── handle_history ───────────────────────────────────────────────────────────
handle_history() {
    if (( ${#SESSION_HISTORY[@]} == 0 )); then
        printf "%b[SYSTEM] No history yet.%b\n\n" "$BOLD_YELLOW" "$RST"
        return
    fi
    printf "%b┌──────────── INPUT HISTORY ─────────────────┐%b\n" \
        "$BOLD_WHITE" "$RST"
    local i=0
    for entry in "${SESSION_HISTORY[@]}"; do
        printf "%b│%b [%02d] %s\n" "$BOLD_WHITE" "$RST" \
            "$(( i + 1 ))" "$entry"
        (( i++ ))
    done
    printf "%b└────────────────────────────────────────────┘%b\n\n" \
        "$BOLD_WHITE" "$RST"
}

# ── handle_demo ──────────────────────────────────────────────────────────────
# Sends a pre-scripted sequence of inputs through the scorer automatically.
handle_demo() {
    local demo_inputs=(
        "How do I configure BGP routing between two routers?"
        "What is the difference between TCP and UDP protocols?"
        "My SSH keys are not working and I suspect a MITM attack"
        "Explain buffer overflow exploitation and stack canaries"
        "The NVMe SSD is reporting high latency; could it be thermal throttling?"
        "What PCIe lanes does a modern GPU require?"
        "Help me refactor this Python function to use generators"
        "Explain how Docker containers differ from virtual machines"
    )

    printf "%b[DEMO] Starting automated demo sequence...%b\n\n" \
        "$BOLD_MAGENTA" "$RST"
    sleep 1

    for input in "${demo_inputs[@]}"; do
        printf "%bDEMO INPUT:%b %s\n" "$BOLD_MAGENTA" "$RST" "$input"
        sleep 0.5
        process_input "$input"
        sleep 1
    done

    printf "%b[DEMO] Demo complete.%b\n\n" "$BOLD_MAGENTA" "$RST"
}

# ── handle_scores ─────────────────────────────────────────────────────────────
handle_scores() {
    draw_session_summary
}

# ── handle_save ──────────────────────────────────────────────────────────────
# Saves current session state (scores, history, active domain) to file.
handle_save() {
    local file="${1:-$SESSION_FILE}"

    # Create directory if it doesn't exist
    local dir
    dir=$(dirname "$file")
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
    fi

    # Write session data to file
    {
        printf "# Keyword Scorer Session State\n"
        printf "# Generated: %s\n" "$(date)"
        printf "ACTIVE_DOMAIN=%s\n" "$ACTIVE_DOMAIN"
        printf "\n"
        printf "# Session Scores\n"
        for d in networking security hardware software general; do
            printf "SESSION_SCORES[%s]=%d\n" "$d" "${SESSION_SCORES[$d]}"
        done
        printf "\n"
        printf "# Session History\n"
        printf "HISTORY_COUNT=%d\n" "${#SESSION_HISTORY[@]}"
        for i in "${!SESSION_HISTORY[@]}"; do
            printf "HISTORY[%d]=%s\n" "$i" "${SESSION_HISTORY[$i]}"
        done
    } > "$file"

    printf "%b[SYSTEM] Session saved to: %b%s%b\n\n" "$BOLD_GREEN" "$CYAN" "$file" "$RST"
}

# ── handle_load ──────────────────────────────────────────────────────────────
# Loads session state from file.
handle_load() {
    local file="${1:-$SESSION_FILE}"

    if [[ ! -f "$file" ]]; then
        printf "%b[ERROR] Session file not found: %b%s%b\n\n" "$RED" "$CYAN" "$file" "$RST"
        return
    fi

    # Source the file to restore state
    # Use a subshell to avoid polluting the global namespace
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ "$key" =~ ^# ]] && continue
        [[ -z "$key" ]] && continue

        # Parse ACTIVE_DOMAIN
        if [[ "$key" == "ACTIVE_DOMAIN" ]]; then
            ACTIVE_DOMAIN="$value"
        # Parse SESSION_SCORES
        elif [[ "$key" =~ ^SESSION_SCORES\[ ]]; then
            local domain
            domain=$(printf "%s" "$key" | sed 's/SESSION_SCORES\[\(.*\)\].*/\1/')
            SESSION_SCORES[$domain]="$value"
        # Parse HISTORY_COUNT (skip, we'll rebuild array)
        elif [[ "$key" == "HISTORY_COUNT" ]]; then
            SESSION_HISTORY=()
        # Parse HISTORY entries
        elif [[ "$key" =~ ^HISTORY\[ ]]; then
            local idx
            idx=$(printf "%s" "$key" | sed 's/HISTORY\[\(.*\)\].*/\1/')
            SESSION_HISTORY[$idx]="$value"
        fi
    done < "$file"

    printf "%b[SYSTEM] Session loaded from: %b%s%b\n" "$BOLD_GREEN" "$CYAN" "$file" "$RST"
    printf "%b[SYSTEM] Active domain: %b%s%b\n" "$BOLD_GREEN" "$CYAN" "$ACTIVE_DOMAIN" "$RST"
    draw_session_summary
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 9: CORE INPUT PROCESSOR
# ─────────────────────────────────────────────────────────────────────────────

# ── process_input ────────────────────────────────────────────────────────────
# The main pipeline: takes user text, scores it, determines domain,
# updates UI personality, and prints a response.
# Usage: process_input "the user's raw input string"
process_input() {
    local user_input="$1"

    # Skip blank input
    [[ -z "${user_input// }" ]] && return

    # ── 1. Add to history (capped at HISTORY_LIMIT) ───────────────────────
    SESSION_HISTORY+=("$user_input")
    if (( ${#SESSION_HISTORY[@]} > HISTORY_LIMIT )); then
        # Remove the oldest entry (shift array manually; bash has no shift for arrays)
        SESSION_HISTORY=("${SESSION_HISTORY[@]:1}")
    fi

    # ── 2. Run the scoring engine ─────────────────────────────────────────
    local scored_output
    scored_output=$(score_input "$user_input")

    # ── 3. Determine winning domain ───────────────────────────────────────
    local new_domain
    new_domain=$(determine_domain "$scored_output")

    # ── 4. Show score breakdown chart ─────────────────────────────────────
    draw_score_breakdown "$scored_output"

    # ── 5. If domain changed, print transition banner ─────────────────────
    if [[ "$new_domain" != "$ACTIVE_DOMAIN" ]]; then
        draw_domain_banner "$new_domain"
        ACTIVE_DOMAIN="$new_domain"
    fi

    # ── 6. Print bot response in active domain's style ───────────────────
    draw_bot_response "$ACTIVE_DOMAIN" "$user_input"
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 10: MAIN LOOP
# ─────────────────────────────────────────────────────────────────────────────

# ── startup ──────────────────────────────────────────────────────────────────
startup() {
    # Verify bash version supports associative arrays (requires 4.0+)
    if (( BASH_VERSINFO[0] < 4 )); then
        printf "ERROR: This script requires Bash 4.0 or later.\n"
        printf "Your version: %s\n" "$BASH_VERSION"
        exit 1
    fi

    draw_main_header

    # Print welcome message
    printf "%b  Welcome to the Weighted Keyword Intent Scorer!%b\n" \
        "$BOLD_WHITE" "$RST"
    printf "%b  Type any technical question or statement.%b\n" \
        "$WHITE" "$RST"
    printf "%b  The bot will score your words and shift personality%b\n" \
        "$WHITE" "$RST"
    printf "%b  once domain weight exceeds the threshold (%d pts).%b\n\n" \
        "$WHITE" "$THRESHOLD" "$RST"
    printf "%b  Type :help for commands.%b\n\n" "$CYAN" "$RST"

    draw_separator "─" "$BOLD_WHITE"
    printf "\n"

    # Show initial (general) domain banner
    draw_domain_banner "general"
}

# ── main ─────────────────────────────────────────────────────────────────────
main() {
    # Parse command-line arguments first
    parse_arguments "$@"

    startup

    # Main read loop
    while true; do
        # Print the styled prompt for the active domain
        draw_prompt "$ACTIVE_DOMAIN"

        # Read user input (handle EOF with Ctrl+D gracefully)
        local user_input
        if ! IFS= read -r user_input; then
            printf "\n%b[SYSTEM] EOF received. Goodbye!%b\n" \
                "$BOLD_YELLOW" "$RST"
            exit 0
        fi

        # Input length validation
        if [[ ${#user_input} -gt 1000 ]]; then
            printf "\n%b[ERROR] Input too long (max 1000 characters)%b\n\n" \
                "$RED" "$RST"
            continue
        fi

        # ── Built-in command dispatcher ───────────────────────────────────
        case "$user_input" in
            :quit|:exit|:q)
                printf "\n%b[SYSTEM] Session ended. Goodbye!%b\n\n" \
                    "$BOLD_YELLOW" "$RST"
                draw_session_summary
                exit 0
                ;;
            :help|:h)
                draw_help_panel
                continue
                ;;
            :history)
                handle_history
                continue
                ;;
            :scores|:score)
                handle_scores
                continue
                ;;
            :save)
                handle_save
                continue
                ;;
            :load)
                handle_load
                continue
                ;;
            :reset)
                handle_reset
                draw_domain_banner "general"
                continue
                ;;
            :demo)
                handle_demo
                continue
                ;;
            :debug)
                if [[ "$DEBUG_MODE" == true ]]; then
                    DEBUG_MODE=false
                    printf "%b[DEBUG] Debug mode disabled.%b\n\n" "$BOLD_YELLOW" "$RST"
                else
                    DEBUG_MODE=true
                    printf "%b[DEBUG] Debug mode enabled.%b\n\n" "$BOLD_GREEN" "$RST"
                fi
                continue
                ;;
            :clear)
                draw_main_header
                continue
                ;;
            "")
                # Empty input: do nothing, re-prompt
                continue
                ;;
            *)
                # Normal text input → run through scoring pipeline
                printf "\n"
                process_input "$user_input"
                ;;
        esac
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 11: ENTRY POINT
# ─────────────────────────────────────────────────────────────────────────────

# Run main only if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi