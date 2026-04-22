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
REVERSE='\033[7m'
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

# Terminal handling
save_cursor() { printf '\033[s'; }
restore_cursor() { printf '\033[u'; }
hide_cursor() { printf '\033[?25l'; }
show_cursor() { printf '\033[?25h'; }
clear_screen() { printf '\033[2J\033[H'; }
play_sound() { printf '\007'; }  # Terminal bell
screen_shake() { printf '\033[5;5H'; sleep 0.05; printf '\033[H'; }

# Difficulty settings
difficulty="normal"
difficulty_multiplier=1.0
xp_multiplier=1.0
gold_multiplier=1.0

# Enhanced animations
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
    local colors=("$RED" "$ORANGE" "$YELLOW" "$GREEN" "$CYAN" "$BLUE" "$PURPLE")
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

# Animation functions
type_text() {
    local text="$1"
    local delay=${2:-0.03}
    for ((i=0; i<${#text}; i++)); do
        printf "%c" "${text:$i:1}"
        sleep $delay
    done
    printf "\n"
}

flash_screen() {
    printf "\033[?5h"
    sleep 0.1
    printf "\033[?5l"
}

pulse_text() {
    local text="$1"
    local color="$2"
    for i in {1..3}; do
        printf "\r${color}%s${NC}" "$text"
        sleep 0.2
        printf "\r${GRAY}%s${NC}" "$text"
        sleep 0.2
    done
    printf "\r${color}%s${NC}\n" "$text"
}

# Get terminal size
get_terminal_size() {
    TERM_WIDTH=${1:-80}
    TERM_HEIGHT=${2:-24}
    if command -v tput >/dev/null 2>&1; then
        TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)
        TERM_HEIGHT=$(tput lines 2>/dev/null || echo 24)
    fi
}

# Save/Load functions
SAVE_DIR="$HOME/.acolyte_saves"
mkdir -p "$SAVE_DIR" 2>/dev/null
SAVE_FILE="$SAVE_DIR/save_1.dat"
CURRENT_SAVE_SLOT=1

game_save() {
    local slot_num=${1:-$CURRENT_SAVE_SLOT}
    local save_file="$SAVE_DIR/save_${slot_num}.dat"
    cat > "$save_file" << EOF
x=$x
y=$y
hp=$hp
max_hp=$max_hp
gold=$gold
level=$level
xp=$xp
xp_needed=$xp_needed
attack=$attack
defense=$defense
turn=$turn
potions=$potions
keys=$keys
has_sword=$has_sword
has_shield=$has_shield
has_boots=$has_boots
has_amulet=$has_amulet
has_ring=$has_ring
has_helm=$has_helm
has_cape=$has_cape
has_gloves=$has_gloves
scrolls=$scrolls
bombs=$bombs
mana=$mana
max_mana=$max_mana
skill_points=$skill_points
skills_crit=$skills_crit
skills_dodge=$skills_dodge
skills_loot=$skills_loot
skills_magic=$skills_magic
skills_stealth=$skills_stealth
skills_vitality=$skills_vitality
kills=$kills
first_kill=$first_kill
treasure_hunter=$treasure_hunter
minimap_enabled=$minimap_enabled
map="$map"
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

# Game State
x=2; y=2
hp=30; max_hp=30
gold=0
level=1; xp=0; xp_needed=50
attack=5
defense=0
msg="Welcome, Acolyte! WASD/Arrows to move, 'i' inventory, 'h' help, 's' save, 'q' quit"
turn=0
kills=0

# Skill System
skill_points=0
skills_crit=0
skills_dodge=0
skills_loot=0
skills_magic=0
skills_stealth=0
skills_vitality=0

# Boss Fight
boss_defeated=false
boss_floor=0

# Minimap enabled
minimap_enabled=true

# Inventory
potions=3
keys=0
has_sword=false
has_shield=false
has_boots=false
has_amulet=false
has_ring=false
has_helm=false
has_cape=false
has_gloves=false
scrolls=0
bombs=0
mana=50
max_mana=50

# Achievements
achievements=""
first_kill=false
treasure_hunter=false
survivor=false
speed_demon=false
pacifist=false
hoarder=false

# Status effects
status_burning=false
status_frozen=false
status_poisoned=false
status_blessed=false
status_turns=0

# Map (16x16 for more space)
# # = wall, . = floor, M = monster, G = gold, H = health potion, K = key, D = door, S = sword, P = shield, B = boots, A = amulet, E = exit, ? = mystery, R = ring, L = helm
map="################ #......M..G..# #.H.K..M.....# #..D..S.P.B..# #....M..?...# #.G.H...K...M# #..M.....D..# #.D..S.P.A.R..# #....M..?...# #.G.H...K...M# #..M.....D..# #.D..S.P.L...# #....M..?..E# #.G.H...K...M# #..M.......# ################"

# Enemy types (name:attack:defense:xp:gold:special:rarity)
declare -A enemies
enemies["skeleton"]="Skeleton:5:2:10:8:none:common"
enemies["goblin"]="Goblin:3:1:5:5:thief:common"
enemies["zombie"]="Zombie:4:3:8:10:infect:common"
enemies["orc"]="Orc:8:4:20:15:berserk:uncommon"
enemies["wolf"]="Dire Wolf:6:2:12:12:pack:uncommon"
enemies["demon"]="Demon:12:6:35:30:fire:rare"
enemies["vampire"]="Vampire:10:5:25:20:lifesteal:rare"
enemies["dragon"]="Dragon:15:8:50:50:boss:legendary"
enemies["lich"]="Lich:14:7:40:35:necromancer:legendary"
enemies["wraith"]="Wraith:11:5:30:25:phase:rare"
enemies["golem"]="Golem:13:9:45:40:immune:rare"
enemies["assassin"]="Assassin:16:3:55:45:backstab:legendary"
enemies["minotaur"]="Minotaur:18:10:60:70:charge:legendary"
enemies["phoenix"]="Phoenix:20:8:70:80:rebirth:mythic"
enemies["hydra"]="Hydra:22:12:80:100:regen:mythic"

# Boss data
boss_data="Necromancer Lord:25:12:100:150:necromaster"

draw_ui() {
    clear_screen
    get_terminal_size
    
    # Animated title based on level
    local title_icon="⚔"
    if [ $level -ge 5 ]; then title_icon="🗡"
    elif [ $level -ge 10 ]; then title_icon="⚜"
    fi
    
    # Header with level-based colors
    local title_color=$YELLOW
    if [ $level -ge 5 ]; then title_color=$ORANGE
    elif [ $level -ge 10 ]; then title_color=$PURPLE
    fi
    
    # Status effects bar
    local status_line=""
    [ "$status_burning" = true ] && status_line="${status_line}${RED}🔥 Burns${NC} "
    [ "$status_frozen" = true ] && status_line="${status_line}${BLUE}❄️ Frozen${NC} "
    [ "$status_poisoned" = true ] && status_line="${status_line}${GREEN}☠ Poison${NC} "
    [ "$status_blessed" = true ] && status_line="${status_line}${YELLOW}✨ Blessed${NC} "
    
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${BOLD}${title_color}${title_icon} ASCII ACOLYTE - Enhanced Edition ${title_icon}${NC} ${CYAN}                    ║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Status:${NC} ${status_line}${CYAN}$(printf '%.0s ' $(seq 1 $((50 - ${#status_line}))))${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    
    # HP bar with visual indicator
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
    
    echo -e "${CYAN}║${NC} ${RED}❤ HP:${NC} ${hp_color}$hp/$max_hp${NC} [$hp_bar] ${CYAN}│${NC} ${YELLOW}⚔ ATK:${NC} ${WHITE}$attack${NC} ${CYAN}│${NC} ${BLUE}🛡 DEF:${NC} ${WHITE}$defense${NC} ${CYAN}│${NC} ${MAGENTA}✨ LVL:${NC} ${WHITE}$level${NC} ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${BLUE}🧪 XP:${NC} ${WHITE}$xp/$xp_needed${NC} ${CYAN}│${NC} ${GREEN}🧪 Potions:${NC} ${WHITE}$potions${NC} ${CYAN}│${NC} ${YELLOW}🗝️ Keys:${NC} ${WHITE}$keys${NC} ${CYAN}│${NC} ${RED}💀 Kills:${NC} ${WHITE}$kills${NC} ${CYAN}│${NC} ${LIME}SP:${WHITE}$skill_points ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    
    # Render Map with colors (16x16)
    for (( i=0; i<16; i++ )); do
        echo -n "${CYAN}║${NC} "
        for (( j=0; j<16; j++ )); do
            if [[ $j -eq $x && $i -eq $y ]]; then
                echo -n "${GREEN}☺${NC} "
            else
                char=${map:$((i*16 + j)):1}
                case "$char" in
                    "#") echo -n "${GRAY}█${NC} " ;;
                    ".") echo -n "· " ;;
                    "M") echo -n "${RED}M${NC} " ;;
                    "G") echo -n "${YELLOW}$${NC} " ;;
                    "H") echo -n "${GREEN}♥${NC} " ;;
                    "K") echo -n "${YELLOW}k${NC} " ;;
                    "D") echo -n "${BROWN}░${NC} " ;;
                    "E") echo -n "${CYAN}▓${NC} " ;;
                    "S") echo -n "${WHITE}†${NC} " ;;
                    "P") echo -n "${BLUE}o${NC} " ;;
                    "B") echo -n "${GREEN}B${NC} " ;;
                    "A") echo -n "${MAGENTA}A${NC} " ;;
                    "R") echo -n "${ORANGE}R${NC} " ;;
                    "L") echo -n "${TEAL}H${NC} " ;;
                    "?") echo -n "${YELLOW}?${NC} " ;;
                    *) echo -n "$char " ;;
                esac
            fi
        done
        echo -e "${CYAN}║${NC}"
    done
    
    # Equipment bar with more items
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -n "${CYAN}║${NC} ${WHITE}Equip:${NC} "
    [ "$has_sword" = true ] && echo -n "${WHITE}†${NC} " || echo -n "${GRAY}_${NC} "
    [ "$has_shield" = true ] && echo -n "${BLUE}o${NC} " || echo -n "${GRAY}_${NC} "
    [ "$has_boots" = true ] && echo -n "${GREEN}B${NC} " || echo -n "${GRAY}_${NC} "
    [ "$has_amulet" = true ] && echo -n "${MAGENTA}A${NC} " || echo -n "${GRAY}_${NC} "
    [ "$has_ring" = true ] && echo -n "${ORANGE}R${NC} " || echo -n "${GRAY}_${NC} "
    [ "$has_helm" = true ] && echo -n "${TEAL}H${NC} " || echo -n "${GRAY}_${NC} "
    [ "$has_cape" = true ] && echo -n "${PURPLE}C${NC} " || echo -n "${GRAY}_${NC} "
    [ "$has_gloves" = true ] && echo -n "${SILVER}G${NC} " || echo -n "${GRAY}_${NC} "
    echo -e "${CYAN}                                       ║${NC}"
    
    # Minimap (if enabled)
    if [ "$minimap_enabled" = true ]; then
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -n "${CYAN}║${NC} ${WHITE}Mini:${NC} "
        for ((my=0; my<4; my++)); do
            for ((mx=0; mx<8; mx++)); do
                local map_x=$((x - 4 + mx))
                local map_y=$((y - 2 + my))
                if [ $map_x -ge 0 ] && [ $map_x -lt 16 ] && [ $map_y -ge 0 ] && [ $map_y -lt 16 ]; then
                    if [ $map_x -eq $x ] && [ $map_y -eq $y ]; then
                        echo -n "${GREEN}☺${NC}"
                    else
                        local m_char=${map:$((map_y*16 + map_x)):1}
                        case "$m_char" in
                            "#") echo -n "${GRAY}█${NC}" ;;
                            "M") echo -n "${RED}M${NC}" ;;
                            "G") echo -n "${YELLOW}$${NC}" ;;
                            "E") echo -n "${CYAN}▓${NC}" ;;
                            *) echo -n "·" ;;
                        esac
                    fi
                else
                    echo -n " "
                fi
            done
            echo -n " "
        done
        echo -e "${CYAN}║${NC}"
    fi
    
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${BOLD}Log:${NC} ${WHITE}$msg${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
}

show_inventory() {
    clear_screen
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${BOLD}${YELLOW}📦 INVENTORY & SKILLS 📦${NC} ${CYAN}                                      ║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${GREEN}🧪 Potions:${NC} ${WHITE}$potions${NC} ${CYAN}│${NC} ${YELLOW}🗝️ Keys:${NC} ${WHITE}$keys${NC} ${CYAN}│${NC} ${RED}💣 Bombs:${NC} ${WHITE}$bombs${NC} ${CYAN}│${NC} ${PURPLE}📜 Scrolls:${NC} ${WHITE}$scrolls${NC} ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${BLUE}💧 Mana:${NC} ${WHITE}$mana/$max_mana${NC} ${CYAN}│${NC} ${LIME}Skill Points:${NC} ${WHITE}$skill_points${NC} ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Equipment:${NC}                                                      ${CYAN}║${NC}"
    
    # Equipment with visual icons
    local eq_sword=$([ "$has_sword" = true ] && echo -e "${GREEN}†${NC}" || echo -e "${GRAY}_${NC}")
    local eq_shield=$([ "$has_shield" = true ] && echo -e "${BLUE}o${NC}" || echo -e "${GRAY}_${NC}")
    local eq_boots=$([ "$has_boots" = true ] && echo -e "${GREEN}B${NC}" || echo -e "${GRAY}_${NC}")
    local eq_amulet=$([ "$has_amulet" = true ] && echo -e "${MAGENTA}A${NC}" || echo -e "${GRAY}_${NC}")
    local eq_ring=$([ "$has_ring" = true ] && echo -e "${ORANGE}R${NC}" || echo -e "${GRAY}_${NC}")
    local eq_helm=$([ "$has_helm" = true ] && echo -e "${TEAL}H${NC}" || echo -e "${GRAY}_${NC}")
    local eq_cape=$([ "$has_cape" = true ] && echo -e "${PURPLE}C${NC}" || echo -e "${GRAY}_${NC}")
    local eq_gloves=$([ "$has_gloves" = true ] && echo -e "${SILVER}G${NC}" || echo -e "${GRAY}_${NC}")
    
    echo -e "${CYAN}║${NC} [$eq_sword] Sword:   $([ "$has_sword" = true ] && echo -e "${GREEN}+3 ATK${NC}" || echo -e "${GRAY}Not found${NC}") ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} [$eq_shield] Shield:  $([ "$has_shield" = true ] && echo -e "${GREEN}+2 DEF, +5 HP${NC}" || echo -e "${GRAY}Not found${NC}") ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} [$eq_boots] Boots:    $([ "$has_boots" = true ] && echo -e "${GREEN}+1 DEF${NC}" || echo -e "${GRAY}Not found${NC}") ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} [$eq_amulet] Amulet:   $([ "$has_amulet" = true ] && echo -e "${GREEN}+10% XP${NC}" || echo -e "${GRAY}Not found${NC}") ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} [$eq_ring] Ring:     $([ "$has_ring" = true ] && echo -e "${GREEN}+2 ATK, +1 CRIT${NC}" || echo -e "${GRAY}Not found${NC}") ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} [$eq_helm] Helm:     $([ "$has_helm" = true ] && echo -e "${GREEN}+3 DEF${NC}" || echo -e "${GRAY}Not found${NC}") ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} [$eq_cape] Cape:     $([ "$has_cape" = true ] && echo -e "${GREEN}+5% Dodge${NC}" || echo -e "${GRAY}Not found${NC}") ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} [$eq_gloves] Gloves:  $([ "$has_gloves" = true ] && echo -e "${GREEN}+2% Crit${NC}" || echo -e "${GRAY}Not found${NC}") ${CYAN}║${NC}"
    
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Skill Tree (cost 1 SP each):${NC}                                   ${CYAN}║${NC}"
    
    # Skill tree visualization
    local crit_bar=""
    for ((i=0; i<skills_crit; i++)); do crit_bar+="█"; done
    for ((i=skills_crit; i<10; i++)); do crit_bar+="░"; done
    
    local dodge_bar=""
    for ((i=0; i<skills_dodge; i++)); do dodge_bar+="█"; done
    for ((i=skills_dodge; i<10; i++)); do dodge_bar+="░"; done
    
    local loot_bar=""
    for ((i=0; i<skills_loot; i++)); do loot_bar+="█"; done
    for ((i=skills_loot; i<10; i++)); do loot_bar+="░"; done
    
    local magic_bar=""
    for ((i=0; i<skills_magic; i++)); do magic_bar+="█"; done
    for ((i=skills_magic; i<10; i++)); do magic_bar+="░"; done
    
    local stealth_bar=""
    for ((i=0; i<skills_stealth; i++)); do stealth_bar+="█"; done
    for ((i=skills_stealth; i<10; i++)); do stealth_bar+="░"; done
    
    local vitality_bar=""
    for ((i=0; i<skills_vitality; i++)); do vitality_bar+="█"; done
    for ((i=skills_vitality; i<10; i++)); do vitality_bar+="░"; done
    
    echo -e "${CYAN}║${NC} ${WHITE}1) ⚔ Critical${NC}  [$crit_bar] ${LIME}${skills_crit*10}% crit${NC}              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}2) 🛡 Dodge${NC}     [$dodge_bar] ${LIME}${skills_dodge*5}% dodge${NC}             ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}3) 💰 Treasure${NC}  [$loot_bar] ${LIME}${skills_loot*10}% gold${NC}              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}4) ✨ Magic${NC}     [$magic_bar] ${LIME}${skills_magic*5} mana regen${NC}        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}5) 🥷 Stealth${NC}   [$stealth_bar] ${LIME}${skills_stealth*3}% avoid${NC}           ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}6) ❤ Vitality${NC}  [$vitality_bar] ${LIME}+${skills_vitality*3} max HP${NC}            ${CYAN}║${NC}"
    
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Actions:${NC} ${CYAN}p) Potion${NC} ${CYAN}b) Bomb${NC} ${CYAN}s) Save${NC} ${CYAN}l) Load${NC} ${CYAN}m) Toggle Minimap${NC} ${CYAN}q) Close${NC} ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    
    read -rsn1 inv_key
    case "$inv_key" in
        p)
            if [ $potions -gt 0 ]; then
                heal=$((RANDOM % 8 + 5))
                hp=$((hp + heal))
                [ $hp -gt $max_hp ] && hp=$max_hp
                potions=$((potions - 1))
                msg="Used potion! Healed $heal HP."
            else
                msg="No potions left!"
            fi
            ;;
        1)
            if [ $skill_points -gt 0 ]; then
                skill_points=$((skill_points - 1))
                skills_crit=$((skills_crit + 1))
                msg="Critical Strike upgraded! +10% crit chance."
            else
                msg="Not enough skill points!"
            fi
            ;;
        2)
            if [ $skill_points -gt 0 ]; then
                skill_points=$((skill_points - 1))
                skills_dodge=$((skills_dodge + 1))
                msg="Dodge upgraded! +5% dodge chance."
            else
                msg="Not enough skill points!"
            fi
            ;;
        3)
            if [ $skill_points -gt 0 ]; then
                skill_points=$((skill_points - 1))
                skills_loot=$((skills_loot + 1))
                msg="Treasure Hunter upgraded! +10% gold."
            else
                msg="Not enough skill points!"
            fi
            ;;
        4)
            if [ $skill_points -gt 0 ]; then
                skill_points=$((skill_points - 1))
                skills_magic=$((skills_magic + 1))
                msg="Magic upgraded! +5% mana regeneration."
            else
                msg="Not enough skill points!"
            fi
            ;;
        5)
            if [ $skill_points -gt 0 ]; then
                skill_points=$((skill_points - 1))
                skills_stealth=$((skills_stealth + 1))
                msg="Stealth upgraded! +3% enemy avoidance."
            else
                msg="Not enough skill points!"
            fi
            ;;
        6)
            if [ $skill_points -gt 0 ]; then
                skill_points=$((skill_points - 1))
                skills_vitality=$((skills_vitality + 1))
                max_hp=$((max_hp + 3))
                hp=$((hp + 3))
                msg="Vitality upgraded! +3 Max HP."
            else
                msg="Not enough skill points!"
            fi
            ;;
        b)
            if [ $bombs -gt 0 ]; then
                bombs=$((bombs - 1))
                # Bomb damages nearby enemies (simple implementation: heals player as effect)
                heal=$((RANDOM % 15 + 10))
                hp=$((hp + heal))
                [ $hp -gt $max_hp ] && hp=$max_hp
                msg="Bomb used! Explosion dealt massive damage! +$heal HP from adrenaline."
                flash_screen
                play_sound
            else
                msg="No bombs left!"
            fi
            ;;
        m)
            if [ "$minimap_enabled" = true ]; then
                minimap_enabled=false
                msg="Minimap disabled."
            else
                minimap_enabled=true
                msg="Minimap enabled."
            fi
            ;;
        s)
            game_save
            ;;
        l)
            game_load
            ;;
        *)
            msg="Inventory closed."
            ;;
    esac
}

show_help() {
    clear_screen
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${BOLD}${YELLOW}📖 HELP 📖${NC} ${CYAN}                                                   ║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Movement:${NC} ${CYAN}WASD or Arrow Keys${NC}                                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}i) Inventory${NC}  ${CYAN}h) Help${NC}  ${CYAN}s) Save${NC}  ${CYAN}l) Load${NC}  ${CYAN}q) Quit${NC}                ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Map Symbols:${NC}                                                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${GREEN}☺${NC} ${WHITE}You${NC}  ${CYAN}█${NC} ${WHITE}Wall${NC}  ${RED}M${NC} ${WHITE}Monster${NC}  ${YELLOW}$${NC} ${WHITE}Gold${NC}  ${GREEN}♥${NC} ${WHITE}Potion${NC}  ${YELLOW}k${NC} ${WHITE}Key${NC}            ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${BROWN}░${NC} ${WHITE}Door${NC}  ${CYAN}▓${NC} ${WHITE}Exit${NC}  ${WHITE}†${NC} ${WHITE}Sword${NC}  ${BLUE}o${NC} ${WHITE}Shield${NC}  ${GREEN}B${NC} ${WHITE}Boots${NC}  ${MAGENTA}A${NC} ${WHITE}Amulet${NC}  ${ORANGE}R${NC} ${WHITE}Ring${NC}  ${TEAL}H${NC} ${WHITE}Helm${NC}  ${YELLOW}?${NC} ${WHITE}Mystery${NC}  ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Tips:${NC}                                                          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}- Find keys to unlock doors${NC}                                      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}- Equip items for stat boosts${NC}                                   ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}- Level up by defeating monsters${NC}                                ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}- Reach the exit (▓) to win${NC}                                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${WHITE}Press any key to continue...${NC}"
    read -rsn1
}

gain_xp() {
    local amount=$1
    # Amulet bonus
    if [ "$has_amulet" = true ]; then
        amount=$((amount * 11 / 10))
    fi
    xp=$((xp + amount))
    if [ $xp -ge $xp_needed ]; then
        level=$((level + 1))
        xp=$((xp - xp_needed))
        xp_needed=$((xp_needed * 2))
        max_hp=$((max_hp + 5))
        hp=$max_hp
        attack=$((attack + 2))
        defense=$((defense + 1))
        skill_points=$((skill_points + 1))
        play_sound
        msg="${GREEN}LEVEL UP!${NC} Now level $level. HP +5, ATK +2, DEF +1, +1 SP!"
    fi
}

combat() {
    local enemy_type=$1
    local enemy_hp=$2
    local enemy_atk=$3
    local enemy_def=$4
    local enemy_xp=$5
    local enemy_gold=$6
    local enemy_special=$7
    
    msg="${RED}⚔ COMBAT! $enemy_type ⚔${NC}"
    draw_ui
    play_sound
    flash_screen
    sleep 0.3
    
    while [ $enemy_hp -gt 0 ] && [ $hp -gt 0 ]; do
        # Check dodge
        local dodge_chance=$((skills_dodge * 5))
        local dodge_roll=$((RANDOM % 100))
        local dodged=false
        if [ $dodge_roll -lt $dodge_chance ]; then
            dodged=true
        fi
        
        # Player attack (minus enemy defense)
        local player_dmg=$((attack - enemy_def + RANDOM % 4))
        [ $player_dmg -lt 1 ] && player_dmg=1
        
        # Critical hit check
        local crit_chance=$((skills_crit * 10))
        local crit_roll=$((RANDOM % 100))
        if [ $crit_roll -lt $crit_chance ]; then
            player_dmg=$((player_dmg * 2))
            msg="${LIME}CRITICAL HIT!${NC} You deal $player_dmg damage! Enemy HP: $enemy_hp"
        else
            msg="You deal $player_dmg damage! Enemy HP: $enemy_hp"
        fi
        
        enemy_hp=$((enemy_hp - player_dmg))
        draw_ui
        sleep 0.3
        
        if [ $enemy_hp -gt 0 ]; then
            # Enemy special abilities
            if [ "$enemy_special" = "lifesteal" ]; then
                local steal=$((enemy_dmg / 2))
                enemy_hp=$((enemy_hp + steal))
            elif [ "$enemy_special" = "berserk" ] && [ $enemy_hp -lt $((enemy_hp / 2)) ]; then
                enemy_atk=$((enemy_atk + 3))
            fi
            
            if [ "$dodged" = true ]; then
                msg="${GREEN}Dodged!${NC} $enemy_type's attack missed!"
            else
                # Enemy attack (minus player defense)
                local enemy_dmg=$((enemy_atk - defense + RANDOM % 2))
                [ $enemy_dmg -lt 1 ] && enemy_dmg=1
                hp=$((hp - enemy_dmg))
                msg="$enemy_type hits you for $enemy_dmg damage! Your HP: $hp"
                screen_shake
            fi
            draw_ui
            sleep 0.3
        fi
    done
    
    if [ $hp -gt 0 ]; then
        # Treasure hunter bonus
        local gold_bonus=$((enemy_gold * skills_loot / 10))
        gold=$((gold + enemy_gold + gold_bonus))
        kills=$((kills + 1))
        gain_xp $enemy_xp
        play_sound
        pulse_text "VICTORY!" "$GREEN"
        msg="${GREEN}Victory!${NC} +$enemy_gold gold (+$gold_bonus bonus), +$enemy_xp XP"
        
        # Random status effect on victory
        if [ $((RANDOM % 20)) -eq 0 ]; then
            status_blessed=true
            status_turns=5
            msg="${GREEN}Victory!${NC} +$enemy_gold gold, +$enemy_xp XP ${YELLOW}✨ BLESSED!${NC}"
        fi
    else
        flash_screen
        msg="${RED}DEFEATED!${NC} The $enemy_type was too strong..."
    fi
}

# Enhanced intro screen
show_intro() {
    clear_screen
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${BOLD}${YELLOW}⚔ ASCII ACOLYTE - Enhanced Edition ⚔${NC} ${CYAN}                         ║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}A roguelike dungeon crawler with skills, equipment, and combat${NC}       ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Controls:${NC}                                                        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}WASD/Arrows${NC} ${WHITE}- Move  ${YELLOW}i${NC} ${WHITE}- Inventory  ${YELLOW}h${NC} ${WHITE}- Help${NC}              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}s${NC} ${WHITE}- Save  ${YELLOW}l${NC} ${WHITE}- Load  ${YELLOW}q${NC} ${WHITE}- Quit${NC}                              ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Select Difficulty:${NC}                                            ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${GREEN}1) Easy${NC}   ${WHITE}- 50% more XP/Gold, enemies deal 25% less damage${NC}    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}2) Normal${NC} ${WHITE}- Standard experience${NC}                                  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${RED}3) Hard${NC}   ${WHITE}- 25% more XP/Gold, enemies deal 25% more damage${NC}     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${CRIMSON}4) Nightmare${NC} ${WHITE}- 50% more XP/Gold, enemies deal 50% more damage${NC}  ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    printf "${WHITE}Choose difficulty [1-4]: ${NC}"
    read -r diff_choice
    case $diff_choice in
        1) difficulty="easy"; difficulty_multiplier=0.75; xp_multiplier=1.5; gold_multiplier=1.5 ;;
        2) difficulty="normal"; difficulty_multiplier=1.0; xp_multiplier=1.0; gold_multiplier=1.0 ;;
        3) difficulty="hard"; difficulty_multiplier=1.25; xp_multiplier=1.25; gold_multiplier=1.25 ;;
        4) difficulty="nightmare"; difficulty_multiplier=1.5; xp_multiplier=1.5; gold_multiplier=1.5 ;;
        *) difficulty="normal"; difficulty_multiplier=1.0; xp_multiplier=1.0; gold_multiplier=1.0 ;;
    esac
    clear_screen
    typing_effect "Starting game on $difficulty difficulty..." 0.03 ${GREEN}
    sleep 1
}

# Main Game Loop
show_intro
hide_cursor
trap 'show_cursor; clear_screen; exit' INT TERM

while true; do
    draw_ui
    read -rsn1 key
    old_x=$x; old_y=$y
    ((turn++))

    case "$key" in
        w|A) ((y--)) ;;
        s|B) ((y++)) ;;
        a|D) ((x--)) ;;
        d|C) ((x++)) ;;
        i) show_inventory; continue ;;
        h) show_help; continue ;;
        s) game_save; continue ;;
        l) game_load; continue ;;
        q) show_cursor; clear_screen; exit ;;
    esac

    # Bounds check (16x16 map)
    if [ $x -lt 0 ] || [ $x -gt 15 ] || [ $y -lt 0 ] || [ $y -gt 15 ]; then
        x=$old_x; y=$old_y
        msg="You cannot go that way."
        continue
    fi

    # Collision & Logic
    pos=$((y*16 + x))
    tile=${map:$pos:1}

    if [[ "$tile" == "#" ]]; then
        x=$old_x; y=$old_y
        msg="${GRAY}You hit a wall.${NC}"
    elif [[ "$tile" == "D" ]]; then
        if [ $keys -gt 0 ]; then
            keys=$((keys - 1))
            map="${map:0:$pos}.${map:$((pos+1))}"
            msg="${GREEN}Unlocked door with key!${NC}"
        else
            x=$old_x; y=$old_y
            msg="${RED}Locked! Find a key (K).${NC}"
        fi
    elif [[ "$tile" == "M" ]]; then
        # Select random enemy based on level
        enemy_roll=$((RANDOM % 10))
        if [ $level -ge 8 ] && [ $enemy_roll -ge 8 ]; then
            enemy_data=${enemies["assassin"]}
        elif [ $level -ge 7 ] && [ $enemy_roll -ge 7 ]; then
            enemy_data=${enemies["golem"]}
        elif [ $level -ge 6 ] && [ $enemy_roll -ge 6 ]; then
            enemy_data=${enemies["wraith"]}
        elif [ $level -ge 5 ] && [ $enemy_roll -ge 5 ]; then
            enemy_data=${enemies["dragon"]}
        elif [ $level -ge 4 ] && [ $enemy_roll -ge 4 ]; then
            enemy_data=${enemies["lich"]}
        elif [ $level -ge 3 ] && [ $enemy_roll -ge 3 ]; then
            enemy_data=${enemies["demon"]}
        elif [ $level -ge 2 ] && [ $enemy_roll -ge 2 ]; then
            enemy_data=${enemies["vampire"]}
        elif [ $level -ge 2 ] && [ $enemy_roll -ge 1 ]; then
            enemy_data=${enemies["orc"]}
        else
            enemy_data=${enemies["skeleton"]}
        fi
        IFS=':' read -r enemy_name enemy_atk enemy_def enemy_xp enemy_gold enemy_special <<< "$enemy_data"
        combat "$enemy_name" $((RANDOM % 10 + 10 + level * 2)) $enemy_atk $enemy_def $enemy_xp $enemy_gold "$enemy_special"
        if [ $hp -gt 0 ]; then
            map="${map:0:$pos}.${map:$((pos+1))}"
            # First kill achievement
            if [ "$first_kill" = false ]; then
                first_kill=true
                achievements="${achievements} First Blood"
                msg="${GREEN}Achievement: First Blood!${NC}"
            fi
        fi
    elif [[ "$tile" == "G" ]]; then
        gold_amt=$((RANDOM % 20 + 10))
        gold=$((gold + gold_amt))
        map="${map:0:$pos}.${map:$((pos+1))}"
        # Treasure hunter achievement
        if [ $gold -ge 100 ] && [ "$treasure_hunter" = false ]; then
            treasure_hunter=true
            achievements="${achievements} Treasure Hunter"
            msg="${YELLOW}Achievement: Treasure Hunter!${NC} Found $gold_amt gold!"
        else
            msg="${YELLOW}Found $gold_amt gold!${NC}"
        fi
    elif [[ "$tile" == "H" ]]; then
        potions=$((potions + 1))
        map="${map:0:$pos}.${map:$((pos+1))}"
        msg="${GREEN}Found a health potion!${NC}"
    elif [[ "$tile" == "K" ]]; then
        keys=$((keys + 1))
        map="${map:0:$pos}.${map:$((pos+1))}"
        msg="${YELLOW}Found a key!${NC}"
    elif [[ "$tile" == "S" ]]; then
        has_sword=true
        attack=$((attack + 3))
        map="${map:0:$pos}.${map:$((pos+1))}"
        msg="${WHITE}Found a sword! +3 Attack!${NC}"
    elif [[ "$tile" == "P" ]]; then
        has_shield=true
        defense=$((defense + 2))
        max_hp=$((max_hp + 5))
        hp=$((hp + 5))
        map="${map:0:$pos}.${map:$((pos+1))}"
        msg="${BLUE}Found a shield! +2 DEF, +5 Max HP!${NC}"
    elif [[ "$tile" == "B" ]]; then
        has_boots=true
        defense=$((defense + 1))
        map="${map:0:$pos}.${map:$((pos+1))}"
        msg="${GREEN}Found boots! +1 Defense!${NC}"
    elif [[ "$tile" == "A" ]]; then
        has_amulet=true
        map="${map:0:$pos}.${map:$((pos+1))}"
        msg="${MAGENTA}Found an amulet! +10% XP gain!${NC}"
    elif [[ "$tile" == "R" ]]; then
        has_ring=true
        attack=$((attack + 2))
        map="${map:0:$pos}.${map:$((pos+1))}"
        msg="${ORANGE}Found a ring! +2 ATK, +1 CRIT!${NC}"
    elif [[ "$tile" == "L" ]]; then
        has_helm=true
        defense=$((defense + 3))
        map="${map:0:$pos}.${map:$((pos+1))}"
        msg="${TEAL}Found a helm! +3 DEF!${NC}"
    elif [[ "$tile" == "?" ]]; then
        # Mystery box - random reward
        mystery=$((RANDOM % 8))
        case $mystery in
            0)
                gold_amt=$((RANDOM % 30 + 20))
                gold=$((gold + gold_amt))
                msg="${YELLOW}Mystery box: $gold_amt gold!${NC}"
                ;;
            1)
                potions=$((potions + 2))
                msg="${GREEN}Mystery box: 2 potions!${NC}"
                ;;
            2)
                heal=15
                hp=$((hp + heal))
                [ $hp -gt $max_hp ] && hp=$max_hp
                msg="${GREEN}Mystery box: Healed $heal HP!${NC}"
                ;;
            3)
                attack=$((attack + 1))
                msg="${WHITE}Mystery box: +1 Attack!${NC}"
                ;;
            4)
                dmg=5
                hp=$((hp - dmg))
                msg="${RED}Mystery box was trapped! -$dmg HP${NC}"
                ;;
            5)
                bombs=$((bombs + 1))
                msg="${RED}Mystery box: 1 bomb!${NC}"
                ;;
            6)
                scrolls=$((scrolls + 1))
                msg="${PURPLE}Mystery box: 1 magic scroll!${NC}"
                ;;
            7)
                skill_points=$((skill_points + 1))
                msg="${LIME}Mystery box: +1 Skill Point!${NC}"
                ;;
        esac
        map="${map:0:$pos}.${map:$((pos+1))}"
    elif [[ "$tile" == "E" ]]; then
        msg="${CYAN}🎉 VICTORY! 🎉 You escaped the dungeon!${NC}"
        draw_ui
        echo -e "\n${GREEN}Final Stats:${NC} Level: $level | Gold: $gold | Turns: $turn"
        echo -e "${LIME}Achievements:${NC} $achievements"
        exit
    else
        msg="Exploring floor $level..."
    fi

    if [ $hp -le 0 ]; then
        show_cursor
        clear_screen
        echo -e "${RED}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║${NC} ${BOLD}☠ YOU DIED ☠${NC} ${RED}                                               ║${NC}"
        echo -e "${RED}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${RED}║${NC} ${WHITE}You fell on floor $level after $turn turns${NC}                    ${RED}║${NC}"
        echo -e "${RED}║${NC} ${YELLOW}Gold collected: $gold | Monsters slain: $kills${NC}               ${RED}║${NC}"
        echo -e "${RED}║${NC} ${LIME}Achievements:${NC} ${WHITE}$achievements${NC}                              ${RED}║${NC}"
        echo -e "${RED}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
        exit
    fi
done