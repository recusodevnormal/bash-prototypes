```bash
#!/usr/bin/env bash
# The TUI Dungeon Crawler - A Rogue-lite RPG in Pure Bash
# Use arrow keys to move, 'i' for inventory, 'q' to quit

set -u

###################
# TERMINAL SETUP
###################

# Store original terminal state
ORIGINAL_STTY=$(stty -g)

# Cleanup function
cleanup() {
    tput cnorm      # Show cursor
    tput rmcup      # Exit alternate screen
    stty "$ORIGINAL_STTY"  # Restore terminal settings
    clear
    echo "Thanks for playing The TUI Dungeon Crawler!"
    exit 0
}

# Set up trap for cleanup
trap cleanup EXIT INT TERM

# Initialize terminal
init_terminal() {
    stty -echo -icanon time 0 min 0  # Disable echo, canonical mode
    tput smcup      # Enter alternate screen
    tput civis      # Hide cursor
    clear
}

###################
# GAME CONSTANTS
###################

MAP_WIDTH=60
MAP_HEIGHT=20
SIDEBAR_WIDTH=35
TOTAL_WIDTH=$((MAP_WIDTH + SIDEBAR_WIDTH + 3))

# Colors
C_RESET="\e[0m"
C_PLAYER="\e[1;33m"     # Bright yellow
C_WALL="\e[37m"         # White
C_FLOOR="\e[2;37m"      # Dim white
C_MONSTER="\e[1;31m"    # Bright red
C_ITEM="\e[1;32m"       # Bright green
C_STAIRS="\e[1;36m"     # Bright cyan
C_HP="\e[1;31m"         # Red
C_XP="\e[1;34m"         # Blue
C_GOLD="\e[1;33m"       # Yellow
C_HEADER="\e[1;37m"     # Bright white

# Tiles
T_WALL="#"
T_FLOOR="."
T_PLAYER="@"
T_STAIRS=">"
T_EMPTY=" "

# Monster types
declare -A MONSTER_TYPES=(
    [goblin]="g:5:2:3:Goblin"
    [orc]="o:10:4:5:Orc"
    [troll]="T:20:6:10:Troll"
    [dragon]="D:40:10:25:Dragon"
    [rat]="r:3:1:1:Rat"
    [skeleton]="s:8:3:4:Skeleton"
)

# Item types
declare -A ITEM_TYPES=(
    [potion]="!:0:0:0:Health Potion"
    [sword]="|:3:0:0:Iron Sword"
    [armor]="[:0:2:0:Leather Armor"
    [gold]="$:0:0:0:Gold"
)

###################
# GAME STATE
###################

# Player stats
PLAYER_X=0
PLAYER_Y=0
PLAYER_HP=30
PLAYER_MAX_HP=30
PLAYER_ATK=5
PLAYER_DEF=2
PLAYER_LEVEL=1
PLAYER_XP=0
PLAYER_GOLD=0
DUNGEON_LEVEL=1

# Inventory
declare -a INVENTORY=()
MAX_INVENTORY=10

# Map data
declare -a MAP=()
declare -a MONSTERS=()
declare -a ITEMS=()
declare -a MESSAGES=()

# Game state
GAME_OVER=0
STAIRS_X=0
STAIRS_Y=0

###################
# RANDOM UTILITIES
###################

random() {
    # Generate random number between $1 and $2 (inclusive)
    local min=$1
    local max=$2
    echo $((min + RANDOM % (max - min + 1)))
}

###################
# MAP GENERATION
###################

# Initialize empty map
init_map() {
    MAP=()
    for ((y=0; y<MAP_HEIGHT; y++)); do
        for ((x=0; x<MAP_WIDTH; x++)); do
            MAP[$((y * MAP_WIDTH + x))]="$T_WALL"
        done
    done
}

# Get tile at position
get_tile() {
    local x=$1 y=$2
    if ((x < 0 || x >= MAP_WIDTH || y < 0 || y >= MAP_HEIGHT)); then
        echo "$T_WALL"
        return
    fi
    echo "${MAP[$((y * MAP_WIDTH + x))]}"
}

# Set tile at position
set_tile() {
    local x=$1 y=$2 tile=$3
    if ((x >= 0 && x < MAP_WIDTH && y >= 0 && y < MAP_HEIGHT)); then
        MAP[$((y * MAP_WIDTH + x))]="$tile"
    fi
}

# Generate random rooms
generate_dungeon() {
    init_map
    MONSTERS=()
    ITEMS=()
    
    local num_rooms=$((5 + DUNGEON_LEVEL))
    local -a rooms=()
    
    # Generate rooms
    for ((i=0; i<num_rooms; i++)); do
        local tries=0
        while ((tries < 50)); do
            local w=$(random 5 10)
            local h=$(random 4 8)
            local x=$(random 1 $((MAP_WIDTH - w - 1)))
            local y=$(random 1 $((MAP_HEIGHT - h - 1)))
            
            # Check if room overlaps with existing rooms
            local overlap=0
            for room in "${rooms[@]}"; do
                IFS=':' read -r rx ry rw rh <<< "$room"
                if ((x < rx + rw + 1 && x + w + 1 > rx && 
                     y < ry + rh + 1 && y + h + 1 > ry)); then
                    overlap=1
                    break
                fi
            done
            
            if ((overlap == 0)); then
                # Create room
                for ((ry=y; ry<y+h; ry++)); do
                    for ((rx=x; rx<x+w; rx++)); do
                        set_tile $rx $ry "$T_FLOOR"
                    done
                done
                
                rooms+=("$x:$y:$w:$h")
                
                # Connect to previous room with corridor
                if ((${#rooms[@]} > 1)); then
                    local prev="${rooms[-2]}"
                    IFS=':' read -r px py pw ph <<< "$prev"
                    local prev_cx=$((px + pw / 2))
                    local prev_cy=$((py + ph / 2))
                    local curr_cx=$((x + w / 2))
                    local curr_cy=$((y + h / 2))
                    
                    # Horizontal corridor
                    local start_x=$((prev_cx < curr_cx ? prev_cx : curr_cx))
                    local end_x=$((prev_cx > curr_cx ? prev_cx : curr_cx))
                    for ((cx=start_x; cx<=end_x; cx++)); do
                        set_tile $cx $prev_cy "$T_FLOOR"
                    done
                    
                    # Vertical corridor
                    local start_y=$((prev_cy < curr_cy ? prev_cy : curr_cy))
                    local end_y=$((prev_cy > curr_cy ? prev_cy : curr_cy))
                    for ((cy=start_y; cy<=end_y; cy++)); do
                        set_tile $curr_cx $cy "$T_FLOOR"
                    done
                fi
                break
            fi
            ((tries++))
        done
    done
    
    # Place player in first room
    if ((${#rooms[@]} > 0)); then
        local first="${rooms[0]}"
        IFS=':' read -r x y w h <<< "$first"
        PLAYER_X=$((x + w / 2))
        PLAYER_Y=$((y + h / 2))
    fi
    
    # Place stairs in last room
    if ((${#rooms[@]} > 0)); then
        local last="${rooms[-1]}"
        IFS=':' read -r x y w h <<< "$last"
        STAIRS_X=$((x + w / 2))
        STAIRS_Y=$((y + h / 2))
    fi
    
    # Place monsters and items in rooms (skip first room)
    for ((i=1; i<${#rooms[@]}; i++)); do
        IFS=':' read -r x y w h <<< "${rooms[$i]}"
        
        # Place 1-3 monsters per room
        local num_monsters=$(random 1 3)
        for ((m=0; m<num_monsters; m++)); do
            local mx=$((x + $(random 1 $((w - 1)))))
            local my=$((y + $(random 1 $((h - 1)))))
            if ((mx != PLAYER_X || my != PLAYER_Y)) && 
               ((mx != STAIRS_X || my != STAIRS_Y)); then
                spawn_monster $mx $my
            fi
        done
        
        # Place 0-2 items per room
        local num_items=$(random 0 2)
        for ((it=0; it<num_items; it++)); do
            local ix=$((x + $(random 1 $((w - 1)))))
            local iy=$((y + $(random 1 $((h - 1)))))
            if ((ix != PLAYER_X || iy != PLAYER_Y)) && 
               ((ix != STAIRS_X || iy != STAIRS_Y)); then
                spawn_item $ix $iy
            fi
        done
    done
}

###################
# ENTITY MANAGEMENT
###################

spawn_monster() {
    local x=$1 y=$2
    
    # Choose monster based on dungeon level
    local monster_keys=("goblin" "rat")
    if ((DUNGEON_LEVEL >= 2)); then
        monster_keys+=("orc" "skeleton")
    fi
    if ((DUNGEON_LEVEL >= 4)); then
        monster_keys+=("troll")
    fi
    if ((DUNGEON_LEVEL >= 6)); then
        monster_keys+=("dragon")
    fi
    
    local idx=$(random 0 $((${#monster_keys[@]} - 1)))
    local mtype="${monster_keys[$idx]}"
    local mdata="${MONSTER_TYPES[$mtype]}"
    
    IFS=':' read -r char hp atk xp name <<< "$mdata"
    MONSTERS+=("$x:$y:$char:$hp:$atk:$xp:$name")
}

spawn_item() {
    local x=$1 y=$2
    
    local item_keys=("potion" "gold")
    if ((DUNGEON_LEVEL >= 2)); then
        item_keys+=("sword" "armor")
    fi
    
    local idx=$(random 0 $((${#item_keys[@]} - 1)))
    local itype="${item_keys[$idx]}"
    local idata="${ITEM_TYPES[$itype]}"
    
    IFS=':' read -r char atk def value name <<< "$idata"
    
    # Random gold amount
    if [[ "$itype" == "gold" ]]; then
        value=$(random 5 20)
        name="$value Gold"
    fi
    
    ITEMS+=("$x:$y:$char:$atk:$def:$value:$name:$itype")
}

get_monster_at() {
    local x=$1 y=$2
    for i in "${!MONSTERS[@]}"; do
        IFS=':' read -r mx my _ <<< "${MONSTERS[$i]}"
        if ((mx == x && my == y)); then
            echo "$i"
            return
        fi
    done
    echo "-1"
}

get_item_at() {
    local x=$1 y=$2
    for i in "${!ITEMS[@]}"; do
        IFS=':' read -r ix iy _ <<< "${ITEMS[$i]}"
        if ((ix == x && iy == y)); then
            echo "$i"
            return
        fi
    done
    echo "-1"
}

###################
# COMBAT
###################

attack_monster() {
    local idx=$1
    IFS=':' read -r mx my char hp atk xp name <<< "${MONSTERS[$idx]}"
    
    local damage=$((PLAYER_ATK - $(random 0 2)))
    ((damage < 1)) && damage=1
    
    hp=$((hp - damage))
    add_message "You hit $name for $damage damage!"
    
    if ((hp <= 0)); then
        add_message "You killed $name! (+${xp} XP)"
        PLAYER_XP=$((PLAYER_XP + xp))
        PLAYER_GOLD=$((PLAYER_GOLD + $(random 1 5)))
        unset 'MONSTERS[$idx]'
        MONSTERS=("${MONSTERS[@]}")  # Reindex array
        check_level_up
    else
        MONSTERS[$idx]="$mx:$my:$char:$hp:$atk:$xp:$name"
        
        # Monster attacks back
        local monster_dmg=$((atk - PLAYER_DEF - $(random 0 1)))
        ((monster_dmg < 1)) && monster_dmg=1
        PLAYER_HP=$((PLAYER_HP - monster_dmg))
        add_message "$name hits you for $monster_dmg damage!")
        
        if ((PLAYER_HP <= 0)); then
            GAME_OVER=1
            add_message "You died! Game Over."
        fi
    fi
}

check_level_up() {
    local xp_needed=$((PLAYER_LEVEL * 10))
    if ((PLAYER_XP >= xp_needed)); then
        PLAYER_LEVEL=$((PLAYER_LEVEL + 1))
        PLAYER_XP=$((PLAYER_XP - xp_needed))
        PLAYER_MAX_HP=$((PLAYER_MAX_HP + 5))
        PLAYER_HP=$PLAYER_MAX_HP
        PLAYER_ATK=$((PLAYER_ATK + 2))
        PLAYER_DEF=$((PLAYER_DEF + 1))
        add_message "Level up! You are now level $PLAYER_LEVEL!"
    fi
}

###################
# ITEMS & INVENTORY
###################

pickup_item() {
    local idx=$1
    IFS=':' read -r ix iy char atk def value name itype <<< "${ITEMS[$idx]}"
    
    if [[ "$itype" == "gold" ]]; then
        PLAYER_GOLD=$((PLAYER_GOLD + value))
        add_message "Picked up $name!"
        unset 'ITEMS[$idx]'
        ITEMS=("${ITEMS[@]}")
        return
    fi
    
    if ((${#INVENTORY[@]} >= MAX_INVENTORY)); then
        add_message "Inventory full!"
        return
    fi
    
    INVENTORY+=("$char:$atk:$def:$value:$name:$itype")
    add_message "Picked up $name!"
    unset 'ITEMS[$idx]'
    ITEMS=("${ITEMS[@]}")
}

use_item() {
    local idx=$1
    IFS=':' read -r char atk def value name itype <<< "${INVENTORY[$idx]}"
    
    case "$itype" in
        potion)
            PLAYER_HP=$((PLAYER_HP + 15))
            ((PLAYER_HP > PLAYER_MAX_HP)) && PLAYER_HP=$PLAYER_MAX_HP
            add_message "Used $name. HP restored!"
            unset 'INVENTORY[$idx]'
            INVENTORY=("${INVENTORY[@]}")
            ;;
        sword)
            PLAYER_ATK=$((PLAYER_ATK + atk))
            add_message "Equipped $name. ATK +$atk!"
            unset 'INVENTORY[$idx]'
            INVENTORY=("${INVENTORY[@]}")
            ;;
        armor)
            PLAYER_DEF=$((PLAYER_DEF + def))
            add_message "Equipped $name. DEF +$def!"
            unset 'INVENTORY[$idx]'
            INVENTORY=("${INVENTORY[@]}")
            ;;
    esac
}

###################
# MESSAGE LOG
###################

add_message() {
    MESSAGES+=("$1")
    # Keep only last 10 messages
    if ((${#MESSAGES[@]} > 10)); then
        MESSAGES=("${MESSAGES[@]:1}")
    fi
}

###################
# PLAYER MOVEMENT
###################

can_move_to() {
    local x=$1 y=$2
    local tile=$(get_tile $x $y)
    [[ "$tile" != "$T_WALL" ]]
}

move_player() {
    local dx=$1 dy=$2
    local new_x=$((PLAYER_X + dx))
    local new_y=$((PLAYER_Y + dy))
    
    # Check for monster
    local monster_idx=$(get_monster_at $new_x $new_y)
    if ((monster_idx >= 0)); then
        attack_monster $monster_idx
        return
    fi
    
    # Check if can move
    if can_move_to $new_x $new_y; then
        PLAYER_X=$new_x
        PLAYER_Y=$new_y
        
        # Check for item
        local item_idx=$(get_item_at $new_x $new_y)
        if ((item_idx >= 0)); then
            pickup_item $item_idx
        fi
        
        # Check for stairs
        if ((PLAYER_X == STAIRS_X && PLAYER_Y == STAIRS_Y)); then
            next_level
        fi
    fi
}

next_level() {
    DUNGEON_LEVEL=$((DUNGEON_LEVEL + 1))
    add_message "You descend to level $DUNGEON_LEVEL..."
    generate_dungeon
}

###################
# RENDERING
###################

move_cursor() {
    tput cup "$1" "$2"
}

draw_border() {
    local width=$1
    local height=$2
    
    # Top border
    move_cursor 0 0
    echo -n "+"
    for ((i=0; i<width; i++)); do echo -n "-"; done
    echo "+"
    
    # Side borders
    for ((i=1; i<=height; i++)); do
        move_cursor $i 0
        echo -n "|"
        move_cursor $i $((width + 1))
        echo -n "|"
    done
    
    # Bottom border
    move_cursor $((height + 1)) 0
    echo -n "+"
    for ((i=0; i<width; i++)); do echo -n "-"; done
    echo "+"
}

draw_map() {
    for ((y=0; y<MAP_HEIGHT; y++)); do
        move_cursor $((y + 1)) 1
        for ((x=0; x<MAP_WIDTH; x++)); do
            local tile=$(get_tile $x $y)
            local drawn=0
            
            # Check if player is here
            if ((x == PLAYER_X && y == PLAYER_Y)); then
                echo -ne "${C_PLAYER}${T_PLAYER}${C_RESET}"
                drawn=1
            fi
            
            # Check for stairs
            if ((drawn == 0 && x == STAIRS_X && y == STAIRS_Y)); then
                echo -ne "${C_STAIRS}${T_STAIRS}${C_RESET}"
                drawn=1
            fi
            
            # Check for monsters
            if ((drawn == 0)); then
                for monster in "${MONSTERS[@]}"; do
                    IFS=':' read -r mx my char _ <<< "$monster"
                    if ((mx == x && my == y)); then
                        echo -ne "${C_MONSTER}${char}${C_RESET}"
                        drawn=1
                        break
                    fi
                done
            fi
            
            # Check for items
            if ((drawn == 0)); then
                for item in "${ITEMS[@]}"; do
                    IFS=':' read -r ix iy char _ <<< "$item"
                    if ((ix == x && iy == y)); then
                        echo -ne "${C_ITEM}${char}${C_RESET}"
                        drawn=1
                        break
                    fi
                done
            fi
            
            # Draw terrain
            if ((drawn == 0)); then
                if [[ "$tile" == "$T_WALL" ]]; then
                    echo -ne "${C_WALL}${tile}${C_RESET}"
                else
                    echo -ne "${C_FLOOR}${tile}${C_RESET}"
                fi
            fi
        done
    done
}

draw_sidebar() {
    local start_col=$((MAP_WIDTH + 3))
    
    move_cursor 1 $start_col
    echo -ne "${C_HEADER}=== THE DUNGEON CRAWLER ===${C_RESET}"
    
    move_cursor 3 $start_col
    echo -ne "${C_HEADER}Player Stats:${C_RESET}"
    move_cursor 4 $start_col
    echo -ne "Level: ${C_XP}$PLAYER_LEVEL${C_RESET}  XP: ${C_XP}$PLAYER_XP${C_RESET}/$(($PLAYER_LEVEL * 10))"
    move_cursor 5 $start_col
    echo -ne "HP: ${C_HP}$PLAYER_HP${C_RESET}/$PLAYER_MAX_HP"
    move_cursor 6 $start_col
    echo -ne "ATK: $PLAYER_ATK  DEF: $PLAYER_DEF"
    move_cursor 7 $start_col
    echo -ne "Gold: ${C_GOLD}$PLAYER_GOLD${C_RESET}"
    
    move_cursor 9 $start_col
    echo -ne "${C_HEADER}Dungeon Level: $DUNGEON_LEVEL${C_RESET}"
    
    move_cursor 11 $start_col
    echo -ne "${C_HEADER}Messages:${C_RESET}"
    local msg_line=12
    for msg in "${MESSAGES[@]}"; do
        move_cursor $msg_line $start_col
        # Truncate message to fit
        echo -ne "${msg:0:33}"
        ((msg_line++))
    done
    
    move_cursor 23 $start_col
    echo -ne "${C_HEADER}Controls:${C_RESET}"
    move_cursor 24 $start_col
    echo -ne "Arrows: Move"
    move_cursor 25 $start_col
    echo -ne "i: Inventory"
    move_cursor 26 $start_col
    echo -ne "q: Quit"
}

draw_screen() {
    clear
    draw_border $MAP_WIDTH $MAP_HEIGHT
    draw_map
    draw_sidebar
}

draw_inventory() {
    clear
    move_cursor 1 2
    echo -e "${C_HEADER}=== INVENTORY (Press ESC to close, 1-9 to use) ===${C_RESET}"
    
    if ((${#INVENTORY[@]} == 0)); then
        move_cursor 3 2
        echo "Your inventory is empty."
    else
        local line=3
        for i in "${!INVENTORY[@]}"; do
            IFS=':' read -r char atk def value name itype <<< "${INVENTORY[$i]}"
            move_cursor $line 2
            local num=$((i + 1))
            echo -ne "$num) ${C_ITEM}$char${C_RESET} $name"
            if ((atk > 0)); then echo -ne " [ATK+$atk]"; fi
            if ((def > 0)); then echo -ne " [DEF+$def]"; fi
            ((line++))
        done
    fi
    
    move_cursor $((line + 2)) 2
    echo "Press ESC to return, or 1-9 to use an item"
}

###################
# INPUT HANDLING
###################

read_key() {
    local key
    IFS= read -rsn1 key
    
    # Handle escape sequences (arrow keys)
    if [[ "$key" == $'\x1b' ]]; then
        read -rsn2 -t 0.01 key
        case "$key" in
            '[A') echo "UP" ;;
            '[B') echo "DOWN" ;;
            '[C') echo "RIGHT" ;;
            '[D') echo "LEFT" ;;
            *) echo "ESC" ;;
        esac
    else
        echo "$key"
    fi
}

handle_inventory_input() {
    while true; do
        local key=$(read_key)
        
        case "$key" in
            ESC)
                return
                ;;
            [1-9])
                local idx=$((${key} - 1))
                if ((idx < ${#INVENTORY[@]})); then
                    use_item $idx
                    return
                fi
                ;;
        esac
        sleep 0.01
    done
}

###################
# GAME LOOP
###################

game_loop() {
    while ((GAME_OVER == 0)); do
        draw_screen
        
        local key=$(read_key)
        
        case "$key" in
            UP|w|k)
                move_player 0 -1
                ;;
            DOWN|s|j)
                move_player 0 1
                ;;
            LEFT|a|h)
                move_player -1 0
                ;;
            RIGHT|d|l)
                move_player 1 0
                ;;
            i|I)
                draw_inventory
                handle_inventory_input
                ;;
            q|Q)
                GAME_OVER=1
                ;;
        esac
        
        sleep 0.01
    done
    
    # Game over screen
    draw_screen
    move_cursor $((MAP_HEIGHT + 3)) 0
    if ((PLAYER_HP <= 0)); then
        echo -e "\n${C_HP}YOU DIED!${C_RESET}"
        echo "Final Level: $PLAYER_LEVEL"
        echo "Deepest Dungeon Level: $DUNGEON_LEVEL"
        echo "Gold Collected: $PLAYER_GOLD"
    else
        echo -e "\nThanks for playing!"
    fi
    echo
    read -n 1 -s -r -p "Press any key to exit..."
}

###################
# MAIN
###################

main() {
    init_terminal
    
    # Initialize game
    add_message "Welcome to the dungeon!"
    add_message "Find the stairs (>) to descend."
    add_message "Good luck, adventurer!"
    
    generate_dungeon
    
    # Start game loop
    game_loop
}

main
```

This is a complete, playable TUI dungeon crawler in a single Bash script! Here's what it features:

**Gameplay:**
- Randomly generated dungeons with rooms and corridors
- Turn-based movement and combat
- Progressive difficulty (deeper levels = harder monsters)
- Experience and leveling system
- Inventory system with usable items
- Multiple monster types (rats, goblins, orcs, trolls, dragons)
- Items: health potions, weapons, armor, gold

**Controls:**
- Arrow keys (or WASD/HJKL) to move
- `i` to open inventory
- `1-9` to use items in inventory
- `q` to quit

**Features:**
- Full TUI rendering with map area and sidebar
- Color-coded entities (player, monsters, items, terrain)
- Message log for combat and events
- Proper terminal cleanup on exit
- Stats tracking (HP, ATK, DEF, Level, XP, Gold)

**Technical Details:**
- Uses `tput` for cursor movement and screen management
- ANSI color codes for visual appeal
- Alternate screen buffer (won't mess up your terminal)
- Proper signal handling for clean exits
- All game logic in pure Bash (no external game dependencies)

The game scales in difficulty as you descend, with stronger monsters appearing on deeper levels. Combat is automatic when you bump into monsters, and you gain XP and gold from victories. Find the stairs to progress deeper into the dungeon!