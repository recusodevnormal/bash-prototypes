#!/bin/sh
# blood_and_banners.sh
# Medieval Dark Fantasy RPG
# Requires: sh (ash/dash/bash compatible), nothing else.
# Tested on Alpine Linux with /bin/sh (busybox ash)

# Check terminal support
if [ ! -t 0 ]; then
    echo "Error: This game requires an interactive terminal"
    exit 1
fi

# =============================================================================
# TERMINAL CONTROL
# Using raw ANSI escape codes via printf. No 'tput' dependency.
# =============================================================================
RESET='\033[0m'
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
DIM='\033[2m'
ORANGE='\033[38;5;208m'
PURPLE='\033[38;5;129m'
PINK='\033[38;5;206m'
TEAL='\033[38;5;43m'
LIME='\033[38;5;154m'
BROWN='\033[0;33m'
GRAY='\033[0;90m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'

clear_screen() {
    printf '\033[2J\033[H'
}

# Enhanced intro screen
show_intro() {
    clear_screen
    printf "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${RESET}\n"
    printf "${CYAN}║${RESET} ${BOLD}${YELLOW}⚔ BLOOD & BANNERS - Enhanced Edition ⚔${RESET} ${CYAN}                    ║${RESET}\n"
    printf "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${RESET}\n"
    printf "${CYAN}║${RESET} ${WHITE}A medieval dark fantasy conquest strategy game${RESET}                  ${CYAN}║${RESET}\n"
    printf "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${RESET}\n"
    printf "${CYAN}║${RESET} ${WHITE}Controls:${RESET}                                                       ${CYAN}║${RESET}\n"
    printf "${CYAN}║${RESET} ${YELLOW}WASD${RESET} ${WHITE}- Move on map  ${YELLOW}1-9${RESET} ${WHITE}- Menu choices${RESET}                       ${CYAN}║${RESET}\n"
    printf "${CYAN}║${RESET} ${YELLOW}q${RESET} ${WHITE}- Quit  ${YELLOW}s${RESET} ${WHITE}- Save  ${YELLOW}l${RESET} ${WHITE}- Load${RESET}                                ${CYAN}║${RESET}\n"
    printf "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${RESET}\n"
    printf "${CYAN}║${RESET} ${WHITE}Objective:${RESET}                                                     ${CYAN}║${RESET}\n"
    printf "${CYAN}║${RESET} ${WHITE}- Conquer all castles (C) to win${RESET}                             ${CYAN}║${RESET}\n"
    printf "${CYAN}║${RESET} ${WHITE}- Manage your gold, troops, and morale${RESET}                        ${CYAN}║${RESET}\n"
    printf "${CYAN}║${RESET} ${WHITE}- Survive random events and sieges${RESET}                           ${CYAN}║${RESET}\n"
    printf "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${RESET}\n"
    printf "${WHITE}Press any key to begin...${RESET}\n"
    read -r _
    clear_screen
}

# =============================================================================
# WORLD MAP DEFINITION
# 5x5 grid stored as a flat positional list.
# We use a shell function with a case statement to act as an associative lookup.
# The map is stored in a single string with cells separated by '|'.
# Cell types:
#   . = open plains
#   F = forest  (recruit peasants hiding here)
#   V = village (buy supplies, recruit)
#   R = road    (caravan raid opportunity, passable)
#   C = castle  (enemy, must be sieged)
#   X = captured castle
#   ~ = river   (impassable)
#   M = mountain (impassable, scenic)
#   S = swamp   (dangerous, high morale cost)
#   T = temple  (bless troops, heal)
#   D = dungeon (risk/reward)
# Layout (row 0 is top):
#   C . F . C
#   . ~ ~ ~ .
#   V R R R V
#   . ~ S ~ .
#   . F T F C
# =============================================================================

# Map is a pipe-delimited string. 25 cells, index 0-24.
# Row-major order: index = row*5 + col
MAP_INIT="C|.|F|.|C|.|~|~|~|.|V|R|R|R|V|.|~|S|~|.|.|F|T|F|C"

# We store the live map in positional parameters via a function that rebuilds
# a global string. Since we can't use arrays portably, we use a dedicated
# variable MAP and parse it with a helper.

MAP="$MAP_INIT"

# get_cell INDEX
# Prints the character at position INDEX in MAP.
get_cell() {
    _idx=$1
    _remaining="$MAP"
    _i=0
    while [ "$_i" -lt "$_idx" ]; do
        _remaining="${_remaining#*|}"
        _i=$(( _i + 1 ))
    done
    # _remaining now starts at our target cell
    _cell="${_remaining%%|*}"
    printf '%s' "$_cell"
}

# set_cell INDEX VALUE
# Returns a new MAP string with the cell at INDEX replaced by VALUE.
# We rebuild the string by iterating.
set_cell() {
    _idx=$1
    _val=$2
    _new_map=""
    _i=0
    _remaining="$MAP"
    while [ "$_i" -lt 25 ]; do
        _cell="${_remaining%%|*}"
        _remaining="${_remaining#*|}"
        if [ "$_i" -eq "$_idx" ]; then
            _cell="$_val"
        fi
        if [ "$_i" -eq 0 ]; then
            _new_map="$_cell"
        else
            _new_map="${_new_map}|${_cell}"
        fi
        _i=$(( _i + 1 ))
    done
    MAP="$_new_map"
}

# =============================================================================
# PLAYER STATE
# =============================================================================
PX=2          # Player column (0-4)
PY=2          # Player row    (0-4)
GOLD=50       # Starting gold
TROOPS=10     # Starting troops
MORALE=100    # 0-100, affects combat
CASTLES=3     # Castles remaining to conquer
TURN=1        # Turn counter
GAME_OVER=0   # Flag
MAX_TROOPS=50 # Max troop capacity
MAX_MORALE=100
MAX_SUPPLIES=50

# Castle defense values (static, keyed by map index)
# Indices: 0 (top-left C), 4 (top-right C), 24 (bottom-right C)
CASTLE_DEF_0=80
CASTLE_DEF_4=120
CASTLE_DEF_24=200

# Additional game state
SUPPLIES=10
BANNER_COUNT=0
WOUNDED=0
REINFORCEMENTS=0
TEMPLE_VISITS=0
DUNGEON_LOOTED=0
CARAVANS_RAIDED=0

# Track which castles have event messages
CASTLE_0_WARNED=0
CASTLE_4_WARNED=0
CASTLE_24_WARNED=0

# =============================================================================
# RENDER ENGINE
# =============================================================================

# draw_map
# Iterates all 25 cells, prints the map with player overlay.
# Adds color coding per cell type.
draw_map() {
    printf "${BOLD}${WHITE}"
    printf '  ╔═══════════╗\n'
    printf '  ║'
    
    _i=0
    _remaining="$MAP"
    while [ "$_i" -lt 25 ]; do
        _cell="${_remaining%%|*}"
        _remaining="${_remaining#*|}"
        
        # Column index
        _col=$(( _i % 5 ))
        
        # Check if player is here
        _pidx=$(( PY * 5 + PX ))
        if [ "$_i" -eq "$_pidx" ]; then
            printf "${BOLD}${YELLOW}@${RESET}${BOLD}${WHITE}"
        else
            case "$_cell" in
                C) printf "${RED}C${RESET}${BOLD}${WHITE}" ;;
                X) printf "${GREEN}X${RESET}${BOLD}${WHITE}" ;;
                F) printf "${GREEN}F${RESET}${BOLD}${WHITE}" ;;
                V) printf "${CYAN}V${RESET}${BOLD}${WHITE}" ;;
                R) printf "${DIM}R${RESET}${BOLD}${WHITE}" ;;
                '~') printf "${CYAN}~${RESET}${BOLD}${WHITE}" ;;
                S) printf "${PURPLE}S${RESET}${BOLD}${WHITE}" ;;
                T) printf "${LIME}T${RESET}${BOLD}${WHITE}" ;;
                M) printf "${GRAY}M${RESET}${BOLD}${WHITE}" ;;
                D) printf "${ORANGE}D${RESET}${BOLD}${WHITE}" ;;
                .) printf "${DIM}.${RESET}${BOLD}${WHITE}" ;;
                *) printf '%s' "$_cell" ;;
            esac
        fi
        
        # Spacing between cells
        if [ "$(( (_i+1) % 5 ))" -eq 0 ] && [ "$_i" -lt 24 ]; then
            # End of row
            printf " ║\n  ║"
        elif [ "$_i" -lt 24 ]; then
            printf ' '
        fi
        
        _i=$(( _i + 1 ))
    done
    
    printf " ║\n"
    printf "${BOLD}${WHITE}  ╚═══════════╝${RESET}\n"
}

# draw_legend
draw_legend() {
    printf "${DIM}  @ You  ${RED}C${DIM} Castle  ${GREEN}X${DIM} Captured\n"
    printf "  ${GREEN}F${DIM} Forest  ${CYAN}V${DIM} Village  R Road  ${CYAN}~${DIM} River\n"
    printf "  ${PURPLE}S${DIM} Swamp  ${LIME}T${DIM} Temple  ${ORANGE}D${DIM} Dungeon  ${GRAY}M${DIM} Mountain${RESET}\n"
}

# draw_hud
draw_hud() {
    printf "${BOLD}${WHITE}"
    printf '┌─────────────────────────────┐\n'
    printf "│ ${YELLOW}BLOOD & BANNERS${WHITE}  Turn: %-4s │\n" "$TURN"
    printf '├─────────────────────────────┤\n'
    printf "│ ${GREEN}Gold${WHITE}:   %-5s  ${ORANGE}Supplies${WHITE}: %-3s│\n" "$GOLD" "$SUPPLIES"
    printf "│ ${RED}Troops${WHITE}: %-5s  ${LIME}Banners${WHITE}: %-3s │\n" "$TROOPS" "$BANNER_COUNT"
    printf "│ Morale: %-3s%%  ${RED}Wounded${WHITE}: %-3s   │\n" "$MORALE" "$WOUNDED"
    printf "│ Castles left: %-2s             │\n" "$CASTLES"
    printf "│ Position: (${CYAN}%s${WHITE},${CYAN}%s${WHITE})             │\n" "$PX" "$PY"
    printf '└─────────────────────────────┘\n'
    printf "${RESET}"
}

# draw_screen
# Master render function called each turn.
draw_screen() {
    clear_screen
    printf "\n"
    draw_hud
    printf "\n"
    draw_map
    printf "\n"
    draw_legend
    printf "\n"
}

# =============================================================================
# MESSAGE LOG
# We keep a rolling 3-line message buffer using three variables.
# =============================================================================
MSG1=""
MSG2=""
MSG3=""

push_message() {
    MSG3="$MSG2"
    MSG2="$MSG1"
    MSG1="$1"
}

draw_messages() {
    printf "${DIM}  ┌─ Chronicle ────────────────────────────┐\n"
    printf "  │ %-40s│\n" "$MSG1"
    printf "  │ %-40s│\n" "$MSG2"
    printf "  │ %-40s│\n" "$MSG3"
    printf "  └────────────────────────────────────────┘${RESET}\n"
}

# =============================================================================
# COMBAT ENGINE
# =============================================================================

# siege_castle CASTLE_INDEX DEFENSE_VAR_NAME
# Attempts to siege the castle at CASTLE_INDEX.
# DEFENSE_VAR_NAME is the name of the variable holding the defense value.
siege_castle() {
    _cidx=$1
    _def_name=$2
    # Indirect variable expansion (POSIX-compatible via eval)
    eval "_def=\$$_def_name"
    
    push_message ">>> SIEGE BEGINS! Your ${TROOPS} troops charge!"
    draw_screen
    draw_messages
    printf "\n"
    
    # Attacker power: troops * random modifier (1-3) * morale factor
    # RANDOM range 0-32767. We want 1-3: (RANDOM % 3) + 1
    _atk_roll=$(( (RANDOM % 3) + 1 ))
    _morale_bonus=$(( MORALE / 50 ))   # 0, 1, or 2
    _attack=$(( TROOPS * _atk_roll + _morale_bonus * 10 ))
    
    # Defender power: static def + random chaos (0-40)
    _def_roll=$(( RANDOM % 41 ))
    _defense=$(( _def + _def_roll ))
    
    printf "${BOLD}${RED}  ⚔  SIEGE REPORT ⚔${RESET}\n"
    printf "  Your attack power : ${YELLOW}%s${RESET}\n" "$_attack"
    printf "  Castle defense    : ${RED}%s${RESET}\n" "$_defense"
    printf "\n"
    
    if [ "$_attack" -gt "$_defense" ]; then
        # Victory
        _loot=$(( (RANDOM % 80) + 40 ))
        _casualties=$(( (TROOPS * (RANDOM % 20)) / 100 ))
        GOLD=$(( GOLD + _loot ))
        TROOPS=$(( TROOPS - _casualties ))
        if [ "$TROOPS" -lt 1 ]; then TROOPS=1; fi
        CASTLES=$(( CASTLES - 1 ))
        set_cell "$_cidx" "X"
        
        printf "${BOLD}${GREEN}  *** VICTORY! The castle falls! ***${RESET}\n"
        printf "  Plunder gained : ${YELLOW}%s gold${RESET}\n" "$_loot"
        printf "  Troops lost    : ${RED}%s${RESET}\n" "$_casualties"
        push_message "Castle at index ${_cidx} CAPTURED! +"${_loot}" gold."
        
        if [ "$CASTLES" -eq 0 ]; then
            GAME_OVER=2  # Win condition
        fi
    else
        # Defeat
        _casualties=$(( (TROOPS * (RANDOM % 40 + 20)) / 100 ))
        _morale_loss=$(( (RANDOM % 20) + 10 ))
        TROOPS=$(( TROOPS - _casualties ))
        MORALE=$(( MORALE - _morale_loss ))
        if [ "$MORALE" -lt 0 ]; then MORALE=0; fi
        
        printf "${BOLD}${RED}  *** REPELLED! Your forces retreat! ***${RESET}\n"
        printf "  Troops lost  : ${RED}%s${RESET}\n" "$_casualties"
        printf "  Morale lost  : ${RED}%s${RESET}\n" "$_morale_loss"
        push_message "Siege failed. Lost ${_casualties} troops, -${_morale_loss} morale."
        
        if [ "$TROOPS" -le 0 ]; then
            GAME_OVER=1  # Lose condition
        fi
        
        # Push player back one step (south or north depending on position)
        if [ "$PY" -lt 4 ]; then
            _new_py=$(( PY + 1 ))
        else
            _new_py=$(( PY - 1 ))
        fi
        PY=$_new_py
    fi
    
    printf "\n  ${DIM}Press ENTER to continue...${RESET}"
    read -r _dummy
}

# =============================================================================
# RANDOM EVENTS
# Called on certain terrain types.
# =============================================================================

# event_forest
# Recruit peasants hiding in the forest.
event_forest() {
    _recruits=$(( (RANDOM % 8) + 2 ))
    _cost=$(( _recruits * 3 ))
    
    push_message "Forest: ${_recruits} peasants offer to join for ${_cost} gold."
    draw_screen
    draw_messages
    
    printf "${BOLD}${GREEN}  [ FOREST ENCAMPMENT ]${RESET}\n"
    printf "  Desperate peasants emerge from the shadows.\n"
    printf "  ${_recruits} men-at-arms will join for ${_cost} gold.\n\n"
    
    if [ "$GOLD" -ge "$_cost" ]; then
        printf "  Recruit them? (y/n): "
        read -r _ans
        if [ "$_ans" = "y" ] || [ "$_ans" = "Y" ]; then
            GOLD=$(( GOLD - _cost ))
            TROOPS=$(( TROOPS + _recruits ))
            MORALE=$(( MORALE + 5 ))
            if [ "$MORALE" -gt 100 ]; then MORALE=100; fi
            push_message "Recruited ${_recruits} troops. Army grows!"
        else
            push_message "You left the peasants behind."
        fi
    else
        printf "  ${RED}Not enough gold to hire them.${RESET}\n"
        printf "\n  ${DIM}Press ENTER...${RESET}"
        read -r _dummy
        push_message "Too poor to recruit. Need ${_cost} gold."
    fi
}

# event_village
# Villages offer supplies (morale/gold) or recruitment.
event_village() {
    # Random event: 50% chance trade, 50% chance recruitment
    _roll=$(( RANDOM % 2 ))
    
    push_message "You enter a village."
    draw_screen
    draw_messages
    
    printf "${BOLD}${CYAN}  [ VILLAGE ]${RESET}\n"
    
    if [ "$_roll" -eq 0 ]; then
        # Trade option
        _cost=20
        _morale_gain=$(( (RANDOM % 15) + 10 ))
        printf "  The innkeeper offers provisions for ${_cost} gold.\n"
        printf "  Your troops will gain ${_morale_gain} morale.\n\n"
        
        if [ "$GOLD" -ge "$_cost" ]; then
            printf "  Purchase? (y/n): "
            read -r _ans
            if [ "$_ans" = "y" ] || [ "$_ans" = "Y" ]; then
                GOLD=$(( GOLD - _cost ))
                MORALE=$(( MORALE + _morale_gain ))
                if [ "$MORALE" -gt 100 ]; then MORALE=100; fi
                push_message "Bought provisions. +${_morale_gain} morale."
            else
                push_message "Declined the innkeeper's offer."
            fi
        else
            printf "  ${RED}Cannot afford provisions.${RESET}\n"
            printf "\n  ${DIM}Press ENTER...${RESET}"
            read -r _dummy
            push_message "Not enough gold for provisions."
        fi
    else
        # Levy troops from village
        _levy=$(( (RANDOM % 5) + 3 ))
        _gold_cost=$(( _levy * 5 ))
        printf "  The village elder offers ${_levy} levies for ${_gold_cost} gold.\n\n"
        
        if [ "$GOLD" -ge "$_gold_cost" ]; then
            printf "  Conscript them? (y/n): "
            read -r _ans
            if [ "$_ans" = "y" ] || [ "$_ans" = "Y" ]; then
                GOLD=$(( GOLD - _gold_cost ))
                TROOPS=$(( TROOPS + _levy ))
                push_message "Levied ${_levy} troops from the village."
            else
                push_message "Left the village without conscripts."
            fi
        else
            printf "  ${RED}Insufficient gold to pay them.${RESET}\n"
            printf "\n  ${DIM}Press ENTER...${RESET}"
            read -r _dummy
            push_message "Can't afford village levies."
        fi
    fi
}

# event_road
# Roads have a chance of caravan raids.
event_road() {
    # 40% chance of caravan encounter
    _roll=$(( RANDOM % 10 ))
    if [ "$_roll" -lt 4 ]; then
        _loot=$(( (RANDOM % 30) + 15 ))
        _risk=$(( (RANDOM % 5) + 1 ))  # Troops lost in raid
        
        push_message "A caravan spotted on the road!"
        draw_screen
        draw_messages
        
        printf "${BOLD}${YELLOW}  [ CARAVAN ON THE ROAD ]${RESET}\n"
        printf "  Merchants travel with goods worth ~${_loot} gold.\n"
        printf "  Your scouts estimate ${_risk} men guard it.\n\n"
        printf "  Raid the caravan? (y/n): "
        read -r _ans
        
        if [ "$_ans" = "y" ] || [ "$_ans" = "Y" ]; then
            GOLD=$(( GOLD + _loot ))
            TROOPS=$(( TROOPS - _risk ))
            if [ "$TROOPS" -lt 1 ]; then TROOPS=1; fi
            _morale_impact=$(( (RANDOM % 6) - 2 ))  # -2 to +3 morale
            MORALE=$(( MORALE + _morale_impact ))
            if [ "$MORALE" -gt 100 ]; then MORALE=100; fi
            if [ "$MORALE" -lt 0 ]; then MORALE=0; fi
            CARAVANS_RAIDED=$(( CARAVANS_RAIDED + 1 ))
            push_message "Raided caravan! +${_loot} gold, -${_risk} troops."
        else
            push_message "Let the caravan pass unmolested."
        fi
    else
        push_message "The road is quiet. No encounters."
    fi
}

# event_temple
# Temples bless troops and heal wounded
event_temple() {
    push_message "You discover an ancient temple."
    draw_screen
    draw_messages
    
    printf "${BOLD}${LIME}  [ ANCIENT TEMPLE ]${RESET}\n"
    printf "  Priests offer blessings for your army.\n"
    printf "  Blessing: +15 morale, heal wounded troops.\n"
    printf "  Cost: 25 gold\n\n"
    
    if [ "$GOLD" -ge 25 ]; then
        printf "  Accept blessing? (y/n): "
        read -r _ans
        if [ "$_ans" = "y" ] || [ "$_ans" = "Y" ]; then
            GOLD=$(( GOLD - 25 ))
            MORALE=$(( MORALE + 15 ))
            if [ "$MORALE" -gt 100 ]; then MORALE=100; fi
            _healed=$(( WOUNDED / 2 ))
            TROOPS=$(( TROOPS + _healed ))
            WOUNDED=$(( WOUNDED - _healed ))
            TEMPLE_VISITS=$(( TEMPLE_VISITS + 1 ))
            push_message "Temple blessing! +15 morale, ${_healed} troops healed."
        else
            push_message "Declined the temple blessing."
        fi
    else
        printf "  ${RED}Not enough gold for blessing.${RESET}\n"
        printf "\n  ${DIM}Press ENTER...${RESET}"
        read -r _dummy
        push_message "Too poor for temple blessing."
    fi
}

# event_swamp
# Swamps are dangerous but may hide treasures
event_swamp() {
    _morale_loss=$(( (RANDOM % 15) + 5 ))
    _troop_loss=$(( (RANDOM % 3) + 1 ))
    
    push_message "Your army struggles through the treacherous swamp."
    draw_screen
    draw_messages
    
    printf "${BOLD}${PURPLE}  [ TREACHEROUS SWAMP ]${RESET}\n"
    printf "  The bog claims ${_morale_loss} morale and ${_troop_loss} troops.\n"
    printf "  But glinting in the muck, you spot...\n\n"
    
    MORALE=$(( MORALE - _morale_loss ))
    if [ "$MORALE" -lt 0 ]; then MORALE=0; fi
    TROOPS=$(( TROOPS - _troop_loss ))
    WOUNDED=$(( WOUNDED + _troop_loss ))
    
    # 30% chance of finding treasure
    if [ "$((RANDOM % 10))" -lt 3 ]; then
        _treasure=$(( (RANDOM % 40) + 20 ))
        GOLD=$(( GOLD + _treasure ))
        printf "  ${GOLD}You found ${_treasure} gold in the muck!${RESET}\n"
        push_message "Swamp peril! -${_morale_loss} morale, -${_troop_loss} troops. +${_treasure} gold!"
    else
        printf "  Just mud and bones. Nothing of value.\n"
        push_message "Swamp peril! -${_morale_loss} morale, -${_troop_loss} troops."
    fi
    
    printf "\n  ${DIM}Press ENTER...${RESET}"
    read -r _dummy
}

# event_dungeon
# Dungeons offer risk/reward scenarios
event_dungeon() {
    push_message "You discover a dark dungeon entrance."
    draw_screen
    draw_messages
    
    printf "${BOLD}${ORANGE}  [ ANCIENT DUNGEON ]${RESET}\n"
    printf "  Dark passages lead to unknown treasures... and dangers.\n"
    printf "  Risk troops for potential loot?\n"
    printf "  Estimated risk: 2-4 troops | Potential reward: 30-60 gold\n\n"
    printf "  Enter dungeon? (y/n): "
    read -r _ans
    
    if [ "$_ans" = "y" ] || [ "$_ans" = "Y" ]; then
        _risk=$(( (RANDOM % 3) + 2 ))
        _reward=$(( (RANDOM % 31) + 30 ))
        
        # 70% success rate
        if [ "$((RANDOM % 10))" -lt 7 ]; then
            GOLD=$(( GOLD + _reward ))
            TROOPS=$(( TROOPS - 1 ))
            DUNGEON_LOOTED=$(( DUNGEON_LOOTED + 1 ))
            printf "  ${GREEN}Success! Found ${_reward} gold! Lost 1 scout.${RESET}\n"
            push_message "Dungeon raid! +${_reward} gold, -1 troop."
        else
            TROOPS=$(( TROOPS - _risk ))
            WOUNDED=$(( WOUNDED + _risk ))
            MORALE=$(( MORALE - 10 ))
            if [ "$MORALE" -lt 0 ]; then MORALE=0; fi
            printf "  ${RED}Ambushed! Lost ${_risk} troops and morale!${RESET}\n"
            push_message "Dungeon disaster! -${_risk} troops, -10 morale."
        fi
    else
        push_message "Left the dungeon unexplored."
    fi
}

# =============================================================================
# TURN EVENTS
# Random events that fire each turn regardless of position.
# =============================================================================
turn_events() {
    # Desertion: low morale causes troop loss
    if [ "$MORALE" -lt 30 ] && [ "$TROOPS" -gt 5 ]; then
        _deserters=$(( (RANDOM % 3) + 1 ))
        TROOPS=$(( TROOPS - _deserters ))
        push_message "Low morale! ${_deserters} troops deserted overnight."
    fi
    
    # Upkeep: troops cost gold each turn
    _upkeep=$(( TROOPS / 5 ))
    if [ "$_upkeep" -lt 1 ]; then _upkeep=1; fi
    if [ "$GOLD" -ge "$_upkeep" ]; then
        GOLD=$(( GOLD - _upkeep ))
    else
        # Can't pay troops
        _unpaid_loss=$(( (RANDOM % 3) + 1 ))
        TROOPS=$(( TROOPS - _unpaid_loss ))
        MORALE=$(( MORALE - 10 ))
        if [ "$MORALE" -lt 0 ]; then MORALE=0; fi
        push_message "Can't pay troops! -${_unpaid_loss} men leave. -10 morale."
    fi
    
    # Slow morale recovery on plains
    _cell_idx=$(( PY * 5 + PX ))
    _cur_cell
    _cur_cell=$(get_cell "$_cell_idx")
    if [ "$_cur_cell" = "." ] && [ "$MORALE" -lt 100 ]; then
        MORALE=$(( MORALE + 2 ))
        if [ "$MORALE" -gt 100 ]; then MORALE=100; fi
    fi
    
    # Death condition check
    if [ "$TROOPS" -le 0 ]; then
        GAME_OVER=1
    fi
}

# =============================================================================
# MOVEMENT ENGINE
# =============================================================================

# try_move DELTA_X DELTA_Y
# Validates and applies movement. Handles terrain blocking and events.
try_move() {
    _dx=$1
    _dy=$2
    
    _new_px=$(( PX + _dx ))
    _new_py=$(( PY + _dy ))
    
    # Bounds check
    if [ "$_new_px" -lt 0 ] || [ "$_new_px" -gt 4 ] || \
       [ "$_new_py" -lt 0 ] || [ "$_new_py" -gt 4 ]; then
        push_message "You cannot march beyond the known world's edge."
        return 1
    fi
    
    # Terrain check
    _tidx=$(( _new_py * 5 + _new_px ))
    _terrain=$(get_cell "$_tidx")
    
    case "$_terrain" in
        '~'|'M')
            if [ "$_terrain" = "~" ]; then
                push_message "The river bars your path. Find another way."
            else
                push_message "The mountain peaks are impassable."
            fi
            return 1
            ;;
        X)
            push_message "Your captured castle stands firm."
            PX=$_new_px
            PY=$_new_py
            return 0
            ;;
        C)
            # Move onto castle triggers siege
            PX=$_new_px
            PY=$_new_py
            # Determine which castle
            case "$_tidx" in
                0)  siege_castle 0  "CASTLE_DEF_0"  ;;
                4)  siege_castle 4  "CASTLE_DEF_4"  ;;
                24) siege_castle 24 "CASTLE_DEF_24" ;;
                *)  push_message "An unknown stronghold looms." ;;
            esac
            return 0
            ;;
        F)
            PX=$_new_px
            PY=$_new_py
            event_forest
            ;;
        V)
            PX=$_new_px
            PY=$_new_py
            event_village
            ;;
        R)
            PX=$_new_px
            PY=$_new_py
            event_road
            ;;
        S)
            PX=$_new_px
            PY=$_new_py
            event_swamp
            ;;
        T)
            PX=$_new_px
            PY=$_new_py
            event_temple
            ;;
        D)
            PX=$_new_px
            PY=$_new_py
            event_dungeon
            ;;
        .)
            PX=$_new_px
            PY=$_new_py
            push_message "Your army marches across open plains."
            ;;
    esac
    
    return 0
}

# =============================================================================
# COMMAND PARSER
# =============================================================================

# show_help
show_help() {
    draw_screen
    draw_messages
    printf "${BOLD}${WHITE}  [ COMMANDS ]${RESET}\n"
    printf "  ${YELLOW}w${RESET} = Move North    ${YELLOW}s${RESET} = Move South\n"
    printf "  ${YELLOW}a${RESET} = Move West     ${YELLOW}d${RESET} = Move East\n"
    printf "  ${YELLOW}h${RESET} = This help     ${YELLOW}q${RESET} = Quit\n"
    printf "  ${YELLOW}l${RESET} = View log\n\n"
    printf "  ${DIM}Moving onto ${RED}C${DIM} initiates a siege.\n"
    printf "  ${GREEN}F${DIM} = forest recruits, ${CYAN}V${DIM} = village, R = road raids.\n"
    printf "  ${PURPLE}S${DIM} = swamp danger, ${LIME}T${DIM} = temple blessing, ${ORANGE}D${DIM} = dungeon.\n"
    printf "  ${CYAN}~${DIM} = impassable river, ${GRAY}M${DIM} = impassable mountain.${RESET}\n\n"
    printf "  ${DIM}Press ENTER...${RESET}"
    read -r _dummy
}

# process_input CMD
process_input() {
    _cmd=$1
    case "$_cmd" in
        w|W) try_move  0 -1 ;;
        s|S) try_move  0  1 ;;
        a|A) try_move -1  0 ;;
        d|D) try_move  1  0 ;;
        h|H) show_help ; return 0 ;;
        l|L)
            draw_screen
            draw_messages
            printf "  ${DIM}Press ENTER...${RESET}"
            read -r _dummy
            return 0
            ;;
        q|Q)
            printf "\n${BOLD}${RED}  You ride into exile. The realm remains divided.${RESET}\n\n"
            exit 0
            ;;
        '')
            push_message "Your army rests. The captains murmur."
            ;;
        *)
            push_message "Unknown command '${_cmd}'. Press h for help."
            ;;
    esac
    
    # Advance turn on any valid action (not just movement)
    turn_events
    TURN=$(( TURN + 1 ))
}

# =============================================================================
# WIN / LOSE SCREENS
# =============================================================================

screen_victory() {
    clear_screen
    printf "\n"
    printf "${BOLD}${YELLOW}"
    printf '  ╔══════════════════════════════════════╗\n'
    printf '  ║        BLOOD & BANNERS               ║\n'
    printf '  ║                                      ║\n'
    printf '  ║   ALL CASTLES HAVE FALLEN.           ║\n'
    printf '  ║   THE REALM IS YOURS, WARLORD.       ║\n'
    printf '  ║                                      ║\n'
    printf "  ║   Turns taken : %-4s                 ║\n" "$TURN"
    printf "  ║   Gold amassed: %-5s                ║\n" "$GOLD"
    printf "  ║   Army size   : %-5s                ║\n" "$TROOPS"
    printf '  ║                                      ║\n'
    printf '  ║   Your banners fly over every keep.  ║\n'
    printf '  ╚══════════════════════════════════════╝\n'
    printf "${RESET}\n"
}

screen_defeat() {
    clear_screen
    printf "\n"
    printf "${BOLD}${RED}"
    printf '  ╔══════════════════════════════════════╗\n'
    printf '  ║        BLOOD & BANNERS               ║\n'
    printf '  ║                                      ║\n'
    printf '  ║   YOUR ARMY IS DESTROYED.            ║\n'
    printf '  ║   THE WARLORD IS DEAD.               ║\n'
    printf '  ║                                      ║\n'
    printf "  ║   You survived %-4s turns.           ║\n" "$TURN"
    printf '  ║   The castles stand unconquered.     ║\n'
    printf '  ║                                      ║\n'
    printf '  ║   Crows pick at your standard.       ║\n'
    printf '  ╚══════════════════════════════════════╝\n'
    printf "${RESET}\n"
}

# =============================================================================
# INTRO SCREEN
# =============================================================================

screen_intro() {
    clear_screen
    printf "\n"
    printf "${BOLD}${RED}"
    printf '        ██████╗ ██╗      ██████╗  ██████╗ ██████╗\n'
    printf '        ██╔══██╗██║     ██╔═══██╗██╔═══██╗██╔══██╗\n'
    printf '        ██████╔╝██║     ██║   ██║██║   ██║██║  ██║\n'
    printf '        ██╔══██╗██║     ██║   ██║██║   ██║██║  ██║\n'
    printf '        ██████╔╝███████╗╚██████╔╝╚██████╔╝██████╔╝\n'
    printf '        ╚═════╝ ╚══════╝ ╚═════╝  ╚═════╝ ╚═════╝\n'
    printf "${YELLOW}"
    printf '               &  B A N N E R S\n'
    printf "${RESET}\n"
    printf "${DIM}  A medieval dark fantasy of conquest and blood.\n\n"
    printf "  Three castles stand between you and dominion.\n"
    printf "  Raise your army. Raid the roads. Siege the keeps.\n\n"
    printf "${RESET}"
    printf "${BOLD}${WHITE}  THE MAP:${RESET}\n\n"
    printf "    ${RED}C${RESET} . ${GREEN}F${RESET} . ${RED}C${RESET}     ${RED}C${RESET} = Enemy Castle (siege to win)\n"
    printf "    . ${CYAN}~${RESET} ${CYAN}~${RESET} ${CYAN}~${RESET} .     ${GREEN}F${RESET} = Forest  (recruit peasants)\n"
    printf "    ${CYAN}V${RESET} R R R ${CYAN}V${RESET}     ${CYAN}V${RESET} = Village (buy troops/morale)\n"
    printf "    . ${CYAN}~${RESET} ${CYAN}~${RESET} ${CYAN}~${RESET} .     R = Road   (raid caravans)\n"
    printf "    . ${GREEN}F${RESET} . ${GREEN}F${RESET} ${RED}C${RESET}     ${CYAN}~${RESET} = River   (impassable)\n\n"
    printf "  ${BOLD}You start at center (F). Controls: w/a/s/d, h=help, q=quit${RESET}\n\n"
    printf "  ${DIM}Troops cost gold each turn. Low morale = desertion.\n"
    printf "  Siege strength = troops * random(1-3) + morale bonus.${RESET}\n\n"
    printf "  ${BOLD}${YELLOW}Press ENTER to raise your banner...${RESET}"
    read -r _dummy
}

# =============================================================================
# MAIN GAME LOOP
# =============================================================================

show_intro
push_message "Your banner rises. Ten men follow. Three castles await."

while [ "$GAME_OVER" -eq 0 ]; do
    draw_screen
    draw_messages
    
    printf "  ${BOLD}${WHITE}Command (wasd/h/q): ${RESET}"
    read -r INPUT
    
    process_input "$INPUT"
    
    # Check game over conditions set by subsystems
    if [ "$GAME_OVER" -eq 1 ]; then
        screen_defeat
        exit 0
    fi
    
    if [ "$GAME_OVER" -eq 2 ]; then
        screen_victory
        exit 0
    fi
done