#!/usr/bin/env bash
# =============================================================================
# TUI Adventure MUD-Lite — Single-file Bash RPG
# =============================================================================
# Dependencies: bash 4+, tput, standard coreutils
# Controls: Type commands at the prompt; 'help' for command list
# =============================================================================

# ─── Terminal / Safety Setup ──────────────────────────────────────────────────
set -o nounset

SAVE_FILE="/tmp/.mud_save_$$"
LOG_FILE="/tmp/.mud_log_$$"

cleanup() {
    tput rmcup 2>/dev/null           # Restore normal screen buffer
    tput cnorm 2>/dev/null           # Show cursor
    tput sgr0  2>/dev/null           # Reset attributes
    stty echo  2>/dev/null           # Restore echo
    rm -f "$SAVE_FILE" "$LOG_FILE"
    echo "Thanks for playing MUD-Lite. Farewell, adventurer."
}
trap cleanup EXIT INT TERM

# ─── Colour / Attribute Helpers ───────────────────────────────────────────────
setup_colors() {
    if tput colors &>/dev/null && [[ $(tput colors) -ge 8 ]]; then
        C_RESET=$(tput sgr0)
        C_BOLD=$(tput bold)
        C_DIM=$(tput dim 2>/dev/null || echo "")
        C_BLACK=$(tput setaf 0)
        C_RED=$(tput setaf 1)
        C_GREEN=$(tput setaf 2)
        C_YELLOW=$(tput setaf 3)
        C_BLUE=$(tput setaf 4)
        C_MAGENTA=$(tput setaf 5)
        C_CYAN=$(tput setaf 6)
        C_WHITE=$(tput setaf 7)
        C_BG_BLACK=$(tput setab 0)
        C_BG_BLUE=$(tput setab 4)
        C_BG_RED=$(tput setab 1)
        C_BG_GREEN=$(tput setab 2)
        C_BG_YELLOW=$(tput setab 3)
        C_BG_MAGENTA=$(tput setab 5)
        C_BG_CYAN=$(tput setab 6)
        C_BG_WHITE=$(tput setab 7)
    else
        C_RESET="" C_BOLD="" C_DIM="" C_BLACK="" C_RED="" C_GREEN=""
        C_YELLOW="" C_BLUE="" C_MAGENTA="" C_CYAN="" C_WHITE=""
        C_BG_BLACK="" C_BG_BLUE="" C_BG_RED="" C_BG_GREEN=""
        C_BG_YELLOW="" C_BG_MAGENTA="" C_BG_CYAN="" C_BG_WHITE=""
    fi
}

# ─── Terminal Dimensions ──────────────────────────────────────────────────────
get_dims() {
    TERM_ROWS=$(tput lines)
    TERM_COLS=$(tput cols)
    # Minimum playable size
    if [[ $TERM_ROWS -lt 24 || $TERM_COLS -lt 80 ]]; then
        tput rmcup 2>/dev/null
        echo "Terminal too small. Need at least 80×24 (current: ${TERM_COLS}×${TERM_ROWS})."
        exit 1
    fi
}

# ─── Drawing Primitives ───────────────────────────────────────────────────────
# move_to ROW COL
move_to() { tput cup "$(($1-1))" "$(($2-1))"; }

# draw_hline ROW COL WIDTH CHAR
draw_hline() {
    local row=$1 col=$2 width=$3 char="${4:-─}"
    move_to "$row" "$col"
    local i; for ((i=0; i<width; i++)); do printf "%s" "$char"; done
}

# draw_vline ROW COL HEIGHT CHAR
draw_vline() {
    local row=$1 col=$2 height=$3 char="${4:-│}"
    local i; for ((i=0; i<height; i++)); do
        move_to $((row+i)) "$col"
        printf "%s" "$char"
    done
}

# draw_box ROW COL HEIGHT WIDTH TITLE
draw_box() {
    local row=$1 col=$2 h=$3 w=$4 title="${5:-}"
    local inner_w=$((w-2))
    # Top border
    move_to "$row" "$col"
    printf "┌"
    if [[ -n "$title" ]]; then
        local tlen=${#title}
        local before=$(( (inner_w - tlen - 2) / 2 ))
        local after=$(( inner_w - tlen - 2 - before ))
        printf "%${before}s" "" | tr ' ' '─'
        printf "[ %s ]" "$title"
        printf "%${after}s" "" | tr ' ' '─'
    else
        printf "%${inner_w}s" "" | tr ' ' '─'
    fi
    printf "┐"
    # Sides
    draw_vline $((row+1)) "$col"         $((h-2)) "│"
    draw_vline $((row+1)) $((col+w-1))   $((h-2)) "│"
    # Bottom border
    move_to $((row+h-1)) "$col"
    printf "└"
    printf "%${inner_w}s" "" | tr ' ' '─'
    printf "┘"
    # Clear interior
    local i; for ((i=1; i<h-1; i++)); do
        move_to $((row+i)) $((col+1))
        printf "%${inner_w}s" ""
    done
}

# print_in_box ROW COL WIDTH TEXT [COLOR]
# Prints text clipped to width inside a box (no border chars)
print_line_in() {
    local row=$1 col=$2 width=$3 text="$4" color="${5:-}"
    # Strip ANSI for length calculation, then print with color
    local plain="${text//$'\e'[*m/}"
    plain=$(printf "%s" "$plain" | sed 's/\x1b\[[0-9;]*m//g')
    local len=${#plain}
    if [[ $len -gt $width ]]; then
        text="${text:0:$width}"
    fi
    move_to "$row" "$col"
    printf "%s%s%s%-*s%s" \
        "${color}" "${C_RESET}" "${color}" "$width" "${text}" "${C_RESET}"
}

# ─── Layout Constants (computed after get_dims) ───────────────────────────────
compute_layout() {
    # ┌─ TITLE ──────────────────────────────────────────────────────────────┐
    # │                        ROOM PANE                                     │
    # ├──────────────────────────────────────┬──────────────────────────────┤
    # │          DESCRIPTION PANE            │       INVENTORY PANE         │
    # ├──────────────────────────────────────┴──────────────────────────────┤
    # │                        MESSAGE LOG PANE                              │
    # ├──────────────────────────────────────────────────────────────────────┤
    # │ STATUS BAR                                                           │
    # ├──────────────────────────────────────────────────────────────────────┤
    # │ > INPUT                                                              │
    # └──────────────────────────────────────────────────────────────────────┘

    TITLE_ROW=1
    TITLE_HEIGHT=3

    MAP_ROW=$((TITLE_ROW + TITLE_HEIGHT - 1))
    MAP_HEIGHT=7
    MAP_COL=1
    MAP_WIDTH=$TERM_COLS

    SPLIT_ROW=$((MAP_ROW + MAP_HEIGHT - 1))
    # Description + Inventory side by side
    local mid=$((TERM_COLS / 2))
    DESC_COL=1
    DESC_WIDTH=$mid
    INV_COL=$mid
    INV_WIDTH=$((TERM_COLS - mid + 1))
    DESC_INV_HEIGHT=10
    DESC_ROW=$SPLIT_ROW
    INV_ROW=$SPLIT_ROW

    LOG_ROW=$((DESC_ROW + DESC_INV_HEIGHT - 1))
    LOG_HEIGHT=$((TERM_ROWS - LOG_ROW - 3))
    [[ $LOG_HEIGHT -lt 3 ]] && LOG_HEIGHT=3
    LOG_COL=1
    LOG_WIDTH=$TERM_COLS

    STATUS_ROW=$((LOG_ROW + LOG_HEIGHT - 1))
    STATUS_HEIGHT=3

    INPUT_ROW=$((STATUS_ROW + STATUS_HEIGHT - 1))
    INPUT_HEIGHT=3

    # Interior regions (inside boxes)
    MAP_INNER_ROW=$((MAP_ROW + 1))
    MAP_INNER_COL=$((MAP_COL + 1))
    MAP_INNER_W=$((MAP_WIDTH - 2))
    MAP_INNER_H=$((MAP_HEIGHT - 2))

    DESC_INNER_ROW=$((DESC_ROW + 1))
    DESC_INNER_COL=$((DESC_COL + 1))
    DESC_INNER_W=$((DESC_WIDTH - 2))
    DESC_INNER_H=$((DESC_INV_HEIGHT - 2))

    INV_INNER_ROW=$((INV_ROW + 1))
    INV_INNER_COL=$((INV_COL + 1))
    INV_INNER_W=$((INV_WIDTH - 2))
    INV_INNER_H=$((DESC_INV_HEIGHT - 2))

    LOG_INNER_ROW=$((LOG_ROW + 1))
    LOG_INNER_COL=$((LOG_COL + 1))
    LOG_INNER_W=$((LOG_WIDTH - 2))
    LOG_INNER_H=$((LOG_HEIGHT - 2))
}

# ─── Game State ───────────────────────────────────────────────────────────────
declare -A PLAYER
PLAYER[name]="Adventurer"
PLAYER[room]="entrance"
PLAYER[hp]=30
PLAYER[max_hp]=30
PLAYER[gold]=10
PLAYER[xp]=0
PLAYER[level]=1
PLAYER[atk]=5
PLAYER[def]=2
PLAYER[moves]=0

declare -a INVENTORY=()

# Message log ring buffer
declare -a MSG_LOG=()
MAX_LOG=200

add_msg() {
    MSG_LOG+=("$*")
    if [[ ${#MSG_LOG[@]} -gt $MAX_LOG ]]; then
        MSG_LOG=("${MSG_LOG[@]:1}")
    fi
}

# ─── World Definition ─────────────────────────────────────────────────────────
# Rooms: ID → "name|description|exits_csv|items_csv|enemy"
# Exits format: dir:room_id,...
# Items: item_id,...
# Enemy: enemy_id or ""

declare -A ROOMS
declare -A ROOM_ITEMS   # room_id → space-separated list of item_ids present
declare -A ROOM_ENEMY   # room_id → enemy_id or ""
declare -A ROOM_VISITED # room_id → 1

define_world() {
    # ── Room definitions ────────────────────────────────────────────────────
    # Format: "Full Name|Description|exits|enemy"
    ROOMS[entrance]="Castle Entrance|You stand in the grand entrance of an ancient castle. Crumbling \
stone archways loom overhead. Torches flicker in iron sconces. The air is \
thick with the smell of damp moss and old secrets.|north:great_hall,east:guard_room,south:drawbridge|"

    ROOMS[drawbridge]="Drawbridge|A creaking wooden drawbridge stretches over a dark moat. \
Wind howls through the gaps in the planks. You can see the outline of the \
village in the distance. A rusted portcullis hangs above.|north:entrance|"

    ROOMS[great_hall]="Great Hall|A vast hall with a vaulted ceiling. Long oak tables lie \
overturned. A moth-eaten tapestry depicts a dragon. Shadows dance at the \
edges of your torchlight. Passages lead in every direction.|south:entrance,north:throne_room,\
east:kitchen,west:library,up:tower_base|goblin_scout"

    ROOMS[guard_room]="Guard Room|Bunk beds line the walls, their straw mattresses long \
since rotted. Rusty weapons hang on pegs. A faded duty roster is pinned \
to the door. Something skitters in the corner.|west:entrance,north:armory|rat_swarm"

    ROOMS[armory]="Armory|Racks of ancient weapons — most too corroded to use. A \
heavy iron door leads deeper in. A single torch still burns, magically, \
in its bracket. The floor is littered with bone.|south:guard_room,east:dungeon_cells|skeleton"

    ROOMS[dungeon_cells]="Dungeon Cells|Iron-barred cells line both walls. Most are empty \
save for chains and despair. One cell door hangs open; inside you find \
scratched markings on the wall — a crude map.|west:armory,north:torture_chamber|"

    ROOMS[torture_chamber]="Torture Chamber|You immediately regret entering. Dark stains \
cover the stone floor. Wicked devices line the walls. A heavy trapdoor \
in the floor is bolted shut. Something groans from the shadows.|south:dungeon_cells|troll"

    ROOMS[kitchen]="Castle Kitchen|Enormous hearths dominate this room. Copper pots hang \
from hooks, green with verdigris. Sacks of grain have burst open, and \
rats have been at them. A pantry door stands ajar.|west:great_hall,north:servants_quarters|"

    ROOMS[servants_quarters]="Servants' Quarters|Small, sparse rooms partitioned by thin \
wooden screens. Personal items — a comb, a broken lute — lie abandoned. \
A sense of melancholy lingers here.|south:kitchen|"

    ROOMS[library]="Library|Floor-to-ceiling bookshelves, though many volumes have \
turned to dust. A reading lectern bears an open tome. Moonlight streams \
through a narrow window. The silence is absolute.|east:great_hall,north:observatory|"

    ROOMS[observatory]="Observatory|A domed chamber with a great brass telescope aimed \
at a crack in the ceiling. Star charts paper the walls. A celestial \
orrery turns slowly — still powered by some forgotten magic.|south:library|"

    ROOMS[throne_room]="Throne Room|A grand throne of black stone dominates the far wall. \
Carved demons writhe along its arms. The floor is inlaid with dark marble. \
The air hums with residual power. This is the seat of whatever evil \
rules here.|south:great_hall,west:royal_vault|lich"

    ROOMS[royal_vault]="Royal Vault|The walls are lined with empty niches that once held \
treasure. A few gold coins glint in the dust. In the centre, an ornate \
chest sits on a pedestal — locked.|east:throne_room|"

    ROOMS[tower_base]="Tower Base|Spiral stone steps wind upward into darkness. The walls \
are carved with warning runes. An arrow slit lets in a sliver of grey sky. \
The steps creak ominously.|down:great_hall,up:tower_top|gargoyle"

    ROOMS[tower_top]="Tower Top|You emerge onto a wind-lashed battlement. The whole \
kingdom stretches before you in breathtaking detail. Far below, the moat \
glitters. In the centre of the platform: a glowing altar.|down:tower_base|"

    # ── Items in rooms ───────────────────────────────────────────────────────
    ROOM_ITEMS[entrance]="torch old_key"
    ROOM_ITEMS[drawbridge]="rope"
    ROOM_ITEMS[great_hall]="wine_bottle"
    ROOM_ITEMS[guard_room]="iron_shield leather_helm"
    ROOM_ITEMS[armory]="short_sword"
    ROOM_ITEMS[dungeon_cells]="crude_map lockpick"
    ROOM_ITEMS[torture_chamber]=""
    ROOM_ITEMS[kitchen]="bread_loaf cheese"
    ROOM_ITEMS[servants_quarters]="silver_coin"
    ROOM_ITEMS[library]="spell_scroll arcane_tome"
    ROOM_ITEMS[observatory]="star_gem"
    ROOM_ITEMS[throne_room]=""
    ROOM_ITEMS[royal_vault]="gold_pile enchanted_key"
    ROOM_ITEMS[tower_base]="climbing_kit"
    ROOM_ITEMS[tower_top]="legendary_sword"

    # ── Enemies in rooms ─────────────────────────────────────────────────────
    ROOM_ENEMY[entrance]=""
    ROOM_ENEMY[drawbridge]=""
    ROOM_ENEMY[great_hall]="goblin_scout"
    ROOM_ENEMY[guard_room]="rat_swarm"
    ROOM_ENEMY[armory]="skeleton"
    ROOM_ENEMY[dungeon_cells]=""
    ROOM_ENEMY[torture_chamber]="troll"
    ROOM_ENEMY[kitchen]=""
    ROOM_ENEMY[servants_quarters]=""
    ROOM_ENEMY[library]=""
    ROOM_ENEMY[observatory]=""
    ROOM_ENEMY[throne_room]="lich"
    ROOM_ENEMY[royal_vault]=""
    ROOM_ENEMY[tower_base]="gargoyle"
    ROOM_ENEMY[tower_top]=""
}

# ─── Item Database ────────────────────────────────────────────────────────────
# Format: "Display Name|type|value|description"
# type: weapon | armor | consumable | quest | misc
declare -A ITEMS
define_items() {
    ITEMS[torch]="Torch|misc|1|A simple pitch torch, still lit. Casts a warm glow."
    ITEMS[old_key]="Old Key|quest|0|A tarnished iron key. What does it open?"
    ITEMS[rope]="Hemp Rope|misc|3|Fifty feet of sturdy rope. Always useful."
    ITEMS[wine_bottle]="Wine Bottle|consumable|2|An aged red. Restores 5 HP when drunk."
    ITEMS[iron_shield]="Iron Shield|armor|8|A battered but functional iron shield. +3 DEF."
    ITEMS[leather_helm]="Leather Helm|armor|4|Cracked leather helm. +1 DEF."
    ITEMS[short_sword]="Short Sword|weapon|10|A reliable short sword. +4 ATK."
    ITEMS[crude_map]="Crude Map|quest|0|A prisoner's scratched map of the dungeon."
    ITEMS[lockpick]="Lockpick|misc|2|A bent wire. Useful for locked doors."
    ITEMS[bread_loaf]="Bread Loaf|consumable|1|Stale bread. Restores 3 HP when eaten."
    ITEMS[cheese]="Aged Cheese|consumable|1|Hard and pungent. Restores 3 HP when eaten."
    ITEMS[silver_coin]="Silver Coin|misc|5|A single silver coin. Worth a bit."
    ITEMS[spell_scroll]="Spell Scroll|weapon|15|Scroll of Fireball. Deals 12 magic damage."
    ITEMS[arcane_tome]="Arcane Tome|misc|20|Ancient magic textbook. Increases XP by 50."
    ITEMS[star_gem]="Star Gem|quest|30|A gem that captures starlight. Mysterious."
    ITEMS[gold_pile]="Pile of Gold|misc|50|Several gold coins scattered in the dust."
    ITEMS[enchanted_key]="Enchanted Key|quest|0|Glows faintly. Opens the vault chest."
    ITEMS[climbing_kit]="Climbing Kit|misc|5|Ropes, pitons, and chalk. Useful for heights."
    ITEMS[legendary_sword]="Legendary Sword|weapon|100|The blade of the fallen king. +12 ATK. It glows with righteous fire."
}

# ─── Enemy Database ───────────────────────────────────────────────────────────
# Format: "Name|hp|atk|def|xp|gold|desc"
declare -A ENEMIES
define_enemies() {
    ENEMIES[goblin_scout]="Goblin Scout|8|3|1|10|3|A wiry goblin in mismatched leather armour."
    ENEMIES[rat_swarm]="Rat Swarm|6|2|0|5|1|A writhing mass of hungry rats."
    ENEMIES[skeleton]="Skeleton Warrior|12|5|2|15|5|Bones animated by foul necromancy."
    ENEMIES[troll]="Cave Troll|20|7|3|25|8|A massive brute with fists like boulders."
    ENEMIES[gargoyle]="Stone Gargoyle|18|6|4|30|10|A winged stone horror animated by dark magic."
    ENEMIES[lich]="The Lich|35|10|5|100|50|An ancient undead sorcerer — the master of this castle."
}

# ─── Enemy Combat State ───────────────────────────────────────────────────────
# Current fight state
FIGHT_ACTIVE=0
declare -A CURRENT_ENEMY  # name hp atk def xp gold

start_fight() {
    local enemy_id="${ROOM_ENEMY[${PLAYER[room]}]:-}"
    [[ -z "$enemy_id" ]] && return
    local edata="${ENEMIES[$enemy_id]:-}"
    [[ -z "$edata" ]] && return

    IFS='|' read -r ename ehp eatk edef exp gold edesc <<< "$edata"
    CURRENT_ENEMY[id]="$enemy_id"
    CURRENT_ENEMY[name]="$ename"
    CURRENT_ENEMY[hp]="$ehp"
    CURRENT_ENEMY[max_hp]="$ehp"
    CURRENT_ENEMY[atk]="$eatk"
    CURRENT_ENEMY[def]="$edef"
    CURRENT_ENEMY[xp]="$exp"
    CURRENT_ENEMY[gold]="$gold"
    CURRENT_ENEMY[desc]="$edesc"
    FIGHT_ACTIVE=1
    add_msg "${C_RED}⚔  A ${ename} appears! ${edesc}${C_RESET}"
    add_msg "${C_YELLOW}   Type 'attack', 'flee', or use an item.${C_RESET}"
}

end_fight_victory() {
    local xp="${CURRENT_ENEMY[xp]}"
    local gold="${CURRENT_ENEMY[gold]}"
    local name="${CURRENT_ENEMY[name]}"
    PLAYER[xp]=$(( PLAYER[xp] + xp ))
    PLAYER[gold]=$(( PLAYER[gold] + gold ))
    FIGHT_ACTIVE=0
    ROOM_ENEMY[${PLAYER[room]}]=""
    add_msg "${C_GREEN}★  ${name} defeated! +${xp} XP, +${gold} gold.${C_RESET}"
    check_level_up
}

check_level_up() {
    local needed=$(( PLAYER[level] * 20 ))
    while [[ ${PLAYER[xp]} -ge $needed ]]; do
        PLAYER[level]=$(( PLAYER[level] + 1 ))
        PLAYER[max_hp]=$(( PLAYER[max_hp] + 5 ))
        PLAYER[hp]=$(( PLAYER[hp] + 5 ))
        PLAYER[atk]=$(( PLAYER[atk] + 2 ))
        PLAYER[def]=$(( PLAYER[def] + 1 ))
        needed=$(( PLAYER[level] * 20 ))
        add_msg "${C_CYAN}${C_BOLD}✦ LEVEL UP! You are now level ${PLAYER[level]}! ATK+2 DEF+1 HP+5${C_RESET}"
    done
}

player_attack() {
    if [[ $FIGHT_ACTIVE -ne 1 ]]; then
        add_msg "${C_YELLOW}There is nothing to fight here.${C_RESET}"; return
    fi
    local dmg=$(( PLAYER[atk] - CURRENT_ENEMY[def] ))
    [[ $dmg -lt 1 ]] && dmg=1
    local roll=$(( RANDOM % 3 ))  # 0-2 bonus
    dmg=$(( dmg + roll ))
    CURRENT_ENEMY[hp]=$(( CURRENT_ENEMY[hp] - dmg ))
    add_msg "${C_WHITE}You strike the ${CURRENT_ENEMY[name]} for ${C_RED}${dmg}${C_WHITE} damage. \
(Enemy HP: ${CURRENT_ENEMY[hp]}/${CURRENT_ENEMY[max_hp]})${C_RESET}"

    if [[ ${CURRENT_ENEMY[hp]} -le 0 ]]; then
        end_fight_victory
        return
    fi
    # Enemy counter-attacks
    enemy_attack
}

enemy_attack() {
    [[ $FIGHT_ACTIVE -ne 1 ]] && return
    local dmg=$(( CURRENT_ENEMY[atk] - PLAYER[def] ))
    [[ $dmg -lt 1 ]] && dmg=1
    local roll=$(( RANDOM % 3 ))
    dmg=$(( dmg + roll ))
    PLAYER[hp]=$(( PLAYER[hp] - dmg ))
    add_msg "${C_RED}The ${CURRENT_ENEMY[name]} hits you for ${dmg} damage. (Your HP: ${PLAYER[hp]}/${PLAYER[max_hp]})${C_RESET}"
    if [[ ${PLAYER[hp]} -le 0 ]]; then
        PLAYER[hp]=0
        add_msg "${C_BG_RED}${C_WHITE}${C_BOLD}  ✝  YOU HAVE DIED.  ✝  ${C_RESET}"
        add_msg "${C_YELLOW}Type 'respawn' to continue from the entrance with half health.${C_RESET}"
        FIGHT_ACTIVE=0
    fi
}

player_flee() {
    if [[ $FIGHT_ACTIVE -ne 1 ]]; then
        add_msg "${C_YELLOW}You aren't in combat.${C_RESET}"; return
    fi
    # 50% flee chance
    if [[ $(( RANDOM % 2 )) -eq 0 ]]; then
        FIGHT_ACTIVE=0
        add_msg "${C_CYAN}You successfully flee!${C_RESET}"
        # Move back to a random adjacent room
        do_move "south" 2>/dev/null || do_move "west" 2>/dev/null || true
    else
        add_msg "${C_YELLOW}You fail to flee!${C_RESET}"
        enemy_attack
    fi
}

# ─── Movement ─────────────────────────────────────────────────────────────────
get_exits() {
    # Returns associative array in global EXITS
    local room_id="$1"
    unset EXITS; declare -gA EXITS
    local data="${ROOMS[$room_id]:-}"
    [[ -z "$data" ]] && return
    IFS='|' read -r _name _desc exits_raw _enemy <<< "$data"
    IFS=',' read -ra exit_list <<< "$exits_raw"
    for ex in "${exit_list[@]}"; do
        [[ -z "$ex" ]] && continue
        local dir="${ex%%:*}"
        local dest="${ex##*:}"
        EXITS["$dir"]="$dest"
    done
}

do_move() {
    local dir="$1"
    if [[ $FIGHT_ACTIVE -eq 1 ]]; then
        add_msg "${C_RED}You can't leave — you're in combat! Fight or flee.${C_RESET}"; return
    fi
    get_exits "${PLAYER[room]}"
    local dest="${EXITS[$dir]:-}"
    if [[ -z "$dest" ]]; then
        add_msg "${C_YELLOW}You can't go ${dir} from here.${C_RESET}"; return
    fi
    PLAYER[room]="$dest"
    PLAYER[moves]=$(( PLAYER[moves] + 1 ))
    ROOM_VISITED["$dest"]=1
    add_msg "${C_CYAN}You move ${dir} to ${C_BOLD}$(room_name "$dest")${C_RESET}${C_CYAN}.${C_RESET}"
    # Check for enemy encounter
    local enemy_id="${ROOM_ENEMY[$dest]:-}"
    if [[ -n "$enemy_id" ]]; then
        start_fight
    fi
}

room_name() {
    local data="${ROOMS[$1]:-}"
    IFS='|' read -r name _rest <<< "$data"
    echo "$name"
}

room_desc() {
    local data="${ROOMS[$1]:-}"
    IFS='|' read -r _name desc _rest <<< "$data"
    echo "$desc"
}

# ─── Inventory Management ─────────────────────────────────────────────────────
has_item() {
    local target="$1"
    local i; for i in "${INVENTORY[@]:-}"; do
        [[ "$i" == "$target" ]] && return 0
    done
    return 1
}

add_item() {
    INVENTORY+=("$1")
}

remove_item() {
    local target="$1"
    local new=()
    local found=0
    local i; for i in "${INVENTORY[@]:-}"; do
        if [[ "$i" == "$target" && $found -eq 0 ]]; then
            found=1
        else
            new+=("$i")
        fi
    done
    INVENTORY=("${new[@]:-}")
}

item_name() {
    local data="${ITEMS[$1]:-}"
    [[ -z "$data" ]] && echo "Unknown Item" && return
    IFS='|' read -r name _rest <<< "$data"
    echo "$name"
}

do_take() {
    local target="$1"
    local room="${PLAYER[room]}"
    local current="${ROOM_ITEMS[$room]:-}"
    local found=0
    local new_list=""

    for item in $current; do
        if [[ "$item" == "$target" && $found -eq 0 ]]; then
            found=1
        else
            new_list+="$item "
        fi
    done

    if [[ $found -eq 1 ]]; then
        add_item "$target"
        ROOM_ITEMS["$room"]="${new_list% }"
        add_msg "${C_GREEN}You pick up the $(item_name "$target").${C_RESET}"
    else
        add_msg "${C_YELLOW}There is no '${target}' here to take.${C_RESET}"
    fi
}

do_drop() {
    local target="$1"
    if has_item "$target"; then
        remove_item "$target"
        local current="${ROOM_ITEMS[${PLAYER[room]}]:-}"
        ROOM_ITEMS[${PLAYER[room]}]="${current} ${target}"
        add_msg "${C_YELLOW}You drop the $(item_name "$target").${C_RESET}"
    else
        add_msg "${C_YELLOW}You don't have '${target}'.${C_RESET}"
    fi
}

do_use() {
    local target="$1"
    if ! has_item "$target"; then
        add_msg "${C_YELLOW}You don't have '${target}'.${C_RESET}"; return
    fi
    local data="${ITEMS[$target]:-}"
    [[ -z "$data" ]] && add_msg "${C_YELLOW}Unknown item.${C_RESET}" && return
    IFS='|' read -r iname itype ivalue idesc <<< "$data"

    case "$itype" in
        consumable)
            local heal=0
            case "$target" in
                wine_bottle) heal=5 ;;
                bread_loaf)  heal=3 ;;
                cheese)      heal=3 ;;
            esac
            PLAYER[hp]=$(( PLAYER[hp] + heal ))
            [[ ${PLAYER[hp]} -gt ${PLAYER[max_hp]} ]] && PLAYER[hp]=${PLAYER[max_hp]}
            remove_item "$target"
            add_msg "${C_GREEN}You use the ${iname}. HP restored by ${heal}. (HP: ${PLAYER[hp]}/${PLAYER[max_hp]})${C_RESET}"
            ;;
        weapon)
            if [[ "$target" == "spell_scroll" ]]; then
                if [[ $FIGHT_ACTIVE -eq 1 ]]; then
                    local dmg=12
                    CURRENT_ENEMY[hp]=$(( CURRENT_ENEMY[hp] - dmg ))
                    remove_item "$target"
                    add_msg "${C_MAGENTA}🔥 Fireball! ${CURRENT_ENEMY[name]} takes ${dmg} magic damage!${C_RESET}"
                    if [[ ${CURRENT_ENEMY[hp]} -le 0 ]]; then
                        end_fight_victory
                    else
                        enemy_attack
                    fi
                else
                    add_msg "${C_YELLOW}No enemy to target with the scroll.${C_RESET}"
                fi
            elif [[ "$target" == "legendary_sword" || "$target" == "short_sword" ]]; then
                local bonus=0
                [[ "$target" == "short_sword" ]]    && bonus=4
                [[ "$target" == "legendary_sword" ]] && bonus=12
                PLAYER[atk]=$(( PLAYER[atk] + bonus ))
                remove_item "$target"
                add_msg "${C_GREEN}You wield the ${iname}! ATK +${bonus}.${C_RESET}"
            else
                add_msg "${C_YELLOW}You brandish the ${iname} but nothing happens.${C_RESET}"
            fi
            ;;
        armor)
            local def_bonus=0
            case "$target" in
                iron_shield)  def_bonus=3 ;;
                leather_helm) def_bonus=1 ;;
            esac
            PLAYER[def]=$(( PLAYER[def] + def_bonus ))
            remove_item "$target"
            add_msg "${C_GREEN}You equip the ${iname}! DEF +${def_bonus}.${C_RESET}"
            ;;
        misc)
            case "$target" in
                arcane_tome)
                    PLAYER[xp]=$(( PLAYER[xp] + 50 ))
                    remove_item "$target"
                    add_msg "${C_CYAN}You study the tome and gain 50 XP!${C_RESET}"
                    check_level_up
                    ;;
                gold_pile)
                    PLAYER[gold]=$(( PLAYER[gold] + ivalue ))
                    remove_item "$target"
                    add_msg "${C_YELLOW}You pocket ${ivalue} gold coins.${C_RESET}"
                    ;;
                silver_coin)
                    PLAYER[gold]=$(( PLAYER[gold] + ivalue ))
                    remove_item "$target"
                    add_msg "${C_YELLOW}You pocket the silver coin (worth ${ivalue} gold).${C_RESET}"
                    ;;
                lockpick)
                    if [[ "${PLAYER[room]}" == "royal_vault" ]] && has_item "lockpick"; then
                        ROOM_ITEMS[royal_vault]+=" chest_treasure"
                        ITEMS[chest_treasure]="Vault Treasure|misc|75|A cache of gold and gems from the vault chest."
                        remove_item "lockpick"
                        add_msg "${C_GREEN}You pick the vault lock! The chest springs open — treasure inside!${C_RESET}"
                        ROOM_ITEMS[royal_vault]+=" chest_gold"
                        ITEMS[chest_gold]="Chest Gold|misc|75|75 coins of pure gold."
                        ROOM_ITEMS[royal_vault]="${ROOM_ITEMS[royal_vault]} chest_gold"
                    else
                        add_msg "${C_YELLOW}There's nothing here to pick.${C_RESET}"
                    fi
                    ;;
                *)
                    add_msg "${C_YELLOW}You examine the ${iname}. ${idesc}${C_RESET}"
                    ;;
            esac
            ;;
        quest)
            add_msg "${C_CYAN}${iname}: ${idesc}${C_RESET}"
            ;;
        *)
            add_msg "${C_YELLOW}You fiddle with the ${iname} but nothing happens.${C_RESET}"
            ;;
    esac
}

do_examine() {
    local target="$1"
    # Check inventory first
    if has_item "$target"; then
        local data="${ITEMS[$target]:-}"
        if [[ -n "$data" ]]; then
            IFS='|' read -r iname _type _val idesc <<< "$data"
            add_msg "${C_CYAN}${iname}: ${idesc}${C_RESET}"
            return
        fi
    fi
    # Check room items
    local room_items="${ROOM_ITEMS[${PLAYER[room]}]:-}"
    for item in $room_items; do
        if [[ "$item" == "$target" ]]; then
            local data="${ITEMS[$target]:-}"
            if [[ -n "$data" ]]; then
                IFS='|' read -r iname _type _val idesc <<< "$data"
                add_msg "${C_CYAN}${iname}: ${idesc}${C_RESET}"
                return
            fi
        fi
    done
    add_msg "${C_YELLOW}You see nothing special about '${target}'.${C_RESET}"
}

# ─── Mini ASCII Map ───────────────────────────────────────────────────────────
# Render a simple schematic showing visited rooms and current position
render_map() {
    # Fixed-layout text art map
    # Positions correspond to approximate layout
    # We'll use a 5×5 grid: each cell = 3 chars wide × 1 row tall
    # Then overlay room abbreviations

    #  Rooms grid (row, col, id):
    #  Row0: observatory(0,2)
    #  Row1: library(1,1) - great_hall(1,2) - tower_base(1,3)
    #  Row2: entrance(2,1) - drawbridge(2,0) / armory(2,3) / tower_top(2,4)
    #  Row2: guard_room(2,2) (below entrance, col 2)
    # ... just render a legend-style map for clarity

    local cur="${PLAYER[room]}"

    # Build map lines
    local map_lines=()

    # Top legend row
    map_lines+=("   [Observatory]──[Library]   [Tower Top]   ")
    map_lines+=("        │              │              │       ")
    map_lines+=("  [Throne Rm]──[Great Hall]──[Tower Base]   ")
    map_lines+=("       │         │    │    │              ")
    map_lines+=("  [Roy.Vault] [Kitchen][Entrance][Armory]  ")
    map_lines+=("                  │         │        │    ")
    map_lines+=("          [Servants][Guard Rm][Dungeon]  ")
    map_lines+=("                         [Drawbridge]   [Torture]")

    # Colour current room name in the map
    local short_names=(
        "Observatory:observatory"
        "Library:library"
        "Tower Top:tower_top"
        "Throne Rm:throne_room"
        "Great Hall:great_hall"
        "Tower Base:tower_base"
        "Roy.Vault:royal_vault"
        "Kitchen:kitchen"
        "Entrance:entrance"
        "Armory:armory"
        "Servants:servants_quarters"
        "Guard Rm:guard_room"
        "Dungeon:dungeon_cells"
        "Drawbridge:drawbridge"
        "Torture:torture_chamber"
    )

    # Print map with highlights
    local row=0
    local i; for i in "${!map_lines[@]}"; do
        local line="${map_lines[$i]}"
        # Highlight current room
        for entry in "${short_names[@]}"; do
            local short="${entry%%:*}"
            local rid="${entry##*:}"
            if [[ "$rid" == "$cur" ]]; then
                line="${line//$short/${C_BG_YELLOW}${C_BLACK}${C_BOLD}${short}${C_RESET}}"
            elif [[ "${ROOM_VISITED[$rid]:-0}" == "1" ]]; then
                line="${line//$short/${C_GREEN}${short}${C_RESET}}"
            else
                line="${line//$short/${C_BLACK}${C_BOLD}${short}${C_RESET}}"
            fi
        done
        # Print at map inner position
        if [[ $i -lt $MAP_INNER_H ]]; then
            move_to $(( MAP_INNER_ROW + i )) $MAP_INNER_COL
            printf "%-*s" "$MAP_INNER_W" ""   # clear line
            move_to $(( MAP_INNER_ROW + i )) $MAP_INNER_COL
            printf "%s" "$line"
        fi
        row=$(( row + 1 ))
    done
}

# ─── Pane Renderers ───────────────────────────────────────────────────────────
render_title() {
    draw_box $TITLE_ROW 1 $TITLE_HEIGHT $TERM_COLS
    local title="${C_BOLD}${C_YELLOW}⚔  TUI Adventure MUD-Lite  ⚔${C_RESET}"
    local subtitle="${C_DIM}Type 'help' for commands — navigate, fight, and loot your way to glory!${C_RESET}"
    move_to $(( TITLE_ROW + 1 )) 1
    printf "${C_BG_BLACK}"
    printf "%*s" "$TERM_COLS" ""
    local tlen=30  # approx visible length of title
    local tcol=$(( (TERM_COLS - tlen) / 2 ))
    move_to $(( TITLE_ROW + 1 )) $tcol
    printf "%s" "$title"
    printf "${C_RESET}"
}

render_map_pane() {
    local room_n
    room_n=$(room_name "${PLAYER[room]}")
    draw_box $MAP_ROW $MAP_COL $MAP_HEIGHT $MAP_WIDTH \
        " MAP — ${room_n} "
    render_map
}

render_desc_pane() {
    draw_box $DESC_ROW $DESC_COL $DESC_INV_HEIGHT $DESC_WIDTH " ROOM "

    local room="${PLAYER[room]}"
    local desc
    desc=$(room_desc "$room")

    # Word-wrap description to inner width
    local w=$DESC_INNER_W
    local words=($desc)
    local lines=() cur_line=""
    for word in "${words[@]}"; do
        if [[ $(( ${#cur_line} + ${#word} + 1 )) -le $w ]]; then
            [[ -n "$cur_line" ]] && cur_line+=" "
            cur_line+="$word"
        else
            lines+=("$cur_line")
            cur_line="$word"
        fi
    done
    [[ -n "$cur_line" ]] && lines+=("$cur_line")

    local i; for i in "${!lines[@]}"; do
        [[ $i -ge $DESC_INNER_H ]] && break
        move_to $(( DESC_INNER_ROW + i )) $DESC_INNER_COL
        printf "%-*s" "$w" "${lines[$i]}"
    done

    # Items on floor
    local floor="${ROOM_ITEMS[$room]:-}"
    local frow=$(( DESC_INNER_ROW + DESC_INNER_H - 2 ))
    move_to $frow $DESC_INNER_COL
    printf "%-*s" "$w" ""
    if [[ -n "$floor" ]]; then
        local display=""
        for it in $floor; do
            display+="$(item_name "$it"), "
        done
        display="${display%, }"
        move_to $frow $DESC_INNER_COL
        printf "${C_GREEN}Items: %-*s${C_RESET}" $((w-7)) "${display:0:$((w-7))}"
    fi

    # Exits
    get_exits "$room"
    local exit_str=""
    for d in "${!EXITS[@]}"; do exit_str+="[$d] "; done
    local erow=$(( DESC_INNER_ROW + DESC_INNER_H - 1 ))
    move_to $erow $DESC_INNER_COL
    printf "${C_CYAN}Exits: %-*s${C_RESET}" $((w-7)) "${exit_str:0:$((w-7))}"

    # Enemy warning
    local enemy="${ROOM_ENEMY[$room]:-}"
    if [[ -n "$enemy" && $FIGHT_ACTIVE -eq 1 ]]; then
        local ebar=$(( 10 * CURRENT_ENEMY[hp] / CURRENT_ENEMY[max_hp] ))
        local bar=""
        local j; for ((j=0; j<10; j++)); do
            [[ $j -lt $ebar ]] && bar+="█" || bar+="░"
        done
        move_to $(( DESC_INNER_ROW + DESC_INNER_H - 3 )) $DESC_INNER_COL
        printf "${C_RED}⚔ ${CURRENT_ENEMY[name]} HP:[%s] %2d/%-2d%s${C_RESET}" \
            "$bar" "${CURRENT_ENEMY[hp]}" "${CURRENT_ENEMY[max_hp]}" \
            "$(printf "%*s" $((w - 35)) "")"
    fi
}

render_inv_pane() {
    draw_box $INV_ROW $INV_COL $DESC_INV_HEIGHT $INV_WIDTH " INVENTORY "
    local w=$INV_INNER_W

    if [[ ${#INVENTORY[@]} -eq 0 ]]; then
        move_to $INV_INNER_ROW $INV_INNER_COL
        printf "${C_DIM}%-*s${C_RESET}" "$w" "(empty)"
    else
        local i; for i in "${!INVENTORY[@]}"; do
            [[ $i -ge $INV_INNER_H ]] && break
            local item="${INVENTORY[$i]}"
            local data="${ITEMS[$item]:-}"
            local iname itype
            IFS='|' read -r iname itype _val _desc <<< "$data"
            local typecolor="${C_WHITE}"
            case "$itype" in
                weapon)     typecolor="${C_RED}"     ;;
                armor)      typecolor="${C_BLUE}"    ;;
                consumable) typecolor="${C_GREEN}"   ;;
                quest)      typecolor="${C_MAGENTA}" ;;
                misc)       typecolor="${C_YELLOW}"  ;;
            esac
            move_to $(( INV_INNER_ROW + i )) $INV_INNER_COL
            printf "${typecolor}%-*s${C_RESET}" "$w" "• ${iname}"
        done
        # Fill remaining
        for ((j=${#INVENTORY[@]}; j<INV_INNER_H; j++)); do
            move_to $(( INV_INNER_ROW + j )) $INV_INNER_COL
            printf "%-*s" "$w" ""
        done
    fi
}

render_log_pane() {
    draw_box $LOG_ROW $LOG_COL $LOG_HEIGHT $LOG_WIDTH " MESSAGE LOG "
    local w=$LOG_INNER_W
    local h=$LOG_INNER_H

    # Show last h messages
    local start=$(( ${#MSG_LOG[@]} - h ))
    [[ $start -lt 0 ]] && start=0

    local row=0
    local i; for (( i=start; i<${#MSG_LOG[@]}; i++ )); do
        [[ $row -ge $h ]] && break
        move_to $(( LOG_INNER_ROW + row )) $LOG_INNER_COL
        # Clear line then print
        printf "%-*s" "$w" ""
        move_to $(( LOG_INNER_ROW + row )) $LOG_INNER_COL
        # Print with possible colour codes (truncate to visible width roughly)
        printf "%s" "${MSG_LOG[$i]}"
        row=$(( row + 1 ))
    done
    # Clear any remaining lines
    for (( ; row<h; row++ )); do
        move_to $(( LOG_INNER_ROW + row )) $LOG_INNER_COL
        printf "%-*s" "$w" ""
    done
}

render_status_pane() {
    draw_box $STATUS_ROW 1 $STATUS_HEIGHT $TERM_COLS " STATUS "
    local hp="${PLAYER[hp]}"
    local mhp="${PLAYER[max_hp]}"

    # HP bar
    local bar_len=15
    local filled=$(( bar_len * hp / mhp ))
    local bar=""
    local j; for ((j=0; j<bar_len; j++)); do
        if [[ $j -lt $filled ]]; then
            bar+="${C_BG_GREEN} "
        else
            bar+="${C_BG_RED} "
        fi
    done
    bar+="${C_RESET}"

    local xp="${PLAYER[xp]}"
    local lvl="${PLAYER[lvl]:-${PLAYER[level]}}"
    local needed=$(( PLAYER[level] * 20 ))
    local xp_pct=0
    [[ $needed -gt 0 ]] && xp_pct=$(( 10 * xp / needed ))
    [[ $xp_pct -gt 10 ]] && xp_pct=10
    local xpbar=""
    for ((j=0; j<10; j++)); do
        [[ $j -lt $xp_pct ]] && xpbar+="${C_BG_CYAN} " || xpbar+="${C_BG_BLACK} "
    done
    xpbar+="${C_RESET}"

    move_to $(( STATUS_ROW + 1 )) 2
    printf "${C_BOLD}%s${C_RESET}" "${PLAYER[name]}"
    printf " │ HP:[%s${C_RESET}] %3d/%-3d" "$bar" "$hp" "$mhp"
    printf " │ XP:[%s${C_RESET}] %3d/%-3d" "$xpbar" "$xp" "$needed"
    printf " │ ${C_YELLOW}LVL:%-2d${C_RESET}" "${PLAYER[level]}"
    printf " │ ${C_YELLOW}GOLD:%-4d${C_RESET}" "${PLAYER[gold]}"
    printf " │ ATK:%-2d DEF:%-2d" "${PLAYER[atk]}" "${PLAYER[def]}"
    printf " │ Moves:%-4d" "${PLAYER[moves]}"
}

render_input_pane() {
    draw_box $INPUT_ROW 1 $INPUT_HEIGHT $TERM_COLS " COMMAND "
    move_to $(( INPUT_ROW + 1 )) 2
    printf "${C_BOLD}${C_GREEN}> ${C_RESET}"
}

render_all() {
    tput clear
    render_title
    render_map_pane
    render_desc_pane
    render_inv_pane
    render_log_pane
    render_status_pane
    render_input_pane
}

partial_refresh() {
    # Faster re-render of dynamic panes only
    render_map_pane
    render_desc_pane
    render_inv_pane
    render_log_pane
    render_status_pane
    render_input_pane
}

# ─── Help Text ────────────────────────────────────────────────────────────────
show_help() {
    add_msg "${C_BOLD}${C_CYAN}═══════ COMMANDS ═══════${C_RESET}"
    add_msg "${C_WHITE}Movement: ${C_YELLOW}go <dir>${C_RESET} or just ${C_YELLOW}<dir>${C_RESET}  (north/south/east/west/up/down)"
    add_msg "${C_WHITE}Shortcut: ${C_YELLOW}n s e w u d${C_RESET}"
    add_msg "${C_WHITE}Items   : ${C_YELLOW}take <item>  drop <item>  use <item>  examine <item>${C_RESET}"
    add_msg "${C_WHITE}Combat  : ${C_YELLOW}attack  flee${C_RESET}"
    add_msg "${C_WHITE}Info    : ${C_YELLOW}look  inventory (i)  status  map${C_RESET}"
    add_msg "${C_WHITE}Other   : ${C_YELLOW}respawn  save  load  help  quit${C_RESET}"
    add_msg "${C_CYAN}═══════════════════════${C_RESET}"
}

# ─── Look ─────────────────────────────────────────────────────────────────────
do_look() {
    local room="${PLAYER[room]}"
    local rname; rname=$(room_name "$room")
    local rdesc; rdesc=$(room_desc "$room")
    add_msg "${C_BOLD}${C_YELLOW}${rname}${C_RESET}"
    add_msg "${rdesc}"
    local floor="${ROOM_ITEMS[$room]:-}"
    if [[ -n "$floor" ]]; then
        local names=""
        for it in $floor; do names+="$(item_name "$it"), "; done
        add_msg "${C_GREEN}You see: ${names%, }${C_RESET}"
    fi
    get_exits "$room"
    local exit_str=""
    for d in "${!EXITS[@]}"; do exit_str+="${d} "; done
    add_msg "${C_CYAN}Exits: ${exit_str}${C_RESET}"
    local enemy="${ROOM_ENEMY[$room]:-}"
    if [[ -n "$enemy" ]]; then
        local edata="${ENEMIES[$enemy]:-}"
        IFS='|' read -r ename _rest <<< "$edata"
        add_msg "${C_RED}⚠  Danger: ${ename} is here!${C_RESET}"
    fi
}

# ─── Save / Load ──────────────────────────────────────────────────────────────
do_save() {
    {
        echo "SAVE_VERSION=1"
        echo "PLAYER_NAME=${PLAYER[name]}"
        echo "PLAYER_ROOM=${PLAYER[room]}"
        echo "PLAYER_HP=${PLAYER[hp]}"
        echo "PLAYER_MAX_HP=${PLAYER[max_hp]}"
        echo "PLAYER_GOLD=${PLAYER[gold]}"
        echo "PLAYER_XP=${PLAYER[xp]}"
        echo "PLAYER_LEVEL=${PLAYER[level]}"
        echo "PLAYER_ATK=${PLAYER[atk]}"
        echo "PLAYER_DEF=${PLAYER[def]}"
        echo "PLAYER_MOVES=${PLAYER[moves]}"
        echo "INVENTORY=$(IFS=','; echo "${INVENTORY[*]:-}")"
        # Room items (encode as key=value)
        for rk in "${!ROOM_ITEMS[@]}"; do
            echo "ROOM_ITEMS_${rk}=${ROOM_ITEMS[$rk]}"
        done
        # Room enemies
        for rk in "${!ROOM_ENEMY[@]}"; do
            echo "ROOM_ENEMY_${rk}=${ROOM_ENEMY[$rk]}"
        done
        # Visited
        for rk in "${!ROOM_VISITED[@]}"; do
            echo "ROOM_VISITED_${rk}=${ROOM_VISITED[$rk]}"
        done
    } > "$SAVE_FILE"
    add_msg "${C_GREEN}Game saved to ${SAVE_FILE}.${C_RESET}"
}

do_load() {
    if [[ ! -f "$SAVE_FILE" ]]; then
        add_msg "${C_YELLOW}No save file found for this session.${C_RESET}"; return
    fi
    while IFS='=' read -r key val; do
        case "$key" in
            PLAYER_NAME)  PLAYER[name]="$val" ;;
            PLAYER_ROOM)  PLAYER[room]="$val" ;;
            PLAYER_HP)    PLAYER[hp]="$val" ;;
            PLAYER_MAX_HP) PLAYER[max_hp]="$val" ;;
            PLAYER_GOLD)  PLAYER[gold]="$val" ;;
            PLAYER_XP)    PLAYER[xp]="$val" ;;
            PLAYER_LEVEL) PLAYER[level]="$val" ;;
            PLAYER_ATK)   PLAYER[atk]="$val" ;;
            PLAYER_DEF)   PLAYER[def]="$val" ;;
            PLAYER_MOVES) PLAYER[moves]="$val" ;;
            INVENTORY)
                IFS=',' read -ra INVENTORY <<< "$val"
                # Remove empty element
                INVENTORY=("${INVENTORY[@]:-}")
                ;;
            ROOM_ITEMS_*)
                local rk="${key#ROOM_ITEMS_}"
                ROOM_ITEMS["$rk"]="$val"
                ;;
            ROOM_ENEMY_*)
                local rk="${key#ROOM_ENEMY_}"
                ROOM_ENEMY["$rk"]="$val"
                ;;
            ROOM_VISITED_*)
                local rk="${key#ROOM_VISITED_}"
                ROOM_VISITED["$rk"]="$val"
                ;;
        esac
    done < "$SAVE_FILE"
    FIGHT_ACTIVE=0
    add_msg "${C_GREEN}Game loaded.${C_RESET}"
}

do_respawn() {
    if [[ ${PLAYER[hp]} -gt 0 ]]; then
        add_msg "${C_YELLOW}You are not dead yet.${C_RESET}"; return
    fi
    PLAYER[room]="entrance"
    PLAYER[hp]=$(( PLAYER[max_hp] / 2 ))
    FIGHT_ACTIVE=0
    add_msg "${C_CYAN}You awaken at the entrance, battered but alive. HP: ${PLAYER[hp]}/${PLAYER[max_hp]}${C_RESET}"
}

# ─── Command Parser ───────────────────────────────────────────────────────────
process_command() {
    local raw="$1"
    local cmd args
    read -r cmd args <<< "$raw"
    cmd="${cmd,,}"  # lowercase

    # Disambiguate item names (allow partial match)
    item_resolve() {
        local fragment="${1,,}"
        # Check inventory
        for item in "${INVENTORY[@]:-}"; do
            local iname; iname=$(item_name "$item")
            if [[ "${iname,,}" == *"$fragment"* || "$item" == *"$fragment"* ]]; then
                echo "$item"; return 0
            fi
        done
        # Check room
        for item in ${ROOM_ITEMS[${PLAYER[room]}]:-}; do
            local iname; iname=$(item_name "$item")
            if [[ "${iname,,}" == *"$fragment"* || "$item" == *"$fragment"* ]]; then
                echo "$item"; return 0
            fi
        done
        echo "$fragment"
    }

    case "$cmd" in
        # Movement
        go)
            do_move "$args"
            ;;
        north|n) do_move "north" ;;
        south|s) do_move "south" ;;
        east|e)  do_move "east"  ;;
        west|w)  do_move "west"  ;;
        up|u)    do_move "up"    ;;
        down|d)  do_move "down"  ;;

        # Actions
        look|l)
            do_look ;;
        take|get|pick)
            local resolved; resolved=$(item_resolve "$args")
            do_take "$resolved" ;;
        drop|leave|put)
            local resolved; resolved=$(item_resolve "$args")
            do_drop "$resolved" ;;
        use|equip|drink|eat|wield|read)
            local resolved; resolved=$(item_resolve "$args")
            do_use "$resolved" ;;
        examine|inspect|x)
            local resolved; resolved=$(item_resolve "$args")
            do_examine "$resolved" ;;

        # Combat
        attack|fight|hit|kill|a)
            player_attack ;;
        flee|run|escape|f)
            player_flee ;;

        # Info
        inventory|inv|i)
            if [[ ${#INVENTORY[@]} -eq 0 ]]; then
                add_msg "${C_YELLOW}Your inventory is empty.${C_RESET}"
            else
                add_msg "${C_CYAN}Inventory:${C_RESET}"
                for item in "${INVENTORY[@]}"; do
                    local iname; iname=$(item_name "$item")
                    add_msg "  • ${iname}"
                done
            fi
            ;;
        status|stat|stats)
            add_msg "${C_CYAN}${PLAYER[name]} | Lvl:${PLAYER[level]} HP:${PLAYER[hp]}/${PLAYER[max_hp]} ATK:${PLAYER[atk]} DEF:${PLAYER[def]} XP:${PLAYER[xp]} Gold:${PLAYER[gold]}${C_RESET}"
            ;;
        map)
            add_msg "${C_CYAN}Map rendered in the top pane. ${C_GREEN}Green${C_RESET}${C_CYAN}=visited, ${C_BG_YELLOW}${C_BLACK}Yellow${C_RESET}${C_CYAN}=here, ${C_BOLD}Dark${C_RESET}${C_CYAN}=unknown.${C_RESET}"
            ;;

        # Meta
        help|h|'?')
            show_help ;;
        save)
            do_save ;;
        load)
            do_load ;;
        respawn|revive)
            do_respawn ;;
        quit|exit|q)
            add_msg "${C_YELLOW}Farewell, ${PLAYER[name]}. Until next time…${C_RESET}"
            partial_refresh
            sleep 1
            exit 0
            ;;
        clear)
            MSG_LOG=()
            add_msg "${C_DIM}Log cleared.${C_RESET}"
            ;;
        '')
            : ;;
        *)
            add_msg "${C_YELLOW}Unknown command: '${cmd}'. Type 'help' for commands.${C_RESET}"
            ;;
    esac
}

# ─── Input Loop ───────────────────────────────────────────────────────────────
read_input() {
    # Position cursor at input line
    move_to $(( INPUT_ROW + 1 )) 4
    tput el          # Clear to end of line
    tput cnorm       # Show cursor
    local input=""
    IFS= read -r input
    tput civis       # Hide cursor while rendering
    echo "$input"
}

# ─── Name Entry ───────────────────────────────────────────────────────────────
get_player_name() {
    tput clear
    local r=$(( TERM_ROWS / 2 - 4 ))
    local c=$(( (TERM_COLS - 50) / 2 ))
    draw_box $r $c 9 50 " Welcome, Adventurer "
    move_to $(( r + 2 )) $(( c + 2 ))
    printf "${C_BOLD}${C_YELLOW}⚔  TUI Adventure MUD-Lite  ⚔${C_RESET}"
    move_to $(( r + 4 )) $(( c + 2 ))
    printf "${C_WHITE}An ancient evil stirs in the ruined castle.${C_RESET}"
    move_to $(( r + 5 )) $(( c + 2 ))
    printf "${C_WHITE}Only a brave soul can uncover its secrets.${C_RESET}"
    move_to $(( r + 7 )) $(( c + 2 ))
    printf "${C_GREEN}Enter your name: ${C_RESET}"
    tput cnorm
    local name=""
    IFS= read -r name
    tput civis
    [[ -z "$name" ]] && name="Adventurer"
    PLAYER[name]="$name"
}

# ─── Intro Messages ───────────────────────────────────────────────────────────
add_intro_messages() {
    add_msg "${C_BOLD}${C_YELLOW}═══ Welcome, ${PLAYER[name]}! ═══${C_RESET}"
    add_msg "${C_WHITE}You arrive at the Castle Entrance, torch in hand.${C_RESET}"
    add_msg "${C_WHITE}Somewhere within these walls, an ancient evil awaits.${C_RESET}"
    add_msg "${C_CYAN}Type 'help' to see commands. Type 'look' to examine your surroundings.${C_RESET}"
    add_msg "${C_DIM}Tip: Take items with 'take <item>', use them with 'use <item>'.${C_RESET}"
    do_look
}

# ─── SIGWINCH Handler (terminal resize) ───────────────────────────────────────
handle_resize() {
    get_dims
    compute_layout
    render_all
}
trap handle_resize WINCH

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    setup_colors
    get_dims

    # Switch to alternate screen buffer & hide cursor
    tput smcup
    tput civis
    tput clear

    compute_layout

    # Player name
    get_player_name

    # Init world
    define_world
    define_items
    define_enemies

    # Mark start room visited
    ROOM_VISITED[entrance]=1

    # Intro log
    add_intro_messages

    # Initial render
    render_all

    # Main game loop
    while true; do
        local input
        input=$(read_input)
        process_command "$input"
        partial_refresh
    done
}

main "$@"