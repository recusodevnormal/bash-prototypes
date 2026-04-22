#!/bin/bash

# ==============================================================================
# DEEP SPACE SCAVENGER - TUI DASHBOARD
# A single-file Bash RPG.
# ==============================================================================

# --- CONFIGURATION & CONSTANTS ---
readonly SCREEN_WIDTH=80
readonly SCREEN_HEIGHT=24
readonly MAX_FUEL=100
readonly MAX_CARGO=50
readonly MAX_HP=100

# Colors
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'
C_WHITE='\033[1;37m'
C_BG_BLUE='\033[44m'

# --- GLOBAL STATE ---
declare -A SYSTEMS
declare -A CONNECTIONS
declare -A MARKET_PRICES
declare -A CARGO_HOLD

PLAYER_HP=$MAX_HP
PLAYER_FUEL=50
PLAYER_CREDITS=500
CURRENT_SYSTEM="Sol"
GAME_LOG="System initialized. Welcome, Commander."
IN_COMBAT=false
COMBAT_TURN=0
ENEMY_HP=0
ENEMY_NAME=""

# --- CLEANUP & SETUP ---
cleanup() {
    tput rmcup       # Exit alternate screen buffer
    tput cnorm       # Show cursor
    tput sgr0        # Reset colors
    clear
    echo "Deep Space Scavenger Terminated."
    echo "Thanks for playing."
    exit 0
}

init_terminal() {
    tput smcup       # Enter alternate screen buffer
    tput civis       # Hide cursor
    clear
    trap cleanup EXIT INT TERM
}

# --- DATA INITIALIZATION ---
init_game_data() {
    # Define Star Systems (Name, Type, DangerLevel)
    SYSTEMS["Sol"]="Hub|1"
    SYSTEMS["Alpha Centauri"]="Industrial|2"
    SYSTEMS["Proxima"]="Mining|3"
    SYSTEMS["Sirius"]="Trade|2"
    SYSTEMS["Betelgeuse"]="Danger|5"
    SYSTEMS["Void"]="Wreckage|4"

    # Define Connections (Graph)
    CONNECTIONS["Sol"]="Alpha Centauri,Sirius"
    CONNECTIONS["Alpha Centauri"]="Sol,Proxima,Sirius"
    CONNECTIONS["Proxima"]="Alpha Centauri,Betelgeuse,Void"
    CONNECTIONS["Sirius"]="Sol,Alpha Centauri,Betelgeuse"
    CONNECTIONS["Betelgeuse"]="Proxima,Sirius,Void"
    CONNECTIONS["Void"]="Proxima,Betelgeuse"

    # Initialize Cargo
    CARGO_HOLD["Ore"]=0
    CARGO_HOLD["Fuel Cells"]=0
    CARGO_HOLD["Cybernetics"]=0
    CARGO_HOLD["Alien Artifacts"]=0

    # Base Prices (will fluctuate slightly per system in logic)
    MARKET_PRICES["Ore"]=10
    MARKET_PRICES["Fuel Cells"]=50
    MARKET_PRICES["Cybernetics"]=200
    MARKET_PRICES["Alien Artifacts"]=1000
}

# --- DRAWING FUNCTIONS ---

draw_box() {
    local x=$1 y=$2 w=$3 h=$4 title=$5 color=$6
    tput cup $y $x
    echo -ne "${color}"
    echo -ne "┌$(printf '─%.0s' $(seq 1 $((w-2))))┐"
    for ((i=1; i<h-1; i++)); do
        tput cup $((y+i)) $x
        echo -ne "│"
        tput cup $((y+i)) $((x+w-1))
        echo -ne "│"
    done
    tput cup $((y+h-1)) $x
    echo -ne "└$(printf '─%.0s' $(seq 1 $((w-2))))┘"
    
    # Title
    if [[ -n "$title" ]]; then
        tput cup $y $((x + 2))
        echo -ne " $title "
    fi
    echo -ne "$C_RESET"
}

draw_dashboard() {
    clear
    
    # Main Frame
    draw_box 1 1 78 22 "DEEP SPACE SCAVENGER // CMD CONSOLE" "$C_CYAN"
    
    # Sub Panels
    draw_box 3 3 34 6 "SHIP STATUS" "$C_BLUE"
    draw_box 39 3 38 6 "NAVIGATION MAP" "$C_BLUE"
    draw_box 3 11 74 6 "SYSTEM LOG" "$C_YELLOW"
    draw_box 3 19 74 3 "CONTROLS" "$C_WHITE"

    # --- Ship Status Content ---
    tput cup 5 5
    echo -ne "HP:      ${C_GREEN}$(printf '%03d' $PLAYER_HP)/${MAX_HP}${C_RESET}"
    tput cup 6 5
    echo -ne "FUEL:    ${C_YELLOW}$(printf '%03d' $PLAYER_FUEL)/${MAX_FUEL}${C_RESET}"
    tput cup 7 5
    echo -ne "CREDITS: ${C_WHITE}₡$(printf '%05d' $PLAYER_CREDITS)${C_RESET}"
    tput cup 8 5
    echo -ne "CARGO:   ${C_RED}$(get_total_cargo)/${MAX_CARGO}${C_RESET}"

    # --- Nav Map Content ---
    local sys_info=${SYSTEMS[$CURRENT_SYSTEM]}
    local sys_type=$(echo $sys_info | cut -d'|' -f1)
    local sys_danger=$(echo $sys_info | cut -d'|' -f2)
    
    tput cup 5 41
    echo -ne "CURRENT: ${C_CYAN}$CURRENT_SYSTEM${C_RESET}"
    tput cup 6 41
    echo -ne "TYPE:    $sys_type"
    tput cup 7 41
    echo -ne "DANGER:  $(get_danger_stars $sys_danger)"
    tput cup 8 41
    echo -ne "ROUTES:  ${CONNECTIONS[$CURRENT_SYSTEM]}"

    # --- Log Content ---
    tput cup 13 5
    # Wrap log text simply
    echo -ne "${GAME_LOG:0:68}"

    # --- Controls ---
    tput cup 21 5
    echo -ne "[W/A/S/D] Move  [T] Trade  [R] Refuel  [Q] Quit"
}

get_total_cargo() {
    local total=0
    for item in "${!CARGO_HOLD[@]}"; do
        total=$((total + CARGO_HOLD[$item]))
    done
    echo $total
}

get_danger_stars() {
    local level=$1
    local stars=""
    for ((i=0; i<level; i++)); do stars+="*"; done
    echo -ne "${C_RED}$stars${C_RESET}"
}

# --- GAME LOGIC ---

log_event() {
    GAME_LOG="$1"
}

travel() {
    local destination=$1
    local cost=10
    
    if [[ $PLAYER_FUEL -lt $cost ]]; then
        log_event "ERR: Insufficient Fuel! Refuel at Sol or buy cells."
        return 1
    fi

    PLAYER_FUEL=$((PLAYER_FUEL - cost))
    CURRENT_SYSTEM=$destination
    
    # Random Encounter Chance based on danger level
    local sys_info=${SYSTEMS[$CURRENT_SYSTEM]}
    local danger=$(echo $sys_info | cut -d'|' -f2)
    local roll=$((RANDOM % 10))
    
    if [[ $roll -lt $danger ]]; then
        start_combat
    else
        log_event "Warp complete. Arrived at $destination."
    fi
}

refuel() {
    if [[ $CURRENT_SYSTEM == "Sol" ]]; then
        PLAYER_FUEL=$MAX_FUEL
        log_event "Tank filled at Sol Station. Cost: 0 (Subsidized)."
    else
        local cost=100
        if [[ $PLAYER_CREDITS -ge $cost ]]; then
            PLAYER_CREDITS=$((PLAYER_CREDITS - cost))
            PLAYER_FUEL=$MAX_FUEL
            log_event "Fuel purchased. -₡100"
        else
            log_event "ERR: Cannot afford fuel (Need ₡100)."
        fi
    fi
}

# --- TRADING SYSTEM ---
trade_menu() {
    local selected=0
    local items=("Ore" "Fuel Cells" "Cybernetics" "Alien Artifacts" "BACK")
    local prices
    local sys_info=${SYSTEMS[$CURRENT_SYSTEM]}
    local sys_type=$(echo $sys_info | cut -d'|' -f1)
    
    # Simple economy modifier based on system type
    local mod=1
    [[ "$sys_type" == "Mining" ]] && mod=0.5
    [[ "$sys_type" == "Trade" ]] && mod=1.2
    [[ "$sys_type" == "Industrial" ]] && mod=0.8

    while true; do
        clear
        draw_box 10 5 60 15 "MARKET: $CURRENT_SYSTEM" "$C_GREEN"
        
        tput cup 7 12
        echo -ne "CREDITS: ₡$PLAYER_CREDITS  |  CARGO: $(get_total_cargo)/$MAX_CARGO"
        
        for i in "${!items[@]}"; do
            local item=${items[$i]}
            local price=${MARKET_PRICES[$item]}
            # Apply modifier
            price=$(echo "$price * $mod" | bc | cut -d'.' -f1)
            [[ $price -lt 1 ]] && price=1
            
            local owned=${CARGO_HOLD[$item]:-0}
            local marker=" "
            [[ $i -eq $selected ]] && marker=">"
            
            local action="[BUY]"
            [[ $item != "BACK" ]] && action="[SELL]" # Simplified: Just list prices, logic below handles buy/sell keys
            
            tput cup $((9 + i)) 12
            if [[ $item == "BACK" ]]; then
                echo -ne "${C_WHITE}$marker $item${C_RESET}"
            else
                echo -ne "${C_CYAN}$marker $item${C_RESET} ... ₡$price (Own: $owned)"
            fi
        done
        
        tput cup 22 1
        echo -ne "UP/DOWN: Select | B: Buy | S: Sell | Q: Exit Market"
        
        read -rsn1 key
        case $key in
            $'\x1b') # Arrow keys
                read -rsn1 -t 0.1 key
                case $key in
                    'A') ((selected > 0)) && ((selected--)) ;; # Up
                    'B') ((selected < ${#items[@]}-1)) && ((selected++)) ;; # Down
                esac
                ;;
            'b'|'B') # Buy
                if [[ ${items[$selected]} != "BACK" ]]; then
                    local item=${items[$selected]}
                    local price=${MARKET_PRICES[$item]}
                    price=$(echo "$price * $mod" | bc | cut -d'.' -f1)
                    [[ $price -lt 1 ]] && price=1
                    
                    if [[ $PLAYER_CREDITS -ge $price ]] && [[ $(get_total_cargo) -lt $MAX_CARGO ]]; then
                        PLAYER_CREDITS=$((PLAYER_CREDITS - price))
                        CARGO_HOLD[$item]=$((${CARGO_HOLD[$item]:-0} + 1))
                        log_event "Bought 1 $item"
                    fi
                fi
                ;;
            's'|'S') # Sell
                if [[ ${items[$selected]} != "BACK" ]]; then
                    local item=${items[$selected]}
                    local price=${MARKET_PRICES[$item]}
                    price=$(echo "$price * $mod" | bc | cut -d'.' -f1)
                    [[ $price -lt 1 ]] && price=1
                    
                    if [[ ${CARGO_HOLD[$item]:-0} -gt 0 ]]; then
                        PLAYER_CREDITS=$((PLAYER_CREDITS + price))
                        CARGO_HOLD[$item]=$((${CARGO_HOLD[$item]} - 1))
                        log_event "Sold 1 $item"
                    fi
                fi
                ;;
            'q'|'Q') return ;;
        esac
    done
}

# --- COMBAT SYSTEM (Split Screen) ---

start_combat() {
    IN_COMBAT=true
    ENEMY_NAME="Space Pirate"
    ENEMY_HP=30
    COMBAT_TURN=1
    log_event "ALERT: Hostile vessel detected!"
    
    while $IN_COMBAT; do
        draw_combat_screen
        read -rsn1 key
        
        case $key in
            'f'|'F') # Fire
                combat_player_attack
                ;;
            'e'|'E') # Evade
                combat_evade
                ;;
            'r'|'R') # Repair
                combat_repair
                ;;
            'q'|'Q') # Flee
                if [[ $((RANDOM % 2)) -eq 0 ]]; then
                    log_event "Escaped successfully."
                    IN_COMBAT=false
                else
                    log_event "Escape failed!"
                    combat_enemy_attack
                fi
                ;;
        esac
        
        if [[ $ENEMY_HP -le 0 ]]; then
            log_event "Target destroyed. Loot acquired: ₡200"
            PLAYER_CREDITS=$((PLAYER_CREDITS + 200))
            IN_COMBAT=false
        elif [[ $PLAYER_HP -le 0 ]]; then
            game_over
        fi
    done
}

draw_combat_screen() {
    clear
    # Top Half: Enemy
    draw_box 1 1 78 11 "HOSTILE CONTACT: $ENEMY_NAME" "$C_RED"
    tput cup 4 30
    echo -ne "${C_RED}"
    cat << 'EOF'
      /\_/\
     ( >.< )  <-- PIRATE
     (  O  )
EOF
    echo -ne "$C_RESET"
    tput cup 9 30
    echo -ne "HP: ${ENEMY_HP}/30"

    # Bottom Half: Player
    draw_box 1 13 78 11 "YOUR SHIP: SCAVENGER-1" "$C_CYAN"
    tput cup 16 30
    echo -ne "${C_CYAN}"
    cat << 'EOF'
      __
     /  \
    | [] |  <-- YOU
     \__/
EOF
    echo -ne "$C_RESET"
    tput cup 21 30
    echo -ne "HP: ${PLAYER_HP}/${MAX_HP} | FUEL: ${PLAYER_FUEL}"

    # Action Menu
    tput cup 23 25
    echo -ne "[F] FIRE  [E] EVADE  [R] REPAIR  [Q] FLEE"
    
    tput cup 22 5
    echo -ne "LOG: $GAME_LOG"
}

combat_player_attack() {
    local hit=$((RANDOM % 100))
    if [[ $hit -gt 20 ]]; then
        local dmg=$((RANDOM % 10 + 5))
        ENEMY_HP=$((ENEMY_HP - dmg))
        log_event "Hit! Dealt $dmg damage."
    else
        log_event "Missed!"
    fi
    combat_enemy_attack
}

combat_evade() {
    local dodge=$((RANDOM % 100))
    if [[ $dodge -gt 30 ]]; then
        log_event "Maneuver successful. Enemy missed."
    else
        log_event "Took damage while evading!"
        combat_enemy_attack
    fi
}

combat_repair() {
    if [[ $PLAYER_FUEL -ge 5 ]]; then
        PLAYER_FUEL=$((PLAYER_FUEL - 5))
        PLAYER_HP=$((PLAYER_HP + 10))
        [[ $PLAYER_HP -gt $MAX_HP ]] && PLAYER_HP=$MAX_HP
        log_event "Repairs complete (+10 HP). -5 Fuel."
        combat_enemy_attack
    else
        log_event "Not enough fuel to power repair drones!"
    fi
}

combat_enemy_attack() {
    if [[ $IN_COMBAT == false ]]; then return; fi
    local hit=$((RANDOM % 100))
    if [[ $hit -gt 40 ]]; then
        local dmg=$((RANDOM % 15 + 5))
        PLAYER_HP=$((PLAYER_HP - dmg))
        log_event "Enemy hit us! -$dmg HP"
    else
        log_event "Enemy fire missed."
    fi
}

game_over() {
    cleanup
    tput cup 10 20
    echo -ne "${C_RED}CRITICAL FAILURE. SHIP DESTROYED.${C_RESET}"
    tput cup 12 20
    echo -ne "Final Score: ₡$PLAYER_CREDITS"
    tput cup 20 0
    exit 0
}

# --- MAIN LOOP ---

main_loop() {
    while true; do
        if $IN_COMBAT; then
            # Combat loop handles its own drawing and input
            continue 
        fi

        draw_dashboard
        
        read -rsn1 key
        case $key in
            'w'|'W') # Up (North)
                # Simplified navigation: Pick first available connection for demo, 
                # or cycle through them. Let's make W/A/S/D map to specific neighbors if possible,
                # but since graph is dynamic, let's just pick a random neighbor for 'W' 
                # and cycle for others, or parse the connection string.
                # For this TUI, let's map W=First Neighbor, S=Second Neighbor (if exists)
                IFS=',' read -ra NEIGHBORS <<< "${CONNECTIONS[$CURRENT_SYSTEM]}"
                if [[ ${#NEIGHBORS[@]} -gt 0 ]]; then
                    travel "${NEIGHBORS[0]}"
                else
                    log_event "ERR: Dead end."
                fi
                ;;
            's'|'S')
                IFS=',' read -ra NEIGHBORS <<< "${CONNECTIONS[$CURRENT_SYSTEM]}"
                if [[ ${#NEIGHBORS[@]} -gt 1 ]]; then
                    travel "${NEIGHBORS[1]}"
                elif [[ ${#NEIGHBORS[@]} -eq 1 ]]; then
                    travel "${NEIGHBORS[0]}"
                else
                    log_event "ERR: Dead end."
                fi
                ;;
            'a'|'A') # Random Neighbor
                IFS=',' read -ra NEIGHBORS <<< "${CONNECTIONS[$CURRENT_SYSTEM]}"
                if [[ ${#NEIGHBORS[@]} -gt 0 ]]; then
                    local rand_idx=$((RANDOM % ${#NEIGHBORS[@]}))
                    travel "${NEIGHBORS[$rand_idx]}"
                fi
                ;;
            'd'|'D') # Refuel shortcut
                refuel
                ;;
            't'|'T')
                trade_menu
                ;;
            'r'|'R')
                refuel
                ;;
            'q'|'Q')
                cleanup
                ;;
        esac
    done
}

# --- ENTRY POINT ---
init_terminal
init_game_data
main_loop