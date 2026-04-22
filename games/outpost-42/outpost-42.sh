#!/bin/sh
# =============================================================================
# NIGHT SHIFT AT OUTPOST 42 - Enhanced Edition
# A Survival Horror RPG for a single POSIX sh script.
# Compatible with Alpine Linux's /bin/sh (busybox ash).
#
# DESIGN NOTES:
#   - Zero external dependencies. Uses ONLY shell built-ins and POSIX features.
#   - $RANDOM is a bash/ash extension, but is available in busybox ash.
#   - printf "\033c" sends the RIS (Reset to Initial State) ANSI escape code,
#     which clears the screen more reliably than 'clear' on most terminals.
#   - All arithmetic is done with $(( )) for POSIX compliance.
#   - 'read' with no flags (no -s, no -t) is used for maximum compatibility.
# =============================================================================

# Check terminal support
if [ ! -t 0 ]; then
    echo "Error: This game requires an interactive terminal"
    exit 1
fi

# =============================================================================
# SECTION 1: CONSTANTS & INITIAL STATE
# These are the starting values and fixed costs for the entire game.
# =============================================================================

# --- Starting Resources ---
GENERATOR_FUEL=80   # The critical resource. Drains every hour. Hits 0 = death.
DOOR_STRENGTH=100   # How well the doors are holding. If it hits 0 = death.
PANIC_LEVEL=10      # Your mental state. High panic = bad random events. 0-100.

# --- Fixed Costs Per Hour (what happens automatically, before player acts) ---
# These represent the environment working against you passively.
FUEL_DRAIN_PER_HOUR=12  # The blizzard forces the generator to work hard.
DOOR_DECAY_PER_HOUR=8   # Whatever is out there claws at the doors constantly.
PANIC_RISE_PER_HOUR=7   # Being alone in the dark takes a toll.

# --- Action Point Economy ---
# Each hour, the player gets 2 Action Points to spend on 3 possible actions.
# This is the core resource management tension: you can never do everything.
ACTIONS_PER_HOUR=2
ACTIONS_REMAINING=2

# --- Event tracking ---
TOTAL_EVENTS=0
CRITICAL_EVENTS=0
WHISPERS_HEARD=0
SHADOWS_SEEN=0
SANITY_EVENTS=0
POWER_SURGES=0
DOOR_BREACHES=0

# --- Action Effects (what each action does when taken) ---
FUEL_FROM_REPAIR=25    # Repairing generator restores this much fuel.
STRENGTH_FROM_BARRICADE=22 # Barricading restores this much door strength.
PANIC_FROM_CAMERAS=15  # Checking cameras REDUCES panic by this much.

# --- Thresholds for random events ---
# If PANIC is above this, there's a chance a bad event triggers each hour.
PANIC_EVENT_THRESHOLD=40

# --- Win/Loss Boundaries ---
FUEL_MIN=0
DOOR_MIN=0
PANIC_MAX=100

# --- Hour tracking ---
CURRENT_HOUR=0
TOTAL_HOURS=6
NIGHT_PHASE=0  # 0=early, 1=mid, 2=late - affects event difficulty
IS_STORMY=false  # Weather condition affecting difficulty


# =============================================================================
# SECTION 2: HELPER FUNCTIONS
# Small, reusable pieces of logic called throughout the game.
# =============================================================================

# --- ANSI Color Codes ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
BOLD='\033[1m'
DIM='\033[2m'
BLINK='\033[5m'
NC='\033[0m'
ORANGE='\033[38;5;208m'
PURPLE='\033[38;5;129m'
CRIMSON='\033[38;5;196m'
TEAL='\033[38;5;43m'

# --- clamp VALUE MIN MAX ---
# Ensures a value never goes below MIN or above MAX.
# This prevents stats from going to -50 or 150, which would break the UI.
# We use a subshell with echo to "return" a value from a function in sh.
clamp() {
    _val=$1
    _min=$2
    _max=$3
    if [ "$_val" -lt "$_min" ]; then
        _val=$_min
    fi
    if [ "$_val" -gt "$_max" ]; then
        _val=$_max
    fi
    echo "$_val"
}

# --- draw_bar CURRENT MAX WIDTH ---
# Draws a simple ASCII progress bar. Example: [████████░░░░░░░░] 50%
# This gives the "dashboard" feel without ncurses.
#
# HOW IT WORKS:
#   1. Calculate how many filled blocks = (CURRENT * WIDTH) / MAX
#   2. Print that many filled chars, then the remainder as empty chars.
#   3. Uses printf's ability to repeat a character via a loop.
#      We avoid seq (external command) by using a while loop.
draw_bar() {
    _current=$1
    _max=$2
    _width=$3
    
    # Avoid division by zero if max is somehow 0
    if [ "$_max" -eq 0 ]; then
        _filled=0
    else
        _filled=$(( (_current * _width) / _max  ))
    fi
    _empty=$(( _width - _filled  ))

    printf "["
    _i=0
    while [ "$_i" -lt "$_filled" ]; do
        printf "█"
        _i=$(( _i + 1  ))
    done
    _i=0
    while [ "$_i" -lt "$_empty" ]; do
        printf "░"
        _i=$(( _i + 1  ))
    done
    printf "]"
}

# --- horror_flash ---
# Creates a screen flash effect for horror moments
horror_flash() {
    printf "\033[?5h"
    sleep 0.15
    printf "\033[?5l"
    sleep 0.05
}

# --- typing_effect TEXT DELAY COLOR ---
# Types text character by character for atmosphere
typing_effect() {
    _TEXT="$1"
    _DELAY=${2:-0.05}
    _COLOR="$3"
    _LEN=${#_TEXT}
    _I=0
    while [ $_I -lt $_LEN ]; do
        _CHAR=$(printf '%s' "$_TEXT" | cut -c$((_I+1))-$((_I+1)))
        printf "${_COLOR}%s${NC}" "$_CHAR"
        sleep $_DELAY
        _I=$(( _I + 1 ))
    done
    printf "\n"
}

# --- heartbeat ---
# Simulates a heartbeat effect
heartbeat() {
    printf "\r${CRIMSON}♥${NC}  "
    sleep 0.3
    printf "\r  ${CRIMSON}♥${NC}"
    sleep 0.2
    printf "\r"
}

# --- static_noise ---
# Creates static noise effect for atmosphere
static_noise() {
    _I=0
    while [ $_I -lt 5 ]; do
        printf "${GRAY}"
        _J=0
        while [ $_J -lt 40 ]; do
            _CHAR=$(printf '%s' "#*@%" | cut -c$((RANDOM % 4 + 1))-$((RANDOM % 4 + 1)))
            printf "%s" "$_CHAR"
            _J=$(( _J + 1 ))
        done
        printf "${NC}\n"
        sleep 0.1
        _I=$(( _I + 1 ))
    done
}

# --- get_status_color VALUE HIGH_IS_BAD ---
# Returns an ANSI color code string based on a value.
# HIGH_IS_BAD: pass "1" if a HIGH value is dangerous (like PANIC),
#              pass "0" if a LOW value is dangerous (like FUEL, DOOR_STRENGTH).
# Colors: Green (safe) > Yellow (caution) > Red (danger)
#
# We use printf to output the escape codes. We do NOT use 'tput' because
# that's an external command. Raw ANSI codes are a built-in capability of printf.
get_status_color() {
    _val=$1
    _high_is_bad=$2
    
    if [ "$_high_is_bad" -eq 1 ]; then
        # High is dangerous (Panic)
        if [ "$_val" -lt 30 ]; then
            printf "\033[32m"  # Green
        elif [ "$_val" -lt 60 ]; then
            printf "\033[33m"  # Yellow
        else
            printf "\033[31m"  # Red
        fi
    else
        # Low is dangerous (Fuel, Door)
        if [ "$_val" -gt 60 ]; then
            printf "\033[32m"  # Green
        elif [ "$_val" -gt 30 ]; then
            printf "\033[33m"  # Yellow
        else
            printf "\033[31m"  # Red
        fi
    fi
}

RESET="\033[0m"    # ANSI reset code - turns off all color/formatting
BOLD="\033[1m"
DIM="\033[2m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
WHITE="\033[37m"

# Animation functions
screen_shake() {
    printf "\033[5;5H"
    sleep 0.05
    printf "\033[H"
}

play_sound() {
    printf "\007"
}

flash_screen() {
    printf "\033[?5h"
    sleep 0.1
    printf "\033[?5l"
}


# =============================================================================
# SECTION 3: THE DISPLAY FUNCTION
# Draws the entire game screen. Called at the start of each action phase.
# This is the heart of the "terminal UI" feel.
# =============================================================================

draw_dashboard() {
    # \033c is the ANSI "Reset to Initial State" escape sequence.
    # It clears the screen AND moves the cursor to the top-left.
    # This is more reliable than \033[2J\033[H on terminal emulators.
    printf "\033c"
    
    # Calculate the time string for the current hour
    _hour_time=$(( 0 + CURRENT_HOUR ))
    case "$_hour_time" in
        0) _time_str="12:00 AM" ;;
        1) _time_str="01:00 AM" ;;
        2) _time_str="02:00 AM" ;;
        3) _time_str="03:00 AM" ;;
        4) _time_str="04:00 AM" ;;
        5) _time_str="05:00 AM" ;;
        6) _time_str="06:00 AM -- DAWN" ;;
    esac

    printf "${BOLD}╔══════════════════════════════════════════╗${RESET}\n"
    printf "${BOLD}║${CYAN}     OUTPOST 42 - NIGHT WATCH ${CYAN}        ║${RESET}\n"
    printf "${BOLD}╚══════════════════════════════════════════╝${RESET}\n"
    printf "\n"
    printf "  ${DIM}Hour: %d/%d   Time: %s${RESET}\n" "$CURRENT_HOUR" "$TOTAL_HOURS" "$_time_str"
    printf "  ${DIM}Actions Remaining: ${YELLOW}%d/%d${RESET}\n\n" "$ACTIONS_REMAINING" "$ACTIONS_PER_HOUR"
    printf "${BOLD}  ── STATION STATUS ─────────────────────────${RESET}\n"
    printf "\n"

    # --- Generator Fuel ---
    _color=$(get_status_color "$GENERATOR_FUEL" 0)
    printf "  ${YELLOW}⚡${RESET} GENERATOR  %b" "$_color"
    draw_bar "$GENERATOR_FUEL" 100 20
    printf " %3d%% ${RESET}\n" "$GENERATOR_FUEL"

    # --- Door Strength ---
    _color=$(get_status_color "$DOOR_STRENGTH" 0)
    printf "  ${RED}🚪${RESET} DOORS      %b" "$_color"
    draw_bar "$DOOR_STRENGTH" 100 20
    printf " %3d%% ${RESET}\n" "$DOOR_STRENGTH"

    # --- Panic Level ---
    _color=$(get_status_color "$PANIC_LEVEL" 1)
    printf "  ${MAGENTA}😱${RESET} PANIC      %b" "$_color"
    draw_bar "$PANIC_LEVEL" 100 20
    printf " %3d%% ${RESET}\n" "$PANIC_LEVEL"
    
    printf "\n"
    printf "${BOLD}  ── EVENT LOG ───────────────────────────────${RESET}\n"
    # EVENT_LOG is a global string set before draw_dashboard is called.
    # We use printf '%s\n' to safely print it even if it contains special chars.
    printf "  %s\n" "$EVENT_LOG"
    printf "  ${DIM}Events: %d | Critical: %d${RESET}\n" "$TOTAL_EVENTS" "$CRITICAL_EVENTS"
    printf "\n"
}


# =============================================================================
# SECTION 4: THE RANDOM EVENT ENGINE
# Each hour, after passive decay, we check if a random event fires.
# Events are more likely and worse when PANIC is high.
# =============================================================================

# --- roll_random_event ---
# Uses $RANDOM (a built-in in bash/ash that gives 0-32767) to determine
# if an event fires. If PANIC is high, the threshold is easier to hit.
roll_random_event() {
    EVENT_LOG="${DIM}The blizzard howls. The night is quiet... for now.${RESET}"
    
    # Update night phase based on hour
    if [ $CURRENT_HOUR -lt 2 ]; then
        NIGHT_PHASE=0
    elif [ $CURRENT_HOUR -lt 4 ]; then
        NIGHT_PHASE=1
    else
        NIGHT_PHASE=2
    fi
    
    # Storm chance increases with night phase
    if [ $((RANDOM % 10)) -lt $((NIGHT_PHASE * 2)) ]; then
        IS_STORMY=true
    else
        IS_STORMY=false
    fi
    
    # Only roll for bad events if panic is above the threshold.
    # This creates a "death spiral": high panic -> more bad events -> higher panic
    if [ "$PANIC_LEVEL" -gt "$PANIC_EVENT_THRESHOLD" ]; then
        TOTAL_EVENTS=$((TOTAL_EVENTS + 1))
        
        # $RANDOM gives 0-32767. Modulo 100 gives 0-99. 
        # A roll under (PANIC_LEVEL / 2) triggers an event.
        # So at 50 panic, 25% chance. At 90 panic, 45% chance.
        _roll=$(( RANDOM % 100 ))
        _event_threshold=$(( PANIC_LEVEL / 2 ))
        
        # Storm increases event chance
        if [ "$IS_STORMY" = true ]; then
            _event_threshold=$(( _event_threshold + 10 ))
        fi
        
        if [ "$_roll" -lt "$_event_threshold" ]; then
            # An event fires! Roll again to pick WHICH event.
            _event_type=$(( RANDOM % 8 ))
            
            case "$_event_type" in
                0)
                    # Fuel leak - panic made you careless in your last check
                    _drain=$(( (RANDOM % 10) + 5 ))
                    GENERATOR_FUEL=$(( GENERATOR_FUEL - _drain ))
                    EVENT_LOG="${RED}!! FUEL LEAK: ${_drain}% lost to the cold!${RESET}"
                    CRITICAL_EVENTS=$((CRITICAL_EVENTS + 1))
                    play_sound
                    screen_shake
                    ;;
                1)
                    # Banging on the walls - it found a weak spot
                    _dmg=$(( (RANDOM % 12) + 8 ))
                    DOOR_STRENGTH=$(( DOOR_STRENGTH - _dmg ))
                    EVENT_LOG="${RED}!! BANGING: East door takes ${_dmg} damage!${RESET}"
                    CRITICAL_EVENTS=$((CRITICAL_EVENTS + 1))
                    DOOR_BREACHES=$((DOOR_BREACHES + 1))
                    play_sound
                    screen_shake
                    ;;
                2)
                    # The cameras glitch - pure psychological horror, raises panic
                    _panic_rise=$(( (RANDOM % 8) + 5 ))
                    PANIC_LEVEL=$(( PANIC_LEVEL + _panic_rise ))
                    EVENT_LOG="${MAGENTA}!! CAMERA GLITCH: You see a FACE! +${_panic_rise} panic!${RESET}"
                    SANITY_EVENTS=$((SANITY_EVENTS + 1))
                    flash_screen
                    static_noise
                    ;;
                3)
                    # The power flickers - fuel AND panic hit
                    _drain=$(( (RANDOM % 6) + 3 ))
                    _panic_rise=5
                    GENERATOR_FUEL=$(( GENERATOR_FUEL - _drain ))
                    PANIC_LEVEL=$(( PANIC_LEVEL + _panic_rise ))
                    EVENT_LOG="${RED}!! POWER OUTAGE: -${_drain}% fuel, +${_panic_rise} panic!${RESET}"
                    CRITICAL_EVENTS=$((CRITICAL_EVENTS + 1))
                    POWER_SURGES=$((POWER_SURGES + 1))
                    play_sound
                    flash_screen
                    screen_shake
                    ;;
                4)
                    # Whispers in the dark - psychological horror
                    _panic_rise=$(( (RANDOM % 10) + 5 ))
                    PANIC_LEVEL=$(( PANIC_LEVEL + _panic_rise ))
                    EVENT_LOG="${PURPLE}!! WHISPERS: You hear voices calling your name... +${_panic_rise} panic!${RESET}"
                    WHISPERS_HEARD=$((WHISPERS_HEARD + 1))
                    SANITY_EVENTS=$((SANITY_EVENTS + 1))
                    heartbeat
                    ;;
                5)
                    # Shadow movement - you're not alone
                    _panic_rise=$(( (RANDOM % 8) + 8 ))
                    PANIC_LEVEL=$(( PANIC_LEVEL + _panic_rise ))
                    EVENT_LOG="${GRAY}!! SHADOW: Something moved in the corner of your eye... +${_panic_rise} panic!${RESET}"
                    SHADOWS_SEEN=$((SHADOWS_SEEN + 1))
                    SANITY_EVENTS=$((SANITY_EVENTS + 1))
                    horror_flash
                    ;;
                6)
                    # Storm damage - if it's storming outside
                    if [ "$IS_STORMY" = true ]; then
                        _drain=$(( (RANDOM % 8) + 5 ))
                        GENERATOR_FUEL=$(( GENERATOR_FUEL - _drain ))
                        EVENT_LOG="${ORANGE}!! STORM: Blizzard strains the generator! -${_drain}% fuel!${RESET}"
                        CRITICAL_EVENTS=$((CRITICAL_EVENTS + 1))
                        play_sound
                    else
                        # Fallback to minor event
                        _panic_rise=3
                        PANIC_LEVEL=$(( PANIC_LEVEL + _panic_rise ))
                        EVENT_LOG="${YELLOW}!! CREAK: The old building settles... +${_panic_rise} panic${RESET}"
                    fi
                    ;;
                7)
                    # Door breach attempt - critical event
                    _dmg=$(( (RANDOM % 15) + 10 ))
                    DOOR_STRENGTH=$(( DOOR_STRENGTH - _dmg ))
                    _panic_rise=15
                    PANIC_LEVEL=$(( PANIC_LEVEL + _panic_rise ))
                    EVENT_LOG="${CRIMSON}!! BREACH: Something claws at the door! -${_dmg}% door strength! +${_panic_rise} panic!${RESET}"
                    CRITICAL_EVENTS=$((CRITICAL_EVENTS + 1))
                    DOOR_BREACHES=$((DOOR_BREACHES + 1))
                    play_sound
                    horror_flash
                    screen_shake
                    ;;
            esac
        fi
    fi
    
    # Clamp all values after the event to prevent out-of-range states
    GENERATOR_FUEL=$(clamp "$GENERATOR_FUEL" 0 100)
    DOOR_STRENGTH=$(clamp "$DOOR_STRENGTH" 0 100)
    PANIC_LEVEL=$(clamp "$PANIC_LEVEL" 0 100)
}


# =============================================================================
# SECTION 5: THE PASSIVE DECAY FUNCTION
# At the start of each new hour, the environment gets worse automatically.
# This is the "clock" that creates the survival tension.
# =============================================================================

apply_hourly_decay() {
    GENERATOR_FUEL=$(( GENERATOR_FUEL - FUEL_DRAIN_PER_HOUR ))
    DOOR_STRENGTH=$(( DOOR_STRENGTH - DOOR_DECAY_PER_HOUR ))
    PANIC_LEVEL=$(( PANIC_LEVEL + PANIC_RISE_PER_HOUR ))
    
    # Clamp immediately after decay
    GENERATOR_FUEL=$(clamp "$GENERATOR_FUEL" 0 100)
    DOOR_STRENGTH=$(clamp "$DOOR_STRENGTH" 0 100)
    PANIC_LEVEL=$(clamp "$PANIC_LEVEL" 0 100)
}


# =============================================================================
# SECTION 6: THE ACTION FUNCTIONS
# These are called when the player chooses an action.
# Each one modifies state and sets a feedback message.
# =============================================================================

action_repair_generator() {
    # There's a small random variance to make it feel less mechanical
    _bonus=$(( (RANDOM % 5) - 2 ))  # -2 to +2 variance
    _gained=$(( FUEL_FROM_REPAIR + _bonus ))
    GENERATOR_FUEL=$(( GENERATOR_FUEL + _gained ))
    GENERATOR_FUEL=$(clamp "$GENERATOR_FUEL" 0 100)
    ACTIONS_REMAINING=$((ACTIONS_REMAINING - 1))
    # Repairing doesn't directly help panic - it's a practical task
    ACTION_FEEDBACK="${GREEN}✓${RESET} Generator repaired. +${_gained}% fuel."
    play_sound
}

action_barricade_doors() {
    _bonus=$(( (RANDOM % 6) - 2 ))  # -2 to +3 variance
    _gained=$(( STRENGTH_FROM_BARRICADE + _bonus ))
    DOOR_STRENGTH=$(( DOOR_STRENGTH + _gained ))
    DOOR_STRENGTH=$(clamp "$DOOR_STRENGTH" 0 100)
    ACTIONS_REMAINING=$((ACTIONS_REMAINING - 1))
    # Barricading is exhausting but necessary
    ACTION_FEEDBACK="${GREEN}✓${RESET} Doors reinforced. +${_gained}% strength."
    play_sound
}

action_check_cameras() {
    _bonus=$(( (RANDOM % 4) - 1 ))  # -1 to +2 variance
    _reduced=$(( PANIC_FROM_CAMERAS + _bonus ))
    PANIC_LEVEL=$(( PANIC_LEVEL - _reduced ))
    PANIC_LEVEL=$(clamp "$PANIC_LEVEL" 0 100)
    ACTIONS_REMAINING=$((ACTIONS_REMAINING - 1))
    # Checking cameras gives peace of mind
    ACTION_FEEDBACK="${GREEN}✓${RESET} Cameras checked. -${_reduced}% panic."
    play_sound
}

# =============================================================================
# SECTION 7: THE ACTION MENU
# Shows available actions and handles user input.
# =============================================================================

show_action_menu() {
    printf "${BOLD}  ── AVAILABLE ACTIONS ──────────────────────${RESET}\n"
    printf "\n"
    printf "  ${YELLOW}1)${RESET} Repair Generator ${DIM}(+fuel)${RESET}\n"
    printf "  ${YELLOW}2)${RESET} Barricade Doors ${DIM}(+door strength)${RESET}\n"
    printf "  ${YELLOW}3)${RESET} Check Cameras ${DIM}(-panic)${RESET}\n"
    printf "\n"
    printf "  ${DIM}Choose action [1-3]: ${RESET}"
}

# =============================================================================
# SECTION 8: WIN/LOSE SCREENS
# =============================================================================

game_over() {
    printf "\033c"
    printf "${BOLD}${RED}╔══════════════════════════════════════════╗${RESET}\n"
    printf "${BOLD}${RED}║${RESET}         ${RED}☠  YOU DIED  ☠${RESET}           ${BOLD}${RED}║${RESET}\n"
    printf "${BOLD}${RED}╚══════════════════════════════════════════╝${RESET}\n"
    printf "\n"
    
    if [ "$GENERATOR_FUEL" -le 0 ]; then
        printf "  ${RED}The generator failed. You froze in the dark.${RESET}\n"
    elif [ "$DOOR_STRENGTH" -le 0 ]; then
        printf "  ${RED}The doors gave way. Something got in...${RESET}\n"
    elif [ "$PANIC_LEVEL" -ge 100 ]; then
        printf "  ${RED}Your mind broke. You ran into the blizzard.${RESET}\n"
    fi
    
    printf "\n"
    printf "  ${DIM}Hour reached: %d/%d${RESET}\n" "$CURRENT_HOUR" "$TOTAL_HOURS"
    printf "  ${DIM}Critical events: %d${RESET}\n" "$CRITICAL_EVENTS"
    printf "\n"
    printf "  ${YELLOW}Press Enter to exit...${RESET}\n"
    read _dummy
    exit 1
}

game_win() {
    printf "\033c"
    printf "${BOLD}${GREEN}╔══════════════════════════════════════════╗${RESET}\n"
    printf "${BOLD}${GREEN}║${RESET}       ${GREEN}☀  DAWN BREAKS  ☀${RESET}         ${BOLD}${GREEN}║${RESET}\n"
    printf "${BOLD}${GREEN}╚══════════════════════════════════════════╝${RESET}\n"
    printf "\n"
    printf "  ${GREEN}You survived the night at Outpost 42!${RESET}\n"
    printf "\n"
    printf "  ${DIM}Final Status:${RESET}\n"
    _color=$(get_status_color "$GENERATOR_FUEL" 0)
    printf "  ${YELLOW}⚡${RESET} Generator: %b%d%%%${RESET}\n" "$_color" "$GENERATOR_FUEL"
    _color=$(get_status_color "$DOOR_STRENGTH" 0)
    printf "  ${RED}🚪${RESET} Doors: %b%d%%%${RESET}\n" "$_color" "$DOOR_STRENGTH"
    _color=$(get_status_color "$PANIC_LEVEL" 1)
    printf "  ${MAGENTA}😱${RESET} Panic: %b%d%%%${RESET}\n" "$_color" "$PANIC_LEVEL"
    printf "\n"
    printf "  ${DIM}Critical events survived: %d${RESET}\n" "$CRITICAL_EVENTS"
    printf "\n"
    printf "  ${YELLOW}Press Enter to exit...${RESET}\n"
    read _dummy
    exit 0
}

# =============================================================================
# SECTION 9: MAIN GAME LOOP
# The core loop: decay -> event -> actions -> repeat
# =============================================================================

show_intro() {
    printf '\033c'
    printf "${CRIMSON}╔════════════════════════════════════════════════════════════════════════════╗${NC}\n"
    printf "${CRIMSON}║${NC} ${BOLD}${WHITE}🏚 NIGHT SHIFT AT OUTPOST 42 - Enhanced Edition 🏚${NC} ${CRIMSON}              ║${NC}\n"
    printf "${CRIMSON}╠════════════════════════════════════════════════════════════════════════════╣${NC}\n"
    printf "${CRIMSON}║${NC} ${WHITE}A survival horror RPG where you manage resources through the night${NC}    ${CRIMSON}║${NC}\n"
    printf "${CRIMSON}╠════════════════════════════════════════════════════════════════════════════╣${NC}\n"
    printf "${CRIMSON}║${NC} ${WHITE}Controls:${NC}                                                        ${CRIMSON}║${NC}\n"
    printf "${CRIMSON}║${NC} ${YELLOW}1-3${NC} ${WHITE}- Choose actions each hour${NC}                                ${CRIMSON}║${NC}\n"
    printf "${CRIMSON}║${NC} ${YELLOW}q${NC} ${WHITE}- Quit${NC}                                                              ${CRIMSON}║${NC}\n"
    printf "${CRIMSON}╠════════════════════════════════════════════════════════════════════════════╣${NC}\n"
    printf "${CRIMSON}║${NC} ${WHITE}Objective:${NC}                                                     ${CRIMSON}║${NC}\n"
    printf "${CRIMSON}║${NC} ${WHITE}- Survive 6 hours until morning${NC}                              ${CRIMSON}║${NC}\n"
    printf "${CRIMSON}║${NC} ${WHITE}- Manage generator fuel (FUEL)${NC}                               ${CRIMSON}║${NC}\n"
    printf "${CRIMSON}║${NC} ${WHITE}- Maintain door strength (DOOR)${NC}                               ${CRIMSON}║${NC}\n"
    printf "${CRIMSON}║${NC} ${WHITE}- Keep panic level low (PANIC)${NC}                                ${CRIMSON}║${NC}\n"
    printf "${CRIMSON}╠════════════════════════════════════════════════════════════════════════════╣${NC}\n"
    printf "${CRIMSON}║${NC} ${WHITE}Actions:${NC}                                                       ${CRIMSON}║${NC}\n"
    printf "${CRIMSON}║${NC} ${YELLOW}1) Repair Generator${NC} ${WHITE}- Restores fuel${NC}                           ${CRIMSON}║${NC}\n"
    printf "${CRIMSON}║${NC} ${YELLOW}2) Barricade Doors${NC} ${WHITE}- Strengthens doors${NC}                           ${CRIMSON}║${NC}\n"
    printf "${CRIMSON}║${NC} ${YELLOW}3) Check Cameras${NC} ${WHITE}- Reduces panic${NC}                               ${CRIMSON}║${NC}\n"
    printf "${CRIMSON}╚════════════════════════════════════════════════════════════════════════════╝${NC}\n"
    printf "${WHITE}Press any key to begin your shift...${NC}\n"
    read _dummy
    printf '\033c'
}

show_intro

# Initial draw
EVENT_LOG="Your shift begins. The blizzard howls outside."
draw_dashboard

while [ "$CURRENT_HOUR" -lt "$TOTAL_HOURS" ]; do
    # Apply passive decay for the new hour
    apply_hourly_decay
    
    # Roll for random events
    roll_random_event
    
    # Check for death conditions
    if [ "$GENERATOR_FUEL" -le "$FUEL_MIN" ] || [ "$DOOR_STRENGTH" -le "$DOOR_MIN" ] || [ "$PANIC_LEVEL" -ge "$PANIC_MAX" ]; then
        game_over
    fi
    
    # Reset action points for the new hour
    ACTIONS_REMAINING=$ACTIONS_PER_HOUR
    
    # Action phase loop
    while [ "$ACTIONS_REMAINING" -gt 0 ]; do
        draw_dashboard
        show_action_menu
        read _choice
        
        case "$_choice" in
            1)
                action_repair_generator
                EVENT_LOG="$ACTION_FEEDBACK"
                ;;
            2)
                action_barricade_doors
                EVENT_LOG="$ACTION_FEEDBACK"
                ;;
            3)
                action_check_cameras
                EVENT_LOG="$ACTION_FEEDBACK"
                ;;
            *)
                EVENT_LOG="${DIM}Invalid choice. Try again.${RESET}"
                continue
                ;;
        esac
        
        # Check for death after action
        if [ "$GENERATOR_FUEL" -le "$FUEL_MIN" ] || [ "$DOOR_STRENGTH" -le "$DOOR_MIN" ] || [ "$PANIC_LEVEL" -ge "$PANIC_MAX" ]; then
            game_over
        fi
    done
    
    # Advance to next hour
    CURRENT_HOUR=$((CURRENT_HOUR + 1))
done

# Win condition - survived all hours
game_win