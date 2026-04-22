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

combat_flash() {
    printf "\033[?5h"
    sleep 0.15
    printf "\033[?5l"
    sleep 0.05
}

# Animation functions
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

draw_progress_bar() {
    local current=$1
    local max=$2
    local width=${3:-20}
    local filled=$(( (current * width) / max ))
    local empty=$(( width - filled ))
    printf "["
    for ((i=0; i<filled; i++)); do printf "█"; done
    for ((i=0; i<empty; i++)); do printf "░"; done
    printf "] %d/%d" "$current" "$max"
}

# Save/Load functions
SAVE_DIR="$HOME/.ashen_king_saves"
mkdir -p "$SAVE_DIR" 2>/dev/null
SAVE_FILE="$SAVE_DIR/save_1.dat"
CURRENT_SAVE_SLOT=1

game_save() {
    local slot_num=${1:-$CURRENT_SAVE_SLOT}
    local save_file="$SAVE_DIR/save_${slot_num}.dat"
    cat > "$save_file" << EOF
HP=$HP
MAX_HP=$MAX_HP
ATTACK=$ATTACK
DEFENSE=$DEFENSE
POTIONS=$POTIONS
FLOOR=$FLOOR
GOLD=$GOLD
XP=$XP
LEVEL=$LEVEL
XP_NEEDED=$XP_NEEDED
CLASS="$CLASS"
SKILL_POINTS=$SKILL_POINTS
HAS_ARMOR=$HAS_ARMOR
HAS_WEAPON=$HAS_WEAPON
HAS_RING=$HAS_RING
HAS_AMULET=$HAS_AMULET
HAS_CROWN=$HAS_CROWN
HAS_BOOTS=$HAS_BOOTS
HAS_GLOVES=$HAS_GLOVES
HAS_CAPE=$HAS_CAPE
HAS_HELM=$HAS_HELM
PERK_STRENGTH=$PERK_STRENGTH
PERK_VITALITY=$PERK_VITALITY
PERK_AGILITY=$PERK_AGILITY
PERK_MAGIC=$PERK_MAGIC
PERK_LUCK=$PERK_LUCK
PERK_WISDOM=$PERK_WISDOM
PERK_FORTITUDE=$PERK_FORTITUDE
ACHIEVEMENTS="$ACHIEVEMENTS"
BOSS_KILLS=$BOSS_KILLS
MANA=$MANA
MAX_MANA=$MAX_MANA
RAGE=$RAGE
MAX_RAGE=$MAX_RAGE
EOF
    echo -e "${GREEN}Game saved!${NC}"
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

# --- Game State Variables ---
HP=25
MAX_HP=25
ATTACK=6
DEFENSE=2
POTIONS=3
FLOOR=1
MAX_FLOORS=25
GOLD=0
XP=0
LEVEL=1
XP_NEEDED=50
KILLS=0

# Character Class
CLASS="Warrior"
SKILL_POINTS=0

# Perk System
PERK_STRENGTH=0
PERK_VITALITY=0
PERK_AGILITY=0
PERK_MAGIC=0
PERK_LUCK=0
PERK_WISDOM=0
PERK_FORTITUDE=0

# Equipment
HAS_ARMOR=false
HAS_WEAPON=false
HAS_RING=false
HAS_AMULET=false
HAS_CROWN=false
HAS_BOOTS=false
HAS_GLOVES=false
HAS_CAPE=false
HAS_HELM=false

# Special abilities
COOLDOWN=0
MAX_COOLDOWN=3
MANA=50
MAX_MANA=50
RAGE=0
MAX_RAGE=100

# Achievements
ACHIEVEMENTS=""
BOSS_KILLS=0
FIRST_BOSS=false
SURVIVOR=false
SLAYER=false
PERFECTIONIST=false
MERCHANT_KING=false
UNSTOPPABLE=false
BOSS_PHASE=0
RICH=false
SPEEDSTER=false
PERFECTIONIST=false

# Status effects
STATUS_BLESSED=false
STATUS_CURSED=false
STATUS_RAGED=false
STATUS_TURNS=0

# --- UI Functions ---
draw_header() {
    clear_screen
    local floor_color=$WHITE
    if [ $FLOOR -ge 10 ]; then floor_color=$ORANGE
    elif [ $FLOOR -ge 20 ]; then floor_color=$RED
    fi
    
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${BOLD}${YELLOW}☠ THE CRYPT OF THE ASHEN KING - Enhanced ☠${NC} ${CYAN}              ║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${floor_color}Floor $FLOOR of $MAX_FLOORS${NC} ${CYAN}$(printf '%.0s' $(seq 1 $((40 - ${#FLOOR} - ${#MAX_FLOORS}))))${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
}

draw_status() {
    # HP bar with visual indicator
    local hp_percent=$((HP * 100 / MAX_HP))
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
    
    # Status effects bar
    local status_line=""
    [ "$STATUS_BLESSED" = true ] && status_line="${status_line}${YELLOW}✨ Blessed${NC} "
    [ "$STATUS_CURSED" = true ] && status_line="${status_line}${PURPLE}☠ Cursed${NC} "
    [ "$STATUS_RAGED" = true ] && status_line="${status_line}${RED}🔥 Raged${NC} "
    
    echo -e "${CYAN}║${NC} ${RED}❤ HP:${NC} ${hp_color}$HP/$MAX_HP${NC} [$hp_bar] ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}⚔ ATK:${NC} ${WHITE}$ATTACK${NC} ${CYAN}│${NC} ${BLUE}🛡 DEF:${NC} ${WHITE}$DEFENSE${NC} ${CYAN}│${NC} ${MAGENTA}✨ LVL:${NC} ${WHITE}$LEVEL${NC} ${CYAN}│${NC} ${LIME}SP:${WHITE}$SKILL_POINTS ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}🪙 Gold:${NC} ${WHITE}$GOLD${NC} ${CYAN}│${NC} ${BLUE}🧪 XP:${NC} ${WHITE}$XP/$XP_NEEDED${NC} ${CYAN}│${NC} ${GREEN}🧪 Potions:${NC} ${WHITE}$POTIONS${NC} ${CYAN}│${NC} ${GRAY}$CLASS${NC} ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${RED}💀 Kills:${NC} ${WHITE}$KILLS${NC} ${CYAN}│${NC} ${MAGENTA}⏱ CD:${NC} ${WHITE}$COOLDOWN/$MAX_COOLDOWN${NC} ${CYAN}│${NC} ${ORANGE}Boss:${WHITE}$BOSS_KILLS ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Status:${NC} ${status_line}${CYAN}$(printf '%.0s ' $(seq 1 $((45 - ${#status_line}))))${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
}

draw_footer() {
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
}

draw_box() {
    local text="$1"
    local len=${#text}
    local padding=$(( (60 - len) / 2 ))
    echo -e "${CYAN}║${NC}$(printf ' %.0s' $(seq 1 $padding))${BOLD}${WHITE}$text${NC}$(printf ' %.0s' $(seq 1 $((60 - padding - len))))${CYAN}║${NC}"
}

show_help() {
    draw_header
    draw_box "📖 HELP 📖"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Class Abilities:${NC}                                                ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Warrior: Heavy Strike (50% hit, 2x DMG)${NC}                          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Rogue: Evasion Roll (50% dodge chance)${NC}                         ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Mage: Fireball (Cost: 1 Potion, High DMG)${NC}                      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Paladin: Holy Smite (Cost: 1 Potion, High Holy DMG)${NC}            ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Perk Tree (cost 1 SP):${NC}                                         ${CYAN}║${NC}"
    
    # Perk visualization bars
    local str_bar=""
    for ((i=0; i<PERK_STRENGTH; i++)); do str_bar+="█"; done
    for ((i=PERK_STRENGTH; i<10; i++)); do str_bar+="░"; done
    
    local vit_bar=""
    for ((i=0; i<PERK_VITALITY; i++)); do vit_bar+="█"; done
    for ((i=PERK_VITALITY; i<10; i++)); do vit_bar+="░"; done
    
    local agi_bar=""
    for ((i=0; i<PERK_AGILITY; i++)); do agi_bar+="█"; done
    for ((i=PERK_AGILITY; i<10; i++)); do agi_bar+="░"; done
    
    local mag_bar=""
    for ((i=0; i<PERK_MAGIC; i++)); do mag_bar+="█"; done
    for ((i=PERK_MAGIC; i<10; i++)); do mag_bar+="░"; done
    
    echo -e "${CYAN}║${NC} ${WHITE}1) 💪 Strength${NC}  [$str_bar] ${LIME}+${PERK_STRENGTH*2} ATK${NC}              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}2) ❤️ Vitality${NC}  [$vit_bar] ${LIME}+${PERK_VITALITY*5} Max HP${NC}             ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}3) 🏃 Agility${NC}   [$agi_bar] ${LIME}+${PERK_AGILITY} DEF, +${PERK_AGILITY*5}% dodge${NC}    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}4) ✨ Magic${NC}      [$mag_bar] ${LIME}+${PERK_MAGIC*2} ATK, +${PERK_MAGIC} CD${NC}        ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Tips:${NC}                                                        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}- Special abilities have cooldowns${NC}                            ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}- Merchants appear randomly to sell items${NC}                       ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}- Shrines can heal or bless (with risk)${NC}                         ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}- Boss encounters on floors 10, 15, 20, 25${NC}                     ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Press any key to continue...${NC}                                   ${CYAN}║${NC}"
    draw_footer
    read -rsn1
}

# --- Character Creation ---
character_creation() {
    draw_header
    draw_box "Choose Your Class"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}1) ⚔️ Warrior${NC}   ${RED}HP:30${NC} ${GREEN}ATK:6${NC} ${BLUE}DEF:4${NC}  - Heavy Strike ability        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}2) 🗡️ Rogue${NC}      ${RED}HP:20${NC} ${GREEN}ATK:9${NC} ${BLUE}DEF:1${NC}  - Evasion Roll ability        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}3) 🔮 Mage${NC}       ${RED}HP:18${NC} ${GREEN}ATK:10${NC} ${BLUE}DEF:1${NC}  - Fireball ability (cost pot)  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}4) 🛡️ Paladin${NC}   ${RED}HP:35${NC} ${GREEN}ATK:5${NC} ${BLUE}DEF:5${NC}  - Holy Smite ability (cost pot)${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}5) 💀 Necromancer${NC} ${RED}HP:22${NC} ${GREEN}ATK:11${NC} ${BLUE}DEF:2${NC}  - Drain Life ability (cost pot)${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Enter your choice [1-5]:${NC}                                    ${CYAN}║${NC}"
    draw_footer
    
    read -p " " class_choice
    
    case $class_choice in
        1)
            CLASS="Warrior"
            HP=30; MAX_HP=30
            ATTACK=6; DEFENSE=4
            ;;
        2)
            CLASS="Rogue"
            HP=20; MAX_HP=20
            ATTACK=9; DEFENSE=1
            ;;
        3)
            CLASS="Mage"
            HP=18; MAX_HP=18
            ATTACK=10; DEFENSE=1
            POTIONS=4
            ;;
        4)
            CLASS="Paladin"
            HP=35; MAX_HP=35
            ATTACK=5; DEFENSE=5
            ;;
        5)
            CLASS="Necromancer"
            HP=22; MAX_HP=22
            ATTACK=11; DEFENSE=2
            POTIONS=3
            ;;
        *)
            CLASS="Warrior"
            HP=30; MAX_HP=30
            ATTACK=6; DEFENSE=4
            ;;
    esac
}

# --- Combat System ---
combat() {
    local enemy_name=$1
    local enemy_hp=$2
    local enemy_atk=$3
    local enemy_def=$4
    local enemy_xp=$5
    local enemy_gold=$6
    local enemy_special=${7:-none}
    local boss_phase=0
    local is_boss=false
    [[ "$enemy_special" != "none" ]] && is_boss=true
    
    echo -e "${CYAN}║${NC} ${BOLD}${RED}⚔ COMBAT: $enemy_name ⚔${NC}                                  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Enemy HP: $enemy_hp | ATK: $enemy_atk | DEF: $enemy_def${NC}            ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Your HP: $HP/$MAX_HP | ATK: $ATTACK | DEF: $DEFENSE${NC}                   ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    play_sound
    flash_screen
    sleep 0.2
    echo -e "${CYAN}║${NC} ${WHITE}1) Attack${NC}                                                   ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}2) Use Potion${NC} (${POTIONS} left)${NC}                                    ${CYAN}║${NC}"
    
    local special_available=false
    if [ "$CLASS" = "Rogue" ]; then
        echo -e "${CYAN}║${NC} ${WHITE}3) Evasion Roll (50% dodge)${NC}                              ${CYAN}║${NC}"
        special_available=true
    elif [ "$CLASS" = "Mage" ]; then
        echo -e "${CYAN}║${NC} ${WHITE}3) Fireball (Cost: 1 Potion, High DMG)${NC}                   ${CYAN}║${NC}"
        special_available=true
    elif [ "$CLASS" = "Warrior" ]; then
        echo -e "${CYAN}║${NC} ${WHITE}3) Heavy Strike (50% hit, 2x DMG)${NC}                      ${CYAN}║${NC}"
        special_available=true
    elif [ "$CLASS" = "Paladin" ]; then
        echo -e "${CYAN}║${NC} ${WHITE}3) Holy Smite (Cost: 1 Potion, High Holy DMG)${NC}            ${CYAN}║${NC}"
        special_available=true
    elif [ "$CLASS" = "Necromancer" ]; then
        echo -e "${CYAN}║${NC} ${WHITE}3) Drain Life (Cost: 1 Potion, DMG + Heal)${NC}              ${CYAN}║${NC}"
        special_available=true
    fi
    
    if [ $COOLDOWN -gt 0 ]; then
        echo -e "${CYAN}║${NC} ${GRAY}Special on cooldown ($COOLDOWN turns left)${NC}                   ${CYAN}║${NC}"
    fi
    
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Choose action:${NC}                                             ${CYAN}║${NC}"
    draw_footer
    
    read -p " " combat_choice
    
    case $combat_choice in
        1)
            # Normal attack with perk bonus
            local perk_bonus=$((PERK_STRENGTH * 2))
            player_dmg=$((ATTACK - enemy_def + perk_bonus + RANDOM % 4))
            [ $player_dmg -lt 1 ] && player_dmg=1
            enemy_hp=$((enemy_hp - player_dmg))
            echo -e "${CYAN}║${NC} ${GREEN}You deal $player_dmg damage!${NC}                                   ${CYAN}║${NC}"
            ;;
        2)
            if [ $POTIONS -gt 0 ]; then
                heal=$((RANDOM % 8 + 7))
                HP=$((HP + heal))
                [ $HP -gt $MAX_HP ] && HP=$MAX_HP
                POTIONS=$((POTIONS - 1))
                echo -e "${CYAN}║${NC} ${GREEN}Healed $heal HP!${NC}                                            ${CYAN}║${NC}"
            else
                echo -e "${CYAN}║${NC} ${RED}No potions left!${NC}                                           ${CYAN}║${NC}"
            fi
            ;;
        3)
            if [ $COOLDOWN -gt 0 ]; then
                echo -e "${CYAN}║${NC} ${RED}Ability on cooldown!${NC}                                     ${CYAN}║${NC}"
            elif [ "$CLASS" = "Rogue" ]; then
                COOLDOWN=$MAX_COOLDOWN
                dodge_roll=$((RANDOM % 2))
                if [ $dodge_roll -eq 1 ]; then
                    echo -e "${CYAN}║${NC} ${GREEN}Dodged the attack!${NC}                                        ${CYAN}║${NC}"
                    enemy_hp=0
                else
                    echo -e "${CYAN}║${NC} ${RED}Evasion failed!${NC}                                           ${CYAN}║${NC}"
                fi
            elif [ "$CLASS" = "Mage" ]; then
                if [ $POTIONS -gt 0 ]; then
                    COOLDOWN=$MAX_COOLDOWN
                    POTIONS=$((POTIONS - 1))
                    fireball_dmg=$((ATTACK * 2 + RANDOM % 6))
                    enemy_hp=$((enemy_hp - fireball_dmg))
                    echo -e "${CYAN}║${NC} ${MAGENTA}Fireball deals $fireball_dmg damage!${NC}                          ${CYAN}║${NC}"
                else
                    echo -e "${CYAN}║${NC} ${RED}No potions for magic!${NC}                                      ${CYAN}║${NC}"
                fi
            elif [ "$CLASS" = "Warrior" ]; then
                COOLDOWN=$MAX_COOLDOWN
                hit_roll=$((RANDOM % 2))
                if [ $hit_roll -eq 1 ]; then
                    heavy_dmg=$((ATTACK * 2))
                    enemy_hp=$((enemy_hp - heavy_dmg))
                    echo -e "${CYAN}║${NC} ${GREEN}Heavy strike! $heavy_dmg damage!${NC}                          ${CYAN}║${NC}"
                else
                    echo -e "${CYAN}║${NC} ${RED}Heavy strike missed!${NC}                                      ${CYAN}║${NC}"
                fi
            elif [ "$CLASS" = "Paladin" ]; then
                if [ $POTIONS -gt 0 ]; then
                    COOLDOWN=$MAX_COOLDOWN
                    POTIONS=$((POTIONS - 1))
                    holy_dmg=$((ATTACK * 2 + RANDOM % 8))
                    enemy_hp=$((enemy_hp - holy_dmg))
                    echo -e "${CYAN}║${NC} ${YELLOW}Holy Smite deals $holy_dmg damage!${NC}                        ${CYAN}║${NC}"
                else
                    echo -e "${CYAN}║${NC} ${RED}No potions for holy magic!${NC}                                ${CYAN}║${NC}"
                fi
            elif [ "$CLASS" = "Necromancer" ]; then
                if [ $POTIONS -gt 0 ]; then
                    COOLDOWN=$MAX_COOLDOWN
                    POTIONS=$((POTIONS - 1))
                    drain_dmg=$((ATTACK * 2 + RANDOM % 6))
                    enemy_hp=$((enemy_hp - drain_dmg))
                    HP=$((HP + drain_dmg / 2))
                    [ $HP -gt $MAX_HP ] && HP=$MAX_HP
                    echo -e "${CYAN}║${NC} ${PURPLE}Drain Life deals $drain_dmg damage! Healed $((drain_dmg / 2))${NC}  ${CYAN}║${NC}"
                else
                    echo -e "${CYAN}║${NC} ${RED}No potions for dark magic!${NC}                               ${CYAN}║${NC}"
                fi
            fi
            ;;
    esac
    
    # Enemy attacks if still alive
    if [ $enemy_hp -gt 0 ]; then
        local dodge_chance=$((PERK_AGILITY * 5))
        local dodge_roll=$((RANDOM % 100))
        
        # Boss special abilities
        if [ "$is_boss" = true ]; then
            # Boss phase triggers at 50% and 25% HP
            local original_hp=$((enemy_hp + $(echo "$enemy_hp $enemy_xp" | awk '{print $2}')))
            local hp_percent=$((enemy_hp * 100 / original_hp))
            
            if [ $hp_percent -lt 50 ] && [ $boss_phase -eq 0 ]; then
                boss_phase=1
                enemy_atk=$((enemy_atk + 5))
                echo -e "${CYAN}║${NC} ${CRIMSON}$enemy_name ENRAGES! Attack increased!${NC}                ${CYAN}║${NC}"
                combat_flash
            elif [ $hp_percent -lt 25 ] && [ $boss_phase -eq 1 ]; then
                boss_phase=2
                enemy_def=$((enemy_def + 3))
                echo -e "${CYAN}║${NC} ${CRIMSON}$enemy_name enters FINAL PHASE! Defense increased!${NC}       ${CYAN}║${NC}"
                combat_flash
            fi
            
            # Boss-specific abilities
            case "$enemy_special" in
                "necromancer")
                    if [ $((RANDOM % 5)) -eq 0 ]; then
                        enemy_hp=$((enemy_hp + 5))
                        echo -e "${CYAN}║${NC} ${PURPLE}$enemy_name drains life! +5 HP${NC}                         ${CYAN}║${NC}"
                    fi
                    ;;
                "fire_breath")
                    if [ $((RANDOM % 4)) -eq 0 ]; then
                        local burn_dmg=$((enemy_atk / 2))
                        HP=$((HP - burn_dmg))
                        echo -e "${CYAN}║${NC} ${ORANGE}$enemy_name breathes fire! -$burn_dmg HP${NC}                 ${CYAN}║${NC}"
                    fi
                    ;;
                "dark_aura")
                    if [ $((RANDOM % 6)) -eq 0 ]; then
                        STATUS_CURSED=true
                        STATUS_TURNS=3
                        echo -e "${CYAN}║${NC} ${PURPLE}$enemy_name curses you! -10% ATK${NC}                     ${CYAN}║${NC}"
                    fi
                    ;;
                "ashen_curse")
                    if [ $((RANDOM % 5)) -eq 0 ]; then
                        local ashen_dmg=$((RANDOM % 10 + 5))
                        HP=$((HP - ashen_dmg))
                        echo -e "${CYAN}║${NC} ${GRAY}$enemy_name's ashen curse deals $ashen_dmg damage!${NC}        ${CYAN}║${NC}"
                    fi
                    ;;
            esac
        fi
        
        if [ $dodge_roll -lt $dodge_chance ]; then
            echo -e "${CYAN}║${NC} ${GREEN}Dodged!${NC} $enemy_name's attack missed!                          ${CYAN}║${NC}"
        else
            actual_dmg=$((enemy_atk - DEFENSE))
            [ $actual_dmg -lt 1 ] && actual_dmg=1
            HP=$((HP - actual_dmg))
            echo -e "${CYAN}║${NC} ${RED}$enemy_name hits for $actual_dmg damage!${NC}                          ${CYAN}║${NC}"
            screen_shake
        fi
    fi
    
    # Reduce cooldown
    [ $COOLDOWN -gt 0 ] && COOLDOWN=$((COOLDOWN - 1))
    
    draw_footer
    sleep 1
    
    if [ $enemy_hp -le 0 ]; then
        GOLD=$((GOLD + enemy_gold))
        XP=$((XP + enemy_xp))
        KILLS=$((KILLS + 1))
        play_sound
        pulse_text "VICTORY!" "$GREEN"
        echo -e "${CYAN}║${NC} ${GREEN}VICTORY! +$enemy_gold gold, +$enemy_xp XP${NC}                    ${CYAN}║${NC}"
        
        # Random status effect on victory
        if [ $((RANDOM % 15)) -eq 0 ]; then
            STATUS_BLESSED=true
            STATUS_TURNS=3
            echo -e "${CYAN}║${NC} ${YELLOW}✨ BLESSED by victory!${NC}                                    ${CYAN}║${NC}"
        fi
        
        check_levelup
        return 0
    else
        return 1
    fi
}

check_levelup() {
    if [ $XP -ge $XP_NEEDED ]; then
        LEVEL=$((LEVEL + 1))
        XP=$((XP - XP_NEEDED))
        XP_NEEDED=$((XP_NEEDED * 2))
        MAX_HP=$((MAX_HP + 5))
        HP=$MAX_HP
        ATTACK=$((ATTACK + 2))
        DEFENSE=$((DEFENSE + 1))
        SKILL_POINTS=$((SKILL_POINTS + 1))
        play_sound
        echo -e "${CYAN}║${NC} ${BOLD}${YELLOW}LEVEL UP! Now level $LEVEL${NC}                               ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${GREEN}HP +5, ATK +2, DEF +1, Skill Point +1${NC}                      ${CYAN}║${NC}"
        sleep 1
    fi
}

# --- Encounter Types ---
encounter_monster() {
    local monsters=("Skeleton:15:2:10:15" "Zombie:20:3:15:20" "Ghost:12:4:20:25" "Wraith:25:5:30:35" "Lich:35:7:50:50" "Vampire:30:6:40:45" "Demon:40:8:60:60" "Dragon:50:10:80:100" "Golem:45:12:55:70" "Assassin:35:3:60:80")
    local monster_idx=$((RANDOM % ${#monsters[@]}))
    
    # Scale monster difficulty with floor
    if [ $FLOOR -gt 5 ]; then
        monster_idx=$((monster_idx + 1))
    fi
    if [ $FLOOR -gt 10 ]; then
        monster_idx=$((monster_idx + 1))
    fi
    if [ $FLOOR -gt 15 ]; then
        monster_idx=$((monster_idx + 1))
    fi
    if [ $FLOOR -gt 20 ]; then
        monster_idx=$((monster_idx + 1))
    fi
    [ $monster_idx -ge ${#monsters[@]} ] && monster_idx=$((${#monsters[@]} - 1))
    
    IFS=':' read -r name hp atk def xp gold <<< "${monsters[$monster_idx]}"
    
    draw_header
    draw_status
    echo -e "${CYAN}║${NC} ${RED}A $name blocks your path!${NC}                                 ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    
    combat "$name" $hp $atk $def $xp $gold
}

encounter_trap() {
    draw_header
    draw_status
    echo -e "${CYAN}║${NC} ${YELLOW}You trigger a trap!${NC}                                          ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}1) Quick Reflexes (D20 check)${NC}                               ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}2) Endure the damage${NC}                                       ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Choose:${NC}                                                    ${CYAN}║${NC}"
    draw_footer
    
    read -p " " trap_choice
    
    if [ "$trap_choice" = "1" ]; then
        roll=$((RANDOM % 20 + 1))
        if [ "$CLASS" = "Rogue" ]; then
            roll=$((roll + 3))
        fi
        if [ $roll -ge 12 ]; then
            echo -e "${CYAN}║${NC} ${GREEN}You dodge the trap!${NC}                                         ${CYAN}║${NC}"
        else
            dmg=$((RANDOM % 8 + 3))
            HP=$((HP - dmg))
            echo -e "${CYAN}║${NC} ${RED}Trap hits! -$dmg HP${NC}                                        ${CYAN}║${NC}"
        fi
    else
        dmg=$((RANDOM % 6 + 2))
        HP=$((HP - dmg))
        echo -e "${CYAN}║${NC} ${RED}You take $dmg damage${NC}                                        ${CYAN}║${NC}"
    fi
    draw_footer
    sleep 1
}

encounter_loot() {
    draw_header
    draw_status
    echo -e "${CYAN}║${NC} ${YELLOW}You find a treasure chest!${NC}                                  ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════╣${NC}"
    
    local loot_type=$((RANDOM % 5))
    case $loot_type in
        0)
            local gold_amt=$((RANDOM % 30 + 20))
            GOLD=$((GOLD + gold_amt))
            echo -e "${CYAN}║${NC} ${YELLOW}Gold coins! +$gold_amt${NC}                                        ${CYAN}║${NC}"
            ;;
        1)
            POTIONS=$((POTIONS + 1))
            echo -e "${CYAN}║${NC} ${GREEN}A healing potion!${NC}                                          ${CYAN}║${NC}"
            ;;
        2)
            ATTACK=$((ATTACK + 1))
            echo -e "${CYAN}║${NC} ${WHITE}A sharpening stone! ATK +1${NC}                               ${CYAN}║${NC}"
            ;;
        3)
            MAX_HP=$((MAX_HP + 5))
            HP=$((HP + 5))
            echo -e "${CYAN}║${NC} ${GREEN}An amulet of vitality! Max HP +5${NC}                         ${CYAN}║${NC}"
            ;;
        4)
            DEFENSE=$((DEFENSE + 1))
            echo -e "${CYAN}║${NC} ${BLUE}A ring of protection! DEF +1${NC}                              ${CYAN}║${NC}"
            ;;
    esac
    draw_footer
    sleep 1
}

encounter_shrine() {
    draw_header
    draw_status
    echo -e "${CYAN}║${NC} ${MAGENTA}An ancient shrine stands before you...${NC}                       ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}1) Pray for healing${NC}                                         ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}2) Pray for blessing (risk)${NC}                                  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}3) Ignore it${NC}                                                 ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Choose:${NC}                                                    ${CYAN}║${NC}"
    draw_footer
    
    read -p " " shrine_choice
    
    case $shrine_choice in
        1)
            heal=$((RANDOM % 10 + 10))
            HP=$((HP + heal))
            [ $HP -gt $MAX_HP ] && HP=$MAX_HP
            echo -e "${CYAN}║${NC} ${GREEN}The shrine heals you for $heal HP!${NC}                           ${CYAN}║${NC}"
            ;;
        2)
            roll=$((RANDOM % 20 + 1))
            if [ $roll -ge 10 ]; then
                ATTACK=$((ATTACK + 2))
                echo -e "${CYAN}║${NC} ${GREEN}Blessed! ATK +2${NC}                                         ${CYAN}║${NC}"
            else
                HP=$((HP - 5))
                echo -e "${CYAN}║${NC} ${RED}The shrine rejects you! -5 HP${NC}                              ${CYAN}║${NC}"
            fi
            ;;
        *)
            echo -e "${CYAN}║${NC} ${GRAY}You leave the shrine undisturbed.${NC}                            ${CYAN}║${NC}"
            ;;
    esac
    draw_footer
    sleep 1
}

encounter_merchant() {
    draw_header
    draw_status
    echo -e "${CYAN}║${NC} ${YELLOW}A wandering merchant appears!${NC}                                ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}1) Buy Potion (20 gold)${NC}                                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}2) Buy Weapon Upgrade (50 gold, ATK +3)${NC}                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}3) Buy Armor Upgrade (40 gold, DEF +2)${NC}                      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}4) Buy Ring of Power (60 gold, ATK +2, DEF +1)${NC}              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}5) Buy Amulet of Wisdom (70 gold, +20% XP)${NC}                   ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}6) Leave${NC}                                                   ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Your Gold: $GOLD${NC}                                             ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Choose:${NC}                                                    ${CYAN}║${NC}"
    draw_footer
    
    read -p " " shop_choice
    
    case $shop_choice in
        1)
            if [ $GOLD -ge 20 ]; then
                GOLD=$((GOLD - 20))
                POTIONS=$((POTIONS + 1))
                echo -e "${CYAN}║${NC} ${GREEN}Potion purchased!${NC}                                          ${CYAN}║${NC}"
            else
                echo -e "${CYAN}║${NC} ${RED}Not enough gold!${NC}                                           ${CYAN}║${NC}"
            fi
            ;;
        2)
            if [ $GOLD -ge 50 ] && [ "$HAS_WEAPON" = false ]; then
                GOLD=$((GOLD - 50))
                ATTACK=$((ATTACK + 3))
                HAS_WEAPON=true
                echo -e "${CYAN}║${NC} ${GREEN}Weapon upgraded! ATK +3${NC}                                  ${CYAN}║${NC}"
            elif [ "$HAS_WEAPON" = true ]; then
                echo -e "${CYAN}║${NC} ${YELLOW}You already have a weapon!${NC}                                ${CYAN}║${NC}"
            else
                echo -e "${CYAN}║${NC} ${RED}Not enough gold!${NC}                                           ${CYAN}║${NC}"
            fi
            ;;
        3)
            if [ $GOLD -ge 40 ] && [ "$HAS_ARMOR" = false ]; then
                GOLD=$((GOLD - 40))
                DEFENSE=$((DEFENSE + 2))
                HAS_ARMOR=true
                echo -e "${CYAN}║${NC} ${GREEN}Armor upgraded! DEF +2${NC}                                   ${CYAN}║${NC}"
            elif [ "$HAS_ARMOR" = true ]; then
                echo -e "${CYAN}║${NC} ${YELLOW}You already have armor!${NC}                                   ${CYAN}║${NC}"
            else
                echo -e "${CYAN}║${NC} ${RED}Not enough gold!${NC}                                           ${CYAN}║${NC}"
            fi
            ;;
        4)
            if [ $GOLD -ge 60 ] && [ "$HAS_RING" = false ]; then
                GOLD=$((GOLD - 60))
                ATTACK=$((ATTACK + 2))
                DEFENSE=$((DEFENSE + 1))
                HAS_RING=true
                echo -e "${CYAN}║${NC} ${GREEN}Ring purchased! ATK +2, DEF +1${NC}                        ${CYAN}║${NC}"
            elif [ "$HAS_RING" = true ]; then
                echo -e "${CYAN}║${NC} ${YELLOW}You already have a ring!${NC}                                 ${CYAN}║${NC}"
            else
                echo -e "${CYAN}║${NC} ${RED}Not enough gold!${NC}                                           ${CYAN}║${NC}"
            fi
            ;;
        5)
            if [ $GOLD -ge 70 ] && [ "$HAS_AMULET" = false ]; then
                GOLD=$((GOLD - 70))
                HAS_AMULET=true
                echo -e "${CYAN}║${NC} ${GREEN}Amulet purchased! +20% XP gain${NC}                        ${CYAN}║${NC}"
            elif [ "$HAS_AMULET" = true ]; then
                echo -e "${CYAN}║${NC} ${YELLOW}You already have an amulet!${NC}                             ${CYAN}║${NC}"
            else
                echo -e "${CYAN}║${NC} ${RED}Not enough gold!${NC}                                           ${CYAN}║${NC}"
            fi
            ;;
    esac
    draw_footer
    sleep 1
}

# --- Rest Phase ---
rest_phase() {
    draw_header
    draw_status
    echo -e "${CYAN}║${NC} ${GREEN}A moment of respite...${NC}                                       ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════╣${NC}"
    
    if [ $POTIONS -gt 0 ]; then
        echo -e "${CYAN}║${NC} ${WHITE}Drink a potion? [y/N]${NC}                                       ${CYAN}║${NC}"
        draw_footer
        read -p " " pot_choice
        if [ "$pot_choice" = "y" ] || [ "$pot_choice" = "Y" ]; then
            heal=$((RANDOM % 8 + 7))
            HP=$((HP + heal))
            [ $HP -gt $MAX_HP ] && HP=$MAX_HP
            POTIONS=$((POTIONS - 1))
            echo -e "${CYAN}║${NC} ${GREEN}Healed $heal HP${NC}                                             ${CYAN}║${NC}"
            draw_footer
            sleep 1
        fi
    fi
}

# Enhanced intro screen
show_intro() {
    clear_screen
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${BOLD}${YELLOW}👑 ASHEN KING - Enhanced Edition 👑${NC} ${CYAN}                           ║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}A dungeon crawler with classes, perks, and epic boss fights${NC}         ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}Controls:${NC}                                                        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}1-7${NC} ${WHITE}- Choose action in menus${NC}                                   ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}s${NC} ${WHITE}- Save  ${YELLOW}l${NC} ${WHITE}- Load  ${YELLOW}h${NC} ${WHITE}- Help${NC}                              ${CYAN}║${NC}"
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

# --- Main Game Loop ---
hide_cursor
trap 'show_cursor; clear_screen; exit' INT TERM

show_intro

echo -e "${CYAN}Press 's' to load saved game, or any other key for new game...${NC}"
read -rsn1 start_choice
if [ "$start_choice" = "s" ]; then
    game_load
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Loaded successfully! Press any key to continue...${NC}"
        read -rsn1
    else
        character_creation
    fi
else
    character_creation
fi

while [ "$HP" -gt 0 ] && [ "$FLOOR" -le $MAX_FLOORS ]; do
    ENCOUNTER=$((RANDOM % 14))
    
    case $ENCOUNTER in
        0|1|2|3|4) encounter_monster ;;
        5|6) encounter_trap ;;
        7|8) encounter_loot ;;
        9) encounter_shrine ;;
        10) encounter_merchant ;;
        11) rest_phase ;;
        12) 
            # Save prompt with perks
            draw_header
            draw_status
            draw_box "Safe Haven - Rest & Upgrade"
            echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
            echo -e "${CYAN}║${NC} ${WHITE}s) Save${NC}  ${CYAN}p) Perks (cost 1 SP)${NC}  ${CYAN}h) Help${NC}  ${CYAN}any) Continue${NC}  ${CYAN}║${NC}"
            draw_footer
            read -rsn1 safe_choice
            case "$safe_choice" in
                s) game_save ;;
                h) show_help ;;
                p) 
                    if [ $SKILL_POINTS -gt 0 ]; then
                        draw_header
                        draw_status
                        draw_box "Perk Selection"
                        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
                        echo -e "${CYAN}║${NC} ${WHITE}1) 💪 Strength${NC}   [+2 ATK]                                      ${CYAN}║${NC}"
                        echo -e "${CYAN}║${NC} ${WHITE}2) ❤️ Vitality${NC}   [+5 Max HP]                                     ${CYAN}║${NC}"
                        echo -e "${CYAN}║${NC} ${WHITE}3) 🏃 Agility${NC}    [+1 DEF, +5% dodge]                              ${CYAN}║${NC}"
                        echo -e "${CYAN}║${NC} ${WHITE}4) ✨ Magic${NC}      [+2 ATK, -1 CD, +10 Mana]                        ${CYAN}║${NC}"
                        echo -e "${CYAN}║${NC} ${WHITE}5) 🍀 Luck${NC}       [+10% gold, +5% crit]                             ${CYAN}║${NC}"
                        echo -e "${CYAN}║${NC} ${WHITE}6) 🧠 Wisdom${NC}     [+15% XP, +5 Mana regen]                          ${CYAN}║${NC}"
                        echo -e "${CYAN}║${NC} ${WHITE}7) 🛡 Fortitude${NC}  [+3 DEF, +10 Max HP]                               ${CYAN}║${NC}"
                        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
                        echo -e "${CYAN}║${NC} ${WHITE}Skill Points: ${LIME}$SKILL_POINTS${NC}                                            ${CYAN}║${NC}"
                        echo -e "${CYAN}║${NC} ${WHITE}Choose perk [1-7]:${NC}                                             ${CYAN}║${NC}"
                        draw_footer
                        read -p " " perk_choice
                        case $perk_choice in
                            1)
                                SKILL_POINTS=$((SKILL_POINTS - 1))
                                PERK_STRENGTH=$((PERK_STRENGTH + 1))
                                ATTACK=$((ATTACK + 2))
                                echo -e "${GREEN}Strength increased! +2 ATK${NC}"
                                ;;
                            2)
                                SKILL_POINTS=$((SKILL_POINTS - 1))
                                PERK_VITALITY=$((PERK_VITALITY + 1))
                                MAX_HP=$((MAX_HP + 5))
                                HP=$MAX_HP
                                echo -e "${GREEN}Vitality increased! +5 Max HP${NC}"
                                ;;
                            3)
                                SKILL_POINTS=$((SKILL_POINTS - 1))
                                PERK_AGILITY=$((PERK_AGILITY + 1))
                                DEFENSE=$((DEFENSE + 1))
                                echo -e "${GREEN}Agility increased! +1 DEF${NC}"
                                ;;
                            4)
                                SKILL_POINTS=$((SKILL_POINTS - 1))
                                PERK_MAGIC=$((PERK_MAGIC + 1))
                                ATTACK=$((ATTACK + 2))
                                MAX_COOLDOWN=$((MAX_COOLDOWN - 1))
                                MAX_MANA=$((MAX_MANA + 10))
                                MANA=$((MANA + 10))
                                [ $MAX_COOLDOWN -lt 1 ] && MAX_COOLDOWN=1
                                echo -e "${GREEN}Magic increased! +2 ATK, -1 CD, +10 Mana${NC}"
                                ;;
                            5)
                                SKILL_POINTS=$((SKILL_POINTS - 1))
                                PERK_LUCK=$((PERK_LUCK + 1))
                                echo -e "${GREEN}Luck increased! +10% gold, +5% crit${NC}"
                                ;;
                            6)
                                SKILL_POINTS=$((SKILL_POINTS - 1))
                                PERK_WISDOM=$((PERK_WISDOM + 1))
                                echo -e "${GREEN}Wisdom increased! +15% XP, +5 Mana regen${NC}"
                                ;;
                            7)
                                SKILL_POINTS=$((SKILL_POINTS - 1))
                                PERK_FORTITUDE=$((PERK_FORTITUDE + 1))
                                DEFENSE=$((DEFENSE + 3))
                                MAX_HP=$((MAX_HP + 10))
                                HP=$((HP + 10))
                                echo -e "${GREEN}Fortitude increased! +3 DEF, +10 Max HP${NC}"
                                ;;
                        esac
                        sleep 1
                    else
                        echo -e "${RED}No skill points!${NC}"
                        sleep 1
                    fi
                    ;;
            esac
            ;;
        13)
            # Boss encounter on higher floors with phases
            if [ $FLOOR -eq 10 ] || [ $FLOOR -eq 15 ] || [ $FLOOR -eq 20 ] || [ $FLOOR -eq 25 ]; then
                local boss_monsters=("Lich Lord:70:10:100:150:necromancer" "Ancient Dragon:90:12:120:200:fire_breath" "Demon King:100:14:150:250:dark_aura" "Ashen King:120:16:200:300:ashen_curse")
                local boss_idx=0
                if [ $FLOOR -eq 10 ]; then boss_idx=0
                elif [ $FLOOR -eq 15 ]; then boss_idx=1
                elif [ $FLOOR -eq 20 ]; then boss_idx=2
                elif [ $FLOOR -eq 25 ]; then boss_idx=3
                fi
                IFS=':' read -r name hp atk def xp gold special <<< "${boss_monsters[$boss_idx]}"
                draw_header
                draw_status
                echo -e "${CYAN}║${NC} ${BOLD}${CRIMSON}⚠ BOSS ENCOUNTER: $name ⚠${NC}                              ${CYAN}║${NC}"
                echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
                combat "$name" $hp $atk $def $xp $gold "$special"
                if [ $HP -gt 0 ]; then
                    BOSS_KILLS=$((BOSS_KILLS + 1))
                    if [ "$FIRST_BOSS" = false ]; then
                        FIRST_BOSS=true
                        ACHIEVEMENTS="${ACHIEVEMENTS} First Boss"
                    fi
                    if [ $BOSS_KILLS -ge 4 ]; then
                        ACHIEVEMENTS="${ACHIEVEMENTS} Slayer"
                    fi
                    # Boss rewards
                    GOLD=$((GOLD + 50 * BOSS_KILLS))
                    XP=$((XP + 25 * BOSS_KILLS))
                    echo -e "${GOLD}Boss defeated! +$((50 * BOSS_KILLS)) gold, +$((25 * BOSS_KILLS)) XP${NC}"
                fi
            else
                encounter_monster
            fi
            ;;
    esac
    
    if [ $HP -le 0 ]; then
        break
    fi
    
    FLOOR=$((FLOOR + 1))
    
    if [ $FLOOR -le $MAX_FLOORS ]; then
        draw_header
        draw_status
        draw_box "Descending to Floor $FLOOR..."
        draw_footer
        sleep 1
    fi
done

# --- Game End ---
show_cursor
draw_header
if [ "$HP" -le 0 ]; then
    draw_box "☠ YOU DIED ☠"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${RED}The crypt claims another soul on floor $FLOOR${NC}                 ${CYAN}║${NC}"
else
    draw_box "🎉 VICTORY! 🎉"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${GREEN}You escaped the Crypt of the Ashen King!${NC}                      ${CYAN}║${NC}"
fi
echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC} ${WHITE}Final Stats:${NC}                                                 ${CYAN}║${NC}"
echo -e "${CYAN}║${NC} ${YELLOW}Level: $LEVEL | Gold: $GOLD | Class: $CLASS${NC}                     ${CYAN}║${NC}"
echo -e "${CYAN}║${NC} ${WHITE}Attack: $ATTACK | Defense: $DEFENSE | Potions: $POTIONS${NC}              ${CYAN}║${NC}"
echo -e "${CYAN}║${NC} ${RED}Monsters Slain: $KILLS${NC} ${CYAN}│${NC} ${ORANGE}Bosses Slain: $BOSS_KILLS${NC}                 ${CYAN}║${NC}"
echo -e "${CYAN}║${NC} ${LIME}Achievements:${NC} ${WHITE}$ACHIEVEMENTS${NC}                                ${CYAN}║${NC}"
draw_footer
