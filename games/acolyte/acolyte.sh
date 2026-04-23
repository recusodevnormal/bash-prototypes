#!/usr/bin/env bash
# Acolyte - Bash Roguelike Game
# Project Structure and Core Game State Setup

# Check for bash availability
if [ -z "$BASH_VERSION" ]; then
    echo "Error: This game requires bash. Install with: apk add bash"
    exit 1
fi

# Check terminal support
if [ ! -t 0 ]; then
    echo "Error: This game requires an interactive terminal"
    exit 1
fi

# ---------------------------------------------------------------------------
# PROJECT STRUCTURE
# ---------------------------------------------------------------------------

# Save directory structure
SAVE_DIR="$HOME/.acolyte_saves"
mkdir -p "$SAVE_DIR" 2>/dev/null || {
    echo "Cannot create save directory"
    SAVE_DIR="/tmp/acolyte_saves"
    mkdir -p "$SAVE_DIR"
}

# Game files directory
GAME_DIR="${GAME_DIR:-.acolyte}"
mkdir -p "$GAME_DIR" 2>/dev/null

# Save file naming convention
SAVE_FILE_FORMAT="$SAVE_DIR/save_{slot}.dat"

# ---------------------------------------------------------------------------
# ANSI COLOR CODES
# ---------------------------------------------------------------------------

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
NC='\033[0m'
BROWN='\033[0;33m'
ORANGE='\033[38;5;208m'
PURPLE='\033[38;5;129m'
PINK='\033[38;5;206m'
TEAL='\033[38;5;43m'
LIME='\033[38;5;154m'
VIOLET='\033[38;5;141m'
GOLD='\033[38;5;220m'
SILVER='\033[38;5;250m'
CRIMSON='\033[38;5;197m'

# ---------------------------------------------------------------------------
# TERMINAL HANDLING
# ---------------------------------------------------------------------------

save_cursor() { printf '\033[s'; }
restore_cursor() { printf '\033[u'; }
hide_cursor() { printf '\033[?25l'; }
show_cursor() { printf '\033[?25h'; }
clear_screen() { printf '\033[2J\033[H'; }
play_sound() { printf '\007'; }

# ---------------------------------------------------------------------------
# DIFFICULTY SETTINGS
# ---------------------------------------------------------------------------

DIFFICULTY_EASY="easy"
DIFFICULTY_NORMAL="normal"
DIFFICULTY_HARD="hard"
DIFFICULTY_NIGHTMARE="nightmare"

# Difficulty multipliers
declare -A DIFFICULTY_MULTIPLIERS
DIFFICULTY_MULTIPLIERS[$DIFFICULTY_EASY]="0.75"
DIFFICULTY_MULTIPLIERS[$DIFFICULTY_NORMAL]="1.0"
DIFFICULTY_MULTIPLIERS[$DIFFICULTY_HARD]="1.25"
DIFFICULTY_MULTIPLIERS[$DIFFICULTY_NIGHTMARE]="1.5"

# ---------------------------------------------------------------------------
# TILE TYPES
# ---------------------------------------------------------------------------

TILE_WALL="#"
TILE_FLOOR="."
TILE_MONSTER="M"
TILE_GOLD="G"
TILE_POTION="H"
TILE_KEY="K"
TILE_DOOR="D"
TILE_EXIT="E"
TILE_SWORD="S"
TILE_SHIELD="P"
TILE_BOOTS="B"
TILE_AMULET="A"
TILE_RING="R"
TILE_HELM="L"
TILE_CAPE="C"
TILE_GLOVES="V"
TILE_MYSTERY="?"

# ---------------------------------------------------------------------------
# EQUIPMENT SLOTS (Requirement 5.1)
# ---------------------------------------------------------------------------

declare -a EQUIPMENT_SLOTS=(
    "sword"
    "shield"
    "boots"
    "amulet"
    "ring"
    "helm"
    "cape"
    "gloves"
)

# ---------------------------------------------------------------------------
# SKILL TYPES (Requirement 4.3)
# ---------------------------------------------------------------------------

declare -a SKILL_TYPES=(
    "critical_strike"
    "dodge"
    "treasure_hunter"
    "magic"
    "stealth"
    "vitality"
)

# ---------------------------------------------------------------------------
# ENEMY TYPES (from design document)
# ---------------------------------------------------------------------------

declare -A ENEMY_TYPES
ENEMY_TYPES["skeleton"]="Skeleton:5:2:10:8:none:common"
ENEMY_TYPES["goblin"]="Goblin:3:1:5:5:thief:common"
ENEMY_TYPES["zombie"]="Zombie:4:3:8:10:infect:common"
ENEMY_TYPES["orc"]="Orc:8:4:20:15:berserk:uncommon"
ENEMY_TYPES["wolf"]="Dire Wolf:6:2:12:12:pack:uncommon"
ENEMY_TYPES["demon"]="Demon:12:6:35:30:fire:rare"
ENEMY_TYPES["vampire"]="Vampire:10:5:25:20:lifesteal:rare"
ENEMY_TYPES["dragon"]="Dragon:15:8:50:50:boss:legendary"
ENEMY_TYPES["lich"]="Lich:14:7:40:35:necromancer:legendary"
ENEMY_TYPES["wraith"]="Wraith:11:5:30:25:phase:rare"
ENEMY_TYPES["golem"]="Golem:13:9:45:40:immune:rare"
ENEMY_TYPES["assassin"]="Assassin:16:3:55:45:backstab:legendary"
ENEMY_TYPES["minotaur"]="Minotaur:18:10:60:70:charge:legendary"
ENEMY_TYPES["phoenix"]="Phoenix:20:8:70:80:rebirth:mythic"
ENEMY_TYPES["hydra"]="Hydra:22:12:80:100:regen:mythic"

# ---------------------------------------------------------------------------
# GAME STATE VARIABLES
# ---------------------------------------------------------------------------

# Game metadata
game_running=true
current_difficulty="$DIFFICULTY_NORMAL"
current_save_slot=1
turn=0

# Map dimensions (Requirement 1.1)
MAP_WIDTH=16
MAP_HEIGHT=16

# ---------------------------------------------------------------------------
# PLAYER STATE (Requirement 1.4)
# ---------------------------------------------------------------------------

# Player position
player_x=2
player_y=2

# Player combat stats
player_hp=30
player_max_hp=30
player_attack=5
player_defense=0

# Player progression
player_level=1
player_xp=0
player_xp_needed=50

# Player resources
player_gold=0
player_mana=50
player_max_mana=50

# ---------------------------------------------------------------------------
# PLAYER INVENTORY (Requirement 1.4)
# ---------------------------------------------------------------------------

inventory_potions=3
inventory_keys=0
inventory_bombs=0
inventory_scrolls=0

# ---------------------------------------------------------------------------
# PLAYER EQUIPMENT (Requirement 5.1)
# ---------------------------------------------------------------------------

# Equipment slots - associative array for 8 slots
declare -A player_equipment
for slot in "${EQUIPMENT_SLOTS[@]}"; do
    player_equipment[$slot]=false
done

# ---------------------------------------------------------------------------
# PLAYER SKILLS (Requirement 4.3)
# ---------------------------------------------------------------------------

# Skill points and skill levels
player_skill_points=0
declare -A player_skills
for skill in "${SKILL_TYPES[@]}"; do
    player_skills[$skill]=0
done

# ---------------------------------------------------------------------------
# MAP STATE (Requirement 1.1)
# ---------------------------------------------------------------------------

# 16x16 grid - initialized with walls and floor
# Format: 16 characters per row, 16 rows
declare -a map_grid
for ((i=0; i<MAP_HEIGHT; i++)); do
    map_grid[$i]=""
    for ((j=0; j<MAP_WIDTH; j++)); do
        if [ $i -eq 0 ] || [ $i -eq $((MAP_HEIGHT-1)) ] || [ $j -eq 0 ] || [ $j -eq $((MAP_WIDTH-1)) ]; then
            map_grid[$i]+="#"
        else
            map_grid[$i]+="."
        fi
    done
done

# Exit position (will be set during map generation)
exit_x=14
exit_y=14

# ---------------------------------------------------------------------------
# ENEMIES STATE (Requirement 1.4)
# ---------------------------------------------------------------------------

# Enemies stored as associative array with position as key
declare -A enemies
# Format: "name:attack:defense:xp:gold:special:rarity:hp"

# ---------------------------------------------------------------------------
# ACHIEVEMENTS (Requirement 8.1)
# ---------------------------------------------------------------------------

declare -A achievements
achievements["first_blood"]=false
achievements["veteran"]=false
achievements["dragon_slayer"]=false
achievements["rich"]=false
achievements["treasure_hunter"]=false
achievements["survivor"]=false
achievements["speed_demon"]=false
achievements["pacifist"]=false
achievements["hoarder"]=false

# ---------------------------------------------------------------------------
# STATUS EFFECTS
# ---------------------------------------------------------------------------

status_burning=false
status_frozen=false
status_poisoned=false
status_blessed=false
status_turns=0

# ---------------------------------------------------------------------------
# GAME LOG
# ---------------------------------------------------------------------------

game_log="Welcome, Acolyte! WASD/Arrows to move, 'i' inventory, 'h' help, 's' save, 'q' quit"

# ---------------------------------------------------------------------------
# UTILITY FUNCTIONS
# ---------------------------------------------------------------------------

# Get tile at position
get_tile() {
    local x=$1
    local y=$2
    if [ $x -ge 0 ] && [ $x -lt $MAP_WIDTH ] && [ $y -ge 0 ] && [ $y -lt $MAP_HEIGHT ]; then
        echo "${map_grid[$y]:$x:1}"
    else
        echo ""
    fi
}

# Set tile at position
set_tile() {
    local x=$1
    local y=$2
    local tile=$3
    if [ $x -ge 0 ] && [ $x -lt $MAP_WIDTH ] && [ $y -ge 0 ] && [ $y -lt $MAP_HEIGHT ]; then
        map_grid[$y]="${map_grid[$y]:0:$x}${tile}${map_grid[$y]:$((x+1))}"
    fi
}

# Check if position is within bounds
is_in_bounds() {
    local x=$1
    local y=$2
    [ $x -ge 0 ] && [ $x -lt $MAP_WIDTH ] && [ $y -ge 0 ] && [ $y -lt $MAP_HEIGHT ]
}

# Calculate difficulty multiplier
get_difficulty_multiplier() {
    local multiplier="${DIFFICULTY_MULTIPLIERS[$current_difficulty]:-1.0}"
    echo "$multiplier"
}

# Apply difficulty to enemy stats
apply_difficulty() {
    local base_stat=$1
    local multiplier=$(get_difficulty_multiplier)
    # Using bc for floating point, or integer approximation
    echo $(( (base_stat * 100 * multiplier) / 100 ))
}

# ---------------------------------------------------------------------------
# SAVE/LOAD FUNCTIONS
# ---------------------------------------------------------------------------

game_save() {
    local slot_num=${1:-$current_save_slot}
    local save_file="$SAVE_DIR/save_${slot_num}.dat"
    
    {
        echo "# Acolyte Save File - Slot $slot_num"
        echo "game_running=$game_running"
        echo "current_difficulty=$current_difficulty"
        echo "current_save_slot=$current_save_slot"
        echo "turn=$turn"
        echo ""
        echo "# Player State"
        echo "player_x=$player_x"
        echo "player_y=$player_y"
        echo "player_hp=$player_hp"
        echo "player_max_hp=$player_max_hp"
        echo "player_attack=$player_attack"
        echo "player_defense=$player_defense"
        echo "player_level=$player_level"
        echo "player_xp=$player_xp"
        echo "player_xp_needed=$player_xp_needed"
        echo "player_gold=$player_gold"
        echo "player_mana=$player_mana"
        echo "player_max_mana=$player_max_mana"
        echo "player_skill_points=$player_skill_points"
        echo ""
        echo "# Inventory"
        echo "inventory_potions=$inventory_potions"
        echo "inventory_keys=$inventory_keys"
        echo "inventory_bombs=$inventory_bombs"
        echo "inventory_scrolls=$inventory_scrolls"
        echo ""
        echo "# Equipment"
        for slot in "${EQUIPMENT_SLOTS[@]}"; do
            echo "equipment_${slot}=${player_equipment[$slot]}"
        done
        echo ""
        echo "# Skills"
        for skill in "${SKILL_TYPES[@]}"; do
            echo "skill_${skill}=${player_skills[$skill]}"
        done
        echo ""
        echo "# Map State"
        for ((y=0; y<MAP_HEIGHT; y++)); do
            echo "map_row_$y=${map_grid[$y]}"
        done
        echo ""
        echo "exit_x=$exit_x"
        echo "exit_y=$exit_y"
        echo ""
        echo "# Enemies"
        for key in "${!enemies[@]}"; do
            echo "enemy_$key=${enemies[$key]}"
        done
        echo ""
        echo "# Achievements"
        for achievement in "${!achievements[@]}"; do
            echo "achievement_$achievement=${achievements[$achievement]}"
        done
        echo ""
        echo "# Status Effects"
        echo "status_burning=$status_burning"
        echo "status_frozen=$status_frozen"
        echo "status_poisoned=$status_poisoned"
        echo "status_blessed=$status_blessed"
        echo "status_turns=$status_turns"
        echo ""
        echo "# Game Log"
        echo "game_log=$game_log"
    } > "$save_file"
    
    game_log="Game saved to slot $slot_num!"
}

game_load() {
    local slot_num=${1:-$current_save_slot}
    local save_file="$SAVE_DIR/save_${slot_num}.dat"
    
    if [ -f "$save_file" ]; then
        # Source the save file (safe parsing)
        source "$save_file"
        current_save_slot=$slot_num
        game_log="Game loaded from slot $slot_num!"
        return 0
    else
        game_log="No save file in slot $slot_num."
        return 1
    fi
}

# ---------------------------------------------------------------------------
# INITIALIZATION
# ---------------------------------------------------------------------------

init_game_state() {
    # Reset player state
    player_x=2
    player_y=2
    player_hp=30
    player_max_hp=30
    player_attack=5
    player_defense=0
    player_level=1
    player_xp=0
    player_xp_needed=50
    player_gold=0
    player_mana=50
    player_max_mana=50
    player_skill_points=0
    
    # Reset inventory
    inventory_potions=3
    inventory_keys=0
    inventory_bombs=0
    inventory_scrolls=0
    
    # Reset equipment
    for slot in "${EQUIPMENT_SLOTS[@]}"; do
        player_equipment[$slot]=false
    done
    
    # Reset skills
    for skill in "${SKILL_TYPES[@]}"; do
        player_skills[$skill]=0
    done
    
    # Reset map (reinitialize with walls and floor)
    for ((i=0; i<MAP_HEIGHT; i++)); do
        map_grid[$i]=""
        for ((j=0; j<MAP_WIDTH; j++)); do
            if [ $i -eq 0 ] || [ $i -eq $((MAP_HEIGHT-1)) ] || [ $j -eq 0 ] || [ $j -eq $((MAP_WIDTH-1)) ]; then
                map_grid[$i]+="#"
            else
                map_grid[$i]+="."
            fi
        done
    done
    
    # Reset enemies
    enemies=()
    
    # Reset achievements
    for achievement in "${!achievements[@]}"; do
        achievements[$achievement]=false
    done
    
    # Reset status effects
    status_burning=false
    status_frozen=false
    status_poisoned=false
    status_blessed=false
    status_turns=0
    
    # Reset game metadata
    game_running=true
    current_difficulty="$DIFFICULTY_NORMAL"
    turn=0
    exit_x=14
    exit_y=14
    
    game_log="Game initialized. Good luck, Acolyte!"
}

# ---------------------------------------------------------------------------
# MAIN ENTRY POINT
# ---------------------------------------------------------------------------

# Initialize game state on load
init_game_state

# Export functions for use in other scripts
export -f get_tile
export -f set_tile
export -f is_in_bounds
export -f get_difficulty_multiplier
export -f apply_difficulty
export -f game_save
export -f game_load
export -f init_game_state
