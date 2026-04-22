#!/usr/bin/env bash

# Bashmon: TUI Monster Tamer
# A monster-catching RPG in pure Bash

set -e

# Terminal setup
setup_terminal() {
    tput clear
    tput civis  # Hide cursor
    stty -echo  # Hide input
}

cleanup_terminal() {
    tput clear
    tput cnorm  # Show cursor
    stty echo   # Show input
}

trap cleanup_terminal EXIT

# Color codes
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_MAGENTA='\033[0;35m'
C_CYAN='\033[0;36m'
C_WHITE='\033[0;37m'
C_BOLD='\033[1m'
C_RESET='\033[0m'

# Game state
PLAYER_TEAM=()
PLAYER_TEAM_HP=()
PLAYER_TEAM_MAX_HP=()
CURRENT_MONSTER_IDX=0
PLAYER_HEALS=5
PLAYER_BALLS=10

WILD_MONSTER=""
WILD_HP=0
WILD_MAX_HP=0
WILD_ATK=0

BATTLES_WON=0
GAME_RUNNING=true

# Monster definitions: NAME|MAX_HP|ATK|ASCII_ART_ID
MONSTER_DB=(
    "Flamo|45|12|1"
    "Aquos|50|10|2"
    "Leafy|40|11|3"
    "Sparky|35|14|4"
    "Rocky|55|9|5"
    "Windy|38|13|6"
    "Frosty|42|11|7"
    "Toxin|40|12|8"
)

# ASCII Art for monsters (stored as base64-like keys for simplicity)
get_monster_art() {
    local art_id=$1
    case $art_id in
        1) # Flamo
            echo "    /\\_/\\"
            echo "   ( o.o )"
            echo "    > ^ <"
            echo "   /|   |\\"
            echo "  (_|   |_)"
            ;;
        2) # Aquos
            echo "    ~~~~"
            echo "   ( O O )"
            echo "   (  ~  )"
            echo "    \\___/"
            echo "   ~~w~w~~"
            ;;
        3) # Leafy
            echo "     _|_"
            echo "    {   }"
            echo "   { o o }"
            echo "    {   }"
            echo "     | |"
            ;;
        4) # Sparky
            echo "    /\\/\\"
            echo "   < o o>"
            echo "    \\ v /"
            echo "     |Z|"
            echo "    /   \\"
            ;;
        5) # Rocky
            echo "    ____"
            echo "   /    \\"
            echo "  | O  O |"
            echo "  |  __  |"
            echo "   \\____/"
            ;;
        6) # Windy
            echo "   ~~o~~"
            echo "  ( @ @ )"
            echo "   ( w )"
            echo "    )~("
            echo "   ~   ~"
            ;;
        7) # Frosty
            echo "    *  *"
            echo "   ( ** )"
            echo "  (  <>  )"
            echo "   ( ** )"
            echo "    *  *"
            ;;
        8) # Toxin
            echo "    (@)"
            echo "   (o_o)"
            echo "   { ~ }"
            echo "    }~{"
            echo "   /   \\"
            ;;
    esac
}

# Initialize player with starter monster
init_game() {
    local starter="${MONSTER_DB[0]}"
    local name=$(echo "$starter" | cut -d'|' -f1)
    local hp=$(echo "$starter" | cut -d'|' -f2)
    
    PLAYER_TEAM=("$name")
    PLAYER_TEAM_MAX_HP=("$hp")
    PLAYER_TEAM_HP=("$hp")
    CURRENT_MONSTER_IDX=0
}

# Generate random wild monster
generate_wild_monster() {
    local idx=$((RANDOM % ${#MONSTER_DB[@]}))
    local monster="${MONSTER_DB[$idx]}"
    
    WILD_MONSTER=$(echo "$monster" | cut -d'|' -f1)
    WILD_MAX_HP=$(echo "$monster" | cut -d'|' -f2)
    WILD_HP=$WILD_MAX_HP
    WILD_ATK=$(echo "$monster" | cut -d'|' -f3)
}

# Get monster art ID by name
get_art_id_by_name() {
    local name=$1
    for monster in "${MONSTER_DB[@]}"; do
        local m_name=$(echo "$monster" | cut -d'|' -f1)
        if [ "$m_name" == "$name" ]; then
            echo "$monster" | cut -d'|' -f4
            return
        fi
    done
    echo "1"
}

# Get monster attack by name
get_atk_by_name() {
    local name=$1
    for monster in "${MONSTER_DB[@]}"; do
        local m_name=$(echo "$monster" | cut -d'|' -f1)
        if [ "$m_name" == "$name" ]; then
            echo "$monster" | cut -d'|' -f3
            return
        fi
    done
    echo "10"
}

# Draw at position
draw_at() {
    local row=$1
    local col=$2
    shift 2
    tput cup $row $col
    echo -ne "$@"
}

# Draw box
draw_box() {
    local row=$1
    local col=$2
    local width=$3
    local height=$4
    
    # Top
    draw_at $row $col "+"
    for ((i=1; i<width-1; i++)); do
        echo -n "-"
    done
    echo -n "+"
    
    # Sides
    for ((i=1; i<height-1; i++)); do
        draw_at $((row + i)) $col "|"
        draw_at $((row + i)) $((col + width - 1)) "|"
    done
    
    # Bottom
    draw_at $((row + height - 1)) $col "+"
    for ((i=1; i<width-1; i++)); do
        echo -n "-"
    done
    echo -n "+"
}

# Draw health bar
draw_health_bar() {
    local row=$1
    local col=$2
    local current=$3
    local max=$4
    local width=20
    
    local filled=$(( current * width / max ))
    [ $filled -lt 0 ] && filled=0
    
    draw_at $row $col "["
    for ((i=0; i<width; i++)); do
        if [ $i -lt $filled ]; then
            echo -ne "${C_GREEN}█${C_RESET}"
        else
            echo -ne "${C_RED}░${C_RESET}"
        fi
    done
    echo -n "]"
}

# Main battle screen
draw_battle_screen() {
    local menu_selection=$1
    
    tput clear
    
    # Title
    draw_at 0 2 "${C_BOLD}${C_CYAN}╔══════════════════════════════════════════════════════════════╗${C_RESET}"
    draw_at 1 2 "${C_BOLD}${C_CYAN}║${C_YELLOW}                      BASHMON BATTLE                          ${C_CYAN}║${C_RESET}"
    draw_at 2 2 "${C_BOLD}${C_CYAN}╚══════════════════════════════════════════════════════════════╝${C_RESET}"
    
    # Wild monster section
    draw_at 4 4 "${C_RED}${C_BOLD}WILD ${WILD_MONSTER}${C_RESET}"
    draw_at 5 4 "HP: ${WILD_HP}/${WILD_MAX_HP}"
    draw_health_bar 6 4 $WILD_HP $WILD_MAX_HP
    
    # Wild monster art
    local art_id=$(get_art_id_by_name "$WILD_MONSTER")
    local art_lines=($(get_monster_art "$art_id"))
    local line_num=0
    while IFS= read -r line; do
        draw_at $((8 + line_num)) 8 "${C_RED}$line${C_RESET}"
        ((line_num++))
    done < <(get_monster_art "$art_id")
    
    # Player monster section
    local player_mon="${PLAYER_TEAM[$CURRENT_MONSTER_IDX]}"
    local player_hp="${PLAYER_TEAM_HP[$CURRENT_MONSTER_IDX]}"
    local player_max_hp="${PLAYER_TEAM_MAX_HP[$CURRENT_MONSTER_IDX]}"
    
    draw_at 4 40 "${C_GREEN}${C_BOLD}YOUR ${player_mon}${C_RESET}"
    draw_at 5 40 "HP: ${player_hp}/${player_max_hp}"
    draw_health_bar 6 40 $player_hp $player_max_hp
    
    # Player monster art
    local player_art_id=$(get_art_id_by_name "$player_mon")
    line_num=0
    while IFS= read -r line; do
        draw_at $((8 + line_num)) 44 "${C_GREEN}$line${C_RESET}"
        ((line_num++))
    done < <(get_monster_art "$player_art_id")
    
    # Battle menu
    draw_at 15 2 "${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    draw_at 16 4 "${C_BOLD}${C_YELLOW}Battle Menu:${C_RESET}"
    
    if [ $menu_selection -eq 0 ]; then
        draw_at 17 6 "${C_BOLD}${C_WHITE}> [ATTACK]${C_RESET}  Heal  Catch  Run"
    elif [ $menu_selection -eq 1 ]; then
        draw_at 17 6 "${C_BOLD}  Attack  ${C_WHITE}> [HEAL]${C_RESET}  Catch  Run"
    elif [ $menu_selection -eq 2 ]; then
        draw_at 17 6 "${C_BOLD}  Attack  Heal  ${C_WHITE}> [CATCH]${C_RESET}  Run"
    else
        draw_at 17 6 "${C_BOLD}  Attack  Heal  Catch  ${C_WHITE}> [RUN]${C_RESET}"
    fi
    
    # Status
    draw_at 19 4 "Heals: ${C_YELLOW}${PLAYER_HEALS}${C_RESET} | Balls: ${C_MAGENTA}${PLAYER_BALLS}${C_RESET} | Wins: ${C_GREEN}${BATTLES_WON}${C_RESET}"
    draw_at 20 4 "Team: ${#PLAYER_TEAM[@]} monsters"
    
    # Instructions
    draw_at 22 2 "${C_CYAN}[a/d] Navigate  [SPACE] Select  [q] Quit${C_RESET}"
}

# Show message
show_message() {
    local msg=$1
    local duration=${2:-2}
    
    draw_at 18 4 "${C_YELLOW}${msg}${C_RESET}"
    draw_at 18 $((4 + ${#msg})) "                                                  "
    sleep $duration
}

# Battle logic
player_attack() {
    local player_mon="${PLAYER_TEAM[$CURRENT_MONSTER_IDX]}"
    local player_atk=$(get_atk_by_name "$player_mon")
    local damage=$((player_atk + RANDOM % 5))
    
    WILD_HP=$((WILD_HP - damage))
    show_message "${player_mon} attacks for ${damage} damage!" 1.5
    
    if [ $WILD_HP -le 0 ]; then
        WILD_HP=0
        return 1  # Wild fainted
    fi
    return 0
}

wild_attack() {
    local damage=$((WILD_ATK + RANDOM % 5))
    local current_hp="${PLAYER_TEAM_HP[$CURRENT_MONSTER_IDX]}"
    
    PLAYER_TEAM_HP[$CURRENT_MONSTER_IDX]=$((current_hp - damage))
    show_message "${WILD_MONSTER} attacks for ${damage} damage!" 1.5
    
    if [ ${PLAYER_TEAM_HP[$CURRENT_MONSTER_IDX]} -le 0 ]; then
        PLAYER_TEAM_HP[$CURRENT_MONSTER_IDX]=0
        return 1  # Player fainted
    fi
    return 0
}

player_heal() {
    if [ $PLAYER_HEALS -le 0 ]; then
        show_message "No heals left!" 1.5
        return 1
    fi
    
    local max_hp="${PLAYER_TEAM_MAX_HP[$CURRENT_MONSTER_IDX]}"
    local heal_amount=$((max_hp / 2))
    local current_hp="${PLAYER_TEAM_HP[$CURRENT_MONSTER_IDX]}"
    
    PLAYER_TEAM_HP[$CURRENT_MONSTER_IDX]=$((current_hp + heal_amount))
    
    if [ ${PLAYER_TEAM_HP[$CURRENT_MONSTER_IDX]} -gt $max_hp ]; then
        PLAYER_TEAM_HP[$CURRENT_MONSTER_IDX]=$max_hp
    fi
    
    PLAYER_HEALS=$((PLAYER_HEALS - 1))
    show_message "Healed for ${heal_amount} HP!" 1.5
    return 0
}

try_catch() {
    if [ $PLAYER_BALLS -le 0 ]; then
        show_message "No balls left!" 1.5
        return 1
    fi
    
    PLAYER_BALLS=$((PLAYER_BALLS - 1))
    
    # Catch chance based on HP
    local catch_chance=$((100 - (WILD_HP * 100 / WILD_MAX_HP)))
    local roll=$((RANDOM % 100))
    
    show_message "Throwing ball... (${catch_chance}% chance)" 1
    
    if [ $roll -lt $catch_chance ]; then
        PLAYER_TEAM+=("$WILD_MONSTER")
        PLAYER_TEAM_HP+=("$WILD_HP")
        PLAYER_TEAM_MAX_HP+=("$WILD_MAX_HP")
        show_message "Caught ${WILD_MONSTER}!" 2
        return 2  # Caught
    else
        show_message "Failed to catch!" 1.5
        return 0  # Failed but continue
    fi
}

# Battle loop
battle() {
    local menu_pos=0
    local action_taken=false
    
    while true; do
        draw_battle_screen $menu_pos
        
        # Check if player's current monster fainted
        if [ ${PLAYER_TEAM_HP[$CURRENT_MONSTER_IDX]} -le 0 ]; then
            show_message "Your ${PLAYER_TEAM[$CURRENT_MONSTER_IDX]} fainted!" 2
            
            # Find next alive monster
            local found_alive=false
            for ((i=0; i<${#PLAYER_TEAM[@]}; i++)); do
                if [ ${PLAYER_TEAM_HP[$i]} -gt 0 ]; then
                    CURRENT_MONSTER_IDX=$i
                    found_alive=true
                    show_message "Go, ${PLAYER_TEAM[$i]}!" 1.5
                    break
                fi
            done
            
            if [ "$found_alive" == false ]; then
                show_message "All your monsters fainted! GAME OVER!" 3
                GAME_RUNNING=false
                return 1
            fi
        fi
        
        # Get input
        read -rsn1 input
        
        case $input in
            a|A)
                menu_pos=$((menu_pos - 1))
                [ $menu_pos -lt 0 ] && menu_pos=3
                ;;
            d|D)
                menu_pos=$((menu_pos + 1))
                [ $menu_pos -gt 3 ] && menu_pos=0
                ;;
            " ")
                action_taken=true
                case $menu_pos in
                    0) # Attack
                        player_attack
                        if [ $? -eq 1 ]; then
                            show_message "${WILD_MONSTER} fainted! You win!" 2
                            BATTLES_WON=$((BATTLES_WON + 1))
                            PLAYER_HEALS=$((PLAYER_HEALS + 1))
                            PLAYER_BALLS=$((PLAYER_BALLS + 2))
                            return 0
                        fi
                        ;;
                    1) # Heal
                        player_heal
                        [ $? -ne 0 ] && action_taken=false
                        ;;
                    2) # Catch
                        try_catch
                        local result=$?
                        if [ $result -eq 2 ]; then
                            BATTLES_WON=$((BATTLES_WON + 1))
                            return 0
                        elif [ $result -eq 1 ]; then
                            action_taken=false
                        fi
                        ;;
                    3) # Run
                        show_message "You ran away!" 1.5
                        return 0
                        ;;
                esac
                
                # Wild monster attacks back if action was taken
                if [ "$action_taken" == true ] && [ $WILD_HP -gt 0 ]; then
                    draw_battle_screen $menu_pos
                    wild_attack
                    action_taken=false
                fi
                ;;
            q|Q)
                GAME_RUNNING=false
                return 1
                ;;
        esac
    done
}

# Overworld screen
draw_overworld() {
    tput clear
    
    draw_at 0 2 "${C_BOLD}${C_GREEN}╔══════════════════════════════════════════════════════════════╗${C_RESET}"
    draw_at 1 2 "${C_BOLD}${C_GREEN}║${C_YELLOW}                    BASHMON OVERWORLD                        ${C_GREEN}║${C_RESET}"
    draw_at 2 2 "${C_BOLD}${C_GREEN}╚══════════════════════════════════════════════════════════════╝${C_RESET}"
    
    draw_at 4 4 "${C_CYAN}You walk through the tall grass...${C_RESET}"
    
    # Draw grass
    for ((i=0; i<10; i++)); do
        local row=$((6 + i))
        draw_at $row 4 "${C_GREEN}"
        for ((j=0; j<50; j++)); do
            local rnd=$((RANDOM % 4))
            case $rnd in
                0) echo -n "'" ;;
                1) echo -n "," ;;
                2) echo -n "." ;;
                3) echo -n "\"" ;;
            esac
        done
        echo -ne "${C_RESET}"
    done
    
    # Player stats
    draw_at 17 4 "${C_BOLD}Your Team:${C_RESET}"
    for ((i=0; i<${#PLAYER_TEAM[@]}; i++)); do
        local marker=""
        [ $i -eq $CURRENT_MONSTER_IDX ] && marker="${C_YELLOW}*${C_RESET}"
        draw_at $((18 + i)) 6 "${marker} ${PLAYER_TEAM[$i]}: ${PLAYER_TEAM_HP[$i]}/${PLAYER_TEAM_MAX_HP[$i]} HP"
    done
    
    draw_at $((20 + ${#PLAYER_TEAM[@]})) 4 "Heals: ${C_YELLOW}${PLAYER_HEALS}${C_RESET} | Balls: ${C_MAGENTA}${PLAYER_BALLS}${C_RESET} | Wins: ${C_GREEN}${BATTLES_WON}${C_RESET}"
    
    draw_at 23 2 "${C_CYAN}[SPACE] Walk forward  [q] Quit${C_RESET}"
}

# Main game loop
main() {
    setup_terminal
    init_game
    
    while $GAME_RUNNING; do
        draw_overworld
        
        read -rsn1 input
        
        case $input in
            " ")
                # Random encounter
                local encounter_chance=$((RANDOM % 100))
                if [ $encounter_chance -lt 40 ]; then
                    generate_wild_monster
                    battle
                else
                    draw_at 5 4 "${C_YELLOW}Nothing happened...${C_RESET}"
                    sleep 0.5
                fi
                ;;
            q|Q)
                GAME_RUNNING=false
                ;;
        esac
    done
    
    # Game over screen
    tput clear
    draw_at 10 20 "${C_BOLD}${C_YELLOW}Thanks for playing BASHMON!${C_RESET}"
    draw_at 11 20 "Battles Won: ${C_GREEN}${BATTLES_WON}${C_RESET}"
    draw_at 12 20 "Monsters Caught: ${C_CYAN}${#PLAYER_TEAM[@]}${C_RESET}"
    draw_at 14 20 "Press any key to exit..."
    read -rsn1
    
    cleanup_terminal
}

main
```

This is a complete monster-catching RPG implemented as a single Bash script! Here's what it includes:

## Features:

1. **8 Different Monsters** - Each with unique ASCII art, HP, and attack stats
2. **Turn-Based Battle System** - Attack, Heal, Catch, or Run
3. **Visual TUI Interface** - Split screen with battle view and status
4. **Health Bars** - Visual representation of HP
5. **Team Building** - Catch monsters and build your team
6. **Resource Management** - Limited heals and pokéballs
7. **Persistence** - Rewards after each battle (more heals/balls)
8. **Color-Coded Display** - Different colors for different monsters and UI elements
9. **Random Encounters** - 40% chance when walking through grass
10. **Game Over Condition** - When all your monsters faint

## How to Play:

1. Save as `bashmon.sh`
2. Make executable: `chmod +x bashmon.sh`
3. Run: `./bashmon.sh`

## Controls:
- **Overworld**: SPACE to walk, Q to quit
- **Battle**: A/D to navigate menu, SPACE to select, Q to quit

The game features proper TUI rendering with boxes, health bars, ASCII monster art, and a complete battle system—all in one standalone Bash script!