#!/usr/bin/env bash

################################################################################
# TUI Adventure MUD-Lite
# A single-file Bash adventure game with a text-based user interface
################################################################################

set -eo pipefail

# Trap to ensure terminal is restored on exit
trap cleanup EXIT INT TERM

################################################################################
# TERMINAL MANAGEMENT
################################################################################

cleanup() {
    tput cnorm      # Show cursor
    tput rmcup      # Restore screen
    stty sane       # Restore terminal settings
    clear
}

init_terminal() {
    tput smcup      # Save screen
    tput civis      # Hide cursor
    stty -echo      # Disable echo
    clear
}

################################################################################
# GAME STATE VARIABLES
################################################################################

# Player state
PLAYER_ROOM="village_square"
PLAYER_HP=100
PLAYER_MAX_HP=100
PLAYER_GOLD=0
PLAYER_XP=0
PLAYER_LEVEL=1

# Inventory (space-separated)
INVENTORY=""

# Game state flags
declare -A FLAGS
FLAGS[has_key]=0
FLAGS[dragon_defeated]=0
FLAGS[talked_to_elder]=0
FLAGS[has_sword]=0
FLAGS[cave_explored]=0
FLAGS[forest_visited]=0

# Message log
declare -a MESSAGE_LOG
MESSAGE_LOG=("Welcome to the adventure!")

################################################################################
# GAME DATA - ROOMS
################################################################################

# Room structure: name|description|exits|items|enemies
declare -A ROOMS

ROOMS[village_square]="Village Square|You stand in the heart of a small village. The fountain gurgles peacefully. To the north is a dense forest, east leads to the elder's house, south to the marketplace, and west to the cave entrance.|north:dark_forest,east:elder_house,south:marketplace,west:cave_entrance|none|none"

ROOMS[dark_forest]="Dark Forest|Tall trees block out most of the sunlight. The air is thick with the smell of moss and decay. You hear strange sounds in the distance.|south:village_square,north:forest_clearing|rusty_sword|goblin"

ROOMS[forest_clearing]="Forest Clearing|A peaceful clearing with sunlight streaming through. Ancient stones form a circle here.|south:dark_forest,east:ancient_shrine|health_potion|none"

ROOMS[ancient_shrine]="Ancient Shrine|A mysterious shrine covered in glowing runes. Magic pulses through the air.|west:forest_clearing|magic_amulet|none"

ROOMS[elder_house]="Elder's House|A cozy cottage filled with books and scrolls. The village elder sits by the fireplace.|west:village_square|none|none"

ROOMS[marketplace]="Marketplace|A bustling market with various stalls. A merchant eyes you carefully.|north:village_square,east:tavern|none|none"

ROOMS[tavern]="The Rusty Flagon|A rowdy tavern filled with adventurers and locals. The smell of ale fills the air.|west:marketplace|health_potion|none"

ROOMS[cave_entrance]="Cave Entrance|A dark cave entrance looms before you. Cold air emanates from within.|east:village_square,north:cave_depths|torch|none"

ROOMS[cave_depths]="Cave Depths|Deep in the cave, you see glittering treasure. But something large moves in the shadows...|south:cave_entrance,north:dragon_lair|gold_coins|bat"

ROOMS[dragon_lair]="Dragon's Lair|A massive chamber filled with treasure. At its center, a dragon sleeps on a pile of gold.|south:cave_depths|legendary_sword,treasure_chest|dragon"

################################################################################
# GAME DATA - ITEMS
################################################################################

declare -A ITEMS
ITEMS[rusty_sword]="Rusty Sword|An old but serviceable weapon|weapon|5"
ITEMS[legendary_sword]="Legendary Sword|A magnificent blade that glows with power|weapon|25"
ITEMS[health_potion]="Health Potion|Restores 30 HP|consumable|30"
ITEMS[magic_amulet]="Magic Amulet|A mysterious amulet that grants protection|armor|10"
ITEMS[torch]="Torch|A simple torch for lighting the way|tool|0"
ITEMS[gold_coins]="Gold Coins|A pouch of gold|currency|50"
ITEMS[treasure_chest]="Treasure Chest|A heavy chest filled with riches|currency|200"
ITEMS[key]="Mysterious Key|An ornate key with unknown purpose|key|0"

################################################################################
# GAME DATA - ENEMIES
################################################################################

declare -A ENEMIES
ENEMIES[goblin]="Goblin|A small, nasty creature|20|5"
ENEMIES[bat]="Giant Bat|A large, aggressive bat|15|3"
ENEMIES[dragon]="Ancient Dragon|A massive, fire-breathing dragon|100|20"

################################################################################
# UTILITY FUNCTIONS
################################################################################

add_message() {
    MESSAGE_LOG+=("$1")
    # Keep only last 10 messages
    if [ ${#MESSAGE_LOG[@]} -gt 10 ]; then
        MESSAGE_LOG=("${MESSAGE_LOG[@]:1}")
    fi
}

has_item() {
    local item="$1"
    [[ " $INVENTORY " =~ " $item " ]]
}

add_item() {
    local item="$1"
    if ! has_item "$item"; then
        INVENTORY="$INVENTORY $item"
        add_message "Picked up: $item"
    fi
}

remove_item() {
    local item="$1"
    INVENTORY="${INVENTORY//$item/}"
    INVENTORY=$(echo $INVENTORY | xargs) # Trim spaces
}

get_weapon_damage() {
    local damage=5 # Base fist damage
    if has_item "legendary_sword"; then
        damage=30
    elif has_item "rusty_sword"; then
        damage=15
    fi
    echo $damage
}

################################################################################
# RENDERING FUNCTIONS
################################################################################

draw_box() {
    local x=$1 y=$2 w=$3 h=$4
    
    # Top border
    tput cup $y $x
    echo -n "┌"
    for ((i=0; i<w-2; i++)); do echo -n "─"; done
    echo -n "┐"
    
    # Sides
    for ((i=1; i<h-1; i++)); do
        tput cup $((y+i)) $x
        echo -n "│"
        tput cup $((y+i)) $((x+w-1))
        echo -n "│"
    done
    
    # Bottom border
    tput cup $((y+h-1)) $x
    echo -n "└"
    for ((i=0; i<w-2; i++)); do echo -n "─"; done
    echo -n "┘"
}

draw_text_in_box() {
    local x=$1 y=$2 w=$3 text="$4"
    local max_width=$((w-4))
    
    tput cup $y $((x+2))
    
    # Word wrap
    local line=""
    local line_count=0
    for word in $text; do
        if [ $((${#line} + ${#word} + 1)) -gt $max_width ]; then
            echo -n "$line"
            line=""
            ((line_count++))
            tput cup $((y+line_count)) $((x+2))
        fi
        line="$line $word"
    done
    echo -n "$line"
}

render_ui() {
    clear
    
    local term_width=$(tput cols)
    local term_height=$(tput lines)
    
    # Calculate layout
    local main_width=$((term_width - 2))
    local sidebar_width=30
    local content_width=$((main_width - sidebar_width - 3))
    
    # Title
    tput cup 0 $((term_width/2 - 15))
    tput bold
    echo "╔══════════════════════════════╗"
    tput cup 1 $((term_width/2 - 15))
    echo "║   TUI ADVENTURE MUD-LITE   ║"
    tput cup 2 $((term_width/2 - 15))
    echo "╚══════════════════════════════╝"
    tput sgr0
    
    # Player stats (top right)
    local stats_x=$((term_width - 32))
    tput cup 0 $stats_x
    tput setaf 2
    echo "HP: $PLAYER_HP/$PLAYER_MAX_HP"
    tput cup 1 $stats_x
    echo "Level: $PLAYER_LEVEL | Gold: $PLAYER_GOLD"
    tput sgr0
    
    # Main content area
    draw_box 0 4 $((content_width)) 12
    tput cup 4 2
    tput bold
    echo "LOCATION"
    tput sgr0
    
    # Room info
    render_room
    
    # Inventory panel (right side)
    draw_box $((content_width + 1)) 4 $((sidebar_width)) 12
    tput cup 4 $((content_width + 3))
    tput bold
    echo "INVENTORY"
    tput sgr0
    
    render_inventory
    
    # Message log
    draw_box 0 16 $((main_width)) 7
    tput cup 16 2
    tput bold
    echo "MESSAGES"
    tput sgr0
    
    render_messages
    
    # Command help
    draw_box 0 23 $((main_width)) 5
    tput cup 23 2
    tput bold
    echo "COMMANDS"
    tput sgr0
    tput cup 24 2
    echo "n/s/e/w: Move | look: Examine room | take <item>: Pick up item"
    tput cup 25 2
    echo "use <item>: Use item | attack: Fight enemy | talk: Speak with NPC"
    tput cup 26 2
    echo "inventory: Show inventory | help: Show help | quit: Exit game"
}

render_room() {
    IFS='|' read -r name desc exits items enemies <<< "${ROOMS[$PLAYER_ROOM]}"
    
    tput cup 6 2
    tput setaf 3
    echo -n "$name"
    tput sgr0
    
    # Description
    local y=8
    local x=2
    local max_width=$(($(tput cols) - 35))
    
    echo "$desc" | fold -s -w $((max_width - 4)) | while IFS= read -r line; do
        tput cup $y $x
        echo "$line"
        ((y++))
    done
    
    # Exits
    ((y++))
    tput cup $y $x
    tput setaf 6
    echo -n "Exits: "
    tput sgr0
    echo "${exits//,/ | }"
    
    # Items in room
    if [ "$items" != "none" ]; then
        ((y++))
        tput cup $y $x
        tput setaf 2
        echo -n "Items: "
        tput sgr0
        echo "${items//,/ | }"
    fi
    
    # Enemies in room
    if [ "$enemies" != "none" ]; then
        ((y++))
        tput cup $y $x
        tput setaf 1
        tput bold
        echo -n "⚠ Enemy: $enemies"
        tput sgr0
    fi
}

render_inventory() {
    local y=6
    local x=$(($(tput cols) - 29))
    
    if [ -z "$INVENTORY" ]; then
        tput cup $y $x
        echo "(empty)"
    else
        for item in $INVENTORY; do
            tput cup $y $x
            echo "• $item"
            ((y++))
            if [ $y -gt 14 ]; then
                break
            fi
        done
    fi
}

render_messages() {
    local y=18
    local x=2
    local start_idx=$((${#MESSAGE_LOG[@]} > 4 ? ${#MESSAGE_LOG[@]} - 4 : 0))
    
    for ((i=start_idx; i<${#MESSAGE_LOG[@]}; i++)); do
        tput cup $y $x
        echo "${MESSAGE_LOG[$i]}" | cut -c 1-$(($(tput cols) - 4))
        ((y++))
    done
}

################################################################################
# GAME LOGIC
################################################################################

move_player() {
    local direction=$1
    IFS='|' read -r name desc exits items enemies <<< "${ROOMS[$PLAYER_ROOM]}"
    
    local new_room=""
    IFS=',' read -ra EXIT_ARRAY <<< "$exits"
    for exit in "${EXIT_ARRAY[@]}"; do
        IFS=':' read -r dir room <<< "$exit"
        if [ "$dir" = "$direction" ]; then
            new_room="$room"
            break
        fi
    done
    
    if [ -n "$new_room" ]; then
        PLAYER_ROOM="$new_room"
        add_message "You travel $direction."
        
        # Check for specific room events
        if [ "$PLAYER_ROOM" = "dark_forest" ] && [ ${FLAGS[forest_visited]} -eq 0 ]; then
            FLAGS[forest_visited]=1
            add_message "You enter a dark and foreboding forest..."
        fi
    else
        add_message "You can't go that way."
    fi
}

take_item() {
    local item=$1
    IFS='|' read -r name desc exits items enemies <<< "${ROOMS[$PLAYER_ROOM]}"
    
    if [[ ",$items," =~ ",$item," ]]; then
        add_item "$item"
        
        # Remove item from room
        items="${items//$item/}"
        items="${items//,,/,}"
        items="${items#,}"
        items="${items%,}"
        [ -z "$items" ] && items="none"
        
        ROOMS[$PLAYER_ROOM]="$name|$desc|$exits|$items|$enemies"
        
        # Special item handling
        IFS='|' read -r iname idesc itype ivalue <<< "${ITEMS[$item]}"
        if [ "$itype" = "currency" ]; then
            PLAYER_GOLD=$((PLAYER_GOLD + ivalue))
            remove_item "$item"
            add_message "Gained $ivalue gold!"
        fi
    else
        add_message "There's no $item here."
    fi
}

use_item() {
    local item=$1
    
    if ! has_item "$item"; then
        add_message "You don't have that item."
        return
    fi
    
    IFS='|' read -r iname idesc itype ivalue <<< "${ITEMS[$item]}"
    
    case "$itype" in
        consumable)
            PLAYER_HP=$((PLAYER_HP + ivalue))
            [ $PLAYER_HP -gt $PLAYER_MAX_HP ] && PLAYER_HP=$PLAYER_MAX_HP
            remove_item "$item"
            add_message "Used $item. Restored $ivalue HP!"
            ;;
        weapon)
            add_message "$item is equipped and ready for combat."
            ;;
        *)
            add_message "You can't use that right now."
            ;;
    esac
}

attack_enemy() {
    IFS='|' read -r name desc exits items enemies <<< "${ROOMS[$PLAYER_ROOM]}"
    
    if [ "$enemies" = "none" ]; then
        add_message "There's nothing to fight here."
        return
    fi
    
    IFS='|' read -r ename edesc ehp edamage <<< "${ENEMIES[$enemies]}"
    
    local player_damage=$(get_weapon_damage)
    local enemy_hp=$ehp
    
    add_message "Combat begins with $ename!"
    
    while [ $enemy_hp -gt 0 ] && [ $PLAYER_HP -gt 0 ]; do
        # Player attacks
        local damage=$((player_damage + RANDOM % 5))
        enemy_hp=$((enemy_hp - damage))
        add_message "You deal $damage damage! ($ename HP: $enemy_hp)"
        
        if [ $enemy_hp -le 0 ]; then
            add_message "You defeated the $ename!"
            PLAYER_XP=$((PLAYER_XP + 20))
            PLAYER_GOLD=$((PLAYER_GOLD + 10))
            
            # Remove enemy from room
            ROOMS[$PLAYER_ROOM]="$name|$desc|$exits|$items|none"
            
            # Special enemy handling
            if [ "$enemies" = "dragon" ]; then
                FLAGS[dragon_defeated]=1
                add_message "The dragon's hoard is yours! You win!"
            fi
            return
        fi
        
        # Enemy attacks
        local enemy_dmg=$((edamage + RANDOM % 3))
        PLAYER_HP=$((PLAYER_HP - enemy_dmg))
        add_message "$ename deals $enemy_dmg damage! (Your HP: $PLAYER_HP)"
        
        if [ $PLAYER_HP -le 0 ]; then
            add_message "You have been defeated!"
            game_over
            return
        fi
        
        render_ui
        sleep 1
    done
}

talk_npc() {
    case "$PLAYER_ROOM" in
        elder_house)
            if [ ${FLAGS[talked_to_elder]} -eq 0 ]; then
                add_message "Elder: 'A dragon terrorizes our land! Defeat it and claim glory!'"
                FLAGS[talked_to_elder]=1
                add_item "key"
            else
                add_message "Elder: 'Good luck on your quest, brave adventurer!'"
            fi
            ;;
        marketplace)
            add_message "Merchant: 'Welcome! I have nothing for sale right now.'"
            ;;
        *)
            add_message "There's no one to talk to here."
            ;;
    esac
}

game_over() {
    add_message "=== GAME OVER ==="
    render_ui
    sleep 3
    exit 0
}

show_help() {
    add_message "Movement: n/north, s/south, e/east, w/west"
    add_message "Actions: take/get, use, attack/fight, talk, look"
}

################################################################################
# MAIN GAME LOOP
################################################################################

process_command() {
    local cmd=$1
    local arg=$2
    
    case "$cmd" in
        n|north) move_player "north" ;;
        s|south) move_player "south" ;;
        e|east) move_player "east" ;;
        w|west) move_player "west" ;;
        look|l) add_message "You look around carefully..." ;;
        take|get) 
            if [ -n "$arg" ]; then
                take_item "$arg"
            else
                add_message "Take what?"
            fi
            ;;
        use)
            if [ -n "$arg" ]; then
                use_item "$arg"
            else
                add_message "Use what?"
            fi
            ;;
        attack|fight) attack_enemy ;;
        talk|speak) talk_npc ;;
        inventory|i) add_message "Inventory: $INVENTORY" ;;
        help|h) show_help ;;
        quit|q|exit) 
            add_message "Thanks for playing!"
            render_ui
            sleep 1
            exit 0
            ;;
        *)
            add_message "Unknown command. Type 'help' for commands."
            ;;
    esac
}

get_input() {
    tput cup $(($(tput lines) - 1)) 0
    tput el
    tput cnorm
    stty echo
    echo -n "> "
    read -r input
    stty -echo
    tput civis
    echo "$input"
}

main() {
    init_terminal
    
    while true; do
        render_ui
        
        local input=$(get_input)
        read -r cmd arg <<< "$input"
        
        process_command "$cmd" "$arg"
        
        # Check win condition
        if [ ${FLAGS[dragon_defeated]} -eq 1 ]; then
            add_message "=== VICTORY! You have saved the land! ==="
            render_ui
            sleep 3
            exit 0
        fi
    done
}

# Start the game
main