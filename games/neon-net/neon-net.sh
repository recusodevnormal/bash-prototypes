#!/bin/sh
# =============================================================================
# NEON-NET.exe v1.0 - Enhanced Edition
# A Cyberpunk Hacker RPG
# Requires: sh (POSIX shell), a terminal with ANSI support
# Zero external dependencies. Zero files written. Pure shell.
# =============================================================================

# Check terminal support
if [ ! -t 0 ]; then
    echo "Error: This game requires an interactive terminal"
    exit 1
fi

# ANSI COLOR CODES
# These are escape sequences sent to the terminal - no external tool involved.
# =============================================================================

R='\033[0m'          # Reset
BOLD='\033[1m'
DIM='\033[2m'
BLINK='\033[5m'

# Foreground colors
FC_RED='\033[91m'
FC_GRN='\033[92m'
FC_YLW='\033[93m'
FC_BLU='\033[94m'
FC_MAG='\033[95m'
FC_CYN='\033[96m'
FC_WHT='\033[97m'
FC_BLK='\033[90m'    # Dark gray (bright black)
FC_ORA='\033[38;5;208m'
FC_PUR='\033[38;5;129m'
FC_PNK='\033[38;5;206m'
FC_TEA='\033[38;5;43m'
FC_LIM='\033[38;5;154m'
FC_VIO='\033[38;5;141m'
FC_GLD='\033[38;5;220m'

# Background colors
BC_RED='\033[41m'
BC_GRN='\033[42m'
BC_BLU='\033[44m'
BC_BLK='\033[40m'
BC_PUR='\033[45m'
BC_CYN='\033[46m'

# =============================================================================
# WORLD DATA - All arrays defined here so functions can reference them
# =============================================================================

# Target corporation names for job generation
TARGETS="MegaCorp DataVault NeoBank SynthCorp ArmsDealer GridControl CyberSec OmniTech BioMesh PulseNet"

# Job type descriptions (parallel to difficulty modifiers)
JOB_TYPES="DataTheft Sabotage Espionage Ransomware Infiltration BlackoutOp CoreDump GhostWipe Phishing DDoS_Attack Crypto_Heist ZeroDay_Exploit Botnet_Hijack"

# Flavor text for job briefings
FLAVOR_CORP="A shadowy fixer sends you an encrypted ping"
FLAVOR_GANG="The shadow board's AI drops a contract in your queue"
FLAVOR_ANON="An anonymous tip routes through seven proxies to reach you"
FLAVOR_DIRECT="Direct neural uplink from an unknown benefactor"

# Black market item names, costs, and stat bonuses
# Format: parallel arrays indexed 1-10
SHOP_NAMES="IceBreaker_v2 NeuralBooster CryptoCloak QuantumDecryptor BlackICE_Shield SyntheticProxy GhostShell AI_Core ZeroDay_Kit Neural_Link Quantum_Key"
SHOP_COSTS="150 200 180 350 400 250 500 600 300 450"
SHOP_BONUSES="15 20 10 30 25 20 35 40 25 30"
# What stat each item boosts: H=hack_power, D=defense, S=speed
SHOP_STATS="H H D H D S D H S H"
SHOP_DESCS="Brute-forces PIN segments faster|Boosts cognitive processing cycles|Masks your true network location|Breaks quantum encryption layers|Deflects counterhack attempts|Routes attacks through ghost nodes|Stealth mode - 50% detection chance|AI co-processor - auto-hack assist|Direct neural interface - +25% speed|Quantum encryption keys - +30% hack power"

# =============================================================================
# GAME STATE VARIABLES
# =============================================================================
# These are the ONLY persistent state. No files. No databases.

PLAYER_NAME=""
PLAYER_DAY=1
PLAYER_MAX_DAYS=30
PLAYER_CREDITS=500
PLAYER_DEBT=10000
PLAYER_HACK_POWER=10    # Affects PIN-crack attempts allowed
PLAYER_DEFENSE=10       # Affects damage taken from failed hacks
PLAYER_SPEED=10         # Affects interest rate (higher = negotiate better)

# Inventory: owned items stored as a space-separated string of item numbers
PLAYER_INVENTORY=""

# Reputation: increases with successful jobs, affects job payouts
PLAYER_REP=0

# Current active job slot (0 = none available, must refresh)
JOB_ACTIVE=0
JOB_TARGET=""
JOB_TYPE=""
JOB_DIFFICULTY=0
JOB_PAYOUT=0
JOB_ACCEPTED=0          # 1 = player has accepted this job

# Session stats
TOTAL_JOBS_DONE=0
TOTAL_HACKS_FAILED=0
TOTAL_ITEMS_BOUGHT=0
TOTAL_MONEY_MADE=0
MAX_REPUTATION=0
BOSSES_DEFEATED=0
STEALTH_HACKS=0

# Flags
GAME_OVER=0
GAME_WON=0
TUTORIAL_SEEN=0

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# ------------------------------------------------------------------------------
# fn: clear_screen
# Clears terminal using ANSI escape. No 'clear' binary needed.
# ESC[2J clears screen, ESC[H moves cursor to home position.
# ------------------------------------------------------------------------------
clear_screen() {
    printf '\033[2J\033[H'
}

# ------------------------------------------------------------------------------
# fn: pause
# Waits for user to press Enter. Pure 'read' built-in.
# ------------------------------------------------------------------------------
pause() {
    printf "${FC_BLK}${DIM}[ press ENTER to continue ]${R}\n"
    read _DUMMY
}

# ------------------------------------------------------------------------------
# fn: rng MIN MAX
# Returns a random number between MIN and MAX inclusive.
# Uses $RANDOM (0-32767) with modulo. Stored in global RNG_RESULT.
# Note: modulo bias exists for large ranges but is acceptable for a game.
# ------------------------------------------------------------------------------
rng() {
    _MIN=$1
    _MAX=$2
    _RANGE=$(( _MAX - _MIN + 1 ))
    RNG_RESULT=$(( (RANDOM % _RANGE) + _MIN ))
}

# ------------------------------------------------------------------------------
# fn: rng_pick_word SPACE_SEPARATED_STRING
# Picks a random word from a space-separated string.
# Result stored in RNG_WORD_RESULT.
# This avoids arrays (not POSIX) while keeping the spirit of array selection.
# ------------------------------------------------------------------------------
rng_pick_word() {
    _STR="$1"
    # Count words by iterating - pure shell
    _COUNT=0
    for _W in $_STR; do
        _COUNT=$(( _COUNT + 1 ))
    done
    # Pick random index 1 to COUNT
    rng 1 $_COUNT
    _TARGET_IDX=$RNG_RESULT
    # Walk to that word
    _IDX=0
    for _W in $_STR; do
        _IDX=$(( _IDX + 1 ))
        if [ $_IDX -eq $_TARGET_IDX ]; then
            RNG_WORD_RESULT="$_W"
            return
        fi
    done
}

# ------------------------------------------------------------------------------
# fn: word_at_index SPACE_SEPARATED_STRING INDEX
# Retrieves the word at a 1-based index. Result in WORD_AT_RESULT.
# ------------------------------------------------------------------------------
word_at_index() {
    _STR="$1"
    _IDX_TARGET="$2"
    _IDX=0
    for _W in $_STR; do
        _IDX=$(( _IDX + 1 ))
        if [ $_IDX -eq $_IDX_TARGET ]; then
            WORD_AT_RESULT="$_W"
            return
        fi
    done
    WORD_AT_RESULT=""
}

# ------------------------------------------------------------------------------
# fn: count_words SPACE_SEPARATED_STRING
# Counts words. Result in WORD_COUNT_RESULT.
# ------------------------------------------------------------------------------
count_words() {
    _STR="$1"
    WORD_COUNT_RESULT=0
    for _W in $_STR; do
        WORD_COUNT_RESULT=$(( WORD_COUNT_RESULT + 1 ))
    done
}

# ------------------------------------------------------------------------------
# fn: string_contains HAYSTACK NEEDLE
# Returns 0 (true) if HAYSTACK contains NEEDLE as a substring.
# Uses shell parameter expansion - no grep, no external tools.
# ------------------------------------------------------------------------------
string_contains() {
    case "$1" in
        *"$2"*) return 0 ;;
        *)       return 1 ;;
    esac
}

# ------------------------------------------------------------------------------
# fn: pad_number NUM WIDTH
# Left-pads a number with spaces to WIDTH characters.
# Result in PAD_RESULT. Used for stat display alignment.
# ------------------------------------------------------------------------------
pad_number() {
    _N="$1"
    _W="$2"
    _LEN=${#_N}
    _PAD=$(( _W - _LEN ))
    PAD_RESULT=""
    _I=0
    while [ $_I -lt $_PAD ]; do
        PAD_RESULT=" $PAD_RESULT"
        _I=$(( _I + 1 ))
    done
    PAD_RESULT="${PAD_RESULT}${_N}"
}

# ------------------------------------------------------------------------------
# fn: draw_bar VALUE MAX WIDTH FILL_CHAR EMPTY_CHAR
# Draws a text progress bar. Pure printf loops.
# Example: draw_bar 7 10 10 "#" "."  → [#######...]
# ------------------------------------------------------------------------------
draw_bar() {
    _VAL=$1
    _MAX=$2
    _WIDTH=$3
    _FILL="$4"
    _EMPTY="$5"
    # Calculate filled segments
    if [ $_MAX -gt 0 ]; then
        _FILLED=$(( (_VAL * _WIDTH) / _MAX ))
    else
        _FILLED=0
    fi
    if [ $_FILLED -gt $_WIDTH ]; then _FILLED=$_WIDTH; fi
    _EMPTY_COUNT=$(( _WIDTH - _FILLED ))
    printf "["
    _I=0
    while [ $_I -lt $_FILLED ]; do
        printf "%s" "$_FILL"
        _I=$(( _I + 1 ))
    done
    _I=0
    while [ $_I -lt $_EMPTY_COUNT ]; do
        printf "%s" "$_EMPTY"
        _I=$(( _I + 1 ))
    done
    printf "]"
}

# ------------------------------------------------------------------------------
# fn: typing_effect TEXT DELAY COLOR
# Types text character by character with animation
# ------------------------------------------------------------------------------
typing_effect() {
    _TEXT="$1"
    _DELAY=${2:-0.03}
    _COLOR="$3"
    _LEN=${#_TEXT}
    _I=0
    while [ $_I -lt $_LEN ]; do
        _CHAR=$(printf '%s' "$_TEXT" | cut -c$((_I+1))-$((_I+1)))
        printf "${_COLOR}%s${R}" "$_CHAR"
        sleep $_DELAY
        _I=$(( _I + 1 ))
    done
    printf "\n"
}

# ------------------------------------------------------------------------------
# fn: glitch_effect TEXT
# Creates a cyberpunk glitch effect on text
# ------------------------------------------------------------------------------
glitch_effect() {
    _TEXT="$1"
    printf "${FC_CYN}"
    for _I in $(seq 1 3); do
        printf "\r%s" "$_TEXT"
        sleep 0.05
        printf "\r${FC_RED}%s${R}" "$_TEXT"
        sleep 0.05
        printf "\r${FC_GRN}%s${R}" "$_TEXT"
        sleep 0.05
    done
    printf "\r${FC_CYN}%s${R}\n" "$_TEXT"
}

# ------------------------------------------------------------------------------
# fn: matrix_rain
# Simple matrix-style rain animation
# ------------------------------------------------------------------------------
matrix_rain() {
    _CHARS="01"
    _I=0
    while [ $_I -lt 10 ]; do
        _LINE=""
        _J=0
        while [ $_J -lt 40 ]; do
            _CHAR=$(printf '%s' "$_CHARS" | cut -c$((RANDOM % 2 + 1))-$((RANDOM % 2 + 1)))
            _LINE="${_LINE}${_CHAR}"
            _J=$(( _J + 1 ))
        done
        printf "${FC_GRN}%s${R}\n" "$_LINE"
        sleep 0.05
        _I=$(( _I + 1 ))
    done
}

# ------------------------------------------------------------------------------
# fn: scan_line
# Creates a scanning line effect
# ------------------------------------------------------------------------------
scan_line() {
    _WIDTH=60
    _I=0
    while [ $_I -lt $_WIDTH ]; do
        printf "\r${FC_CYN}" 1>&2
        _J=0
        while [ $_J -lt $_I ]; do
            printf " " 1>&2
            _J=$(( _J + 1 ))
        done
        printf "█" 1>&2
        printf "${R}" 1>&2
        sleep 0.02
        _I=$(( _I + 1 ))
    done
    printf "\r" 1>&2
    _I=0
    while [ $_I -lt $_WIDTH ]; do
        printf " " 1>&2
        _I=$(( _I + 1 ))
    done
}

# =============================================================================
# SCREEN / DISPLAY FUNCTIONS
# =============================================================================

# ------------------------------------------------------------------------------
# fn: draw_header
# Draws the persistent top banner. Called at the start of each major screen.
# ------------------------------------------------------------------------------
draw_header() {
    printf "${BC_BLK}${FC_CYN}${BOLD}"
    printf "╔══════════════════════════════════════════════════════════════════════════════╗\n"
    printf "║  ███╗   ██╗███████╗ ██████╗ ███╗   ██╗      ███╗   ██╗███████╗████████╗   ║\n"
    printf "║  ████╗  ██║██╔════╝██╔═══██╗████╗  ██║      ████╗  ██║██╔════╝╚══██╔══╝   ║\n"
    printf "║  ██╔██╗ ██║█████╗  ██║   ██║██╔██╗ ██║█████╗██╔██╗ ██║█████╗     ██║      ║\n"
    printf "║  ██║╚██╗██║██╔══╝  ██║   ██║██║╚██╗██║╚════╝██║╚██╗██║██╔══╝     ██║      ║\n"
    printf "║  ██║ ╚████║███████╗╚██████╔╝██║ ╚████║      ██║ ╚████║███████╗   ██║      ║\n"
    printf "║  ╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚═╝  ╚═══╝      ╚═╝  ╚═══╝╚══════╝   ╚═╝      ║\n"
    printf "╚══════════════════════════════════════════════════════════════════════════════╝${R}\n"
}

# ------------------------------------------------------------------------------
# fn: draw_status_bar
# Draws the persistent HUD below the header on every screen.
# Shows: Day, Credits, Debt, Key Stats
# ------------------------------------------------------------------------------
draw_status_bar() {
    # Calculate debt color: red if high, yellow if medium, green if low
    if [ $PLAYER_DEBT -gt 7000 ]; then
        _DEBT_COLOR="${FC_RED}"
    elif [ $PLAYER_DEBT -gt 3000 ]; then
        _DEBT_COLOR="${FC_YLW}"
    else
        _DEBT_COLOR="${FC_GRN}"
    fi

    # Days remaining
    _DAYS_LEFT=$(( PLAYER_MAX_DAYS - PLAYER_DAY + 1 ))
    if [ $_DAYS_LEFT -le 5 ]; then
        _DAY_COLOR="${FC_RED}${BLINK}"
    elif [ $_DAYS_LEFT -le 10 ]; then
        _DAY_COLOR="${FC_YLW}"
    else
        _DAY_COLOR="${FC_CYN}"
    fi

    printf "${FC_BLK}────────────────────────────────────────────────────────────────────────────────${R}\n"
    printf " ${FC_MAG}${BOLD}OPERATOR:${R} ${FC_WHT}%-12s${R}" "$PLAYER_NAME"
    printf " ${FC_MAG}${BOLD}DAY:${R} ${_DAY_COLOR}%02d${R}${FC_BLK}/%02d${R}" "$PLAYER_DAY" "$PLAYER_MAX_DAYS"
    printf " ${FC_MAG}${BOLD}CREDITS:${R} ${FC_GRN}¢%d${R}" "$PLAYER_CREDITS"
    printf " ${FC_MAG}${BOLD}DEBT:${R} ${_DEBT_COLOR}¢%d${R}" "$PLAYER_DEBT"
    printf "\n"
    printf " ${FC_BLK}HACK:${R}${FC_CYN}%3d${R}  ${FC_BLK}DEF:${R}${FC_BLU}%3d${R}  ${FC_BLK}SPD:${R}${FC_YLW}%3d${R}  ${FC_BLK}REP:${R}${FC_MAG}%3d${R}  ${FC_BLK}JOBS:${R}${FC_WHT}%d${R}\n" \
        "$PLAYER_HACK_POWER" "$PLAYER_DEFENSE" "$PLAYER_SPEED" "$PLAYER_REP" "$TOTAL_JOBS_DONE"
    printf "${FC_BLK}────────────────────────────────────────────────────────────────────────────────${R}\n"
}

# ------------------------------------------------------------------------------
# fn: draw_main_menu
# The central hub. Called after every major action returns.
# ------------------------------------------------------------------------------
draw_main_menu() {
    clear_screen
    draw_header
    draw_status_bar
    printf "\n"
    printf "  ${FC_CYN}${BOLD}// SHADOW TERMINAL v4.7 //${R}\n"
    printf "  ${FC_BLK}%s${R}\n\n" "Select an operation from the queue:"

    # Show job notification if one is pending
    if [ $JOB_ACTIVE -eq 1 ] && [ $JOB_ACCEPTED -eq 0 ]; then
        printf "  ${FC_YLW}${BLINK}[!]${R} ${FC_YLW}New contract in queue: ${FC_WHT}${JOB_TARGET}${R} ${FC_BLK}(${JOB_TYPE})${R}\n\n"
    elif [ $JOB_ACTIVE -eq 1 ] && [ $JOB_ACCEPTED -eq 1 ]; then
        printf "  ${FC_GRN}[✓]${R} ${FC_GRN}Active contract: ${FC_WHT}${JOB_TARGET}${R} ${FC_BLK}// Payout: ${FC_GRN}¢${JOB_PAYOUT}${R}\n\n"
    else
        printf "  ${FC_BLK}[ No contracts in queue. Check the job board. ]${R}\n\n"
    fi

    printf "  ${FC_CYN}[ 1 ]${R} ${FC_WHT}JOB BOARD${R}      ${FC_BLK}// View & accept contracts${R}\n"
    printf "  ${FC_CYN}[ 2 ]${R} ${FC_WHT}BLACK MARKET${R}   ${FC_BLK}// Purchase hardware & software${R}\n"
    printf "  ${FC_CYN}[ 3 ]${R} ${FC_WHT}SLEEP CYCLE${R}    ${FC_BLK}// Rest. Advance time. Debt grows.${R}\n"
    printf "  ${FC_CYN}[ 4 ]${R} ${FC_WHT}SYSTEM STATUS${R}  ${FC_BLK}// Full stats & inventory${R}\n"

    # Only show execute option if job is accepted
    if [ $JOB_ACCEPTED -eq 1 ]; then
        printf "  ${FC_GRN}[ 5 ]${R} ${FC_GRN}${BOLD}EXECUTE HACK${R}   ${FC_BLK}// Launch operation on ${JOB_TARGET}${R}\n"
    fi

    printf "  ${FC_RED}[ 0 ]${R} ${FC_RED}TERMINATE${R}      ${FC_BLK}// Quit to OS${R}\n"
    printf "\n"
    printf "  ${FC_BLK}>${R} "
}

# =============================================================================
# GAME LOGIC FUNCTIONS
# =============================================================================

# ------------------------------------------------------------------------------
# fn: generate_job
# Dynamically builds a job from random components.
# Sets: JOB_ACTIVE, JOB_TARGET, JOB_TYPE, JOB_DIFFICULTY, JOB_PAYOUT
# This replaces a static job array with pure runtime generation.
# ------------------------------------------------------------------------------
generate_job() {
    # Pick random target
    rng_pick_word "$TARGETS"
    JOB_TARGET="$RNG_WORD_RESULT"

    # Pick random job type
    rng_pick_word "$JOB_TYPES"
    JOB_TYPE="$RNG_WORD_RESULT"

    # Difficulty scales with day number and reputation
    # Base: 1-5, modified by day progression
    rng 1 5
    _BASE_DIFF=$RNG_RESULT
    _DAY_BONUS=$(( PLAYER_DAY / 6 ))      # +1 difficulty per 6 days
    JOB_DIFFICULTY=$(( _BASE_DIFF + _DAY_BONUS ))
    if [ $JOB_DIFFICULTY -gt 10 ]; then JOB_DIFFICULTY=10; fi

    # Payout = difficulty * base_rate + reputation bonus + random variance
    _BASE_RATE=80
    _REP_BONUS=$(( PLAYER_REP * 5 ))
    rng 0 50
    _VARIANCE=$RNG_RESULT
    JOB_PAYOUT=$(( (JOB_DIFFICULTY * _BASE_RATE) + _REP_BONUS + _VARIANCE ))

    JOB_ACTIVE=1
    JOB_ACCEPTED=0
}

# ------------------------------------------------------------------------------
# fn: screen_job_board
# Displays the job board and allows accepting/refreshing jobs.
# ------------------------------------------------------------------------------
screen_job_board() {
    clear_screen
    draw_header
    draw_status_bar
    printf "\n"
    printf "  ${FC_MAG}${BOLD}// JOB BOARD //${R}  ${FC_BLK}Contracts sourced from shadow network${R}\n\n"

    if [ $JOB_ACTIVE -eq 0 ]; then
        # No job available, generate one automatically
        generate_job
    fi

    # Pick a random flavor intro
    rng_pick_word "$FLAVOR_CORP $FLAVOR_GANG $FLAVOR_ANON $FLAVOR_DIRECT"
    _FLAVOR="$RNG_WORD_RESULT $RNG_WORD_RESULT"  # reuse same for display

    # Determine difficulty color
    if [ $JOB_DIFFICULTY -le 3 ]; then
        _DIFF_COLOR="${FC_GRN}"
        _DIFF_LABEL="LOW"
    elif [ $JOB_DIFFICULTY -le 6 ]; then
        _DIFF_COLOR="${FC_YLW}"
        _DIFF_LABEL="MED"
    elif [ $JOB_DIFFICULTY -le 8 ]; then
        _DIFF_COLOR="${FC_RED}"
        _DIFF_LABEL="HIGH"
    else
        _DIFF_COLOR="${FC_RED}${BOLD}"
        _DIFF_LABEL="CRITICAL"
    fi

    printf "  ${FC_BLK}┌─────────────────────────────────────────────────────────┐${R}\n"
    printf "  ${FC_BLK}│${R} ${FC_YLW}CONTRACT BRIEF${R}                                          ${FC_BLK}│${R}\n"
    printf "  ${FC_BLK}├─────────────────────────────────────────────────────────┤${R}\n"
    printf "  ${FC_BLK}│${R}  ${FC_BLK}TARGET   :${R} ${FC_WHT}${BOLD}%-20s${R}                    ${FC_BLK}│${R}\n" "$JOB_TARGET"
    printf "  ${FC_BLK}│${R}  ${FC_BLK}OPERATION:${R} ${FC_CYN}%-20s${R}                    ${FC_BLK}│${R}\n" "$JOB_TYPE"
    printf "  ${FC_BLK}│${R}  ${FC_BLK}DIFFICULTY:${R} ${_DIFF_COLOR}%-4s${R}  "
    draw_bar $JOB_DIFFICULTY 10 20 "█" "░"
    printf "  ${FC_BLK}│${R}\n"
    printf "  ${FC_BLK}│${R}  ${FC_BLK}PAYOUT   :${R} ${FC_GRN}¢%d${R}                                  ${FC_BLK}│${R}\n" "$JOB_PAYOUT"
    printf "  ${FC_BLK}│${R}                                                         ${FC_BLK}│${R}\n"

    # Risk warning based on difficulty vs player hack power
    _RISK=$(( JOB_DIFFICULTY * 10 - PLAYER_HACK_POWER ))
    if [ $_RISK -le 0 ]; then
        printf "  ${FC_BLK}│${R}  ${FC_GRN}RISK ASSESSMENT: Minimal. Your rig outclasses target.   ${FC_BLK}│${R}\n"
    elif [ $_RISK -le 30 ]; then
        printf "  ${FC_BLK}│${R}  ${FC_YLW}RISK ASSESSMENT: Moderate. Proceed with caution.        ${FC_BLK}│${R}\n"
    else
        printf "  ${FC_BLK}│${R}  ${FC_RED}RISK ASSESSMENT: HIGH. This could burn your rig.        ${FC_BLK}│${R}\n"
    fi

    printf "  ${FC_BLK}└─────────────────────────────────────────────────────────┘${R}\n\n"

    if [ $JOB_ACCEPTED -eq 1 ]; then
        printf "  ${FC_GRN}[CONTRACT ACTIVE]${R} ${FC_BLK}Return to terminal to execute.${R}\n\n"
        printf "  ${FC_CYN}[ 1 ]${R} Return to Terminal\n"
        printf "  ${FC_CYN}[ 2 ]${R} Abandon Contract ${FC_BLK}(generate new job)${R}\n"
    else
        printf "  ${FC_CYN}[ 1 ]${R} ${FC_GRN}Accept Contract${R}\n"
        printf "  ${FC_CYN}[ 2 ]${R} ${FC_YLW}Refresh Board${R} ${FC_BLK}(find new job)${R}\n"
        printf "  ${FC_CYN}[ 3 ]${R} Return to Terminal\n"
    fi
    printf "\n  ${FC_BLK}>${R} "

    read _JOB_CHOICE
    case $_JOB_CHOICE in
        1)
            if [ $JOB_ACCEPTED -eq 1 ]; then
                return  # Back to main menu
            else
                JOB_ACCEPTED=1
                printf "\n  ${FC_GRN}Contract accepted. Prepare your intrusion toolkit.${R}\n"
                pause
            fi
            ;;
        2)
            if [ $JOB_ACCEPTED -eq 1 ]; then
                JOB_ACCEPTED=0
                JOB_ACTIVE=0
                printf "\n  ${FC_YLW}Contract abandoned. Reputation impact noted.${R}\n"
                PLAYER_REP=$(( PLAYER_REP - 1 ))
                if [ $PLAYER_REP -lt 0 ]; then PLAYER_REP=0; fi
                pause
            else
                # Refresh: generate a new job, costs some credits (fixer fee)
                _REFRESH_COST=20
                if [ $PLAYER_CREDITS -ge $_REFRESH_COST ]; then
                    PLAYER_CREDITS=$(( PLAYER_CREDITS - _REFRESH_COST ))
                    generate_job
                    printf "\n  ${FC_YLW}New contract sourced. Fixer fee: ¢${_REFRESH_COST}${R}\n"
                    pause
                    screen_job_board  # Re-enter to show new job
                    return
                else
                    printf "\n  ${FC_RED}Insufficient credits for fixer fee (¢${_REFRESH_COST}).${R}\n"
                    pause
                fi
            fi
            ;;
        3)
            if [ $JOB_ACCEPTED -ne 1 ]; then
                return
            fi
            ;;
    esac
}

# ------------------------------------------------------------------------------
# fn: screen_black_market
# Shop screen. Lists items with costs. Handles purchasing logic.
# Items are stored as space-separated strings (parallel arrays).
# ------------------------------------------------------------------------------
screen_black_market() {
    clear_screen
    draw_header
    draw_status_bar
    printf "\n"
    printf "  ${FC_MAG}${BOLD}// BLACK MARKET //${R}  ${FC_BLK}Unlicensed hardware & darknet software${R}\n\n"
    printf "  ${FC_BLK}Your Credits: ${FC_GRN}¢%d${R}\n\n" "$PLAYER_CREDITS"

    # Display items - we iterate by index through the parallel word-strings
    count_words "$SHOP_NAMES"
    _SHOP_COUNT=$WORD_COUNT_RESULT

    printf "  ${FC_BLK}┌──────────────────────────────────────────────────────────────┐${R}\n"
    printf "  ${FC_BLK}│${R}  ${FC_YLW}#   ITEM                  COST   BONUS  STAT  STATUS${R}        ${FC_BLK}│${R}\n"
    printf "  ${FC_BLK}├──────────────────────────────────────────────────────────────┤${R}\n"

    _ITEM_NUM=1
    while [ $_ITEM_NUM -le $_SHOP_COUNT ]; do
        word_at_index "$SHOP_NAMES"   $_ITEM_NUM; _INAME="$WORD_AT_RESULT"
        word_at_index "$SHOP_COSTS"   $_ITEM_NUM; _ICOST="$WORD_AT_RESULT"
        word_at_index "$SHOP_BONUSES" $_ITEM_NUM; _IBONUS="$WORD_AT_RESULT"
        word_at_index "$SHOP_STATS"   $_ITEM_NUM; _ISTAT="$WORD_AT_RESULT"

        # Check if player owns this item
        if string_contains "$PLAYER_INVENTORY" " $_ITEM_NUM " || \
           string_contains "$PLAYER_INVENTORY" "|$_ITEM_NUM|"; then
            _STATUS="${FC_GRN}[OWNED]${R}"
        elif [ $PLAYER_CREDITS -ge $_ICOST ]; then
            _STATUS="${FC_CYN}[BUY]  ${R}"
        else
            _STATUS="${FC_RED}[N/A]  ${R}"
        fi

        printf "  ${FC_BLK}│${R}  ${FC_CYN}%d${R}   ${FC_WHT}%-22s${R}  ${FC_GRN}¢%-5s${R}  +%-5s ${FC_MAG}%-4s${R}  %b  ${FC_BLK}│${R}\n" \
            "$_ITEM_NUM" "$_INAME" "$_ICOST" "$_IBONUS" "$_ISTAT" "$_STATUS"

        _ITEM_NUM=$(( _ITEM_NUM + 1 ))
    done

    printf "  ${FC_BLK}└──────────────────────────────────────────────────────────────┘${R}\n\n"
    printf "  ${FC_BLK}STAT KEY: H=HackPower  D=Defense  S=Speed${R}\n\n"
    printf "  Enter item number to purchase, or ${FC_CYN}0${R} to leave:\n"
    printf "  ${FC_BLK}>${R} "
    read _SHOP_CHOICE

    # Validate input is numeric and in range
    case $_SHOP_CHOICE in
        0)
            return
            ;;
        [1-9])
            # Check within range
            if [ $_SHOP_CHOICE -le $_SHOP_COUNT ]; then
                _BUY_NUM=$_SHOP_CHOICE
                word_at_index "$SHOP_NAMES"   $_BUY_NUM; _BNAME="$WORD_AT_RESULT"
                word_at_index "$SHOP_COSTS"   $_BUY_NUM; _BCOST="$WORD_AT_RESULT"
                word_at_index "$SHOP_BONUSES" $_BUY_NUM; _BBONUS="$WORD_AT_RESULT"
                word_at_index "$SHOP_STATS"   $_BUY_NUM; _BSTAT="$WORD_AT_RESULT"

                # Check if already owned
                # We track inventory as "|1|2|5|" format for easy substring check
                if string_contains "$PLAYER_INVENTORY" "|${_BUY_NUM}|"; then
                    printf "\n  ${FC_YLW}You already own ${_BNAME}. Duplicate install rejected.${R}\n"
                    pause
                    screen_black_market
                    return
                fi

                # Check funds
                if [ $PLAYER_CREDITS -lt $_BCOST ]; then
                    printf "\n  ${FC_RED}Insufficient credits. Need ¢${_BCOST}, have ¢${PLAYER_CREDITS}.${R}\n"
                    pause
                    screen_black_market
                    return
                fi

                # Execute purchase
                PLAYER_CREDITS=$(( PLAYER_CREDITS - _BCOST ))
                PLAYER_INVENTORY="${PLAYER_INVENTORY}|${_BUY_NUM}|"
                TOTAL_ITEMS_BOUGHT=$(( TOTAL_ITEMS_BOUGHT + 1 ))

                # Apply stat bonus
                case $_BSTAT in
                    H) PLAYER_HACK_POWER=$(( PLAYER_HACK_POWER + _BBONUS )) ;;
                    D) PLAYER_DEFENSE=$(( PLAYER_DEFENSE + _BBONUS )) ;;
                    S) PLAYER_SPEED=$(( PLAYER_SPEED + _BBONUS )) ;;
                esac

                printf "\n  ${FC_GRN}${BOLD}PURCHASE CONFIRMED${R}\n"
                printf "  ${FC_WHT}%s${R} installed. ${FC_CYN}+%d${R} to ${FC_MAG}%s${R}.\n" \
                    "$_BNAME" "$_BBONUS" "$_BSTAT"
                pause
                screen_black_market  # Loop back for more shopping
                return
            else
                printf "\n  ${FC_RED}Invalid selection.${R}\n"
                pause
                screen_black_market
                return
            fi
            ;;
        *)
            printf "\n  ${FC_RED}Invalid input. Enter a number.${R}\n"
            pause
            screen_black_market
            return
            ;;
    esac
}

# ------------------------------------------------------------------------------
# fn: screen_sleep
# Advances time by 1 day. Applies interest to debt.
# Interest rate: 5% base, reduced by speed stat.
# POSIX integer math: 5% of DEBT = DEBT * 5 / 100 = DEBT / 20
# Speed reduces rate: effective_rate = max(1%, 5% - speed/100)
# All as integer percentages to avoid floating point.
# ------------------------------------------------------------------------------
screen_sleep() {
    clear_screen
    draw_header
    draw_status_bar
    printf "\n"
    printf "  ${FC_MAG}${BOLD}// SLEEP CYCLE //${R}\n\n"

    # Check if already at max days
    if [ $PLAYER_DAY -ge $PLAYER_MAX_DAYS ]; then
        printf "  ${FC_RED}${BLINK}TIME IS UP.${R} ${FC_RED}The 30-day deadline has passed.${R}\n"
        pause
        check_end_conditions
        return
    fi

    printf "  ${FC_BLK}Initiating neural rest protocol...${R}\n\n"

    # Calculate interest
    # Base rate = 5 (representing 5%)
    # Speed reduces it: every 20 speed points = -1% rate
    _BASE_INTEREST_PCT=5
    _SPEED_REDUCTION=$(( PLAYER_SPEED / 20 ))
    _EFFECTIVE_PCT=$(( _BASE_INTEREST_PCT - _SPEED_REDUCTION ))
    # Floor at 1%
    if [ $_EFFECTIVE_PCT -lt 1 ]; then _EFFECTIVE_PCT=1; fi

    _INTEREST=$(( PLAYER_DEBT * _EFFECTIVE_PCT / 100 ))
    # Minimum interest of 1 credit if any debt remains
    if [ $PLAYER_DEBT -gt 0 ] && [ $_INTEREST -eq 0 ]; then _INTEREST=1; fi

    _OLD_DEBT=$PLAYER_DEBT
    PLAYER_DEBT=$(( PLAYER_DEBT + _INTEREST ))
    PLAYER_DAY=$(( PLAYER_DAY + 1 ))

    # Random encounter during sleep (10% chance)
    rng 1 10
    _SLEEP_EVENT=$RNG_RESULT

    printf "  ${FC_BLK}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}\n"
    printf "  ${FC_CYN}Day %d${R} ${FC_BLK}→${R} ${FC_CYN}Day %d${R}\n\n" \
        "$(( PLAYER_DAY - 1 ))" "$PLAYER_DAY"
    printf "  ${FC_YLW}Debt:${R}    ¢%d ${FC_BLK}→${R} ¢%d ${FC_RED}(+¢%d at %d%% rate)${R}\n" \
        "$_OLD_DEBT" "$PLAYER_DEBT" "$_INTEREST" "$_EFFECTIVE_PCT"
    printf "\n"

    # Sleep event
    if [ $_SLEEP_EVENT -eq 1 ]; then
        # Positive event: anonymous credit transfer
        rng 50 200
        _BONUS=$RNG_RESULT
        PLAYER_CREDITS=$(( PLAYER_CREDITS + _BONUS ))
        printf "  ${FC_GRN}[NETWORK EVENT]${R} Anonymous transfer received: ${FC_GRN}+¢%d${R}\n" "$_BONUS"
        printf "  ${FC_BLK}Source untraceable. Accept and move on.${R}\n"
    elif [ $_SLEEP_EVENT -eq 2 ]; then
        # Negative event: security daemon charges a fee
        rng 30 120
        _FEE=$RNG_RESULT
        if [ $_FEE -gt $PLAYER_CREDITS ]; then _FEE=$PLAYER_CREDITS; fi
        PLAYER_CREDITS=$(( PLAYER_CREDITS - _FEE ))
        printf "  ${FC_RED}[SECURITY ALERT]${R} Trace daemon extracted ¢%d in countermeasure fees.\n" "$_FEE"
        printf "  ${FC_BLK}Encrypt deeper next time.${R}\n"
    elif [ $_SLEEP_EVENT -eq 3 ]; then
        # Neutral event: intel drop
        printf "  ${FC_MAG}[INTEL DROP]${R} Shadow network update:\n"
        rng_pick_word "$TARGETS"
        printf "  ${FC_BLK}\"${RNG_WORD_RESULT} has increased security. Expect harder resistance.\"${R}\n"
    else
        # Standard sleep messages
        rng 1 5
        case $RNG_RESULT in
            1) printf "  ${FC_BLK}You dream of clean RAM and zero latency.${R}\n" ;;
            2) printf "  ${FC_BLK}Your rig hums quietly in sleep mode.${R}\n" ;;
            3) printf "  ${FC_BLK}Neon bleeds through the blinds. Another day in the net.${R}\n" ;;
            4) printf "  ${FC_BLK}Neural static. You wake sweating but rested.${R}\n" ;;
            5) printf "  ${FC_BLK}The debt clock ticks. You sleep anyway.${R}\n" ;;
        esac
    fi

    printf "\n  ${FC_BLK}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}\n"
    pause
    check_end_conditions
}

# ------------------------------------------------------------------------------
# fn: screen_stats
# Full stats screen showing all player data and inventory.
# ------------------------------------------------------------------------------
screen_stats() {
    clear_screen
    draw_header
    draw_status_bar
    printf "\n"
    printf "  ${FC_MAG}${BOLD}// SYSTEM STATUS //${R}\n\n"

    _DAYS_LEFT=$(( PLAYER_MAX_DAYS - PLAYER_DAY + 1 ))
    _NET=$(( PLAYER_CREDITS - PLAYER_DEBT ))

    printf "  ${FC_BLK}┌─────────────────────────────────────────┐${R}\n"
    printf "  ${FC_BLK}│${R}  ${FC_CYN}FINANCIAL STATUS${R}                        ${FC_BLK}│${R}\n"
    printf "  ${FC_BLK}├─────────────────────────────────────────┤${R}\n"
    printf "  ${FC_BLK}│${R}  Credits:      ${FC_GRN}¢%-10d${R}              ${FC_BLK}│${R}\n" "$PLAYER_CREDITS"
    printf "  ${FC_BLK}│${R}  Debt:         ${FC_RED}¢%-10d${R}              ${FC_BLK}│${R}\n" "$PLAYER_DEBT"
    if [ $_NET -ge 0 ]; then
        printf "  ${FC_BLK}│${R}  Net Position: ${FC_GRN}+¢%-9d${R}              ${FC_BLK}│${R}\n" "$_NET"
    else
        printf "  ${FC_BLK}│${R}  Net Position: ${FC_RED}¢%-10d${R}              ${FC_BLK}│${R}\n" "$_NET"
    fi
    printf "  ${FC_BLK}│${R}  Days Left:    ${FC_YLW}%-3d / %-3d${R}                  ${FC_BLK}│${R}\n" \
        "$_DAYS_LEFT" "$PLAYER_MAX_DAYS"
    printf "  ${FC_BLK}└─────────────────────────────────────────┘${R}\n\n"

    printf "  ${FC_BLK}┌─────────────────────────────────────────┐${R}\n"
    printf "  ${FC_BLK}│${R}  ${FC_CYN}COMBAT STATISTICS${R}                      ${FC_BLK}│${R}\n"
    printf "  ${FC_BLK}├─────────────────────────────────────────┤${R}\n"
    printf "  ${FC_BLK}│${R}  Hack Power:  %3d  " "$PLAYER_HACK_POWER"
    draw_bar $PLAYER_HACK_POWER 100 15 "▓" "░"
    printf "  ${FC_BLK}│${R}\n"
    printf "  ${FC_BLK}│${R}  Defense:     %3d  " "$PLAYER_DEFENSE"
    draw_bar $PLAYER_DEFENSE 100 15 "▓" "░"
    printf "  ${FC_BLK}│${R}\n"
    printf "  ${FC_BLK}│${R}  Speed:       %3d  " "$PLAYER_SPEED"
    draw_bar $PLAYER_SPEED 100 15 "▓" "░"
    printf "  ${FC_BLK}│${R}\n"
    printf "  ${FC_BLK}│${R}  Reputation:  %3d  " "$PLAYER_REP"
    draw_bar $PLAYER_REP 50 15 "★" "·"
    printf "  ${FC_BLK}│${R}\n"
    printf "  ${FC_BLK}└─────────────────────────────────────────┘${R}\n\n"

    printf "  ${FC_BLK}┌─────────────────────────────────────────┐${R}\n"
    printf "  ${FC_BLK}│${R}  ${FC_CYN}SESSION LOG${R}                            ${FC_BLK}│${R}\n"
    printf "  ${FC_BLK}├─────────────────────────────────────────┤${R}\n"
    printf "  ${FC_BLK}│${R}  Jobs Completed: %-5d                  ${FC_BLK}│${R}\n" "$TOTAL_JOBS_DONE"
    printf "  ${FC_BLK}│${R}  Hacks Failed:   %-5d                  ${FC_BLK}│${R}\n" "$TOTAL_HACKS_FAILED"
    printf "  ${FC_BLK}│${R}  Items Purchased: %-4d                  ${FC_BLK}│${R}\n" "$TOTAL_ITEMS_BOUGHT"
    printf "  ${FC_BLK}└─────────────────────────────────────────┘${R}\n\n"

    # Inventory display
    printf "  ${FC_CYN}${BOLD}INSTALLED HARDWARE & SOFTWARE:${R}\n"
    if [ -z "$PLAYER_INVENTORY" ]; then
        printf "  ${FC_BLK}No items installed. Visit the Black Market.${R}\n"
    else
        count_words "$SHOP_NAMES"
        _TOTAL=$WORD_COUNT_RESULT
        _IDX=1
        while [ $_IDX -le $_TOTAL ]; do
            if string_contains "$PLAYER_INVENTORY" "|${_IDX}|"; then
                word_at_index "$SHOP_NAMES"   $_IDX; _INAME="$WORD_AT_RESULT"
                word_at_index "$SHOP_BONUSES" $_IDX; _IBONUS="$WORD_AT_RESULT"
                word_at_index "$SHOP_STATS"   $_IDX; _ISTAT="$WORD_AT_RESULT"
                printf "  ${FC_GRN}[ACTIVE]${R} ${FC_WHT}%s${R} ${FC_BLK}(+%d %s)${R}\n" \
                    "$_INAME" "$_IBONUS" "$_ISTAT"
            fi
            _IDX=$(( _IDX + 1 ))
        done
    fi
    printf "\n"
    pause
}

# =============================================================================
# HACKING MINI-GAME
# =============================================================================

# ------------------------------------------------------------------------------
# fn: minigame_hack
# The core combat system: a themed number-guessing game.
#
# DESIGN RATIONALE:
# The "combat" is a PIN-cracking simulation. The server has a 4-digit PIN.
# You must guess it using higher/lower hints - representing your hacking tools
# scanning port ranges and narrowing the attack surface.
#
# MECHANICS:
# - PIN range: 1000-9999
# - Base attempts: 3
# - Bonus attempts: +1 per 25 hack_power above 10
# - On success: receive payout, gain reputation
# - On failure: lose credits (damage), lose reputation, job is lost
#
# The difficulty of the job affects the feedback granularity (flavor only,
# the actual mechanic stays consistent so it's always beatable with skill).
# ------------------------------------------------------------------------------
minigame_hack() {
    clear_screen
    draw_header
    printf "\n"
    printf "  ${FC_RED}${BOLD}// INITIATING INTRUSION SEQUENCE //${R}\n"
    printf "  ${FC_BLK}Target: ${FC_WHT}${JOB_TARGET}${R}  ${FC_BLK}Operation: ${FC_CYN}${JOB_TYPE}${R}\n\n"

    # Generate PIN: 4 digits, range 1000-9999
    rng 1000 9999
    _SECRET_PIN=$RNG_RESULT

    # Calculate attempts allowed
    # Base 3, +1 per 25 hack_power over 10, max 7
    _BONUS_ATTEMPTS=$(( (PLAYER_HACK_POWER - 10) / 25 ))
    _MAX_ATTEMPTS=$(( 3 + _BONUS_ATTEMPTS ))
    if [ $_MAX_ATTEMPTS -gt 7 ]; then _MAX_ATTEMPTS=7; fi
    if [ $_MAX_ATTEMPTS -lt 1 ]; then _MAX_ATTEMPTS=1; fi

    printf "  ${FC_YLW}TARGET SYSTEM LOCKED${R}\n"
    printf "  ${FC_BLK}Security layer: ${FC_RED}PIN AUTHENTICATION${R}\n"
    printf "  ${FC_BLK}PIN format: ${FC_WHT}4-digit numeric (1000-9999)${R}\n"
    printf "  ${FC_BLK}Your scanner: ${FC_GRN}%d probe attempt(s) available${R}\n" "$_MAX_ATTEMPTS"
    printf "\n"
    printf "  ${FC_BLK}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}\n"
    printf "  ${FC_BLK}STRATEGY: Binary search. Each wrong guess halves search space.${R}\n"
    printf "  ${FC_BLK}Start with 5500, then adjust based on HIGHER/LOWER response.${R}\n"
    printf "  ${FC_BLK}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}\n\n"

    _ATTEMPT=1
    _HACK_SUCCESS=0

    while [ $_ATTEMPT -le $_MAX_ATTEMPTS ]; do
        # Remaining attempts indicator
        _REMAINING=$(( _MAX_ATTEMPTS - _ATTEMPT + 1 ))
        printf "  ${FC_CYN}[PROBE %d/%d]${R} " "$_ATTEMPT" "$_MAX_ATTEMPTS"

        # Visual attempt indicator: filled dots for remaining attempts
        _DOT=1
        while [ $_DOT -le $_MAX_ATTEMPTS ]; do
            if [ $_DOT -lt $_ATTEMPT ]; then
                printf "${FC_RED}✗${R}"
            elif [ $_DOT -eq $_ATTEMPT ]; then
                printf "${FC_YLW}▶${R}"
            else
                printf "${FC_GRN}○${R}"
            fi
            _DOT=$(( _DOT + 1 ))
        done
        printf "\n"

        printf "  ${FC_BLK}>>${R} Enter PIN probe (1000-9999): "
        read _GUESS

        # Validate input: must be numeric and 4 digits
        # Shell arithmetic: non-numeric will cause an error, trap with case
        case $_GUESS in
            ''|*[!0-9]*)
                printf "  ${FC_RED}INVALID${R}: Non-numeric input rejected by intrusion suite.\n\n"
                # Don't count this as an attempt
                continue
                ;;
        esac

        # Range check
        if [ $_GUESS -lt 1000 ] || [ $_GUESS -gt 9999 ]; then
            printf "  ${FC_RED}INVALID${R}: PIN must be 4-digit range (1000-9999).\n\n"
            continue
        fi

        # Evaluate guess
        if [ $_GUESS -eq $_SECRET_PIN ]; then
            # SUCCESS
            _HACK_SUCCESS=1
            printf "\n  ${FC_GRN}${BOLD}██████ ACCESS GRANTED ██████${R}\n\n"
            printf "  ${FC_GRN}PIN CONFIRMED: %d${R}\n" "$_SECRET_PIN"
            printf "  ${FC_GRN}Firewall bypassed. Data extraction in progress...${R}\n\n"
            break
        elif [ $_GUESS -lt $_SECRET_PIN ]; then
            # Theming the feedback based on difficulty
            if [ $JOB_DIFFICULTY -le 3 ]; then
                printf "  ${FC_YLW}◀ LOWER BOUND${R}: Target PIN is ${FC_WHT}HIGHER${R} than %d\n\n" "$_GUESS"
            elif [ $JOB_DIFFICULTY -le 7 ]; then
                printf "  ${FC_YLW}◀ SCAN RESULT${R}: Authentication layer rejects. Probe ${FC_WHT}HIGHER${R}.\n\n"
            else
                printf "  ${FC_YLW}◀ COUNTERMEASURE${R}: Vector rejected. Adjust ${FC_WHT}UPWARD${R}.\n\n"
            fi
        else
            if [ $JOB_DIFFICULTY -le 3 ]; then
                printf "  ${FC_YLW}▶ UPPER BOUND${R}: Target PIN is ${FC_WHT}LOWER${R} than %d\n\n" "$_GUESS"
            elif [ $JOB_DIFFICULTY -le 7 ]; then
                printf "  ${FC_YLW}▶ SCAN RESULT${R}: Authentication layer rejects. Probe ${FC_WHT}LOWER${R}.\n\n"
            else
                printf "  ${FC_YLW}▶ COUNTERMEASURE${R}: Vector rejected. Adjust ${FC_WHT}DOWNWARD${R}.\n\n"
            fi
        fi

        _ATTEMPT=$(( _ATTEMPT + 1 ))
    done

    # ---- Resolve hack outcome ----
    if [ $_HACK_SUCCESS -eq 1 ]; then
        # Calculate bonus pay for efficiency (fewer attempts used = bonus)
        _ATTEMPTS_USED=$(( _ATTEMPT ))
        _EFFICIENCY_BONUS=$(( (_MAX_ATTEMPTS - _ATTEMPTS_USED) * 50 ))
        _TOTAL_PAY=$(( JOB_PAYOUT + _EFFICIENCY_BONUS ))

        PLAYER_CREDITS=$(( PLAYER_CREDITS + _TOTAL_PAY ))
        PLAYER_REP=$(( PLAYER_REP + JOB_DIFFICULTY ))
        TOTAL_JOBS_DONE=$(( TOTAL_JOBS_DONE + 1 ))

        # Rep cap
        if [ $PLAYER_REP -gt 50 ]; then PLAYER_REP=50; fi

        printf "  ${FC_BLK}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}\n"
        printf "  ${FC_GRN}BASE PAYOUT:    ¢%d${R}\n" "$JOB_PAYOUT"
        if [ $_EFFICIENCY_BONUS -gt 0 ]; then
            printf "  ${FC_GRN}EFFICIENCY BONUS: ¢%d${R} ${FC_BLK}(solved in %d probes)${R}\n" \
                "$_EFFICIENCY_BONUS" "$_ATTEMPTS_USED"
        fi
        printf "  ${FC_GRN}${BOLD}TOTAL EARNED:   ¢%d${R}\n" "$_TOTAL_PAY"
        printf "  ${FC_MAG}REPUTATION:     +%d${R}\n" "$JOB_DIFFICULTY"
        printf "  ${FC_BLK}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}\n"

        # Clear job
        JOB_ACTIVE=0
        JOB_ACCEPTED=0

    else
        # FAILURE
        TOTAL_HACKS_FAILED=$(( TOTAL_HACKS_FAILED + 1 ))

        printf "\n  ${FC_RED}${BOLD}██████ INTRUSION DETECTED ██████${R}\n\n"
        printf "  ${FC_RED}PIN was: %d${R}\n" "$_SECRET_PIN"
        printf "  ${FC_RED}Security countermeasures engaged.${R}\n\n"

        # Damage calculation: based on difficulty vs defense
        _BASE_DAMAGE=$(( JOB_DIFFICULTY * 30 ))
        _DEFENSE_REDUCTION=$(( PLAYER_DEFENSE / 2 ))
        _DAMAGE=$(( _BASE_DAMAGE - _DEFENSE_REDUCTION ))
        if [ $_DAMAGE -lt 20 ]; then _DAMAGE=20; fi  # Minimum damage

        # Can't lose more than you have
        if [ $_DAMAGE -gt $PLAYER_CREDITS ]; then _DAMAGE=$PLAYER_CREDITS; fi

        PLAYER_CREDITS=$(( PLAYER_CREDITS - _DAMAGE ))
        _REP_LOSS=$(( JOB_DIFFICULTY / 2 ))
        PLAYER_REP=$(( PLAYER_REP - _REP_LOSS ))
        if [ $PLAYER_REP -lt 0 ]; then PLAYER_REP=0; fi

        printf "  ${FC_BLK}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}\n"
        printf "  ${FC_RED}COUNTERMEASURE DAMAGE: ¢%d${R}\n" "$_DAMAGE"
        printf "  ${FC_RED}REPUTATION LOSS:       -%d${R}\n" "$_REP_LOSS"
        printf "  ${FC_BLK}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}\n"

        # Job is lost regardless
        JOB_ACTIVE=0
        JOB_ACCEPTED=0
    fi

    pause
    check_end_conditions
}

# =============================================================================
# END CONDITION CHECKS
# =============================================================================

# ------------------------------------------------------------------------------
# fn: check_end_conditions
# Called after sleep and after hacks. Checks win/lose states.
# Win: PLAYER_CREDITS >= PLAYER_DEBT (can pay it off)
# Lose: Day > MAX_DAYS, or PLAYER_CREDITS <= 0 and day passes
# ------------------------------------------------------------------------------
check_end_conditions() {
    # Win condition: player has enough to pay off debt
    if [ $PLAYER_CREDITS -ge $PLAYER_DEBT ]; then
        screen_victory
        return
    fi

    # Lose condition 1: Out of days
    if [ $PLAYER_DAY -gt $PLAYER_MAX_DAYS ]; then
        screen_game_over "TIME"
        return
    fi

    # Lose condition 2: Completely broke AND in debt with no way to earn
    # (Only trigger if credits are 0 AND no job available - still fair)
    if [ $PLAYER_CREDITS -le 0 ] && [ $JOB_ACTIVE -eq 0 ]; then
        # Give them one more chance with a generated job before calling it
        : # Continue playing - bankruptcy isn't instant death
    fi
}

# ------------------------------------------------------------------------------
# fn: screen_victory
# Win screen. Displays stats summary.
# ------------------------------------------------------------------------------
screen_victory() {
    clear_screen
    printf "${FC_GRN}${BOLD}"
    printf "╔══════════════════════════════════════════════════════════════════════════════╗\n"
    printf "║                                                                              ║\n"
    printf "║          ██████╗ ███████╗██████╗ ████████╗    ██████╗ ███████╗███████╗      ║\n"
    printf "║          ██╔══██╗██╔════╝██╔══██╗╚══██╔══╝    ██╔══██╗██╔════╝██╔════╝      ║\n"
    printf "║          ██║  ██║█████╗  ██████╔╝   ██║       ██████╔╝█████╗  █████╗        ║\n"
    printf "║          ██║  ██║██╔══╝  ██╔══██╗   ██║       ██╔══██╗██╔══╝  ██╔══╝        ║\n"
    printf "║          ██████╔╝███████╗██████╔╝   ██║       ██║  ██║███████╗███████╗      ║\n"
    printf "║          ╚═════╝ ╚══════╝╚═════╝    ╚═╝       ╚═╝  ╚═╝╚══════╝╚══════╝      ║\n"
    printf "║                                                                              ║\n"
    printf "╚══════════════════════════════════════════════════════════════════════════════╝\n"
    printf "${R}\n"

    printf "  ${FC_GRN}DEBT CLEARED.${R} ${FC_WHT}The shadow board acknowledges your skill.${R}\n\n"
    printf "  ${FC_BLK}Operator:   ${FC_WHT}%s${R}\n"            "$PLAYER_NAME"
    printf "  ${FC_BLK}Days Used:  ${FC_CYN}%d / %d${R}\n"       "$PLAYER_DAY" "$PLAYER_MAX_DAYS"
    printf "  ${FC_BLK}Jobs Done:  ${FC_GRN}%d${R}\n"            "$TOTAL_JOBS_DONE"
    printf "  ${FC_BLK}Credits:    ${FC_GRN}¢%d${R}\n"           "$PLAYER_CREDITS"
    printf "  ${FC_BLK}Final Debt: ${FC_GRN}¢%d${R} ${FC_GRN}(PAID)${R}\n" "$PLAYER_DEBT"
    printf "  ${FC_BLK}Reputation: ${FC_MAG}%d / 50${R}\n\n"     "$PLAYER_REP"

    # Rating based on days used
    _DAYS_USED=$PLAYER_DAY
    if [ $_DAYS_USED -le 10 ]; then
        printf "  ${FC_GRN}${BOLD}RATING: S-TIER GHOST OPERATOR${R}\n"
        printf "  ${FC_BLK}\"You paid that debt before they even noticed you owed it.\"${R}\n"
    elif [ $_DAYS_USED -le 20 ]; then
        printf "  ${FC_YLW}${BOLD}RATING: A-TIER NETRUNNER${R}\n"
        printf "  ${FC_BLK}\"Clean work. The corps won't forget your handle.\"${R}\n"
    else
        printf "  ${FC_CYN}RATING: B-TIER STREET HACKER${R}\n"
        printf "  ${FC_BLK}\"Made it by the skin of your teeth. Impressive either way.\"${R}\n"
    fi

    printf "\n${FC_BLK}Press ENTER to exit NEON-NET.${R}\n"
    read _WIN_DUMMY
    GAME_OVER=1
    GAME_WON=1
}

# ------------------------------------------------------------------------------
# fn: screen_game_over REASON
# Lose screen.
# ------------------------------------------------------------------------------
screen_game_over() {
    _REASON="$1"
    clear_screen
    printf "${FC_RED}${BOLD}"
    printf "╔══════════════════════════════════════════════════════════════════════════════╗\n"
    printf "║                                                                              ║\n"
    printf "║      ██████╗  █████╗ ███╗   ███╗███████╗     ██████╗ ██╗   ██╗███████╗     ║\n"
    printf "║     ██╔════╝ ██╔══██╗████╗ ████║██╔════╝    ██╔═══██╗██║   ██║██╔════╝     ║\n"
    printf "║     ██║  ███╗███████║██╔████╔██║█████╗      ██║   ██║██║   ██║█████╗       ║\n"
    printf "║     ██║   ██║██╔══██║██║╚██╔╝██║██╔══╝      ██║   ██║╚██╗ ██╔╝██╔══╝       ║\n"
    printf "║     ╚██████╔╝██║  ██║██║ ╚═╝ ██║███████╗    ╚██████╔╝ ╚████╔╝ ███████╗     ║\n"
    printf "║      ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝     ╚═════╝   ╚═══╝  ╚══════╝     ║\n"
    printf "║                                                                              ║\n"
    printf "╚══════════════════════════════════════════════════════════════════════════════╝\n"
    printf "${R}\n"

    case $_REASON in
        TIME)
            printf "  ${FC_RED}DEADLINE EXCEEDED.${R} ${FC_WHT}The corporations have liquidated your assets.${R}\n\n"
            printf "  ${FC_BLK}\"Thirty days. That's what they gave you. You ran out.\"${R}\n\n"
            ;;
        BROKE)
            printf "  ${FC_RED}BANKRUPT.${R} ${FC_WHT}Rig repossessed. Identity sold to a data broker.${R}\n\n"
            ;;
        *)
            printf "  ${FC_RED}SYSTEM FAILURE.${R} ${FC_WHT}You've been disconnected permanently.${R}\n\n"
            ;;
    esac

    printf "  ${FC_BLK}Operator:    ${FC_WHT}%s${R}\n"           "$PLAYER_NAME"
    printf "  ${FC_BLK}Days Active: ${FC_CYN}%d / %d${R}\n"      "$PLAYER_DAY" "$PLAYER_MAX_DAYS"
    printf "  ${FC_BLK}Jobs Done:   ${FC_YLW}%d${R}\n"           "$TOTAL_JOBS_DONE"
    printf "  ${FC_BLK}Hacks Lost:  ${FC_RED}%d${R}\n"           "$TOTAL_HACKS_FAILED"
    printf "  ${FC_BLK}Final Debt:  ${FC_RED}¢%d${R} ${FC_RED}(UNPAID)${R}\n" "$PLAYER_DEBT"
    printf "  ${FC_BLK}Credits:     ${FC_YLW}¢%d${R}\n\n"        "$PLAYER_CREDITS"
    printf "  ${FC_BLK}\"The debt always wins. Until it doesn't.\"${R}\n\n"

    printf "${FC_BLK}Press ENTER to exit NEON-NET.${R}\n"
    read _LOSE_DUMMY
    GAME_OVER=1
}

# =============================================================================
# INTRO & SETUP
# =============================================================================

# ------------------------------------------------------------------------------
# fn: screen_intro
# Title sequence and character setup.
# ------------------------------------------------------------------------------
screen_intro() {
    clear_screen
    # Typewriter effect using printf + read with tiny pauses
    # We can't use 'sleep' (external), so we approximate delay with a loop
    # that does arithmetic - this creates minimal but noticeable CPU-bound delay
    _delay() {
        _C=0
        while [ $_C -lt 50000 ]; do
            _C=$(( _C + 1 ))
        done
    }

    draw_header
    printf "\n"
    printf "  ${FC_BLK}Initializing shadow terminal...${R}\n"
    _delay
    printf "  ${FC_BLK}Routing through proxy chain: ["; _delay
    printf "██"; _delay; printf "████"; _delay; printf "██████"; _delay
    printf "████████"; _delay; printf "██████████${R}${FC_BLK}]${R}\n"
    printf "  ${FC_BLK}Encryption layer: ACTIVE${R}\n"
    _delay
    printf "  ${FC_BLK}Identity mask: ENABLED${R}\n"
    _delay
    printf "  ${FC_BLK}Shadow board connection: ESTABLISHED${R}\n\n"
    _delay

    printf "  ${FC_CYN}${BOLD}TRANSMISSION INCOMING...${R}\n\n"
    printf "  ${FC_WHT}You owe us ¢10,000.${R}\n"
    printf "  ${FC_WHT}We gave you 30 days.${R}\n"
    printf "  ${FC_WHT}We are not patient people.${R}\n\n"
    printf "  ${FC_WHT}The jobs are queued. The market is open.${R}\n"
    printf "  ${FC_WHT}Earn. Pay. Or disappear.${R}\n\n"
    printf "  ${FC_BLK}                              -- The Shadow Board${R}\n\n"

    printf "  ${FC_BLK}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}\n"
    printf "  ${FC_CYN}Enter your operator handle: ${R}"
    read PLAYER_NAME

    # Default name if empty
    if [ -z "$PLAYER_NAME" ]; then
        PLAYER_NAME="Ghost"
    fi

    # Sanitize: keep first 12 chars if longer (pure shell parameter expansion)
    PLAYER_NAME="${PLAYER_NAME%"${PLAYER_NAME#????????????}"}"

    printf "\n  ${FC_GRN}Welcome to the net, ${PLAYER_NAME}.${R}\n"
    printf "  ${FC_BLK}Starting credits: ¢500. Debt: ¢10,000. Days remaining: 30.${R}\n\n"

    printf "  ${FC_YLW}QUICK REFERENCE:${R}\n"
    printf "  ${FC_BLK}• Accept a job, then execute the hack to earn credits${R}\n"
    printf "  ${FC_BLK}• Hacking = PIN cracking. Use binary search (higher/lower hints)${R}\n"
    printf "  ${FC_BLK}• Sleep advances the day but adds interest to your debt${R}\n"
    printf "  ${FC_BLK}• Buy gear from the Black Market to improve your stats${R}\n"
    printf "  ${FC_BLK}• Win by earning enough credits to cover your total debt${R}\n\n"

    pause

    # Pre-generate the first job so there's always one waiting
    generate_job
}

# =============================================================================
# MAIN GAME LOOP
# =============================================================================

# ------------------------------------------------------------------------------
# The main loop is a simple while/case construct.
# Every iteration draws the menu and reads one choice.
# Sub-screens are called as functions; they return here when done.
# This is the "Open World Sandbox" structure - no forced progression.
# ------------------------------------------------------------------------------
main_loop() {
    while [ $GAME_OVER -eq 0 ]; do
        draw_main_menu
        read _MAIN_CHOICE

        case $_MAIN_CHOICE in
            1) screen_job_board ;;
            2) screen_black_market ;;
            3) screen_sleep ;;
            4) screen_stats ;;
            5)
                if [ $JOB_ACCEPTED -eq 1 ]; then
                    minigame_hack
                else
                    # Provide feedback without a separate screen
                    clear_screen
                    draw_header
                    draw_status_bar
                    printf "\n  ${FC_RED}No active contract. Accept a job first (Option 1).${R}\n"
                    pause
                fi
                ;;
            0)
                clear_screen
                printf "\n  ${FC_BLK}Disconnecting from shadow terminal...${R}\n"
                printf "  ${FC_BLK}Clearing proxy logs...${R}\n"
                printf "  ${FC_BLK}Identity mask: STANDBY${R}\n\n"
                printf "  ${FC_CYN}Stay ghost, ${PLAYER_NAME}.${R}\n\n"
                GAME_OVER=1
                ;;
            *)
                # Silently ignore invalid input - just redraw the menu
                ;;
        esac
    done
}

# =============================================================================
# ENTRY POINT
# =============================================================================
# Script execution begins here.

screen_intro
main_loop

# Clean exit
exit 0