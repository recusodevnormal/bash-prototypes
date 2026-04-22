#!/bin/sh
#
# Sector 7 Scavenger - Enhanced Edition
# A post-apocalyptic scavenger RPG
# Requires: POSIX sh only. Zero external dependencies.
# Compatible with: Alpine Linux busybox ash, bash, dash
#

# Check terminal support
if [ ! -t 0 ]; then
    echo "Error: This game requires an interactive terminal"
    exit 1
fi

# ── ANSI COLOR CODES ────────────────────────────────────────────────
R='\033[0;31m'
G='\033[0;32m'
Y='\033[0;33m'
C='\033[0;36m'
W='\033[1;37m'
D='\033[2;37m'
N='\033[0m'
ORANGE='\033[38;5;208m'
PURPLE='\033[38;5;129m'
PINK='\033[38;5;206m'
TEAL='\033[38;5;43m'
LIME='\033[38;5;154m'
CRIMSON='\033[38;5;196m'
INDIGO='\033[38;5;57m'
BEIGE='\033[38;5;230m'
BOLD='\033[1m'
BLINK='\033[5m'

# ── CONSTANTS ───────────────────────────────────────────────────────
GRID_MAX=9
GRID_MIN=0
RADS_WARNING=40
RADS_DANGER=60
RADS_LETHAL=80
PLAYER_MAX_HP=30
ENEMY_ATTACK_MIN=3
ENEMY_ATTACK_MAX=8
PLAYER_ATTACK_MIN=4
PLAYER_ATTACK_MAX=10
DRIVES_NEEDED=5
RADS_REGEN_RATE=2  # Radiation naturally decreases per turn
RAD_SICKNESS_THRESHOLD=50
RAD_SICKNESS_DAMAGE=2
RAD_HOTSPOTS="3_3 7_7 1_8 8_2 4_6"  # High radiation areas

# Achievements
achievements=""
first_drive=false
scavenger=false
survivor=false
speedster=false
pacifist=false
rad_warrior=false
boss_slayer=false
hoarder=false
explorer=false

# Status effects
status_rad_sickness=false
status_adrenaline=false
status_turns=0
status_bleeding=false
status_infected=false
status_shielded=false
status_turns_remaining=0
rad_accumulation=0  # Tracks total radiation exposure
hotzone_bonus=0  # Bonus damage in hot zones

# ── HELPER: PAUSE ───────────────────────────────────────────────────
press_any_key() {
    printf "${D}[ Press ENTER to continue ]${N}\n"
    read DUMMY
}

# ── HELPER: DICE ROLL ───────────────────────────────────────────────
# Result stored in global $ROLL
roll_dice() {
    _min=$1
    _max=$2
    _range=$(( _max - _min + 1 ))
    ROLL=$(( (RANDOM % _range) + _min ))
}

# ── PLAYER INITIALIZATION ────────────────────────────────────────────
player_init() {
    X=0
    Y=0
    HP=$PLAYER_MAX_HP
    MAX_HP=$PLAYER_MAX_HP
    RADS=0
    MEDKITS=2
    DRIVES=0
    AMMO=10
    SCRAP=0
    FOOD=2
    WATER=2
    LOOTED_0_0=0
    LOOTED_4_7=0
    LOOTED_1_3=0
    LOOTED_7_2=0
    LOOTED_9_8=0
    LOOTED_2_9=0
    LOOTED_6_4=0
    LOOTED_3_6=0
    LOOTED_8_1=0
    TRADED_5_5=0
    BOSS_KILLED_9_0=0
    TURNS=0
    GAME_OVER=0
    WIN=0
    LOCATIONS_VISITED=0
    ENEMIES_DEFEATED=0
    TOTAL_RADS_EXPOSED=0
}

# ── HUD DISPLAY ──────────────────────────────────────────────────────
print_status() {
    printf '\033[2J\033[H'
    
    # Status effects bar
    local status_line=""
    [ "$status_rad_sickness" = true ] && status_line="${status_line}${CRIMSON} Rad-sick${NC} "
    [ "$status_adrenaline" = true ] && status_line="${status_line}${YELLOW} Adrenaline${NC} "
    [ "$status_bleeding" = true ] && status_line="${status_line}${RED} Bleeding${NC} "
    [ "$status_infected" = true ] && status_line="${status_line}${PURPLE} Infected${NC} "
    [ "$status_shielded" = true ] && status_line="${status_line}${TEAL} Shielded${NC} "
    
    echo '╔════════════════════════════════════════════════════════════════════════════╗'
    echo '║           SECTOR 7 - Enhanced Edition                        ║'
    echo '╠════════════════════════════════════════════════════════════════════════════╣'
    
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
    
    # RADS bar
    local rads_percent=$rads
    local rads_color=$GREEN
    if [ $rads_percent -gt 30 ]; then rads_color=$YELLOW
    elif [ $rads_percent -gt 60 ]; then rads_color=$RED
    fi
    local rads_bar=""
    local rads_blocks=$((rads_percent / 5))
    for ((i=0; i<20; i++)); do
        if [ $i -lt $rads_blocks ]; then rads_bar+="█"
        else rads_bar+="░"; fi
    done
    
    echo "║ ${RED} HP:${NC} ${hp_color}$hp/$max_hp${NC} [$hp_bar] ${CYAN}│${NC} ${GREEN} RADS:${NC} ${rads_color}$rads/100${NC} [$rads_bar] ${CYAN}│${NC} ${YELLOW} Drives:${NC} $drives/5 ${CYAN}║"
    echo "║ ${BLUE} Medkits:${NC} $medkits ${CYAN}│${NC} ${ORANGE} Ammo:${NC} $ammo ${CYAN}│${NC} ${GRAY} Scrap:${NC} $scrap ${CYAN}│${NC} ${GREEN} Food:${NC} $food ${CYAN}│${NC} ${BLUE} Water:${NC} $water ${CYAN}║"
    echo "║ ${WHITE}Status:${NC} $status_line${CYAN}$(printf '%.0s ' $(seq 1 $((50 - ${#status_line}))))${CYAN}║"
    echo '╠════════════════════════════════════════════════════════════════════════════╣'
    echo "║ ${WHITE}Location:${NC} $x,$y ${CYAN}│${NC} ${MAGENTA}$location_name${NC}"
    echo "║ ${WHITE}Message:${NC} $msg"
    echo '╚════════════════════════════════════════════════════════════════════════════╝'
}

# Terminal handling
hide_cursor() { printf '\033[?25l'; }
show_cursor() { printf '\033[?25h'; }
clear_screen() { printf '\033[2J\033[H'; }
play_sound() { printf '\007'; }
screen_shake() { printf '\033[5;5H'; sleep 0.05; printf '\033[H'; }

# Animation functions
flash_screen() {
    printf "\033[?5h"
    sleep 0.1
    printf "\033[?5l"
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

typing_effect() {
    local text="$1"
    local delay=${2:-0.02}
    local color="$3"
    local len=${#text}
    local i=0
    while [ $i -lt $len ]; do
        local char=$(printf '%s' "$text" | cut -c$((i+1))-$((i+1)))
        printf "${color}%s${NC}" "$char"
        sleep $delay
        i=$((i + 1))
    done
    printf "\n"
}

glow_effect() {
    local text="$1"
    local color="$2"
    for i in {1..3}; do
        printf "${color}%s${NC}\n" "$text"
        sleep 0.1
        printf "${DIM}%s${NC}\n" "$text"
        sleep 0.1
    done
    printf "${color}%s${NC}\n" "$text"
}

radiation_pulse() {
    printf "${CRIMSON}"
    for i in {1..3}; do
        printf "\r☢"
        sleep 0.2
        printf "\r ☢"
        sleep 0.2
    done
    printf "\r"
    printf "${NC}"
}

# ── COMBAT ENGINE ────────────────────────────────────────────────────
combat() {
    _ename=$1
    _ehp=$2
    _emin=$3
    _emax=$4
    _loot_desc=$5
    _gives_drive=$6
    COMBAT_WIN=0
    COMBAT_FLED=0
    printf "\n${R}⚠ ENCOUNTER: %s appears!${N}\n" "$_ename"
    printf "${D}Enemy HP: %d | Your HP: %d${N}\n\n" "$_ehp" "$HP"
    press_any_key
    _pmin=$PLAYER_ATTACK_MIN
    _pmax=$PLAYER_ATTACK_MAX
    if [ "$RADS" -ge "$RADS_DANGER" ]; then
        _pmin=$(( _pmin - 2 ))
        _pmax=$(( _pmax - 3 ))
        [ "$_pmin" -lt 1 ] && _pmin=1
        [ "$_pmax" -lt 1 ] && _pmax=1
        printf "${R}Radiation sickness weakens your attacks!${N}\n"
    fi
    while [ "$_ehp" -gt 0 ] && [ "$HP" -gt 0 ]; do
        printf "${W}--- Your HP: %d | %s HP: %d ---${N}\n" \
               "$HP" "$_ename" "$_ehp"
        printf "  ${W}[A]${N}ttack  ${W}[U]${N}se Medkit  ${W}[F]${N}lee\n"
        printf "> "
        read _action
        case "$_action" in
            a|A)
                roll_dice "$_pmin" "$_pmax"
                _pdmg=$ROLL
                _ehp=$(( _ehp - _pdmg ))
                printf "${G}You hit %s for %d damage!${N}\n" "$_ename" "$_pdmg"
                if [ "$_ehp" -le 0 ]; then
                    break
                fi
                roll_dice "$_emin" "$_emax"
                _edmg=$ROLL
                HP=$(( HP - _edmg ))
                printf "${R}%s hits you for %d damage!${N}\n" "$_ename" "$_edmg"
                ;;
            u|U)
                if [ "$MEDKITS" -gt 0 ]; then
                    roll_dice 8 15
                    _heal=$ROLL
                    HP=$(( HP + _heal ))
                    [ "$HP" -gt "$PLAYER_MAX_HP" ] && HP=$PLAYER_MAX_HP
                    MEDKITS=$(( MEDKITS - 1 ))
                    printf "${G}Healed %d HP. HP: %d/%d${N}\n" \
                           "$_heal" "$HP" "$PLAYER_MAX_HP"
                else
                    printf "${Y}No medkits!${N}\n"
                fi
                roll_dice "$_emin" "$_emax"
                _edmg=$ROLL
                HP=$(( HP - _edmg ))
                printf "${R}%s hits you for %d damage!${N}\n" "$_ename" "$_edmg"
                ;;
            f|F)
                roll_dice 0 1
                if [ "$ROLL" -eq 1 ]; then
                    roll_dice 2 5
                    HP=$(( HP - ROLL ))
                    printf "${Y}Escaped! Took %d damage fleeing.${N}\n" "$ROLL"
                    COMBAT_FLED=1
                    return
                else
                    printf "${R}Escape failed!${N}\n"
                    roll_dice "$_emin" "$_emax"
                    _edmg=$ROLL
                    HP=$(( HP - _edmg ))
                    printf "${R}%s hits you for %d damage!${N}\n" "$_ename" "$_edmg"
                fi
                ;;
            *)
                printf "${Y}Choose A, U, or F.${N}\n"
                continue
                ;;
        esac
        printf "\n"
    done
    if [ "$HP" -le 0 ]; then
        HP=0
        printf "${R}You have been defeated.${N}\n"
        press_any_key
        return
    fi
    printf "${G}You defeated %s!${N}\n\n" "$_ename"
    COMBAT_WIN=1
    if [ -n "$_loot_desc" ]; then
        printf "${G}Loot: %s${N}\n" "$_loot_desc"
        case "$_loot_desc" in
            *medkit*|*Medkit*|*MEDKIT*)
                MEDKITS=$(( MEDKITS + 1 ))
                printf "${G}+1 Medkit added.${N}\n"
                ;;
        esac
    fi
    if [ "$_gives_drive" -eq 1 ]; then
        DRIVES=$(( DRIVES + 1 ))
        printf "${W}★ TECH DRIVE RECOVERED! [%d/%d]${N}\n" \
               "$DRIVES" "$DRIVES_NEEDED"
    fi
    press_any_key
}

# ── RADIATION CHECKS ─────────────────────────────────────────────────
check_radiation() {
    # Check if player is in a radiation hotspot
    local current_pos="${X}_${Y}"
    local is_hotspot=0
    for hotspot in $RAD_HOTSPOTS; do
        if [ "$current_pos" = "$hotspot" ]; then
            is_hotspot=1
            break
        fi
    done
    
    # Apply hotspot radiation
    if [ "$is_hotspot" -eq 1 ]; then
        local hot_damage=$(( (RANDOM % 5) + 3 ))
        RADS=$(( RADS + hot_damage ))
        TOTAL_RADS_EXPOSED=$(( TOTAL_RADS_EXPOSED + hot_damage ))
        radiation_pulse
        printf "${CRIMSON}☢ HOTSPOT! +${hot_damage} radiation!${N}\n"
    fi
    
    # Natural radiation regeneration
    if [ "$RADS" -gt 0 ]; then
        RADS=$(( RADS - RADS_REGEN_RATE ))
        [ "$RADS" -lt 0 ] && RADS=0
    fi
    
    # Apply radiation sickness
    if [ "$RADS" -ge "$RAD_SICKNESS_THRESHOLD" ]; then
        status_rad_sickness=true
        HP=$(( HP - RAD_SICKNESS_DAMAGE ))
        [ "$HP" -lt 0 ] && HP=0
    else
        status_rad_sickness=false
    fi
    
    if [ "$RADS" -ge "$RADS_LETHAL" ]; then
        printf "\n${R}╔══════════════════════════════════════╗${N}\n"
        printf "${R}║  LETHAL RADIATION DOSE REACHED       ║${N}\n"
        printf "${R}╚══════════════════════════════════════╝${N}\n"
        printf "${D}Sector 7 claims another scavenger.${N}\n\n"
        GAME_OVER=1
    elif [ "$RADS" -ge "$RADS_DANGER" ]; then
        printf "\n${R}⚠ SEVERE RADIATION WARNING ⚠${N}\n"
        printf "${R}RADS: %d/%d. Combat effectiveness reduced.${N}\n" \
               "$RADS" "$RADS_LETHAL"
        press_any_key
    elif [ "$RADS" -ge "$RADS_WARNING" ]; then
        printf "\n${Y}⚠ RADIATION WARNING ⚠${N}\n"
        printf "${Y}RADS: %d/%d. Find shelter soon.${N}\n" \
               "$RADS" "$RADS_LETHAL"
        press_any_key
    fi
}

# ── LOCATION EVENT SYSTEM ────────────────────────────────────────────
check_location() {
    if [ "$X" -eq 0 ] && [ "$Y" -eq 0 ]; then
        if [ "$LOOTED_0_0" != "1" ]; then
            LOOTED_0_0=1
            printf "${D}The rusted gate of Sector 7. Your${N}\n"
            printf "${D}Geiger counter crackles. A battered medkit${N}\n"
            printf "${D}sits by the gate post.${N}\n"
            printf "${G}+1 Medkit.${N}\n"
            MEDKITS=$(( MEDKITS + 1 ))
            press_any_key
        fi
    elif [ "$X" -eq 4 ] && [ "$Y" -eq 7 ]; then
        if [ "$LOOTED_4_7" -eq 0 ]; then
            LOOTED_4_7=1
            printf "${Y}★ COLLAPSED COMMS TOWER${N}\n\n"
            printf "${D}A buckled transmission tower. Sparks shower${N}\n"
            printf "${D}from exposed wiring. Deep in the rubble,${N}\n"
            printf "${D}a glowing data module - guarded by a${N}\n"
            printf "${D}Radscorpion.${N}\n\n"
            press_any_key
            combat "Radscorpion" 18 3 6 "" 1
            press_any_key
        else
            printf "${D}The comms tower. Already cleared.${N}\n"
            press_any_key
        fi
    elif [ "$X" -eq 1 ] && [ "$Y" -eq 3 ]; then
        if [ "$LOOTED_1_3" -eq 0 ]; then
            LOOTED_1_3=1
            printf "${Y}★ FLOODED SUBWAY ENTRANCE${N}\n\n"
            printf "${D}Glowing brackish water fills the stairwell.${N}\n"
            printf "${R}Wading through: -5 HP, +3 RADS.${N}\n"
            HP=$(( HP - 5 ))
            RADS=$(( RADS + 3 ))
            printf "${D}At the bottom: a waterproof tech drive.${N}\n"
            DRIVES=$(( DRIVES + 1 ))
            printf "${W}★ TECH DRIVE RECOVERED! [%d/%d]${N}\n" \
                   "$DRIVES" "$DRIVES_NEEDED"
            press_any_key
        else
            printf "${D}The flooded subway. Drive already retrieved.${N}\n"
            press_any_key
        fi
    elif [ "$X" -eq 7 ] && [ "$Y" -eq 2 ]; then
        if [ "$LOOTED_7_2" -eq 0 ]; then
            LOOTED_7_2=1
            printf "${Y}★ RUINED RESEARCH LAB${N}\n\n"
            printf "${D}NovaCorp R&D - Sector 7. Emergency power${N}\n"
            printf "${D}hums in the server room. Two Feral Drones${N}\n"
            printf "${D}patrol the corridor.${N}\n\n"
            press_any_key
            combat "Feral Drone Alpha" 15 4 7 "" 0
            if [ "$COMBAT_WIN" -eq 1 ]; then
                combat "Feral Drone Beta" 12 3 6 "" 0
                if [ "$COMBAT_WIN" -eq 1 ]; then
                    printf "${G}Server room clear. Research drive extracted.${N}\n"
                    DRIVES=$(( DRIVES + 1 ))
                    printf "${W}★ TECH DRIVE RECOVERED! [%d/%d]${N}\n" \
                           "$DRIVES" "$DRIVES_NEEDED"
                    press_any_key
                fi
            fi
        else
            printf "${D}The research lab. Silent now.${N}\n"
            press_any_key
        fi
    elif [ "$X" -eq 9 ] && [ "$Y" -eq 8 ]; then
        if [ "$LOOTED_9_8" -eq 0 ]; then
            LOOTED_9_8=1
            printf "${Y}★ THE CRATER${N}\n\n"
            printf "${D}A massive impact site. Glass-smooth earth.${N}\n"
            printf "${R}Intense radiation. +8 RADS.${N}\n"
            RADS=$(( RADS + 8 ))
            printf "${D}At the epicenter: a lead-sealed military${N}\n"
            printf "${D}data vault. The drive inside survived.${N}\n"
            DRIVES=$(( DRIVES + 1 ))
            printf "${W}★ TECH DRIVE RECOVERED! [%d/%d]${N}\n" \
                   "$DRIVES" "$DRIVES_NEEDED"
            press_any_key
        else
            printf "${D}The Crater. You've already braved this.${N}\n"
            press_any_key
        fi
    elif [ "$X" -eq 2 ] && [ "$Y" -eq 9 ]; then
        if [ "$LOOTED_2_9" -eq 0 ]; then
            LOOTED_2_9=1
            printf "${Y}★ SATELLITE DISH ARRAY${N}\n\n"
            printf "${D}Three massive dishes. The control bunker${N}\n"
            printf "${D}below is locked - your crowbar handles it.${N}\n"
            printf "${D}The final drive is slotted into an active${N}\n"
            printf "${D}uplink terminal. Transmitting to whom?${N}\n"
            printf "${D}A Mutant Guard lurches from the shadows.${N}\n\n"
            press_any_key
            combat "Mutant Guard" 25 5 9 "Tactical medkit" 1
            if [ "$COMBAT_WIN" -eq 1 ]; then
                printf "${D}The drive ejects with a hiss. Fifth. Final.${N}\n"
            fi
            press_any_key
        else
            printf "${D}The satellite array. Your work is done here.${N}\n"
            press_any_key
        fi
    elif [ "$X" -eq 6 ] && [ "$Y" -eq 4 ]; then
        if [ "$LOOTED_6_4" -eq 0 ]; then
            LOOTED_6_4=1
            printf "${Y}OLD MILITARY BUNKER${N}\n\n"
            printf "${D}Blast door ajar. Emergency medical cache inside.${N}\n"
            printf "${G}+2 Medkits. Rad-Flush: -10 RADS.${N}\n"
            MEDKITS=$(( MEDKITS + 2 ))
            RADS=$(( RADS - 10 ))
            [ "$RADS" -lt 0 ] && RADS=0
            press_any_key
        else
            printf "${D}The bunker. You've stripped it clean.${N}\n"
            press_any_key
        fi
    elif [ "$X" -eq 3 ] && [ "$Y" -eq 6 ]; then
        if [ "$LOOTED_3_6" -eq 0 ]; then
            LOOTED_3_6=1
            printf "${Y}ABANDONED HOSPITAL${N}\n\n"
            printf "${D}St. Yevgenia Medical Center. The autodoc${N}\n"
            printf "${D}station in the surgical ward still functions.${N}\n"
            printf "${G}Full HP restored.${N}\n"
            HP=$PLAYER_MAX_HP
            printf "${G}HP: %d/%d${N}\n" "$HP" "$PLAYER_MAX_HP"
            press_any_key
        else
            printf "${D}The hospital. The autodoc hums quietly.${N}\n"
            press_any_key
        fi
    elif [ "$X" -eq 8 ] && [ "$Y" -eq 1 ]; then
        if [ "$LOOTED_8_1" -eq 0 ]; then
            LOOTED_8_1=1
            printf "${Y}WRECKED SUPPLY CONVOY${N}\n\n"
            printf "${D}Three armored trucks jackknifed on the highway.${N}\n"
            printf "${D}A Scav Raider has claimed one of the cabs.${N}\n\n"
            press_any_key
            combat "Scav Raider" 20 4 8 "Raider medkit" 0
            if [ "$COMBAT_WIN" -eq 1 ]; then
                printf "${G}You find a sealed medical crate. +1 Medkit.${N}\n"
                MEDKITS=$(( MEDKITS + 1 ))
            fi
            press_any_key
        else
            printf "${D}The wrecked convoy. Stripped clean.${N}\n"
            press_any_key
        fi
    elif [ "$X" -eq 5 ] && [ "$Y" -eq 5 ]; then
        printf "${Y}MERCHANT CAMP${N}\n\n"
        printf "${D}Vex the merchant watches you approach.${N}\n"
        printf "${D}'What'll it be, Scav?'${N}\n\n"
        printf "  ${W}[1]${N} Buy Medkit (+5 RADS, Vex's price is pain)\n"
        printf "  ${W}[2]${N} Sell drive intel (+1 Medkit)\n"
        printf "  ${W}[3]${N} Leave\n"
        printf "> "
        read _trade
        case "$_trade" in
            1)
                RADS=$(( RADS + 5 ))
                MEDKITS=$(( MEDKITS + 1 ))
                printf "${G}+1 Medkit. RADS now: %d${N}\n" "$RADS"
                ;;
            2)
                MEDKITS=$(( MEDKITS + 1 ))
                printf "${G}Vex nods. +1 Medkit.${N}\n"
                ;;
            3)
                printf "${D}'Stay sharp out there.'${N}\n"
                ;;
            *)
                printf "${Y}Vex waves you off.${N}\n"
                ;;
        esac
        press_any_key
    elif [ "$X" -eq 9 ] && [ "$Y" -eq 0 ]; then
        if [ "$BOSS_KILLED_9_0" -eq 0 ]; then
            printf "${R}★ DANGER ZONE${N}\n\n"
            printf "${D}Korrath the Irradiated. He glows. His body${N}\n"
            printf "${D}has absorbed so much radiation it has become${N}\n"
            printf "${D}a weapon. Proximity alone costs you 5 RADS.${N}\n\n"
            RADS=$(( RADS + 5 ))
            press_any_key
            combat "Korrath the Irradiated" 40 6 12 "" 0
            if [ "$COMBAT_WIN" -eq 1 ]; then
                BOSS_KILLED_9_0=1
                printf "${D}'The drives... were never meant to leave...'${N}\n"
                printf "${D}Korrath says no more.${N}\n"
            fi
            press_any_key
        else
            printf "${D}Korrath's body. The glow has faded.${N}\n"
            press_any_key
        fi
    elif [ "$X" -eq 0 ] && [ "$Y" -eq 9 ]; then
        printf "${Y}RAD STORM SHELTER${N}\n\n"
        printf "${D}Lead-lined concrete. The Geiger counter${N}\n"
        printf "${D}finally goes quiet.${N}\n"
        printf "${G}Resting here: -13 RADS (net).${N}\n"
        RADS=$(( RADS - 13 ))
        [ "$RADS" -lt 0 ] && RADS=0
        printf "${G}RADS reduced to: %d${N}\n" "$RADS"
        press_any_key
    else
        # Random encounter: 25% chance
        if [ "$(( RANDOM % 4 ))" -eq 0 ]; then
            case "$(( RANDOM % 3 ))" in
                0)
                    printf "${R}A Feral Dog pack charges from the rubble!${N}\n"
                    press_any_key
                    combat "Feral Dog Pack" 14 2 5 "" 0
                    ;;
                1)
                    printf "${R}A Scav Raider ambushes you!${N}\n"
                    press_any_key
                    combat "Scav Raider" 16 3 7 "Raider medkit" 0
                    ;;
                2)
                    printf "${R}A Mutated Crawler attacks!${N}\n"
                    press_any_key
                    combat "Mutated Crawler" 12 2 6 "" 0
                    ;;
            esac
        else
            case "$(( RANDOM % 6 ))" in
                0) printf "${D}Ash drifts past. Your Geiger counter murmurs.${N}\n" ;;
                1) printf "${D}A structure groans in the toxic wind.${N}\n" ;;
                2) printf "${D}Dense ruins. Hard to navigate.${N}\n" ;;
                3) printf "${D}A faded photograph. Someone's family.${N}\n" ;;
                4) printf "${D}Scorch marks. Old battle. Long over.${N}\n" ;;
                5) printf "${D}Broken glass and old bone beneath your boots.${N}\n" ;;
            esac
        fi
    fi
}

# ── MAIN ─────────────────────────────────────────────────────────────
main() {
    printf '\033[2J\033[H'
    show_intro
    printf "${W}"
    printf "  ╔═══════════════════════════════════════╗\n"
    printf "  ║         SECTOR 7  SCAVENGER           ║\n"
    printf "  ║    A Post-Apocalyptic Survival RPG    ║\n"
    printf "  ╚═══════════════════════════════════════╝\n"
    printf "${N}\n"
    printf "${D}The year is unknown. The city is dead.${N}\n"
    printf "${D}You are Scav-7, a freelance salvager.${N}\n"
    printf "${D}Five rare tech drives are hidden across${N}\n"
    printf "${D}the ruins of Sector 7. Find them all.${N}\n\n"
    printf "${R}Your Geiger counter is already ticking.${N}\n\n"
    printf "${Y}Move : W=North  S=South  A=West  D=East${N}\n"
    printf "${Y}Other: U=Medkit M=Map    Q=Quit${N}\n\n"
    press_any_key

    player_init
    check_location

    while [ "$GAME_OVER" -eq 0 ]; do
        print_status

        if [ "$DRIVES" -ge "$DRIVES_NEEDED" ]; then
            WIN=1
            break
        fi

        if [ "$HP" -le 0 ]; then
            GAME_OVER=1
            break
        fi

        printf "${C}Move: ${W}[W]${N}N ${W}[S]${N}S ${W}[A]${N}W ${W}[D]${N}E"
        printf " | ${W}[U]${N}Medkit ${W}[M]${N}Map ${W}[Q]${N}Quit\n"
        printf "> "
        read INPUT

        _moved=0

        case "$INPUT" in
            w|W|n|N)
                if [ "$Y" -lt "$GRID_MAX" ]; then
                    Y=$(( Y + 1 ))
                    _moved=1
                else
                    printf "${Y}Northern boundary. Rubble wall. Impassable.${N}\n"
                fi
                ;;
            s|S)
                if [ "$Y" -gt "$GRID_MIN" ]; then
                    Y=$(( Y - 1 ))
                    _moved=1
                else
                    printf "${Y}Southern perimeter fence. Electrified.${N}\n"
                fi
                ;;
            d|D|e|E)
                if [ "$X" -lt "$GRID_MAX" ]; then
                    X=$(( X + 1 ))
                    _moved=1
                else
                    printf "${Y}Eastern refinery wall. Impassable.${N}\n"
                fi
                ;;
            a|A)
                if [ "$X" -gt "$GRID_MIN" ]; then
                    X=$(( X - 1 ))
                    _moved=1
                else
                    printf "${Y}Western boundary. Toxic marshland.${N}\n"
                fi
                ;;
            u|U)
                if [ "$MEDKITS" -gt 0 ]; then
                    roll_dice 10 18
                    _heal=$ROLL
                    HP=$(( HP + _heal ))
                    [ "$HP" -gt "$PLAYER_MAX_HP" ] && HP=$PLAYER_MAX_HP
                    MEDKITS=$(( MEDKITS - 1 ))
                    RADS=$(( RADS + 2 ))
                    printf "${G}Healed %d HP. HP: %d/%d. Medkits: %d${N}\n" \
                           "$_heal" "$HP" "$PLAYER_MAX_HP" "$MEDKITS"
                    press_any_key
                else
                    printf "${R}No medkits!${N}\n"
                    press_any_key
                fi
                ;;
            m|M)
                printf '\033[2J\033[H'
                printf "${W}SECTOR 7 - KNOWN LOCATIONS${N}\n\n"
                printf "${Y}  (4,7)${N} Collapsed Comms Tower    ${W}[DRIVE]${N}\n"
                printf "${Y}  (1,3)${N} Flooded Subway Entrance  ${W}[DRIVE]${N}\n"
                printf "${Y}  (7,2)${N} Ruined Research Lab      ${W}[DRIVE]${N}\n"
                printf "${Y}  (9,8)${N} The Crater               ${W}[DRIVE]${N}\n"
                printf "${Y}  (2,9)${N} Satellite Dish Array     ${W}[DRIVE]${N}\n"
                printf "${G}  (6,4)${N} Old Military Bunker      ${G}[MEDKITS]${N}\n"
                printf "${G}  (3,6)${N} Abandoned Hospital       ${G}[HEALING]${N}\n"
                printf "${G}  (8,1)${N} Wrecked Supply Convoy    ${G}[LOOT]${N}\n"
                printf "${C}  (5,5)${N} Merchant Camp            ${C}[TRADE]${N}\n"
                printf "${G}  (0,9)${N} Rad Storm Shelter        ${G}[RAD FLUSH]${N}\n"
                printf "${R}  (9,0)${N} ??? DANGER ZONE          ${R}[BOSS]${N}\n"
                printf "\n${C}  You: X=%d, Y=%d${N}\n\n" "$X" "$Y"
                press_any_key
                ;;
            q|Q)
                printf "${Y}Quit? [y/N]: ${N}"
                read _qc
                case "$_qc" in
                    y|Y)
                        GAME_OVER=1
                        printf "${D}You abandon Sector 7.${N}\n"
                        ;;
                esac
                ;;
            *)
                printf "${Y}Unknown command. W/A/S/D to move.${N}\n"
                ;;
        esac

        if [ "$_moved" -eq 1 ]; then
            RADS=$(( RADS + 1 ))
            TURNS=$(( TURNS + 1 ))
            check_radiation
            [ "$GAME_OVER" -eq 1 ] && break
            [ "$HP" -le 0 ] && { GAME_OVER=1; break; }
            check_location
            [ "$HP" -le 0 ] && { GAME_OVER=1; break; }
            [ "$DRIVES" -ge "$DRIVES_NEEDED" ] && { WIN=1; break; }
        fi
    done

    printf '\033[2J\033[H'

    if [ "$WIN" -eq 1 ]; then
        printf "${W}"
        printf "  ╔═══════════════════════════════════════╗\n"
        printf "  ║           MISSION COMPLETE            ║\n"
        printf "  ╚═══════════════════════════════════════╝\n"
        printf "${N}\n"
        printf "${G}All five tech drives recovered.${N}\n\n"
        printf "${D}You limp back through the rusted gate.${N}\n"
        printf "${D}The contractor's signal crackles:${N}\n"
        printf "${D}'Confirmed. Extraction in 10.'${N}\n\n"
        printf "${D}Korrath's words echo: 'Never meant to leave.'${N}\n"
        printf "${D}That's a problem for someone getting paid less.${N}\n\n"
        printf "${C}Turns: %d | RADS: %d/%d | HP: %d/%d | Medkits: %d${N}\n\n" \
               "$TURNS" "$RADS" "$RADS_LETHAL" "$HP" "$PLAYER_MAX_HP" "$MEDKITS"
    else
        printf "${R}"
        printf "  ╔═══════════════════════════════════════╗\n"
        printf "  ║             SCAV DOWN                 ║\n"
        printf "  ╚═══════════════════════════════════════╝\n"
        printf "${N}\n"
        if [ "$HP" -le 0 ]; then
            printf "${D}You fought hard. Not hard enough.${N}\n\n"
        else
            printf "${D}The radiation claimed you. Like everything${N}\n"
            printf "${D}else in Sector 7.${N}\n\n"
        fi
        printf "${C}Drives: %d/%d | Turns: %d | RADS: %d/%d | HP: %d/%d${N}\n\n" \
               "$DRIVES" "$DRIVES_NEEDED" "$TURNS" \
               "$RADS" "$RADS_LETHAL" "$HP" "$PLAYER_MAX_HP"
    fi

    printf "${W}Thanks for playing Sector 7 Scavenger.${N}\n\n"
}

main