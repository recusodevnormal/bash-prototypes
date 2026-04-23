#!/usr/bin/env bash
# Alpine-compatible: ensure bash is available (apk add bash)

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
# STRICT MODE — catch errors early
# ---------------------------------------------------------------------------
set -euo pipefail
IFS=$'\n\t'

# ANSI Color Codes
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
UNDERLINE='\033[4m'
BLINK='\033[5m'
NC='\033[0m'
ORANGE='\033[38;5;208m'
PURPLE='\033[38;5;129m'
PINK='\033[38;5;206m'
TEAL='\033[38;5;43m'
LIME='\033[38;5;154m'
BROWN='\033[0;33m'
VIOLET='\033[38;5;141m'
GOLD='\033[38;5;220m'
SILVER='\033[38;5;250m'
CRIMSON='\033[38;5;196m'
INDIGO='\033[38;5;57m'
BEIGE='\033[38;5;230m'

# Terminal handling
hide_cursor() { printf '\033[?25l'; }
show_cursor() { printf '\033[?25h'; }
clear_screen() { printf '\033[2J\033[H'; }
play_sound() { printf '\007'; }
screen_shake() { printf '\033[5;5H'; sleep 0.05; printf '\033[H'; }

# Difficulty settings
difficulty="normal"
difficulty_multiplier=1.0
xp_multiplier=1.0
gold_multiplier=1.0

# Animation functions
flash_screen() {
    printf "\033[?5h"
    sleep 0.1
    printf "\033[?5l"
}

typing_effect() {
    local text="$1"
    local delay=${2:-0.02}
    local color="$3"
    for ((i=0; i<${#text}; i++)); do
        printf "${color}%c${NC}" "${text:$i:1}"
        sleep $delay
    done
    printf "\n"
}

rainbow_text() {
    local text="$1"
    local colors=("$WHITE" "$CYAN" "$BLUE" "$INDIGO" "$VIOLET" "$PURPLE")
    for ((i=0; i<${#text}; i++)); do
        local color_idx=$((i % ${#colors[@]}))
        printf "${colors[$color_idx]}%s${NC}" "${text:$i:1}"
    done
    printf "\n"
}

draw_border() {
    local width=${1:-60}
    local char=${2:-═}
    printf "${CYAN}╔"
    for ((i=0; i<width; i++)); do printf "$char"; done
    printf "╗${NC}\n"
}

draw_border_bottom() {
    local width=${1:-60}
    local char=${2:-═}
    printf "${CYAN}╚"
    for ((i=0; i<width; i++)); do printf "$char"; done
    printf "╝${NC}\n"
}

weather_animation() {
    local wtype="$1"
    case "$wtype" in
        "snow")
            for i in {1..5}; do
                printf "\r${WHITE}*${NC}  "
                sleep 0.1
                printf "\r  ${WHITE}*${NC}"
                sleep 0.1
            done
            printf "\r"
            ;;
        "blizzard")
            for i in {1..8}; do
                printf "\r${WHITE}***${NC}"
                sleep 0.05
                printf "\r   ${WHITE}***${NC}"
                sleep 0.05
            done
            printf "\r"
            ;;
        "rain")
            for i in {1..6}; do
                printf "\r${BLUE}|${NC}  "
                sleep 0.08
                printf "\r  ${BLUE}|${NC}"
                sleep 0.08
            done
            printf "\r"
            ;;
    esac
}

type_text() {
    local text="$1"
    local delay=${2:-0.02}
    for ((i=0; i<${#text}; i++)); do
        printf "%c" "${text:$i:1}"
        sleep $delay
    done
    printf "\n"
}

pulse_text() {
    local text="$1"
    local color="$2"
    for i in {1..2}; do
        printf "\r${color}%s${NC}" "$text"
        sleep 0.15
        printf "\r${GRAY}%s${NC}" "$text"
        sleep 0.15
    done
    printf "\r${color}%s${NC}\n" "$text"
}

# Save/Load functions
SAVE_DIR="$HOME/.tundra_saves"
mkdir -p "$SAVE_DIR" 2>/dev/null
SAVE_FILE="$SAVE_DIR/save_1.dat"
CURRENT_SAVE_SLOT=1

game_save() {
    local slot_num=${1:-$CURRENT_SAVE_SLOT}
    local save_file="$SAVE_DIR/save_${slot_num}.dat"
    cat > "$save_file" << EOF
px=$px
py=$py
hp=$hp
max_hp=$max_hp
gold=$gold
hunger=$hunger
max_hunger=$max_hunger
warmth=$warmth
max_warmth=$max_warmth
day=$day
time_of_day=$time_of_day
weather="$weather"
turn=$turn
wood=$wood
food=$food
torches=$torches
fur=$fur
herbs=$herbs
crafted_items="$crafted_items"
score=$score
skill_points=$skill_points
skill_foraging=$skill_foraging
skill_survival=$skill_survival
skill_exploration=$skill_exploration
skill_crafting=$skill_crafting
skill_hunting=$skill_hunting
skill_endurance=$skill_endurance
achievements="$achievements"
max_day=$max_day
total_distance=$total_distance
first_night=$first_night
explorer=$explorer
survivor=$survivor
master_crafter=$master_crafter
wealthy=$wealthy
weather_master=$weather_master
tundra_walker=$tundra_walker
night_survivor=$night_survivor
storm_chaser=$storm_chaser
status_frostbite=$status_frostbite
status_heatstroke=$status_heatstroke
status_wellfed=$status_wellfed
status_turns=$status_turns
status_hydrated=$status_hydrated
status_energized=$status_energized
equipped_weapon="$equipped_weapon"
weapon_damage=$weapon_damage
equipped_armor="$equipped_armor"
armor_defense=$armor_defense
equipped_tool="$equipped_tool"
tool_bonus=$tool_bonus
current_quest="$current_quest"
quest_type="$quest_type"
quest_target=$quest_target
quest_progress=$quest_progress
quest_reward_gold=$quest_reward_gold
quest_reward_xp=$quest_reward_xp
EOF
    msg="Game saved!"
}

game_load() {
    local slot_num=${1:-$CURRENT_SAVE_SLOT}
    local save_file="$SAVE_DIR/save_${slot_num}.dat"
    if [ -f "$save_file" ]; then
        source "$save_file"
        CURRENT_SAVE_SLOT=$slot_num
        msg="Game loaded from slot $slot_num!"
        return 0
    else
        msg="No save file in slot $slot_num."
        return 1
    fi
}

# --- Game State ---
px=100; py=100
hp=100; max_hp=100
gold=0
hunger=100; max_hunger=100
warmth=100; max_warmth=100
view_dist=6
day=1
time_of_day=0  # 0-23
weather="clear"
weather_intensity=0  # 0-10, affects difficulty
weather_duration=0   # turns until weather changes
msg="Explore the infinite tundra... WASD/Arrows to move, 'i' camp, 'h' help, 's' save, 'q' quit"
turn=0
score=0

# Skill System
skill_points=0
skill_foraging=0
skill_survival=0
skill_exploration=0
skill_crafting=0
skill_hunting=0
skill_endurance=0

# Achievements
achievements=""
max_day=0
total_distance=0
first_night=false
explorer=false
survivor=false
master_crafter=false
wealthy=false
weather_master=false
tundra_walker=false
night_survivor=false
storm_chaser=false

# Status effects
status_frostbite=false
status_heatstroke=false
status_wellfed=false
status_turns=0
status_hydrated=false
status_energized=false

# Inventory
wood=5
food=3
torches=2
fur=0
herbs=0

# Survival mechanics
freezing=false
starving=false
poisoned=false
poison_turns=0

# Crafting
crafted_items=""

# Equipment System
equipped_weapon="none"
weapon_damage=0
equipped_armor="none"
armor_defense=0
equipped_tool="none"
tool_bonus=0

# Quest System
current_quest=""
quest_type=""
quest_target=0
quest_progress=0
quest_reward_gold=0
quest_reward_xp=0

# --- Procedural Generation ---
get_tile() {
    local x=$1 y=$2
    # Improved hash for more interesting terrain
    local val=$(( (x * 98765 + y * 43210 + day * 123) % 100 ))
    if [ $val -lt 0 ]; then val=$((val * -1)); fi

    if [ $val -lt 3 ]; then echo "M"; # Monster
    elif [ $val -lt 6 ]; then echo "G"; # Gold
    elif [ $val -lt 9 ]; then echo "T"; # Town
    elif [ $val -lt 12 ]; then echo "C"; # Cave
    elif [ $val -lt 20 ]; then echo "W"; # Water
    elif [ $val -lt 35 ]; then echo "^"; # Forest
    elif [ $val -lt 50 ]; then echo "~"; # Snow
    elif [ $val -lt 70 ]; then echo "*"; # Rocky
    else echo "."; # Plains
    fi
}

# --- Weather System ---
get_weather_icon() {
    case "$1" in
        "clear") echo "☀️" ;;
        "cloudy") echo "☁️" ;;
        "snowing") echo "❄️" ;;
        "blizzard") echo "🌨️" ;;
        "aurora") echo "🌌" ;;
        "meteor_shower") echo "☄️" ;;
        *) echo "🌤" ;;
    esac
}

get_weather_color() {
    case "$1" in
        "clear") echo "${YELLOW}" ;;
        "cloudy") echo "${GRAY}" ;;
        "snowing") echo "${BLUE}" ;;
        "blizzard") echo "${RED}" ;;
        "aurora") echo "${MAGENTA}" ;;
        "meteor_shower") echo "${ORANGE}" ;;
        *) echo "${WHITE}" ;;
    esac
}

update_weather() {
    weather_duration=$((weather_duration - 1))
    
    if [ $weather_duration -le 0 ]; then
        local weather_roll=$((RANDOM % 100))
        if [ $weather_roll -lt 50 ]; then
            weather="clear"
            weather_intensity=$((RANDOM % 3))
            weather_duration=$((RANDOM % 5 + 3))
        elif [ $weather_roll -lt 70 ]; then
            weather="cloudy"
            weather_intensity=$((RANDOM % 4 + 1))
            weather_duration=$((RANDOM % 4 + 2))
        elif [ $weather_roll -lt 85 ]; then
            weather="snowing"
            weather_intensity=$((RANDOM % 5 + 2))
            weather_duration=$((RANDOM % 6 + 3))
        elif [ $weather_roll -lt 95 ]; then
            weather="blizzard"
            weather_intensity=$((RANDOM % 4 + 6))
            weather_duration=$((RANDOM % 4 + 2))
        elif [ $weather_roll -lt 98 ]; then
            weather="aurora"  # Special weather event
            weather_intensity=10
            weather_duration=2
        else
            weather="meteor_shower"  # Rare event
            weather_intensity=8
            weather_duration=1
        fi
        
        # Weather animation on change
        if [ "$weather" = "blizzard" ] || [ "$weather" = "snowing" ] || [ "$weather" = "rain" ]; then
            weather_animation "$weather"
        fi
    fi
}

# --- Day/Night Cycle ---
update_time() {
    time_of_day=$((time_of_day + 1))
    if [ $time_of_day -ge 24 ]; then
        time_of_day=0
        day=$((day + 1))
        update_weather
    fi
}

# --- Combat System ---
combat_encounter() {
    local monster_hp=$((RANDOM % 30 + 20))
    local monster_max_hp=$monster_hp
    local monster_damage=$((RANDOM % 10 + 5))
    
    while [ $monster_hp -gt 0 ] && [ $hp -gt 0 ]; do
        clear_screen
        echo -e "${RED}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║${NC} ${BOLD}${WHITE}⚔ COMBAT ENCOUNTER ⚔${NC} ${RED}                                            ║${NC}"
        echo -e "${RED}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${RED}║${NC} ${WHITE}Monster HP:${NC} ${GREEN}$monster_hp${NC}/${WHITE}$monster_max_hp ${RED}│${NC} ${WHITE}Your HP:${NC} ${GREEN}$hp${NC}/${WHITE}$max_hp ${RED}│${NC} ${WHITE}Weapon:${NC} ${YELLOW}$equipped_weapon${NC} ${RED}║${NC}"
        echo -e "${RED}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${RED}║${NC} ${WHITE}1) Attack${NC}    ${WHITE}2) Defend${NC}    ${WHITE}3) Flee${NC}                              ${RED}║${NC}"
        echo -e "${RED}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
        read -p " " combat_choice
        
        case $combat_choice in
            1)
                # Attack
                local your_damage=$((weapon_damage + RANDOM % 10 + 5))
                monster_hp=$((monster_hp - your_damage))
                echo -e "${WHITE}You deal $your_damage damage!${NC}"
                sleep 0.5
                ;;
            2)
                # Defend - reduce incoming damage
                local defense_reduction=$((armor_defense + 5))
                local incoming_damage=$((monster_damage - defense_reduction))
                [ $incoming_damage -lt 1 ] && incoming_damage=1
                hp=$((hp - incoming_damage))
                echo -e "${WHITE}You defend! Monster deals only $incoming_damage damage.${NC}"
                sleep 0.5
                ;;
            3)
                # Flee
                local flee_chance=$((30 + skill_survival * 5))
                local flee_roll=$((RANDOM % 100))
                if [ $flee_roll -lt $flee_chance ]; then
                    echo -e "${GREEN}You escaped successfully!${NC}"
                    sleep 1
                    px=$old_px; py=$old_py
                    return 1
                else
                    echo -e "${RED}Failed to flee! Monster attacks!${NC}"
                    sleep 0.5
                fi
                ;;
        esac
        
        # Monster attacks (if not defending)
        if [ "$combat_choice" != "2" ] && [ $monster_hp -gt 0 ]; then
            local incoming_damage=$((monster_damage - armor_defense))
            [ $incoming_damage -lt 2 ] && incoming_damage=2
            hp=$((hp - incoming_damage))
            echo -e "${RED}Monster attacks for $incoming_damage damage!${NC}"
            sleep 0.5
        fi
    done
    
    if [ $monster_hp -le 0 ]; then
        echo -e "${GREEN}You defeated the monster!${NC}"
        sleep 1
        # Drop loot
        local loot_roll=$((RANDOM % 100))
        if [ $loot_roll -lt 30 ]; then
            gold=$((gold + RANDOM % 20 + 10))
            msg="Monster defeated! Found gold!"
        elif [ $loot_roll -lt 50 ]; then
            food=$((food + 1))
            msg="Monster defeated! Found food!"
        elif [ $loot_roll -lt 60 ]; then
            fur=$((fur + 1))
            msg="Monster defeated! Found fur!"
        else
            msg="Monster defeated!"
        fi
        # Quest progress
        if [ "$quest_type" = "kill_monsters" ]; then
            quest_progress=$((quest_progress + 1))
            if [ $quest_progress -ge $quest_target ]; then
                gold=$((gold + quest_reward_gold))
                skill_points=$((skill_points + 1))
                current_quest=""
                msg="Quest complete! +$quest_reward_gold gold, +1 SP"
            fi
        fi
        return 0
    else
        msg="You were defeated by the monster..."
        return 1
    fi
}

# --- Equipment Functions ---
show_equipment_menu() {
    clear_screen
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${BOLD}${YELLOW}⚔ EQUIPMENT & CRAFTING ⚔${NC} ${CYAN}                                       ║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Equipped:${NC} ${YELLOW}Weapon:$equipped_weapon${NC} (+$weapon_damage dmg) ${CYAN}│${NC} ${WHITE}Armor:$equipped_armor${NC} (+$armor_defense def) ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Craft Weapons:${NC}                                                   ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}1) Stone Club (3 wood, +5 dmg)${NC}                                 ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}2) Iron Sword (5 wood, 2 fur, +12 dmg)${NC}                        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}3) Ice Axe (7 wood, 3 fur, +18 dmg)${NC}                           ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Craft Armor:${NC}                                                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}4) Leather Armor (4 fur, +3 def)${NC}                              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}5) Fur Coat (6 fur, +6 def)${NC}                                   ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}6) Ice Armor (8 fur, 2 wood, +10 def)${NC}                          ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Craft Tools:${NC}                                                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}7) Hunting Knife (2 wood, +10% meat from kills)${NC}               ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}8) Pickaxe (4 wood, +20% gold from caves)${NC}                     ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}q) Back${NC}                                                       ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    read -p " " equip_choice
    
    case $equip_choice in
        1)
            if [ $wood -ge 3 ]; then
                wood=$((wood - 3))
                equipped_weapon="Stone Club"
                weapon_damage=5
                msg="Crafted Stone Club! +5 damage."
            else
                msg="Not enough wood! Need 3."
            fi
            ;;
        2)
            if [ $wood -ge 5 ] && [ $fur -ge 2 ]; then
                wood=$((wood - 5))
                fur=$((fur - 2))
                equipped_weapon="Iron Sword"
                weapon_damage=12
                msg="Crafted Iron Sword! +12 damage."
            else
                msg="Not enough materials! Need 5 wood, 2 fur."
            fi
            ;;
        3)
            if [ $wood -ge 7 ] && [ $fur -ge 3 ]; then
                wood=$((wood - 7))
                fur=$((fur - 3))
                equipped_weapon="Ice Axe"
                weapon_damage=18
                msg="Crafted Ice Axe! +18 damage."
            else
                msg="Not enough materials! Need 7 wood, 3 fur."
            fi
            ;;
        4)
            if [ $fur -ge 4 ]; then
                fur=$((fur - 4))
                equipped_armor="Leather Armor"
                armor_defense=3
                msg="Crafted Leather Armor! +3 defense."
            else
                msg="Not enough fur! Need 4."
            fi
            ;;
        5)
            if [ $fur -ge 6 ]; then
                fur=$((fur - 6))
                equipped_armor="Fur Coat"
                armor_defense=6
                msg="Crafted Fur Coat! +6 defense."
            else
                msg="Not enough fur! Need 6."
            fi
            ;;
        6)
            if [ $fur -ge 8 ] && [ $wood -ge 2 ]; then
                fur=$((fur - 8))
                wood=$((wood - 2))
                equipped_armor="Ice Armor"
                armor_defense=10
                msg="Crafted Ice Armor! +10 defense."
            else
                msg="Not enough materials! Need 8 fur, 2 wood."
            fi
            ;;
        7)
            if [ $wood -ge 2 ]; then
                wood=$((wood - 2))
                equipped_tool="Hunting Knife"
                skill_hunting=$((skill_hunting + 2))
                msg="Crafted Hunting Knife! +2 hunting skill."
            else
                msg="Not enough wood! Need 2."
            fi
            ;;
        8)
            if [ $wood -ge 4 ]; then
                wood=$((wood - 4))
                equipped_tool="Pickaxe"
                msg="Crafted Pickaxe! Better cave loot!"
            else
                msg="Not enough wood! Need 4."
            fi
            ;;
        *)
            msg="Back to inventory..."
            ;;
    esac
}

# --- Quest System ---
generate_quest() {
    if [ -z "$current_quest" ]; then
        local quest_roll=$((RANDOM % 5))
        case $quest_roll in
            0)
                current_quest="Collect Gold"
                quest_type="collect_gold"
                quest_target=$((RANDOM % 50 + 30))
                quest_progress=$gold
                quest_reward_gold=$((quest_target / 2))
                quest_reward_xp=1
                ;;
            1)
                current_quest="Survive Days"
                quest_type="survive_days"
                quest_target=$((RANDOM % 5 + 3))
                quest_progress=$day
                quest_reward_gold=50
                quest_reward_xp=2
                ;;
            2)
                current_quest="Kill Monsters"
                quest_type="kill_monsters"
                quest_target=$((RANDOM % 5 + 3))
                quest_progress=0
                quest_reward_gold=40
                quest_reward_xp=1
                ;;
            3)
                current_quest="Gather Resources"
                quest_type="gather_resources"
                quest_target=$((RANDOM % 20 + 10))
                quest_progress=$((wood + food))
                quest_reward_gold=30
                quest_reward_xp=1
                ;;
            4)
                current_quest="Travel Distance"
                quest_type="travel_distance"
                quest_target=$((RANDOM % 200 + 100))
                quest_progress=$total_distance
                quest_reward_gold=35
                quest_reward_xp=1
                ;;
        esac
        msg="New Quest: $current_quest"
    fi
}

update_quest_progress() {
    if [ -n "$current_quest" ]; then
        case "$quest_type" in
            collect_gold)
                quest_progress=$gold
                ;;
            survive_days)
                quest_progress=$day
                ;;
            gather_resources)
                quest_progress=$((wood + food))
                ;;
            travel_distance)
                quest_progress=$total_distance
                ;;
        esac
        
        if [ $quest_progress -ge $quest_target ]; then
            gold=$((gold + quest_reward_gold))
            skill_points=$((skill_points + quest_reward_xp))
            msg="Quest Complete: $current_quest! +$quest_reward_gold gold, +$quest_reward_xp SP"
            current_quest=""
            quest_type=""
            quest_target=0
            quest_progress=0
        fi
    fi
}

# --- Town Trading System ---
show_trading_menu() {
    while true; do
        clear_screen
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC} ${BOLD}${YELLOW}🏪 TOWN TRADING POST 🏪${NC} ${CYAN}                                        ║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${WHITE}Your Gold:${NC} ${YELLOW}$gold${NC} ${CYAN}│${NC} ${WHITE}Wood:$wood${NC} ${CYAN}│${NC} ${WHITE}Food:$food${NC} ${CYAN}│${NC} ${WHITE}Fur:$fur${NC} ${CYAN}│${NC} ${WHITE}Herbs:$herbs${NC} ${CYAN}║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${WHITE}Buy:${NC}                                                           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${WHITE}1) Food (15g)${NC}    ${WHITE}2) Wood (10g)${NC}    ${WHITE}3) Herbs (20g)${NC}              ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${WHITE}4) Torch (25g)${NC}    ${WHITE}5) Fur (30g)${NC}                                   ${CYAN}║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${WHITE}Sell:${NC}                                                          ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${WHITE}6) Sell Wood (5g)${NC}  ${WHITE}7) Sell Food (8g)${NC}  ${WHITE}8) Sell Fur (15g)${NC}       ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${WHITE}9) Sell Herbs (12g)${NC}                                             ${CYAN}║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${WHITE}r) Rest (Free - restores HP, hunger, warmth)${NC}                    ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${WHITE}q) Leave Town${NC}                                                  ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
        read -p " " trade_choice
        
        case $trade_choice in
            1)
                if [ $gold -ge 15 ]; then
                    gold=$((gold - 15))
                    food=$((food + 1))
                    msg="Bought food for 15 gold."
                else
                    msg="Not enough gold!"
                fi
                ;;
            2)
                if [ $gold -ge 10 ]; then
                    gold=$((gold - 10))
                    wood=$((wood + 1))
                    msg="Bought wood for 10 gold."
                else
                    msg="Not enough gold!"
                fi
                ;;
            3)
                if [ $gold -ge 20 ]; then
                    gold=$((gold - 20))
                    herbs=$((herbs + 1))
                    msg="Bought herbs for 20 gold."
                else
                    msg="Not enough gold!"
                fi
                ;;
            4)
                if [ $gold -ge 25 ]; then
                    gold=$((gold - 25))
                    torches=$((torches + 1))
                    msg="Bought torch for 25 gold."
                else
                    msg="Not enough gold!"
                fi
                ;;
            5)
                if [ $gold -ge 30 ]; then
                    gold=$((gold - 30))
                    fur=$((fur + 1))
                    msg="Bought fur for 30 gold."
                else
                    msg="Not enough gold!"
                fi
                ;;
            6)
                if [ $wood -gt 0 ]; then
                    wood=$((wood - 1))
                    gold=$((gold + 5))
                    msg="Sold wood for 5 gold."
                else
                    msg="No wood to sell!"
                fi
                ;;
            7)
                if [ $food -gt 0 ]; then
                    food=$((food - 1))
                    gold=$((gold + 8))
                    msg="Sold food for 8 gold."
                else
                    msg="No food to sell!"
                fi
                ;;
            8)
                if [ $fur -gt 0 ]; then
                    fur=$((fur - 1))
                    gold=$((gold + 15))
                    msg="Sold fur for 15 gold."
                else
                    msg="No fur to sell!"
                fi
                ;;
            9)
                if [ $herbs -gt 0 ]; then
                    herbs=$((herbs - 1))
                    gold=$((gold + 12))
                    msg="Sold herbs for 12 gold."
                else
                    msg="No herbs to sell!"
                fi
                ;;
            r)
                hp=$max_hp
                hunger=$max_hunger
                warmth=$max_warmth
                msg="Rested at town. Fully recovered!"
                ;;
            q)
                msg="Left town."
                break
                ;;
            *)
                msg="Invalid choice."
                ;;
        esac
    done
}

# --- Survival Mechanics ---
update_survival() {
    # Hunger decreases over time (reduced by survival skill)
    local hunger_loss=$((1 - skill_survival / 10))
    [ $hunger_loss -lt 1 ] && hunger_loss=1
    hunger=$((hunger - hunger_loss))
    
    # Warmth affected by weather and time (reduced by survival skill)
    local warmth_loss=1
    if [ "$weather" = "snowing" ]; then warmth_loss=2; fi
    if [ "$weather" = "blizzard" ]; then warmth_loss=4; fi
    if [ "$weather" = "meteor_shower" ]; then warmth_loss=3; fi
    if [ $time_of_day -ge 20 ] || [ $time_of_day -lt 6 ]; then warmth_loss=$((warmth_loss + 1)); fi
    
    # Survival skill reduces warmth loss
    warmth_loss=$((warmth_loss - skill_survival / 5))
    [ $warmth_loss -lt 1 ] && warmth_loss=1
    
    warmth=$((warmth - warmth_loss))
    
    # Poison damage
    if [ "$poisoned" = true ]; then
        poison_turns=$((poison_turns - 1))
        hp=$((hp - 2))
        if [ $poison_turns -le 0 ]; then
            poisoned=false
            msg="Poison wore off!"
        fi
    fi
    
    # Status effects
    if [ "$status_frostbite" = true ]; then
        status_turns=$((status_turns - 1))
        hp=$((hp - 3))
        if [ $status_turns -le 0 ]; then
            status_frostbite=false
            msg="Frostbite healed!"
        fi
    fi
    
    if [ "$status_wellfed" = true ]; then
        status_turns=$((status_turns - 1))
        if [ $status_turns -le 0 ]; then
            status_wellfed=false
        fi
    fi
    
    # Check survival status
    if [ $hunger -le 0 ]; then
        hunger=0
        starving=true
        hp=$((hp - 5))
    else
        starving=false
    fi
    
    if [ $warmth -le 0 ]; then
        warmth=0
        freezing=true
        hp=$((hp - 3))
    else
        freezing=false
    fi
    
    # Update max day achievement
    if [ $day -gt $max_day ]; then
        max_day=$day
    fi
    
    # First night achievement
    if [ $time_of_day -ge 20 ] && [ "$first_night" = false ]; then
        first_night=true
        achievements="${achievements} First Night"
    fi
}

# --- UI Functions ---
draw_ui() {
    clear_screen
    
    # Time of day indicator
    local time_color="$YELLOW"
    local time_icon="☀️"
    if [ $time_of_day -ge 20 ] || [ $time_of_day -lt 6 ]; then 
        time_color="$BLUE"
        time_icon="🌙"
    fi
    local time_str="Morning"
    if [ $time_of_day -ge 12 ] && [ $time_of_day -lt 17 ]; then 
        time_str="Afternoon"
        time_icon="🌤"
    elif [ $time_of_day -ge 17 ] && [ $time_of_day -lt 20 ]; then 
        time_str="Evening"
        time_icon="🌅"
    elif [ $time_of_day -ge 20 ] || [ $time_of_day -lt 6 ]; then 
        time_str="Night"
        time_icon="🌙"
    fi
    
    # Weather icon and color
    local weather_icon=$(get_weather_icon "$weather")
    local weather_color=$(get_weather_color "$weather")
    
    # HP bar
    local hp_percent=$((hp * 100 / max_hp))
    local hp_color=$GREEN
    if [ $hp_percent -lt 50 ]; then hp_color=$YELLOW
    elif [ $hp_percent -lt 25 ]; then hp_color=$RED
    fi
    local hp_bar=""
    local hp_blocks=$((hp_percent / 5))
    for ((i=0; i<20; i++)); do
        if [ $i -lt $hp_blocks ]; then hp_bar+="█"
        else hp_bar+="░"; fi
    done
    
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${BOLD}${WHITE}❄ INFINITE TUNDRA - Enhanced Edition ❄${NC} ${CYAN}                   ║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${RED}❤ HP:${NC} ${hp_color}$hp/$max_hp${NC} [$hp_bar] ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}🍖 Hunger:${NC} $([ $starving = true ] && echo -e "${RED}$hunger${NC}" || echo -e "${GREEN}$hunger${NC}") ${CYAN}│${NC} ${BLUE}🌡 Warmth:${NC} $([ $freezing = true ] && echo -e "${RED}$warmth${NC}" || echo -e "${GREEN}$warmth${NC}") ${CYAN}│${NC} ${LIME}SP:${WHITE}$skill_points ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${time_color}${time_icon} Day $day - $time_str${NC} ${CYAN}$(printf '%.0s ' $(seq 1 $((25 - ${#time_str}))))${CYAN}│${NC} ${weather_color}${weather_icon} ${weather}${NC} ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}🪙 Gold:${NC} ${WHITE}$gold${NC} ${CYAN}│${NC} ${GREEN}📍 X:$px Y:$py${NC} ${CYAN}│${NC} ${MAGENTA}⭐ Score:$score${NC} ${CYAN}│${NC} ${ORANGE}Dist:${WHITE}$total_distance ${CYAN}║${NC}"
    
    # Equipment display
    local equip_line=""
    [ "$equipped_weapon" != "none" ] && equip_line="${equip_line}${YELLOW}⚔${equipped_weapon}${NC} "
    [ "$equipped_armor" != "none" ] && equip_line="${equip_line}${BLUE}🛡${equipped_armor}${NC} "
    echo -e "${CYAN}║${NC} ${WHITE}Equip:${NC} ${equip_line}${CYAN}$(printf '%.0s ' $(seq 1 $((60 - ${#equip_line} - 8))))${CYAN}║${NC}"
    
    # Quest display
    if [ -n "$current_quest" ]; then
        local quest_info="${MAGENTA}Quest:${WHITE} $current_quest ($quest_progress/$quest_target)${NC}"
        echo -e "${CYAN}║${NC} $quest_info ${CYAN}$(printf '%.0s ' $(seq 1 $((60 - ${#quest_info} - 4))))${CYAN}║${NC}"
    else
        echo -e "${CYAN}║${NC} ${WHITE}No active quest${NC} ${CYAN}$(printf '%.0s ' $(seq 1 $((60 - 16))))${CYAN}║${NC}"
    fi
    
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    
    # Status effects
    local status_line=""
    [ "$poisoned" = true ] && status_line="${status_line}${RED}☠ Poisoned${NC} "
    [ "$starving" = true ] && status_line="${status_line}${RED}🤤 Starving${NC} "
    [ "$freezing" = true ] && status_line="${status_line}${RED}❄️ Freezing${NC} "
    [ "$status_frostbite" = true ] && status_line="${status_line}${BLUE}🥶 Frostbite${NC} "
    [ "$status_wellfed" = true ] && status_line="${status_line}${GREEN}😊 Well-fed${NC} "
    echo -e "${CYAN}║${NC} ${WHITE}Status:${NC} ${status_line}${CYAN}$(printf '%.0s ' $(seq 1 $((60 - ${#status_line} - 10))))${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    
    # Render viewport with colors
    for ((y=py-view_dist; y<=py+view_dist; y++)); do
        echo -n "${CYAN}║${NC} "
        for ((x=px-view_dist; x<=px+view_dist; x++)); do
            if [ $x -eq $px ] && [ $y -eq $py ]; then
                echo -n "${GREEN}☺${NC} "
            else
                tile=$(get_tile $x $y)
                case "$tile" in
                    "M") echo -n "${RED}M${NC} " ;;
                    "G") echo -n "${YELLOW}$${NC} " ;;
                    "T") echo -n "${CYAN}▣${NC} " ;;
                    "C") echo -n "${GRAY}◙${NC} " ;;
                    "W") echo -n "${BLUE}≈${NC} " ;;
                    "^") echo -n "${GREEN}↑${NC} " ;;
                    "~") echo -n "${WHITE}*${NC} " ;;
                    "*") echo -n "${GRAY}•${NC} " ;;
                    *) echo -n "· " ;;
                esac
            fi
        done
        echo -e "${CYAN}║${NC}"
    done
    
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${BOLD}Log:${NC} ${WHITE}$msg${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
}

show_inventory() {
    clear_screen
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${BOLD}${YELLOW}🎒 INVENTORY & CRAFTING 🎒${NC} ${CYAN}                                     ║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}🪵 Wood:${NC} ${WHITE}$wood${NC} ${CYAN}│${NC} ${GREEN}🍖 Food:${NC} ${WHITE}$food${NC} ${CYAN}│${NC} ${YELLOW}🔥 Torches:${NC} ${WHITE}$torches${NC} ${CYAN}│${NC} ${WHITE}🐺 Fur:${NC} ${WHITE}$fur${NC} ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${GREEN}🌿 Herbs:${NC} ${WHITE}$herbs${NC} ${CYAN}│${NC} ${LIME}Skill Points:${NC} ${WHITE}$skill_points${NC} ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    
    # Skill tree visualization
    echo -e "${CYAN}║${NC} ${WHITE}Skill Tree (cost 1 SP):${NC}                                         ${CYAN}║${NC}"
    local forage_bar=""
    for ((i=0; i<skill_foraging; i++)); do forage_bar+="█"; done
    for ((i=skill_foraging; i<10; i++)); do forage_bar+="░"; done
    
    local surv_bar=""
    for ((i=0; i<skill_survival; i++)); do surv_bar+="█"; done
    for ((i=skill_survival; i<10; i++)); do surv_bar+="░"; done
    
    local expl_bar=""
    for ((i=0; i<skill_exploration; i++)); do expl_bar+="█"; done
    for ((i=skill_exploration; i<10; i++)); do expl_bar+="░"; done
    
    local craft_bar=""
    for ((i=0; i<skill_crafting; i++)); do craft_bar+="█"; done
    for ((i=skill_crafting; i<10; i++)); do craft_bar+="░"; done
    
    local hunt_bar=""
    for ((i=0; i<skill_hunting; i++)); do hunt_bar+="█"; done
    for ((i=skill_hunting; i<10; i++)); do hunt_bar+="░"; done
    
    local endur_bar=""
    for ((i=0; i<skill_endurance; i++)); do endur_bar+="█"; done
    for ((i=skill_endurance; i<10; i++)); do endur_bar+="░"; done
    
    echo -e "${CYAN}║${NC} ${WHITE}1) 🌿 Foraging${NC}  [$forage_bar] ${LIME}${skill_foraging*10}% gather${NC}           ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}2) 🛡 Survival${NC}   [$surv_bar] ${LIME}-${skill_survival*10}% loss${NC}              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}3) 🔭 Explore${NC}    [$expl_bar] ${LIME}+${skill_exploration} view${NC}                ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}4) 🔨 Crafting${NC}   [$craft_bar] ${LIME}+${skill_crafting*5}% craft efficiency${NC}     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}5) 🏹 Hunting${NC}    [$hunt_bar] ${LIME}+${skill_hunting*10% meat from kills${NC}       ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}6) 💪 Endurance${NC}  [$endur_bar] ${LIME}+${skill_endurance*5 max HP${NC}             ${CYAN}║${NC}"
    
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Crafting & Survival:${NC}                                            ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}7) 🔥 Campfire (2 wood, +warmth)${NC}                               ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}8) 🍖 Eat food (1 food, +hunger)${NC}                                 ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}9) 💤 Rest by fire (1 wood, +10 HP)${NC}                             ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}0) 🧥 Fur coat (3 fur, -2 warmth loss)${NC}                          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}a) 💊 Use herbs (1 herb, cure poison, +5 HP)${NC}                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}b) 🏠 Shelter (5 wood, -50% warmth loss)${NC}                        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}c) 🪣 Water canteen (2 wood, +hydration)${NC}                         ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}d) 🏕️ Shelter (5 wood, +20 HP, -5 hunger)${NC}                      ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}e) ⚔ Equipment Crafting (weapons, armor, tools)${NC}               ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Game:${NC} s) Save  l) Load  h) Help  q) Close                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    
    read -p " " inv_choice
    
    case $inv_choice in
        1)
            if [ $skill_points -gt 0 ]; then
                skill_points=$((skill_points - 1))
                skill_foraging=$((skill_foraging + 1))
                msg="Foraging upgraded! +10% gather chance."
            else
                msg="Not enough skill points!"
            fi
            ;;
        2)
            if [ $skill_points -gt 0 ]; then
                skill_points=$((skill_points - 1))
                skill_survival=$((skill_survival + 1))
                msg="Survival upgraded! -10% warmth/hunger loss."
            else
                msg="Not enough skill points!"
            fi
            ;;
        3)
            if [ $skill_points -gt 0 ]; then
                skill_points=$((skill_points - 1))
                skill_exploration=$((skill_exploration + 1))
                view_dist=$((view_dist + 1))
                msg="Exploration upgraded! +1 view distance."
            else
                msg="Not enough skill points!"
            fi
            ;;
        4)
            if [ $wood -ge 2 ]; then
                wood=$((wood - 2))
                warmth=$max_warmth
                msg="Campfire made! Warmth restored."
            else
                msg="Not enough wood! Need 2."
            fi
            ;;
        5)
            if [ $food -gt 0 ]; then
                food=$((food - 1))
                hunger=$max_hunger
                msg="Ate food! Hunger restored."
            else
                msg="No food left!"
            fi
            ;;
        6)
            if [ $wood -gt 0 ] && [ $hp -lt $max_hp ]; then
                wood=$((wood - 1))
                hp=$((hp + 10))
                [ $hp -gt $max_hp ] && hp=$max_hp
                msg="Rested by fire. Healed 10 HP."
            elif [ $wood -le 0 ]; then
                msg="Need wood to make a fire for resting!"
            else
                msg="HP already full!"
            fi
            ;;
        7)
            if [ $wood -ge 2 ]; then
                wood=$((wood - 2))
                warmth=$max_warmth
                msg="Campfire made! Warmth restored."
            else
                msg="Not enough wood! Need 2."
            fi
            ;;
        8)
            if [ $food -gt 0 ]; then
                food=$((food - 1))
                hunger=$max_hunger
                msg="Ate food! Hunger restored."
            else
                msg="No food left!"
            fi
            ;;
        9)
            if [ $wood -gt 0 ] && [ $hp -lt $max_hp ]; then
                wood=$((wood - 1))
                hp=$((hp + 10))
                [ $hp -gt $max_hp ] && hp=$max_hp
                msg="Rested by fire. Healed 10 HP."
            elif [ $wood -le 0 ]; then
                msg="Need wood to make a fire for resting!"
            else
                msg="HP already full!"
            fi
            ;;
        0)
            if [ $fur -ge 3 ] && [[ ! "$crafted_items" =~ "fur_coat" ]]; then
                fur=$((fur - 3))
                crafted_items="${crafted_items} fur_coat"
                msg="Crafted fur coat! Warmth loss reduced."
            elif [[ "$crafted_items" =~ "fur_coat" ]]; then
                msg="Already have a fur coat!"
            else
                msg="Not enough fur! Need 3."
            fi
            ;;
        a)
            if [ $herbs -gt 0 ]; then
                herbs=$((herbs - 1))
                poisoned=false
                poison_turns=0
                hp=$((hp + 5))
                [ $hp -gt $max_hp ] && hp=$max_hp
                msg="Used herbs! Poison cured, +5 HP."
            else
                msg="No herbs left!"
            fi
            ;;
        b)
            if [ $wood -ge 5 ]; then
                wood=$((wood - 5))
                hp=$((hp + 20))
                [ $hp -gt $max_hp ] && hp=$max_hp
                hunger=$((hunger + 15))
                [ $hunger -gt $max_hunger ] && hunger=$max_hunger
                status_wellfed=true
                status_turns=3
                msg="Built shelter! Healed 20 HP, +15 hunger."
            else
                msg="Not enough wood! Need 5."
            fi
            ;;
        c)
            msg="Water canteen crafted! (placeholder)"
            ;;
        d)
            if [ $wood -ge 5 ]; then
                wood=$((wood - 5))
                hp=$((hp + 20))
                [ $hp -gt $max_hp ] && hp=$max_hp
                hunger=$((hunger + 15))
                [ $hunger -gt $max_hunger ] && hunger=$max_hunger
                status_wellfed=true
                status_turns=3
                msg="Built shelter! Healed 20 HP, +15 hunger."
            else
                msg="Not enough wood! Need 5."
            fi
            ;;
        e)
            show_equipment_menu
            ;;
        s)
            game_save
            ;;
        l)
            game_load
            ;;
        h)
            show_help
            ;;
        *)
            msg="Back to exploration..."
            ;;
    esac
    
    # Random events
    if [ $((turn % 10)) -eq 0 ]; then
        local event=$((RANDOM % 12))
        case $event in
            0) wood=$((wood + 2)); msg="Found fallen branches! +2 wood" ;;
            1) food=$((food + 1)); msg="Found berries! +1 food" ;;
            2) gold=$((gold + 15)); msg="Found buried coins! +15 gold" ;;
            3) warmth=$((warmth - 15)); msg="Sudden cold snap! Warmth -15" ;;
            4) hp=$((hp - 5)); msg="Tripped and fell! -5 HP" ;;
            5) 
                poisoned=true
                poison_turns=5
                msg="Stepped on poisonous plant! Poisoned for 5 turns"
                flash_screen
                ;;
            6) fur=$((fur + 1)); msg="Found animal fur!" ;;
            7) 
                if [ "$weather" = "aurora" ]; then
                    score=$((score + 50))
                    pulse_text "Aurora Blessing!" "$MAGENTA"
                    msg="Aurora blessing! +50 score"
                else
                    herbs=$((herbs + 1)); msg="Found medicinal herbs!"
                fi
                ;;
            8) 
                if [ "$weather" = "meteor_shower" ]; then
                    gold=$((gold + 30))
                    pulse_text "Meteor Fragment!" "$ORANGE"
                    msg="Meteor fragment! +30 gold"
                else
                    torches=$((torches + 1)); msg="Found abandoned torch!"
                fi
                ;;
            9) skill_points=$((skill_points + 1)); msg="Found ancient scroll! +1 Skill Point" ;;
            10) 
                status_frostbite=true
                status_turns=3
                msg="Frostbite! -3 HP for 3 turns"
                ;;
            11) 
                status_wellfed=true
                status_turns=5
                food=$((food + 2))
                msg="Found food cache! +2 food, well-fed for 5 turns"
                ;;
        esac
    fi
    
    # Aurora bonus
    if [ "$weather" = "aurora" ]; then
        score=$((score + 1))
    fi
    
    # Meteor shower bonus
    if [ "$weather" = "meteor_shower" ]; then
        score=$((score + 2))
    fi
    
    # Fur coat bonus
    if [[ "$crafted_items" =~ "fur_coat" ]]; then
        warmth=$((warmth + 1))
    fi
    
    # Track total distance
    total_distance=$((total_distance + 1))
    
    # Explorer achievement
    if [ $total_distance -ge 1000 ] && [ "$explorer" = false ]; then
        explorer=true
        achievements="${achievements} Explorer"
    fi
    
    # Survivor achievement
    if [ $day -ge 10 ] && [ "$survivor" = false ]; then
        survivor=true
        achievements="${achievements} Survivor"
    fi
    
    # Master crafter achievement
    if [[ "$crafted_items" =~ "fur_coat" ]] && [ "$master_crafter" = false ]; then
        master_crafter=true
        achievements="${achievements} Master Crafter"
    fi
    
    # Wealthy achievement
    if [ $gold -ge 1000 ] && [ "$wealthy" = false ]; then
        wealthy=true
        achievements="${achievements} Wealthy"
    fi
    
    # Check death conditions
    if [ $hp -le 0 ]; then
        show_cursor
        clear_screen
        echo -e "${RED}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║${NC} ${BOLD}☠ YOU PERISHED IN THE TUNDRA ☠${NC} ${RED}                              ║${NC}"
        echo -e "${RED}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${RED}║${NC} Days survived: $day | Gold collected: $gold | Turns: $turn ${RED}║${NC}"
        echo -e "${RED}║${NC} Distance traveled: $total_distance${RED}                                 ║${NC}"
        echo -e "${RED}║${NC} Final Score: $score${RED}                                            ║${NC}"
        echo -e "${RED}║${NC} ${LIME}Achievements:${NC} ${WHITE}$achievements${RED}                                ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
        exit
    fi
}

show_help() {
    clear_screen
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${BOLD}${YELLOW}📖 HELP 📖${NC} ${CYAN}                                                   ║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Movement:${NC} WASD or Arrow Keys                                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}i) Inventory/Camp  h) Help  s) Save  l) Load  q) Quit${NC}           ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Map Symbols:${NC}                                                  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${GREEN}☺${NC} ${WHITE}You${NC}  ${RED}M${NC} ${WHITE}Monster${NC}  ${YELLOW}$${NC} ${WHITE}Gold${NC}  ${CYAN}▣${NC} ${WHITE}Town${NC}  ${GRAY}◙${NC} ${WHITE}Cave${NC}  ${BLUE}≈${NC} ${WHITE}Water${NC}      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${GREEN}↑${NC} ${WHITE}Forest${NC}  ${WHITE}*${NC} ${WHITE}Snow${NC}  ${GRAY}•${NC} ${WHITE}Rocky${NC}  ${WHITE}·${NC} ${WHITE}Plains${NC}                         ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Weather Effects:${NC}                                               ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Clear: Normal${NC}  ${CYAN}Cloudy: Slight warmth loss${NC}  ${CYAN}Snowing: -2 warmth${NC}  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Blizzard: -4 warmth${NC}  ${CYAN}Aurora: +50 score${NC}  ${CYAN}Meteor Shower: -3 warmth${NC}  ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Survival Tips:${NC}                                                ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}- Keep hunger and warmth above 0 to survive${NC}                   ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}- Visit towns to rest and trade${NC}                               ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}- Explore caves with torches for loot${NC}                         ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}- Gather wood in forests, find food in snow${NC}                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}- Level up skills to survive longer${NC}                            ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Press any key to continue...${NC}                                   ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    read -rsn1
}

# Enhanced intro screen
show_intro() {
    clear_screen
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${BOLD}${WHITE}❄️ INFINITE TUNDRA - Enhanced Edition ❄️${NC} ${CYAN}                     ║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}A survival exploration game with procedural world and weather${NC}       ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Controls:${NC}                                                        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}WASD/Arrows${NC} ${WHITE}- Move  ${YELLOW}i${NC} ${WHITE}- Inventory/Camp  ${YELLOW}h${NC} ${WHITE}- Help${NC}            ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}s${NC} ${WHITE}- Save  ${YELLOW}l${NC} ${WHITE}- Load  ${YELLOW}q${NC} ${WHITE}- Quit${NC}                              ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Select Difficulty:${NC}                                            ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${GREEN}1) Easy${NC}   ${WHITE}- 50% more resources, slower survival drain${NC}            ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}2) Normal${NC} ${WHITE}- Standard survival experience${NC}                          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${RED}3) Hard${NC}   ${WHITE}- Faster survival drain, rare resources${NC}               ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${CRIMSON}4) Nightmare${NC} ${WHITE}- Extreme survival challenge${NC}                       ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    printf "${WHITE}Choose difficulty [1-4]: ${NC}"
    read -r diff_choice
    case $diff_choice in
        1) difficulty="easy"; difficulty_multiplier=0.7 ;;
        2) difficulty="normal"; difficulty_multiplier=1.0 ;;
        3) difficulty="hard"; difficulty_multiplier=1.3 ;;
        4) difficulty="nightmare"; difficulty_multiplier=1.6 ;;
        *) difficulty="normal"; difficulty_multiplier=1.0 ;;
    esac
    clear_screen
    typing_effect "Starting survival on $difficulty difficulty..." 0.03 ${GREEN}
    sleep 1
}

# --- Main Game Loop ---
hide_cursor
trap 'show_cursor; clear_screen; exit' INT TERM

show_intro

# Generate initial quest
generate_quest

while true; do
    draw_ui
    
    read -rsn1 key
    old_px=$px; old_py=$py
    ((turn++))
    
    case "$key" in
        w|A) ((py--)) ;;
        s|B) ((py++)) ;;
        a|D) ((px--)) ;;
        d|C) ((px++)) ;;
        i) show_inventory; continue ;;
        h) show_help; continue ;;
        s) game_save; continue ;;
        l) game_load; continue ;;
        q) show_cursor; clear_screen; exit ;;
    esac
    
    # Update time and survival
    update_time
    update_survival
    
    # Check tile interactions
    current_tile=$(get_tile $px $py)
    
    case "$current_tile" in
        M)
            # Monster encounter - use combat system
            combat_encounter
            ;;
        G)
            gold_amt=$((RANDOM % 30 + 20))
            gold=$((gold + gold_amt))
            msg="Found gold cache! +$gold_amt gold"
            ;;
        T)
            # Town - rest and trade
            show_trading_menu
            ;;
        C)
            # Cave - shelter but dangerous
            if [ $torches -gt 0 ]; then
                local loot=$((RANDOM % 3))
                case $loot in
                    0) gold=$((gold + 40)); msg="Cave explored with torch: +40 gold" ;;
                    1) food=$((food + 3)); msg="Cave explored with torch: +3 food" ;;
                    2) wood=$((wood + 5)); msg="Cave explored with torch: +5 wood" ;;
                esac
                torches=$((torches - 1))
            else
                msg="Cave too dark! Need a torch."
                px=$old_px; py=$old_py
            fi
            ;;
        W)
            # Water - refill but cold
            warmth=$((warmth - 10))
            msg="Drank from water source. Warmth -10."
            ;;
        ^)
            # Forest - gather wood (bonus from foraging skill)
            local forage_chance=$((30 + skill_foraging * 10))
            local forage_roll=$((RANDOM % 100))
            if [ $forage_roll -lt $forage_chance ]; then
                wood=$((wood + 1))
                msg="Gathered wood from forest."
            elif [ $forage_roll -lt $((forage_chance + 5)) ]; then
                fur=$((fur + 1))
                msg="Found fur in forest!"
            else
                msg="Walking through dense forest..."
            fi
            ;;
        ~)
            # Snow - cold but can find food (bonus from foraging skill)
            warmth=$((warmth - 5))
            local forage_chance=$((20 + skill_foraging * 10))
            local forage_roll=$((RANDOM % 100))
            if [ $forage_roll -lt $forage_chance ]; then
                food=$((food + 1))
                msg="Found food in snow! Warmth -5."
            elif [ $forage_roll -lt $((forage_chance + 7)) ]; then
                herbs=$((herbs + 1))
                msg="Found herbs in snow! Warmth -5."
            else
                msg="Trudging through snow... Warmth -5."
            fi
            ;;
        *)
            msg="Trekking through the tundra..."
            ;;
    esac
    
    # Update quest progress
    update_quest_progress
    
    # Generate new quest if none active
    if [ -z "$current_quest" ]; then
        generate_quest
    fi
    
    # Random events
    if [ $((turn % 10)) -eq 0 ]; then
        local event=$((RANDOM % 12))
        case $event in
            0) wood=$((wood + 2)); msg="Found fallen branches! +2 wood" ;;
            1) food=$((food + 1)); msg="Found berries! +1 food" ;;
            2) gold=$((gold + 15)); msg="Found buried coins! +15 gold" ;;
            3) warmth=$((warmth - 15)); msg="Sudden cold snap! Warmth -15" ;;
            4) hp=$((hp - 5)); msg="Tripped and fell! -5 HP" ;;
            5) 
                poisoned=true
                poison_turns=5
                msg="Stepped on poisonous plant! Poisoned for 5 turns"
                flash_screen
                ;;
            6) fur=$((fur + 1)); msg="Found animal fur!" ;;
            7) 
                if [ "$weather" = "aurora" ]; then
                    score=$((score + 50))
                    pulse_text "Aurora Blessing!" "$MAGENTA"
                    msg="Aurora blessing! +50 score"
                else
                    herbs=$((herbs + 1)); msg="Found medicinal herbs!"
                fi
                ;;
            8) 
                if [ "$weather" = "meteor_shower" ]; then
                    gold=$((gold + 30))
                    pulse_text "Meteor Fragment!" "$ORANGE"
                    msg="Meteor fragment! +30 gold"
                else
                    torches=$((torches + 1)); msg="Found abandoned torch!"
                fi
                ;;
            9) skill_points=$((skill_points + 1)); msg="Found ancient scroll! +1 Skill Point" ;;
            10) 
                status_frostbite=true
                status_turns=3
                msg="Frostbite! -3 HP for 3 turns"
                ;;
            11) 
                status_wellfed=true
                status_turns=5
                food=$((food + 2))
                msg="Found food cache! +2 food, well-fed for 5 turns"
                ;;
        esac
    fi
    
    # Aurora bonus
    if [ "$weather" = "aurora" ]; then
        score=$((score + 1))
    fi
    
    # Meteor shower bonus
    if [ "$weather" = "meteor_shower" ]; then
        score=$((score + 2))
    fi
    
    # Fur coat bonus
    if [[ "$crafted_items" =~ "fur_coat" ]]; then
        warmth=$((warmth + 1))
    fi
    
    # Track total distance
    total_distance=$((total_distance + 1))
    
    # Explorer achievement
    if [ $total_distance -ge 1000 ] && [ "$explorer" = false ]; then
        explorer=true
        achievements="${achievements} Explorer"
    fi
    
    # Survivor achievement
    if [ $day -ge 10 ] && [ "$survivor" = false ]; then
        survivor=true
        achievements="${achievements} Survivor"
    fi
    
    # Check death conditions
    if [ $hp -le 0 ]; then
        show_cursor
        clear_screen
        echo -e "${RED}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║${NC} ${BOLD}☠ YOU PERISHED IN THE TUNDRA ☠${NC} ${RED}                              ║${NC}"
        echo -e "${RED}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${RED}║${NC} Days survived: $day | Gold collected: $gold | Turns: $turn ${RED}║${NC}"
        echo -e "${RED}║${NC} Distance traveled: $total_distance${RED}                                 ║${NC}"
        echo -e "${RED}║${NC} Final Score: $score${RED}                                            ║${NC}"
        echo -e "${RED}║${NC} ${LIME}Achievements:${NC} ${WHITE}$achievements${RED}                                ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
        exit
    fi
done