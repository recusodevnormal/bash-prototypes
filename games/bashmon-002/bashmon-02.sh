#!/usr/bin/env bash
# =============================================================================
# BASHMON: TUI Monster Tamer
# A single-file Bash RPG with ASCII monsters, turn-based combat, and TUI
# =============================================================================

# --- Terminal Setup & Cleanup ------------------------------------------------
setup_terminal() {
    tput smcup          # Save screen
    tput civis          # Hide cursor
    stty -echo          # Disable echo
    clear
}

restore_terminal() {
    tput rmcup          # Restore screen
    tput cnorm          # Show cursor
    stty echo           # Enable echo
    clear
    echo "Thanks for playing Bashmon! Goodbye!"
}

trap restore_terminal EXIT INT TERM

# --- Global Constants --------------------------------------------------------
declare -i TERM_COLS TERM_ROWS
TERM_COLS=$(tput cols)
TERM_ROWS=$(tput lines)

# Ensure minimum terminal size
if [[ $TERM_COLS -lt 80 || $TERM_ROWS -lt 24 ]]; then
    echo "Error: Terminal must be at least 80x24. Current: ${TERM_COLS}x${TERM_ROWS}"
    exit 1
fi

# Layout dimensions
declare -i BATTLE_W BATTLE_H STATUS_W STATUS_H DIVIDER_COL
DIVIDER_COL=55
BATTLE_W=$DIVIDER_COL
BATTLE_H=$TERM_ROWS
STATUS_W=$(( TERM_COLS - DIVIDER_COL - 1 ))
STATUS_H=$TERM_ROWS

# Colors (ANSI escape codes)
RED='\033[0;31m';    LRED='\033[1;31m'
GREEN='\033[0;32m';  LGREEN='\033[1;32m'
YELLOW='\033[0;33m'; LYELLOW='\033[1;33m'
BLUE='\033[0;34m';   LBLUE='\033[1;34m'
MAGENTA='\033[0;35m';LMAGENTA='\033[1;35m'
CYAN='\033[0;36m';   LCYAN='\033[1;36m'
WHITE='\033[0;37m';  LWHITE='\033[1;37m'
BOLD='\033[1m';      DIM='\033[2m'
NC='\033[0m'         # No Color / Reset

# Box-drawing characters
TL='╔'; TR='╗'; BL='╚'; BR='╝'
HL='═'; VL='║'
TT='╦'; BT='╩'; LT='╠'; RT='╣'; CC='╬'
STL='┌'; STR='┐'; SBL='└'; SBR='┘'
SHL='─'; SVL='│'

# --- Cursor Movement Helpers -------------------------------------------------
move_to() { tput cup "$(( $1 - 1 ))" "$(( $2 - 1 ))"; }
# move_to ROW COL (1-indexed)

print_at() {
    local row=$1 col=$2; shift 2
    move_to "$row" "$col"
    echo -en "$*"
}

# --- Monster Database --------------------------------------------------------
# Format: NAME|HP|MAX_HP|ATK|DEF|SPEED|TYPE|RARITY|CATCH_RATE
# Types: FIRE WATER GRASS ELECTRIC GHOST NORMAL

declare -a MONSTER_NAMES=(
    "Flambit"   "Aquarel"   "Leafrog"   "Zappix"
    "Spookle"   "Pebblor"   "Frostbun"  "Shadling"
    "Emberon"   "Torrento"  "Thornvine" "Voltmoth"
    "Phantusk"  "Rockgrum"  "Glaceon"   "Duskwing"
)

declare -a MONSTER_TYPES=(
    "FIRE"    "WATER"   "GRASS"   "ELECTRIC"
    "GHOST"   "NORMAL"  "WATER"   "GHOST"
    "FIRE"    "WATER"   "GRASS"   "ELECTRIC"
    "GHOST"   "NORMAL"  "WATER"   "GHOST"
)

declare -a MONSTER_MAX_HP=(
    30 35 28 25 20 40 32 22 50 55 45 38 30 60 48 25
)

declare -a MONSTER_ATK=(
    12  8 10 14  9  7 11 13 18 15 12 16 11  9 14 15
)

declare -a MONSTER_DEF=(
    6  9  8  5  4 12  8  6 10 12 10  7  5 15 11  7
)

declare -a MONSTER_SPEED=(
    8  7  6 12  9  5  7 11 10  8  6 13 10  4  7 12
)

declare -a MONSTER_RARITY=(
    "Common" "Common" "Common" "Common"
    "Uncommon" "Common" "Uncommon" "Uncommon"
    "Rare" "Rare" "Rare" "Rare"
    "Epic" "Epic" "Epic" "Epic"
)

declare -a MONSTER_CATCH=(
    80 80 80 80 60 85 60 60 30 30 30 30 15 15 15 15
)

# Monster ASCII Art (8 lines each, padded to same width)
declare -a MONSTER_ART_FLAMBIT=(
    "   (\\(\\   "
    "  ( ^.^ ) "
    "  o(\")(\")" 
    " /|  ~  |\ "
    "/ | fire| \ "
    "  |_____|  "
    " //_____\\ "
    "  ~~ ~~ ~~ "
)

declare -a MONSTER_ART_AQUAREL=(
    "  _______  "
    " /  o o  \ "
    "|  (___) | "
    "|  water  | "
    " \_______/ "
    "  |  |  |  "
    " ~|~~|~~|~ "
    "~~~~~~~~~~~"
)

declare -a MONSTER_ART_LEAFROG=(
    "   _____   "
    "  / o o \  "
    " |  ___  | "
    " | |   | | "
    "  \_____/  "
    " __|   |__ "
    "/  |___|  \ "
    "   leaf    "
)

declare -a MONSTER_ART_ZAPPIX=(
    "  /\\ /\\  "
    " ( *  * ) "
    "  \\ __ / "
    " /|~~~~|\ "
    "/ |volt | \ "
    " /______\ "
    "   |  |   "
    "  _|__|_  "
)

declare -a MONSTER_ART_SPOOKLE=(
    "           "
    " .-------, "
    " |  o  o | "
    " |   __  | "
    " |  (__)| "
    "  \______/ "
    " ~~~ghost~~"
    "           "
)

declare -a MONSTER_ART_PEBBLOR=(
    "  _______  "
    " / . . . \ "
    "|  _____  |"
    "| | NRM | |"
    "|  -----  |"
    " \_______/ "
    "  /     \  "
    " /       \ "
)

declare -a MONSTER_ART_FROSTBUN=(
    "  (\\(\\   "
    " (* . *)  "
    "  (  *  ) "
    " / COLD \ "
    "|  ~~~~  | "
    " \______/ "
    "  || ||   "
    " /| || |\ "
)

declare -a MONSTER_ART_SHADLING=(
    " _,-._,-,_ "
    "(_ o   o _)"
    " |  ___  | "
    " | (GHO) | "
    " |  ---  | "
    "  \_____/  "
    " /  | |  \ "
    "    | |    "
)

declare -a MONSTER_ART_EMBERON=(
    " /\\  /\\  "
    "( ##  ## ) "
    " \\  /\\/ "
    "/|  FIRE |\ "
    " |  ~~~  | "
    " |_______| "
    "/  /   \  \"
    "  /_____\  "
)

declare -a MONSTER_ART_TORRENTO=(
    "  _______  "
    " / ## ## \ "
    "/ (     ) \ "
    "| (WAVE)  |"
    "|  -----  |"
    " \_______/ "
    " /  ~~~  \ "
    "~~~~~~~~~~~"
)

declare -a MONSTER_ART_THORNVINE=(
    "  _/\\___  "
    " / o   o \\ "
    "|  THORN  |"
    "|  _____  |"
    "| |GRASS| |"
    " \\_______/"
    " /|     |\\ "
    "/_|_____|_\\"
)

declare -a MONSTER_ART_VOLTMOTH=(
    "  _/ \\_ "
    " /  O O  \\ "
    "| ELEC~~~ |"
    " \\  ___  / "
    "  |     |  "
    " /\\_____/\\ "
    "/  |   |  \\"
    "   |___|   "
)

declare -a MONSTER_ART_PHANTUSK=(
    "  .......  "
    " . o   o . "
    ".  _____  ."
    ". | GHO | ."
    " . -----  ."
    "  .______. "
    "    |  |   "
    "   ~~~~~   "
)

declare -a MONSTER_ART_ROCKGRUM=(
    " _________  "
    "/ ### ### \\"
    "| #  _  # |"
    "| # NRM # |"
    "| #_____# |"
    "\\_________/"
    "  /     \\ "
    " /  ___  \\ "
)

declare -a MONSTER_ART_GLACEON=(
    " /\\ _ /\\ "
    "(  * . *  )"
    " \\ ICE /  "
    "/-|___|-\\ "
    "| |   | |  "
    " \\|___|/  "
    "  /   \\  "
    " / ___ \\ "
)

declare -a MONSTER_ART_DUSKWING=(
    "  /\\ /\\   "
    " (* . *)  "
    "(  ___  )  "
    " \\ GHO /  "
    "  |___|    "
    " / | | \\  "
    "/  | |  \\ "
    "   | |    "
)

# Map monster index to art array name
get_monster_art() {
    local idx=$1
    local names=("FLAMBIT" "AQUAREL" "LEAFROG" "ZAPPIX"
                  "SPOOKLE" "PEBBLOR" "FROSTBUN" "SHADLING"
                  "EMBERON" "TORRENTO" "THORNVINE" "VOLTMOTH"
                  "PHANTUSK" "ROCKGRUM" "GLACEON" "DUSKWING")
    echo "${names[$idx]}"
}

# Type colors
type_color() {
    case "$1" in
        FIRE)     echo -n "$LRED" ;;
        WATER)    echo -n "$LBLUE" ;;
        GRASS)    echo -n "$LGREEN" ;;
        ELECTRIC) echo -n "$LYELLOW" ;;
        GHOST)    echo -n "$LMAGENTA" ;;
        NORMAL)   echo -n "$LWHITE" ;;
        *)        echo -n "$NC" ;;
    esac
}

# --- Player State ------------------------------------------------------------
declare -a TEAM_IDX=()        # Indices into monster arrays
declare -a TEAM_HP=()         # Current HP
declare -a TEAM_MAX_HP=()
declare -a TEAM_ATK=()
declare -a TEAM_DEF=()
declare -a TEAM_SPEED=()
declare -i TEAM_SIZE=0
declare -i MAX_TEAM=6

declare -i PLAYER_MONEY=100
declare -i HEAL_ITEMS=3
declare -i CATCH_BALLS=5
declare -i STEPS=0
declare -i TOTAL_CAUGHT=0
declare -i TOTAL_BATTLES=0
declare -i BATTLES_WON=0

# Starter monster: Flambit (index 0)
init_player() {
    TEAM_IDX=(0)
    TEAM_HP=(${MONSTER_MAX_HP[0]})
    TEAM_MAX_HP=(${MONSTER_MAX_HP[0]})
    TEAM_ATK=(${MONSTER_ATK[0]})
    TEAM_DEF=(${MONSTER_DEF[0]})
    TEAM_SPEED=(${MONSTER_SPEED[0]})
    TEAM_SIZE=1
}

# --- Battle State -----------------------------------------------------------
declare -i ENEMY_IDX=0
declare -i ENEMY_HP=0
declare -i ENEMY_MAX_HP=0
declare -i ENEMY_ATK=0
declare -i ENEMY_DEF=0
declare -i ENEMY_SPEED=0
declare    ENEMY_NAME=""
declare    ENEMY_TYPE=""
declare    BATTLE_LOG=""
declare -a BATTLE_MESSAGES=()
declare -i ACTIVE_MON=0  # Which team monster is active

# --- TUI Drawing Functions --------------------------------------------------

# Draw a box: draw_box ROW COL HEIGHT WIDTH [COLOR] [TITLE]
draw_box() {
    local row=$1 col=$2 height=$3 width=$4
    local color="${5:-$NC}" title="${6:-}"
    local inner_w=$(( width - 2 ))

    # Top border
    move_to "$row" "$col"
    echo -en "${color}${TL}"
    if [[ -n "$title" ]]; then
        local title_str=" ${title} "
        local title_len=${#title_str}
        local left_pad=$(( (inner_w - title_len) / 2 ))
        local right_pad=$(( inner_w - title_len - left_pad ))
        printf "%${left_pad}s" | tr ' ' "$HL"
        echo -en "${BOLD}${title_str}${NC}${color}"
        printf "%${right_pad}s" | tr ' ' "$HL"
    else
        printf "%${inner_w}s" | tr ' ' "$HL"
    fi
    echo -en "${TR}${NC}"

    # Sides
    local r
    for (( r = 1; r < height - 1; r++ )); do
        move_to $(( row + r )) "$col"
        echo -en "${color}${VL}${NC}"
        printf "%${inner_w}s" " "
        move_to $(( row + r )) $(( col + width - 1 ))
        echo -en "${color}${VL}${NC}"
    done

    # Bottom border
    move_to $(( row + height - 1 )) "$col"
    echo -en "${color}${BL}"
    printf "%${inner_w}s" | tr ' ' "$HL"
    echo -en "${BR}${NC}"
}

# Draw vertical divider
draw_divider() {
    local col=$DIVIDER_COL
    local color="$CYAN"
    move_to 1 "$col"
    echo -en "${color}${TT}${NC}"
    local r
    for (( r = 2; r < TERM_ROWS; r++ )); do
        move_to "$r" "$col"
        echo -en "${color}${VL}${NC}"
    done
    move_to "$TERM_ROWS" "$col"
    echo -en "${color}${BT}${NC}"
}

# Draw HP bar: draw_hp_bar ROW COL CURRENT MAX WIDTH
draw_hp_bar() {
    local row=$1 col=$2 cur=$3 max=$4 width=$5
    local pct=$(( cur * 100 / max ))
    local filled=$(( cur * width / max ))
    [[ $filled -gt $width ]] && filled=$width
    local empty=$(( width - filled ))

    local color
    if   [[ $pct -gt 60 ]]; then color="$LGREEN"
    elif [[ $pct -gt 30 ]]; then color="$LYELLOW"
    else                          color="$LRED"
    fi

    move_to "$row" "$col"
    echo -en "${color}"
    printf "%${filled}s" | tr ' ' '█'
    echo -en "${DIM}${NC}"
    printf "%${empty}s" | tr ' ' '░'
    echo -en "${NC}"
}

# Center text within a width
center_text() {
    local text="$1" width=$2
    # Strip ANSI for length calculation
    local clean
    clean=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local len=${#clean}
    local pad=$(( (width - len) / 2 ))
    [[ $pad -lt 0 ]] && pad=0
    printf "%${pad}s%s" "" "$text"
}

# --- Screen Layout Drawing --------------------------------------------------

draw_main_frame() {
    tput clear
    # Outer border
    draw_box 1 1 "$TERM_ROWS" "$TERM_COLS" "$CYAN"
    # Battle panel title
    draw_box 1 1 3 "$DIVIDER_COL" "$LBLUE" "⚔ BATTLE ARENA"
    # Status panel title
    draw_box 1 "$DIVIDER_COL" 3 "$(( TERM_COLS - DIVIDER_COL + 1 ))" "$LGREEN" "📊 STATUS"
    # Divider
    draw_divider
}

draw_status_panel() {
    local start_col=$(( DIVIDER_COL + 1 ))
    local inner_w=$(( STATUS_W - 2 ))
    local row=4

    # Clear status area
    local r
    for (( r = 4; r <= TERM_ROWS - 1; r++ )); do
        move_to "$r" $(( start_col + 1 ))
        printf "%${inner_w}s" " "
    done

    # Player info
    print_at "$row" $(( start_col + 2 )) "${BOLD}${LYELLOW}🎮 TRAINER${NC}"
    (( row++ ))
    print_at "$row" $(( start_col + 2 )) "${LWHITE}💰 Money:${NC} ${LYELLOW}\$${PLAYER_MONEY}${NC}"
    (( row++ ))
    print_at "$row" $(( start_col + 2 )) "${LWHITE}💊 Heals:${NC}  ${LGREEN}${HEAL_ITEMS}${NC}"
    (( row++ ))
    print_at "$row" $(( start_col + 2 )) "${LWHITE}⚾ Balls:${NC}  ${LBLUE}${CATCH_BALLS}${NC}"
    (( row++ ))
    print_at "$row" $(( start_col + 2 )) "${LWHITE}👟 Steps:${NC}  ${LCYAN}${STEPS}${NC}"
    (( row++ ))
    print_at "$row" $(( start_col + 2 )) "${LWHITE}🏆 Won:${NC}   ${LGREEN}${BATTLES_WON}${NC}${LWHITE}/${TOTAL_BATTLES}${NC}"
    (( row++ ))
    print_at "$row" $(( start_col + 2 )) "${LWHITE}🐾 Caught:${NC} ${LMAGENTA}${TOTAL_CAUGHT}${NC}"

    (( row += 2 ))
    print_at "$row" $(( start_col + 2 )) "${BOLD}${LCYAN}── TEAM ──────────────────${NC}"
    (( row++ ))

    local i
    for (( i = 0; i < TEAM_SIZE && i < MAX_TEAM; i++ )); do
        local midx="${TEAM_IDX[$i]}"
        local mname="${MONSTER_NAMES[$midx]}"
        local mtype="${MONSTER_TYPES[$midx]}"
        local chp="${TEAM_HP[$i]}"
        local mhp="${TEAM_MAX_HP[$i]}"
        local tc
        tc=$(type_color "$mtype")

        local marker=" "
        [[ $i -eq $ACTIVE_MON ]] && marker="${LGREEN}▶${NC}"

        if [[ $chp -le 0 ]]; then
            print_at "$row" $(( start_col + 2 )) "${DIM}${marker} ${mname} ${RED}[KO]${NC}"
        else
            print_at "$row" $(( start_col + 2 )) "${marker} ${tc}${mname}${NC}"
        fi
        (( row++ ))

        if [[ $chp -gt 0 ]]; then
            local bar_w=$(( inner_w - 4 ))
            [[ $bar_w -gt 20 ]] && bar_w=20
            move_to "$row" $(( start_col + 4 ))
            local pct_hp=$(( chp * 100 / mhp ))
            local bar_color
            if   [[ $pct_hp -gt 60 ]]; then bar_color="$LGREEN"
            elif [[ $pct_hp -gt 30 ]]; then bar_color="$LYELLOW"
            else                             bar_color="$LRED"
            fi
            local filled=$(( chp * bar_w / mhp ))
            [[ $filled -gt $bar_w ]] && filled=$bar_w
            local empty=$(( bar_w - filled ))
            echo -en "${bar_color}"
            printf "%${filled}s" | tr ' ' '▪'
            echo -en "${DIM}${NC}"
            printf "%${empty}s" | tr ' ' '·'
            echo -en "${NC}"
            print_at "$row" $(( start_col + bar_w + 5 )) "${LWHITE}${chp}${NC}"
            (( row++ ))
        fi

        [[ $row -ge $(( TERM_ROWS - 3 )) ]] && break
    done

    # Controls hint at bottom
    local hint_row=$(( TERM_ROWS - 3 ))
    print_at "$hint_row" $(( start_col + 2 )) "${DIM}${CYAN}── CONTROLS ──────────────${NC}"
    (( hint_row++ ))
    print_at "$hint_row" $(( start_col + 2 )) "${DIM}[1-3] Action  [W/S] Select${NC}"
    (( hint_row++ ))
    print_at "$hint_row" $(( start_col + 2 )) "${DIM}[Q] Quit  [ENTER] Confirm${NC}"
}

# --- Battle View Drawing ----------------------------------------------------

draw_battle_scene() {
    local inner_w=$(( DIVIDER_COL - 2 ))

    # Clear battle area (rows 4 to TERM_ROWS-1)
    local r
    for (( r = 4; r <= TERM_ROWS - 1; r++ )); do
        move_to "$r" 2
        printf "%${inner_w}s" " "
    done

    # --- Enemy area (top half) ---
    local enemy_art_name
    enemy_art_name=$(get_monster_art "$ENEMY_IDX")

    # Draw enemy monster art
    local art_row=5
    local art_col=4
    local art_var="MONSTER_ART_${enemy_art_name}[@]"
    local art_lines=("${!art_var}")
    local line
    for line in "${art_lines[@]}"; do
        local tc
        tc=$(type_color "$ENEMY_TYPE")
        print_at "$art_row" "$art_col" "${tc}${line}${NC}"
        (( art_row++ ))
    done

    # Enemy name & type
    local enemy_info_col=$(( art_col + 15 ))
    print_at 5 "$enemy_info_col" "${BOLD}${LRED}${ENEMY_NAME}${NC}"
    local tc
    tc=$(type_color "$ENEMY_TYPE")
    print_at 6 "$enemy_info_col" "${tc}[${ENEMY_TYPE}]${NC}  ${DIM}${MONSTER_RARITY[$ENEMY_IDX]}${NC}"
    print_at 7 "$enemy_info_col" "${LWHITE}HP:${NC} ${ENEMY_HP}/${ENEMY_MAX_HP}"
    print_at 8 "$enemy_info_col" "${LWHITE}ATK:${NC}${LRED}${ENEMY_ATK}${NC} ${LWHITE}DEF:${NC}${LBLUE}${ENEMY_DEF}${NC}"
    print_at 9 "$enemy_info_col" "${LWHITE}SPD:${NC}${LYELLOW}${ENEMY_SPEED}${NC}"

    # Enemy HP bar
    print_at 10 "$enemy_info_col" "HP "
    draw_hp_bar 10 $(( enemy_info_col + 3 )) "$ENEMY_HP" "$ENEMY_MAX_HP" 18

    # Divider line
    local mid_row=14
    move_to "$mid_row" 2
    echo -en "${DIM}${CYAN}"
    printf "%${inner_w}s" | tr ' ' '─'
    echo -en "${NC}"

    # --- Player monster area (bottom half) ---
    local player_midx="${TEAM_IDX[$ACTIVE_MON]}"
    local player_art_name
    player_art_name=$(get_monster_art "$player_midx")
    local player_type="${MONSTER_TYPES[$player_midx]}"
    local player_name="${MONSTER_NAMES[$player_midx]}"
    local player_hp="${TEAM_HP[$ACTIVE_MON]}"
    local player_max="${TEAM_MAX_HP[$ACTIVE_MON]}"
    local player_atk="${TEAM_ATK[$ACTIVE_MON]}"
    local player_def="${TEAM_DEF[$ACTIVE_MON]}"
    local player_spd="${TEAM_SPEED[$ACTIVE_MON]}"

    # Player info on left
    local pinfo_col=3
    local pinfo_row=$(( mid_row + 1 ))
    print_at "$pinfo_row" "$pinfo_col" "${BOLD}${LGREEN}YOUR: ${player_name}${NC}"
    (( pinfo_row++ ))
    local ptc
    ptc=$(type_color "$player_type")
    print_at "$pinfo_row" "$pinfo_col" "${ptc}[${player_type}]${NC}"
    (( pinfo_row++ ))
    print_at "$pinfo_row" "$pinfo_col" "${LWHITE}HP:${NC} ${player_hp}/${player_max}"
    (( pinfo_row++ ))
    print_at "$pinfo_row" "$pinfo_col" "HP "
    draw_hp_bar "$pinfo_row" $(( pinfo_col + 3 )) "$player_hp" "$player_max" 18
    (( pinfo_row++ ))
    print_at "$pinfo_row" "$pinfo_col" "${LWHITE}ATK:${NC}${LRED}${player_atk}${NC} ${LWHITE}DEF:${NC}${LBLUE}${player_def}${NC} ${LWHITE}SPD:${NC}${LYELLOW}${player_spd}${NC}"

    # Player art on right
    local p_art_var="MONSTER_ART_${player_art_name}[@]"
    local p_art_lines=("${!p_art_var}")
    local p_art_row=$(( mid_row + 1 ))
    local p_art_col=35
    for line in "${p_art_lines[@]}"; do
        ptc=$(type_color "$player_type")
        print_at "$p_art_row" "$p_art_col" "${ptc}${line}${NC}"
        (( p_art_row++ ))
    done
}

# --- Battle Message Log -----------------------------------------------------

draw_battle_log() {
    local inner_w=$(( DIVIDER_COL - 4 ))
    local log_start_row=$(( TERM_ROWS - 8 ))
    local log_end_row=$(( TERM_ROWS - 2 ))

    # Draw log box
    draw_box "$log_start_row" 2 $(( log_end_row - log_start_row + 1 )) $(( DIVIDER_COL - 2 )) "$DIM$WHITE" "BATTLE LOG"

    # Clear log area
    local r
    for (( r = log_start_row + 1; r < log_end_row; r++ )); do
        move_to "$r" 3
        printf "%${inner_w}s" " "
    done

    # Show last N messages
    local max_lines=$(( log_end_row - log_start_row - 2 ))
    local msg_count=${#BATTLE_MESSAGES[@]}
    local start=$(( msg_count - max_lines ))
    [[ $start -lt 0 ]] && start=0

    local row=$(( log_start_row + 1 ))
    local i
    for (( i = start; i < msg_count; i++ )); do
        move_to "$row" 3
        # Truncate to fit
        local msg="${BATTLE_MESSAGES[$i]}"
        local clean
        clean=$(echo -e "$msg" | sed 's/\x1b\[[0-9;]*m//g')
        if [[ ${#clean} -gt $inner_w ]]; then
            msg="${msg:0:$inner_w}"
        fi
        echo -en " ${msg}"
        (( row++ ))
    done
}

add_battle_msg() {
    BATTLE_MESSAGES+=("$1")
    draw_battle_log
}

clear_battle_msgs() {
    BATTLE_MESSAGES=()
    draw_battle_log
}

# --- Battle Menu ------------------------------------------------------------

MENU_OPTIONS=("⚔  ATTACK" "💊 HEAL" "⚾  CATCH" "🔄 SWITCH" "🏃 RUN")
declare -i MENU_CURSOR=0
declare -i MENU_SIZE=5

draw_battle_menu() {
    local menu_row=4
    local menu_col=2
    local menu_h=$(( MENU_SIZE + 4 ))
    local menu_w=28

    draw_box "$menu_row" "$menu_col" "$menu_h" "$menu_w" "$LYELLOW" "ACTION"

    local i
    for (( i = 0; i < MENU_SIZE; i++ )); do
        local r=$(( menu_row + 2 + i ))
        local c=$(( menu_col + 2 ))
        if [[ $i -eq $MENU_CURSOR ]]; then
            print_at "$r" "$c" "${LGREEN}▶ ${BOLD}${MENU_OPTIONS[$i]}${NC}"
        else
            print_at "$r" "$c" "  ${DIM}${MENU_OPTIONS[$i]}${NC}"
        fi
    done
}

# --- Switch Monster Sub-Menu ------------------------------------------------

draw_switch_menu() {
    local menu_row=4
    local menu_col=2
    local menu_h=$(( TEAM_SIZE + 4 ))
    local menu_w=32

    draw_box "$menu_row" "$menu_col" "$menu_h" "$menu_w" "$LCYAN" "SWITCH MONSTER"

    local i
    for (( i = 0; i < TEAM_SIZE; i++ )); do
        local r=$(( menu_row + 2 + i ))
        local c=$(( menu_col + 2 ))
        local midx="${TEAM_IDX[$i]}"
        local mname="${MONSTER_NAMES[$midx]}"
        local chp="${TEAM_HP[$i]}"
        local mhp="${TEAM_MAX_HP[$i]}"
        local tc
        tc=$(type_color "${MONSTER_TYPES[$midx]}")

        if [[ $i -eq $ACTIVE_MON ]]; then
            print_at "$r" "$c" "${LCYAN}▶ ${tc}${mname}${NC} ${DIM}(active)${NC}"
        elif [[ $chp -le 0 ]]; then
            print_at "$r" "$c" "  ${DIM}${mname} [KO]${NC}"
        else
            print_at "$r" "$c" "  ${tc}${mname}${NC} ${LWHITE}HP:${chp}/${mhp}${NC}"
        fi
    done

    print_at $(( menu_row + menu_h - 1 )) $(( menu_col + 2 )) "${DIM}[W/S] Select  [ENTER] Confirm  [Q] Back${NC}"
}

# --- Overworld / Field View -------------------------------------------------

FIELD_COLS=50
FIELD_ROWS=15

draw_field() {
    tput clear

    # Outer frame
    draw_box 1 1 "$TERM_ROWS" "$TERM_COLS" "$CYAN"
    draw_divider

    # Status panel
    draw_status_panel

    # Field title
    draw_box 1 1 3 "$DIVIDER_COL" "$LGREEN" "🌿 TALL GRASS FIELD"

    local inner_w=$(( DIVIDER_COL - 4 ))
    local inner_h=$(( TERM_ROWS - 8 ))

    # Draw grass pattern
    local row col
    for (( row = 4; row < inner_h + 4; row++ )); do
        move_to "$row" 2
        local grass_line=""
        for (( col = 0; col < inner_w; col++ )); do
            local rand=$(( RANDOM % 8 ))
            case $rand in
                0) grass_line+="${LGREEN}ʷ${NC}" ;;
                1) grass_line+="${GREEN}ʸ${NC}" ;;
                2) grass_line+="${LGREEN}⌇${NC}" ;;
                3) grass_line+="${GREEN}⌑${NC}" ;;
                4) grass_line+="${DIM}${GREEN}.${NC}" ;;
                5) grass_line+="${LGREEN}׳${NC}" ;;
                *) grass_line+=" " ;;
            esac
        done
        echo -en "$grass_line"
    done

    # Player marker in center
    local py=$(( inner_h / 2 + 4 ))
    local px=$(( inner_w / 2 + 2 ))
    print_at "$py" "$px" "${BOLD}${LYELLOW}☺${NC}"

    # Bottom instruction box
    local irow=$(( TERM_ROWS - 5 ))
    draw_box "$irow" 2 4 $(( DIVIDER_COL - 2 )) "$DIM$CYAN" "CONTROLS"
    print_at $(( irow + 1 )) 4 "${LWHITE}[ENTER]${NC} Walk in grass (find monster)"
    print_at $(( irow + 2 )) 4 "${LWHITE}[H]${NC} Heal team  ${LWHITE}[S]${NC} Shop  ${LWHITE}[Q]${NC} Quit"
}

# --- Heal Team Function -----------------------------------------------------

heal_team() {
    if [[ $HEAL_ITEMS -le 0 ]]; then
        return 1
    fi
    (( HEAL_ITEMS-- ))
    local i
    for (( i = 0; i < TEAM_SIZE; i++ )); do
        local maxhp="${TEAM_MAX_HP[$i]}"
        TEAM_HP[$i]="$maxhp"
    done
    return 0
}

# --- Shop -------------------------------------------------------------------

draw_shop() {
    tput clear
    draw_box 1 1 "$TERM_ROWS" "$TERM_COLS" "$LYELLOW" "🏪 BASHMON SHOP"

    local mid=$(( TERM_COLS / 2 - 20 ))
    local row=4

    print_at "$row" "$mid" "${BOLD}${LYELLOW}Welcome to the shop!${NC}"
    (( row += 2 ))
    print_at "$row" "$mid" "${LWHITE}💰 Your money: ${LYELLOW}\$${PLAYER_MONEY}${NC}"
    (( row += 2 ))

    print_at "$row" "$mid" "${BOLD}${LCYAN}── ITEMS FOR SALE ────────────────────${NC}"
    (( row++ ))
    print_at "$row" "$mid" "${LGREEN}[1]${NC} Heal Potion   ${LYELLOW}\$20${NC}  (Heals whole team)"
    (( row++ ))
    print_at "$row" "$mid" "${LBLUE}[2]${NC} Bashmon Ball  ${LYELLOW}\$30${NC}  (Catch monsters)"
    (( row += 2 ))
    print_at "$row" "$mid" "${DIM}[Q] Leave shop${NC}"

    (( row += 2 ))
    print_at "$row" "$mid" "${DIM}Currently: ${HEAL_ITEMS} Heal Potions, ${CATCH_BALLS} Bashmon Balls${NC}"

    local shop_open=true
    while $shop_open; do
        local key
        read -rsn1 key
        case "$key" in
            1)
                if [[ $PLAYER_MONEY -ge 20 ]]; then
                    (( PLAYER_MONEY -= 20 ))
                    (( HEAL_ITEMS++ ))
                    print_at $(( row + 2 )) "$mid" "${LGREEN}Bought Heal Potion!${NC}        "
                    sleep 0.8
                    print_at $(( row + 2 )) "$mid" "                         "
                    print_at $(( row - 5 )) "$mid" "${LWHITE}💰 Your money: ${LYELLOW}\$${PLAYER_MONEY}${NC}  "
                    print_at "$row" "$mid" "${DIM}Currently: ${HEAL_ITEMS} Heal Potions, ${CATCH_BALLS} Bashmon Balls${NC}"
                else
                    print_at $(( row + 2 )) "$mid" "${LRED}Not enough money!${NC}          "
                    sleep 1
                    print_at $(( row + 2 )) "$mid" "                              "
                fi
                ;;
            2)
                if [[ $PLAYER_MONEY -ge 30 ]]; then
                    (( PLAYER_MONEY -= 30 ))
                    (( CATCH_BALLS++ ))
                    print_at $(( row + 2 )) "$mid" "${LGREEN}Bought Bashmon Ball!${NC}       "
                    sleep 0.8
                    print_at $(( row + 2 )) "$mid" "                              "
                    print_at $(( row - 5 )) "$mid" "${LWHITE}💰 Your money: ${LYELLOW}\$${PLAYER_MONEY}${NC}  "
                    print_at "$row" "$mid" "${DIM}Currently: ${HEAL_ITEMS} Heal Potions, ${CATCH_BALLS} Bashmon Balls${NC}"
                else
                    print_at $(( row + 2 )) "$mid" "${LRED}Not enough money!${NC}          "
                    sleep 1
                    print_at $(( row + 2 )) "$mid" "                              "
                fi
                ;;
            q|Q) shop_open=false ;;
        esac
    done
}

# --- Game Over Screen -------------------------------------------------------

show_game_over() {
    tput clear
    draw_box 1 1 "$TERM_ROWS" "$TERM_COLS" "$LRED" "GAME OVER"
    local mid_r=$(( TERM_ROWS / 2 - 4 ))
    local mid_c=$(( TERM_COLS / 2 - 15 ))

    print_at "$mid_r" "$mid_c" "${LRED}${BOLD}"
    cat << 'EOF'
  ___   _   __  __ ___    _____   _____ ___ 
 / __| /_\ |  \/  | __|  / _ \ \ / / __| _ \
| (_ |/ _ \| |\/| | _|  | (_) \ V /| _||   /
 \___/_/ \_\_|  |_|___|  \___/ \_/ |___|_|_\
EOF
    echo -en "${NC}"
    (( mid_r += 5 ))
    print_at "$mid_r" $(( mid_c + 2 )) "All your Bashmon have fainted!"
    (( mid_r += 2 ))
    print_at "$mid_r" $(( mid_c + 2 )) "Battles Won: ${LGREEN}${BATTLES_WON}${NC} / ${TOTAL_BATTLES}"
    (( mid_r++ ))
    print_at "$mid_r" $(( mid_c + 2 )) "Monsters Caught: ${LMAGENTA}${TOTAL_CAUGHT}${NC}"
    (( mid_r += 2 ))
    print_at "$mid_r" $(( mid_c + 2 )) "${DIM}Press any key to return to title...${NC}"
    read -rsn1
}

# --- Victory Screen ---------------------------------------------------------

show_victory() {
    local earned=$1
    tput clear
    draw_box 1 1 "$TERM_ROWS" "$TERM_COLS" "$LGREEN" "VICTORY!"
    local mid_r=$(( TERM_ROWS / 2 - 3 ))
    local mid_c=$(( TERM_COLS / 2 - 15 ))

    print_at "$mid_r" "$mid_c" "${LGREEN}${BOLD}"
    cat << 'EOF'
 __   _____ ___ _____ ___  _____   _ 
 \ \ / /_ _/ __|_   _/ _ \| _ \ \ / /
  \ V / | | (__  | || (_) |   /\ V / 
   \_/ |___\___| |_| \___/|_|_\ |_|  
EOF
    echo -en "${NC}"
    (( mid_r += 5 ))
    print_at "$mid_r" $(( mid_c + 4 )) "${LGREEN}You defeated ${ENEMY_NAME}!${NC}"
    (( mid_r++ ))
    print_at "$mid_r" $(( mid_c + 4 )) "${LYELLOW}Earned: \$${earned}${NC}"
    (( mid_r += 2 ))
    print_at "$mid_r" $(( mid_c + 4 )) "${DIM}Press any key to continue...${NC}"
    read -rsn1
}

# --- Catch Animation --------------------------------------------------------

show_catch_animation() {
    local success=$1
    local ball_row=8
    local ball_col=25

    # Ball flying animation
    local i
    for (( i = 0; i < 5; i++ )); do
        print_at "$ball_row" $(( ball_col + i * 2 )) "${LBLUE}⚾${NC}"
        sleep 0.1
        print_at "$ball_row" $(( ball_col + i * 2 )) " "
    done

    # Shake animation
    for (( i = 0; i < 3; i++ )); do
        print_at "$ball_row" $(( ball_col + 10 )) "${LBLUE}【⚾】${NC}"
        sleep 0.3
        print_at "$ball_row" $(( ball_col + 10 )) "${LBLUE}[⚾] ${NC}"
        sleep 0.3
    done

    if [[ "$success" == "true" ]]; then
        print_at "$ball_row" $(( ball_col + 10 )) "${LGREEN}★⚾★${NC}"
        sleep 0.5
        print_at $(( ball_row + 1 )) $(( ball_col + 6 )) "${BOLD}${LGREEN}CAUGHT!${NC}"
    else
        print_at "$ball_row" $(( ball_col + 10 )) "${LRED}✗   ${NC}"
        sleep 0.5
        print_at $(( ball_row + 1 )) $(( ball_col + 6 )) "${LRED}Broke free!${NC}"
    fi
    sleep 1
    # Clear animation area
    print_at "$ball_row" $(( ball_col )) "                              "
    print_at $(( ball_row + 1 )) $(( ball_col )) "                              "
}

# --- Type Effectiveness -----------------------------------------------------

type_effectiveness() {
    local atk_type="$1"
    local def_type="$2"
    # Returns multiplier * 10 (to avoid floats): 20=2x, 10=1x, 5=0.5x
    case "${atk_type}:${def_type}" in
        FIRE:GRASS|FIRE:WATER)    echo 20 ;;
        FIRE:FIRE|WATER:FIRE)     echo 5 ;;
        WATER:FIRE)               echo 20 ;;
        WATER:GRASS)              echo 5 ;;
        WATER:WATER)              echo 10 ;;
        GRASS:WATER)              echo 20 ;;
        GRASS:FIRE)               echo 5 ;;
        GRASS:GRASS)              echo 10 ;;
        ELECTRIC:WATER)           echo 20 ;;
        ELECTRIC:GRASS)           echo 5 ;;
        ELECTRIC:ELECTRIC)        echo 10 ;;
        GHOST:GHOST)              echo 20 ;;
        GHOST:NORMAL)             echo 5 ;;
        NORMAL:GHOST)             echo 5 ;;
        *)                        echo 10 ;;
    esac
}

# --- Damage Calculation -----------------------------------------------------

calc_damage() {
    local atk=$1 def=$2 atk_type="$3" def_type="$4"
    local base=$(( atk * 2 / (def + 1) + RANDOM % 5 ))
    local eff
    eff=$(type_effectiveness "$atk_type" "$def_type")
    echo $(( base * eff / 10 ))
}

# --- Find Active Monster (first non-KO) ------------------------------------

find_active_monster() {
    local i
    for (( i = 0; i < TEAM_SIZE; i++ )); do
        if [[ ${TEAM_HP[$i]} -gt 0 ]]; then
            ACTIVE_MON=$i
            return 0
        fi
    done
    return 1  # All KO
}

# --- Check Team Alive -------------------------------------------------------

team_alive() {
    local i
    for (( i = 0; i < TEAM_SIZE; i++ )); do
        [[ ${TEAM_HP[$i]} -gt 0 ]] && return 0
    done
    return 1
}

# --- Battle Engine ----------------------------------------------------------

start_battle() {
    # Spawn random enemy
    ENEMY_IDX=$(( RANDOM % ${#MONSTER_NAMES[@]} ))
    ENEMY_NAME="${MONSTER_NAMES[$ENEMY_IDX]}"
    ENEMY_TYPE="${MONSTER_TYPES[$ENEMY_IDX]}"
    ENEMY_MAX_HP="${MONSTER_MAX_HP[$ENEMY_IDX]}"
    ENEMY_HP=$ENEMY_MAX_HP
    ENEMY_ATK="${MONSTER_ATK[$ENEMY_IDX]}"
    ENEMY_DEF="${MONSTER_DEF[$ENEMY_IDX]}"
    ENEMY_SPEED="${MONSTER_SPEED[$ENEMY_IDX]}"

    (( TOTAL_BATTLES++ ))
    BATTLE_MESSAGES=()
    MENU_CURSOR=0

    # Ensure active monster is alive
    find_active_monster

    # Draw initial battle screen
    tput clear
    draw_box 1 1 "$TERM_ROWS" "$TERM_COLS" "$CYAN"
    draw_divider
    draw_box 1 1 3 "$DIVIDER_COL" "$LRED" "⚔ BATTLE!"
    draw_status_panel
    draw_battle_scene

    add_battle_msg "${LRED}A wild ${BOLD}${ENEMY_NAME}${NC}${LRED} appeared!${NC}"
    add_battle_msg "${LWHITE}Type: ${NC}$(type_color "$ENEMY_TYPE")${ENEMY_TYPE}${NC}  ${DIM}${MONSTER_RARITY[$ENEMY_IDX]}${NC}"

    draw_battle_menu
    battle_loop
}

enemy_turn() {
    sleep 0.5
    local player_midx="${TEAM_IDX[$ACTIVE_MON]}"
    local player_type="${MONSTER_TYPES[$player_midx]}"

    local dmg
    dmg=$(calc_damage "$ENEMY_ATK" "${TEAM_DEF[$ACTIVE_MON]}" "$ENEMY_TYPE" "$player_type")
    local eff
    eff=$(type_effectiveness "$ENEMY_TYPE" "$player_type")

    TEAM_HP[$ACTIVE_MON]=$(( TEAM_HP[$ACTIVE_MON] - dmg ))
    [[ ${TEAM_HP[$ACTIVE_MON]} -lt 0 ]] && TEAM_HP[$ACTIVE_MON]=0

    local eff_msg=""
    if   [[ $eff -gt 10 ]]; then eff_msg=" ${LYELLOW}Super effective!${NC}"
    elif [[ $eff -lt 10 ]]; then eff_msg=" ${DIM}Not very effective...${NC}"
    fi

    add_battle_msg "${LRED}${ENEMY_NAME}${NC} attacks for ${BOLD}${LRED}${dmg}${NC} dmg!${eff_msg}"

    if [[ ${TEAM_HP[$ACTIVE_MON]} -le 0 ]]; then
        local mon_name="${MONSTER_NAMES[$player_midx]}"
        add_battle_msg "${LRED}${mon_name}${NC} fainted!"
        TEAM_HP[$ACTIVE_MON]=0

        draw_battle_scene
        draw_status_panel

        # Try to switch to next alive monster
        if find_active_monster; then
            local new_name="${MONSTER_NAMES[${TEAM_IDX[$ACTIVE_MON]}]}"
            add_battle_msg "${LGREEN}Go ${new_name}!${NC}"
            draw_battle_scene
            draw_status_panel
        fi
    else
        draw_battle_scene
        draw_status_panel
    fi
}

player_attack() {
    local player_midx="${TEAM_IDX[$ACTIVE_MON]}"
    local player_type="${MONSTER_TYPES[$player_midx]}"
    local player_name="${MONSTER_NAMES[$player_midx]}"

    local dmg
    dmg=$(calc_damage "${TEAM_ATK[$ACTIVE_MON]}" "$ENEMY_DEF" "$player_type" "$ENEMY_TYPE")
    local eff
    eff=$(type_effectiveness "$player_type" "$ENEMY_TYPE")

    ENEMY_HP=$(( ENEMY_HP - dmg ))
    [[ $ENEMY_HP -lt 0 ]] && ENEMY_HP=0

    local eff_msg=""
    if   [[ $eff -gt 10 ]]; then eff_msg=" ${LYELLOW}Super effective!${NC}"
    elif [[ $eff -lt 10 ]]; then eff_msg=" ${DIM}Not very effective...${NC}"
    fi

    add_battle_msg "${LGREEN}${player_name}${NC} attacks for ${BOLD}${LGREEN}${dmg}${NC} dmg!${eff_msg}"
    draw_battle_scene
}

player_heal() {
    if [[ $HEAL_ITEMS -le 0 ]]; then
        add_battle_msg "${LRED}No heal items left!${NC}"
        return 1
    fi

    local player_midx="${TEAM_IDX[$ACTIVE_MON]}"
    local player_name="${MONSTER_NAMES[$player_midx]}"
    local heal_amt=$(( TEAM_MAX_HP[$ACTIVE_MON] / 3 ))
    (( HEAL_ITEMS-- ))

    TEAM_HP[$ACTIVE_MON]=$(( TEAM_HP[$ACTIVE_MON] + heal_amt ))
    if [[ ${TEAM_HP[$ACTIVE_MON]} -gt ${TEAM_MAX_HP[$ACTIVE_MON]} ]]; then
        TEAM_HP[$ACTIVE_MON]="${TEAM_MAX_HP[$ACTIVE_MON]}"
    fi

    add_battle_msg "${LGREEN}${player_name}${NC} healed ${BOLD}${LGREEN}${heal_amt}${NC} HP!"
    draw_battle_scene
    draw_status_panel
    return 0
}

player_catch() {
    if [[ $CATCH_BALLS -le 0 ]]; then
        add_battle_msg "${LRED}No Bashmon Balls left!${NC}"
        return 1
    fi
    (( CATCH_BALLS-- ))

    local catch_rate="${MONSTER_CATCH[$ENEMY_IDX]}"
    # HP factor: lower enemy HP = easier catch
    local hp_factor=$(( 100 - ENEMY_HP * 100 / ENEMY_MAX_HP ))
    local effective_rate=$(( catch_rate + hp_factor / 3 ))
    [[ $effective_rate -gt 99 ]] && effective_rate=99

    local roll=$(( RANDOM % 100 ))
    local caught="false"
    [[ $roll -lt $effective_rate ]] && caught="true"

    show_catch_animation "$caught"

    if [[ "$caught" == "true" ]]; then
        add_battle_msg "${LGREEN}${BOLD}Caught ${ENEMY_NAME}!${NC}"
        (( TOTAL_CAUGHT++ ))
        (( PLAYER_MONEY += 10 ))

        if [[ $TEAM_SIZE -lt $MAX_TEAM ]]; then
            TEAM_IDX+=("$ENEMY_IDX")
            TEAM_HP+=("$ENEMY_HP")
            TEAM_MAX_HP+=("${MONSTER_MAX_HP[$ENEMY_IDX]}")
            TEAM_ATK+=("${MONSTER_ATK[$ENEMY_IDX]}")
            TEAM_DEF+=("${MONSTER_DEF[$ENEMY_IDX]}")
            TEAM_SPEED+=("${MONSTER_SPEED[$ENEMY_IDX]}")
            (( TEAM_SIZE++ ))
            add_battle_msg "${ENEMY_NAME} joined your team! (${TEAM_SIZE}/${MAX_TEAM})"
        else
            add_battle_msg "${DIM}Team full! Released to collection.${NC}"
        fi

        draw_status_panel
        draw_battle_log
        sleep 1.5
        return 0  # Battle ends
    else
        add_battle_msg "${LRED}${ENEMY_NAME}${NC} broke free!"
        return 1
    fi
}

player_run() {
    local player_speed="${TEAM_SPEED[$ACTIVE_MON]}"
    local run_chance=$(( player_speed * 10 / (player_speed + ENEMY_SPEED) * 10 ))
    local roll=$(( RANDOM % 100 ))

    if [[ $roll -lt 60 ]]; then
        add_battle_msg "${LWHITE}Got away safely!${NC}"
        draw_battle_log
        sleep 1
        return 0  # Escaped
    else
        add_battle_msg "${LRED}Can't escape!${NC}"
        return 1
    fi
}

perform_switch() {
    local target=$1
    if [[ $target -eq $ACTIVE_MON ]]; then
        add_battle_msg "${LWHITE}Already using this Bashmon!${NC}"
        return 1
    fi
    if [[ ${TEAM_HP[$target]} -le 0 ]]; then
        add_battle_msg "${LRED}That Bashmon has fainted!${NC}"
        return 1
    fi
    local old_name="${MONSTER_NAMES[${TEAM_IDX[$ACTIVE_MON]}]}"
    ACTIVE_MON=$target
    local new_name="${MONSTER_NAMES[${TEAM_IDX[$ACTIVE_MON]}]}"
    add_battle_msg "${LWHITE}Come back ${old_name}! Go ${LGREEN}${new_name}${NC}${LWHITE}!${NC}"
    draw_battle_scene
    draw_status_panel
    return 0
}

battle_loop() {
    local battle_over=false
    local result=""

    while ! $battle_over; do
        draw_battle_menu

        # Read player input
        local key
        read -rsn1 key

        # Arrow key handling (escape sequences)
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 rest
            key="${key}${rest}"
        fi

        case "$key" in
            # Menu navigation
            $'\x1b[A'|w|W)  # Up
                (( MENU_CURSOR-- ))
                [[ $MENU_CURSOR -lt 0 ]] && MENU_CURSOR=$(( MENU_SIZE - 1 ))
                ;;
            $'\x1b[B'|s|S)  # Down
                (( MENU_CURSOR++ ))
                [[ $MENU_CURSOR -ge $MENU_SIZE ]] && MENU_CURSOR=0
                ;;
            # Direct number selection
            1) MENU_CURSOR=0; key=$'\n' ;;
            2) MENU_CURSOR=1; key=$'\n' ;;
            3) MENU_CURSOR=2; key=$'\n' ;;
            4) MENU_CURSOR=3; key=$'\n' ;;
            5) MENU_CURSOR=4; key=$'\n' ;;
        esac

        # Confirm selection
        if [[ "$key" == $'\n' || "$key" == "" || "$key" == $'\r' ]]; then
            local player_acted=false
            local battle_ended=false

            case $MENU_CURSOR in
                0)  # ATTACK
                    player_attack
                    player_acted=true

                    if [[ $ENEMY_HP -le 0 ]]; then
                        local reward=$(( MONSTER_ATK[$ENEMY_IDX] + ENEMY_MAX_HP / 3 ))
                        (( PLAYER_MONEY += reward ))
                        (( BATTLES_WON++ ))
                        add_battle_msg "${LGREEN}${BOLD}${ENEMY_NAME} fainted!${NC}"
                        add_battle_msg "${LYELLOW}Earned \$${reward}!${NC}"
                        draw_status_panel
                        draw_battle_log
                        sleep 1.5
                        show_victory "$reward"
                        battle_over=true
                        result="win"
                    fi
                    ;;

                1)  # HEAL
                    if player_heal; then
                        player_acted=true
                    fi
                    ;;

                2)  # CATCH
                    if player_catch; then
                        battle_over=true
                        result="caught"
                    else
                        player_acted=true
                    fi
                    ;;

                3)  # SWITCH
                    local switch_cursor=$ACTIVE_MON
                    local switch_done=false
                    while ! $switch_done; do
                        draw_switch_menu
                        local sk
                        read -rsn1 sk
                        if [[ "$sk" == $'\x1b' ]]; then
                            read -rsn2 -t 0.1 sr
                            sk="${sk}${sr}"
                        fi
                        case "$sk" in
                            $'\x1b[A'|w|W)
                                (( switch_cursor-- ))
                                [[ $switch_cursor -lt 0 ]] && switch_cursor=$(( TEAM_SIZE - 1 ))
                                ;;
                            $'\x1b[B'|s|S)
                                (( switch_cursor++ ))
                                [[ $switch_cursor -ge $TEAM_SIZE ]] && switch_cursor=0
                                ;;
                            $'\n'|""| $'\r')
                                if perform_switch "$switch_cursor"; then
                                    player_acted=true
                                fi
                                switch_done=true
                                ;;
                            q|Q) switch_done=true ;;
                        esac
                    done
                    # Redraw battle menu area
                    tput clear
                    draw_box 1 1 "$TERM_ROWS" "$TERM_COLS" "$CYAN"
                    draw_divider
                    draw_box 1 1 3 "$DIVIDER_COL" "$LRED" "⚔ BATTLE!"
                    draw_status_panel
                    draw_battle_scene
                    draw_battle_log
                    ;;

                4)  # RUN
                    if player_run; then
                        battle_over=true
                        result="ran"
                    else
                        player_acted=true
                    fi
                    ;;
            esac

            # Enemy turn (if player acted and battle not over)
            if $player_acted && ! $battle_over; then
                # Speed check: fast player might get bonus
                enemy_turn

                if ! team_alive; then
                    add_battle_msg "${LRED}${BOLD}All Bashmon fainted!${NC}"
                    draw_battle_log
                    sleep 1.5
                    battle_over=true
                    result="lost"
                fi
            fi
        fi

        # Quit battle (debug/escape)
        if [[ "$key" == "q" || "$key" == "Q" ]]; then
            battle_over=true
            result="quit"
        fi
    done

    # Post-battle
    if [[ "$result" == "lost" ]]; then
        show_game_over
        # Reset team HP to 1 each (revival)
        local i
        for (( i = 0; i < TEAM_SIZE; i++ )); do
            TEAM_HP[$i]=1
        done
        find_active_monster
    fi
}

# --- Title Screen -----------------------------------------------------------

show_title() {
    tput clear
    draw_box 1 1 "$TERM_ROWS" "$TERM_COLS" "$LCYAN" ""

    local mid_r=$(( TERM_ROWS / 2 - 8 ))
    local mid_c=$(( TERM_COLS / 2 - 25 ))

    print_at "$mid_r" "$mid_c" "${LGREEN}${BOLD}"
    cat << 'TITLE_ART'
 ██████╗  █████╗ ███████╗██╗  ██╗███╗   ███╗ ██████╗ ███╗   ██╗
 ██╔══██╗██╔══██╗██╔════╝██║  ██║████╗ ████║██╔═══██╗████╗  ██║
 ██████╔╝███████║███████╗███████║██╔████╔██║██║   ██║██╔██╗ ██║
 ██╔══██╗██╔══██║╚════██║██╔══██║██║╚██╔╝██║██║   ██║██║╚██╗██║
 ██████╔╝██║  ██║███████║██║  ██║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
 ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
TITLE_ART
    echo -en "${NC}"

    (( mid_r += 7 ))
    print_at "$mid_r" $(( mid_c + 8 )) "${LYELLOW}${BOLD}~ TUI Monster Tamer ~${NC}"
    (( mid_r += 2 ))

    # Show some monster previews
    print_at "$mid_r" $(( mid_c + 2 )) "$(type_color FIRE)FIRE${NC}  $(type_color WATER)WATER${NC}  $(type_color GRASS)GRASS${NC}  $(type_color ELECTRIC)ELECTRIC${NC}  $(type_color GHOST)GHOST${NC}"
    (( mid_r += 2 ))

    # Animated monster display
    local preview_monsters=("Flambit" "Aquarel" "Leafrog" "Zappix" "Spookle")
    local prev_types=("FIRE" "WATER" "GRASS" "ELECTRIC" "GHOST")
    local i col
    for (( i = 0; i < 5; i++ )); do
        col=$(( mid_c + i * 10 ))
        local tc
        tc=$(type_color "${prev_types[$i]}")
        print_at "$mid_r" "$col" "${tc}${preview_monsters[$i]}${NC}"
    done

    (( mid_r += 3 ))
    print_at "$mid_r" $(( mid_c + 6 )) "${LWHITE}Catch, train, and battle Bashmon!${NC}"
    (( mid_r += 2 ))
    print_at "$mid_r" $(( mid_c + 10 )) "${DIM}You start with ${LRED}Flambit${NC}${DIM}, a fire type.${NC}"
    (( mid_r += 3 ))

    # Blinking start prompt
    local blink=true
    local frame=0
    print_at "$mid_r" $(( mid_c + 10 )) "${BOLD}${LGREEN}▶ Press ENTER to start! ◀${NC}"
    (( mid_r++ ))
    print_at "$mid_r" $(( mid_c + 12 )) "${DIM}[Q] to quit${NC}"

    # Wait for enter
    while true; do
        local key
        read -rsn1 -t 0.5 key
        case "$key" in
            "") break ;;  # Enter
            q|Q) restore_terminal; exit 0 ;;
        esac
        # Blink the prompt
        (( frame++ ))
        if (( frame % 2 == 0 )); then
            print_at "$mid_r" $(( mid_c + 10 )) "${BOLD}${LGREEN}▶ Press ENTER to start! ◀${NC}"
        else
            print_at "$mid_r" $(( mid_c + 10 )) "${DIM}  Press ENTER to start!  ${NC}"
        fi
    done
}

# --- Main Overworld Loop ----------------------------------------------------

overworld_loop() {
    local running=true

    while $running; do
        draw_field
        draw_status_panel

        local key
        read -rsn1 key

        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 rest
            key="${key}${rest}"
        fi

        case "$key" in
            ""| $'\r'| $'\n')  # Enter: walk in grass
                (( STEPS++ ))
                draw_field

                # Encounter chance: increases with steps
                local base_chance=40
                local step_bonus=$(( STEPS / 10 ))
                [[ $step_bonus -gt 30 ]] && step_bonus=30
                local encounter_chance=$(( base_chance + step_bonus ))

                if (( RANDOM % 100 < encounter_chance )); then
                    # Battle encounter!
                    setup_terminal
                    start_battle

                    # After battle, check if all dead
                    if ! team_alive; then
                        find_active_monster || true
                        # Reset with 1 HP
                        local i
                        for (( i = 0; i < TEAM_SIZE; i++ )); do
                            [[ ${TEAM_HP[$i]} -le 0 ]] && TEAM_HP[$i]=1
                        done
                        find_active_monster
                    fi
                else
                    # No encounter - show rustling
                    local rrow=$(( TERM_ROWS - 8 ))
                    draw_box "$rrow" 2 3 40 "$DIM$GREEN" ""
                    print_at $(( rrow + 1 )) 4 "${LGREEN}The grass rustles... nothing appears.${NC}"
                    sleep 0.8
                fi
                ;;

            h|H)  # Heal
                if heal_team; then
                    draw_field
                    local hrow=$(( TERM_ROWS - 8 ))
                    draw_box "$hrow" 2 3 40 "$LGREEN" ""
                    print_at $(( hrow + 1 )) 4 "${LGREEN}Used Heal Potion! Team restored!${NC}"
                    draw_status_panel
                    sleep 1
                else
                    local hrow=$(( TERM_ROWS - 8 ))
                    draw_box "$hrow" 2 3 40 "$LRED" ""
                    print_at $(( hrow + 1 )) 4 "${LRED}No Heal Potions left!${NC}"
                    sleep 1
                fi
                ;;

            s|S)  # Shop
                draw_shop
                ;;

            q|Q)  # Quit
                running=false
                ;;

            t|T)  # Team view (bonus)
                show_team_detail
                ;;
        esac
    done
}

# --- Team Detail View -------------------------------------------------------

show_team_detail() {
    tput clear
    draw_box 1 1 "$TERM_ROWS" "$TERM_COLS" "$LMAGENTA" "🐾 YOUR BASHMON TEAM"

    local row=4
    local col=3

    local i
    for (( i = 0; i < TEAM_SIZE; i++ )); do
        local midx="${TEAM_IDX[$i]}"
        local mname="${MONSTER_NAMES[$midx]}"
        local mtype="${MONSTER_TYPES[$midx]}"
        local chp="${TEAM_HP[$i]}"
        local mhp="${TEAM_MAX_HP[$i]}"
        local matk="${TEAM_ATK[$i]}"
        local mdef="${TEAM_DEF[$i]}"
        local mspd="${TEAM_SPEED[$i]}"
        local mrarity="${MONSTER_RARITY[$midx]}"
        local tc
        tc=$(type_color "$mtype")

        # Box for each monster
        local box_w=$(( (TERM_COLS - 6) / 3 ))
        local box_col=$(( col + (i % 3) * box_w ))
        local box_row=$(( row + (i / 3) * 8 ))

        draw_box "$box_row" "$box_col" 7 "$box_w" "$tc" ""

        local ir=$(( box_row + 1 ))
        local ic=$(( box_col + 2 ))

        if [[ $i -eq $ACTIVE_MON ]]; then
            print_at "$ir" "$ic" "${BOLD}${LGREEN}▶${NC} ${tc}${mname}${NC} ${BOLD}★${NC}"
        else
            print_at "$ir" "$ic" "  ${tc}${mname}${NC}"
        fi
        (( ir++ ))
        print_at "$ir" "$ic" "  ${tc}[${mtype}]${NC} ${DIM}${mrarity}${NC}"
        (( ir++ ))
        local pct=$(( chp * 100 / mhp ))
        local hp_color
        if   [[ $pct -gt 60 ]]; then hp_color="$LGREEN"
        elif [[ $pct -gt 30 ]]; then hp_color="$LYELLOW"
        else                          hp_color="$LRED"
        fi
        if [[ $chp -le 0 ]]; then
            print_at "$ir" "$ic" "  ${LRED}FAINTED${NC}"
        else
            print_at "$ir" "$ic" "  ${hp_color}HP:${chp}/${mhp}${NC}"
        fi
        (( ir++ ))
        print_at "$ir" "$ic" "  ${LRED}ATK:${matk}${NC} ${LBLUE}DEF:${mdef}${NC} ${LYELLOW}SPD:${mspd}${NC}"
        (( ir++ ))
        draw_hp_bar "$ir" $(( ic + 2 )) "$chp" "$mhp" $(( box_w - 6 ))
    done

    local brow=$(( TERM_ROWS - 3 ))
    print_at "$brow" 4 "${DIM}Press any key to return...${NC}"
    read -rsn1
}

# --- Entry Point ------------------------------------------------------------

main() {
    setup_terminal
    show_title
    init_player
    overworld_loop
}

main
```

## How to Run

```bash
chmod +x bashmon.sh
./bashmon.sh
```

## Architecture & Features

### Layout
```
┌─────────────────────────────────────────────────────╦──────────────────────┐
│                  ⚔ BATTLE ARENA                     ║    📊 STATUS         │
│  [Enemy ASCII Art]    Enemy Name/Type/HP             ║  Money/Items/Stats   │
│  ────────────────────────────────────────────────── ║  Team HP bars        │
│  [Player ASCII Art]   Player Name/Type/HP            ║  Active marker       │
│  ┌──────────────────────────────────────────────┐   ║                      │
│  │               BATTLE LOG                     │   ║  Controls hint       │
│  └──────────────────────────────────────────────┘   ║                      │
└─────────────────────────────────────────────────────╩──────────────────────┘
```

### Systems Implemented
| System | Details |
|---|---|
| **16 Monsters** | 4 rarity tiers, 6 types with elemental matchups |
| **Type Chart** | Fire/Water/Grass/Electric/Ghost/Normal effectiveness |
| **Battle Menu** | Attack, Heal, Catch, Switch, Run with cursor navigation |
| **Catch System** | Rate based on rarity + enemy HP percentage |
| **Economy** | Earn money from wins, buy items at shop |
| **Team** | Up to 6 Bashmon with switching during battle |
| **Overworld** | Grass field, step counter, random encounters |