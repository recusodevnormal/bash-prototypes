#!/usr/bin/env bash
# =============================================================================
# THE TUI DUNGEON CRAWLER
# A turn-based rogue-lite dungeon crawler with full TUI rendering
# =============================================================================

# --- Strict mode & cleanup ---------------------------------------------------
set -euo pipefail

# Terminal state
_ORIGINAL_STTY=""
_TERM_SETUP=false

cleanup() {
    # Restore terminal
    tput rmcup 2>/dev/null || true
    tput cnorm 2>/dev/null || true
    if [[ -n "$_ORIGINAL_STTY" ]]; then
        stty "$_ORIGINAL_STTY" 2>/dev/null || true
    fi
    echo ""
    echo "Thanks for playing The TUI Dungeon Crawler!"
}

trap cleanup EXIT INT TERM

# =============================================================================
# CONSTANTS & CONFIGURATION
# =============================================================================

# Map dimensions (playable area)
readonly MAP_W=60
readonly MAP_H=22

# Sidebar
readonly SIDEBAR_W=30
readonly SIDEBAR_X=$((MAP_W + 3))

# Total window
readonly WIN_W=$((MAP_W + SIDEBAR_W + 4))
readonly WIN_H=$((MAP_H + 4))

# Status bar row (below map)
readonly STATUS_ROW=$((MAP_H + 3))

# Map draw offset (1-indexed terminal positions)
readonly MAP_DRAW_X=2
readonly MAP_DRAW_Y=2

# Colors (ANSI escape)
readonly C_RESET='\e[0m'
readonly C_BOLD='\e[1m'
readonly C_DIM='\e[2m'

# Foreground colors
readonly C_BLACK='\e[30m'
readonly C_RED='\e[31m'
readonly C_GREEN='\e[32m'
readonly C_YELLOW='\e[33m'
readonly C_BLUE='\e[34m'
readonly C_MAGENTA='\e[35m'
readonly C_CYAN='\e[36m'
readonly C_WHITE='\e[37m'
readonly C_BRIGHT_RED='\e[91m'
readonly C_BRIGHT_GREEN='\e[92m'
readonly C_BRIGHT_YELLOW='\e[93m'
readonly C_BRIGHT_BLUE='\e[94m'
readonly C_BRIGHT_MAGENTA='\e[95m'
readonly C_BRIGHT_CYAN='\e[96m'
readonly C_BRIGHT_WHITE='\e[97m'

# Background colors
readonly C_BG_BLACK='\e[40m'
readonly C_BG_RED='\e[41m'
readonly C_BG_GREEN='\e[42m'
readonly C_BG_YELLOW='\e[43m'
readonly C_BG_BLUE='\e[44m'
readonly C_BG_MAGENTA='\e[45m'
readonly C_BG_CYAN='\e[46m'
readonly C_BG_WHITE='\e[47m'
readonly C_BG_BRIGHT_BLACK='\e[100m'

# Tile characters
readonly T_WALL='#'
readonly T_FLOOR='.'
readonly T_DOOR='+'
readonly T_STAIR='>'
readonly T_EMPTY=' '

# Entity symbols
readonly E_PLAYER='@'
readonly E_GOBLIN='g'
readonly E_ORC='o'
readonly E_TROLL='T'
readonly E_DRAGON='D'
readonly E_RAT='r'
readonly E_SKELETON='s'
readonly E_CHEST='$'
readonly E_POTION='!'
readonly E_WEAPON='/'
readonly E_ARMOR=']'

# Directions
readonly DIR_N="n"; readonly DIR_S="s"; readonly DIR_E="e"; readonly DIR_W="w"
readonly DIR_NE="ne"; readonly DIR_NW="nw"; readonly DIR_SE="se"; readonly DIR_SW="sw"

# =============================================================================
# GAME STATE (Global Arrays & Variables)
# =============================================================================

# Map: flat array [y*MAP_W + x]
declare -a MAP_TILES=()        # tile type: W=wall, F=floor, D=door, S=stair, E=empty
declare -a MAP_VISIBLE=()      # 1=currently visible, 0=not
declare -a MAP_EXPLORED=()     # 1=explored (show dim), 0=unknown
declare -a MAP_ITEMS=()        # item code at tile, or ""
declare -a MAP_MONSTERS=()     # monster id at tile, or ""

# Player state
declare -i PL_X=1 PL_Y=1
declare -i PL_HP=30 PL_MAX_HP=30
declare -i PL_ATK=5 PL_DEF=2 PL_GOLD=0
declare -i PL_LVL=1 PL_XP=0 PL_XP_NEXT=10
declare -i PL_FLOOR=1
declare    PL_WEAPON="Fists" PL_ARMOR="Rags"
declare -i PL_WEAPON_DMG=2 PL_ARMOR_DEF=0
declare -i PL_POTIONS=2

# Monsters: parallel arrays indexed by monster_id
declare -a MON_TYPE=()    # goblin/orc/troll/dragon/rat/skeleton
declare -a MON_X=()
declare -a MON_Y=()
declare -a MON_HP=()
declare -a MON_MAX_HP=()
declare -a MON_ATK=()
declare -a MON_DEF=()
declare -a MON_XP=()
declare -a MON_GOLD=()
declare -a MON_ALIVE=()   # 1=alive 0=dead
declare -i MON_COUNT=0

# Items on ground (already encoded in MAP_ITEMS)
# Item format: TYPE:VALUE  e.g. potion:15, gold:20, weapon:Iron Sword:8, armor:Chain Mail:3

# Message log (ring buffer of last 8 messages)
declare -a MSG_LOG=()
declare -i MSG_HEAD=0
declare -i MSG_COUNT=0
readonly MSG_MAX=8

# Turn counter
declare -i TURN=0

# Rooms (for reference)
declare -a ROOMS_X=() ROOMS_Y=() ROOMS_W=() ROOMS_H=()
declare -i ROOM_COUNT=0

# Random seed state
declare -i _RAND_STATE=0

# RNG state
declare -i _LCG_A=1664525 _LCG_C=1013904223 _LCG_M=4294967296

# Game flags
declare -i GAME_OVER=0   # 0=playing, 1=dead, 2=won
declare    NEEDS_REDRAW=1

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Fast LCG random number generator
# Usage: rand_int MIN MAX -> result in $RAND_RESULT
declare -i RAND_RESULT=0
rand_init() {
    _RAND_STATE=$(date +%N 2>/dev/null || echo $RANDOM)
    _RAND_STATE=$(( (_RAND_STATE ^ (RANDOM * 65537)) & 0x7FFFFFFF ))
}

rand_next() {
    _RAND_STATE=$(( (_LCG_A * _RAND_STATE + _LCG_C) % _LCG_M ))
    echo $(( _RAND_STATE & 0x7FFFFFFF ))
}

rand_int() {
    local min=$1 max=$2
    local range=$(( max - min + 1 ))
    local r
    r=$(rand_next)
    RAND_RESULT=$(( (r % range) + min ))
}

# Clamp value
clamp() {
    local val=$1 lo=$2 hi=$3
    if   (( val < lo )); then echo $lo
    elif (( val > hi )); then echo $hi
    else                      echo $val
    fi
}

# Move cursor (1-indexed)
goto() {
    local row=$1 col=$2
    printf '\e[%d;%dH' "$row" "$col"
}

# Print with color
cprint() {
    printf "%b%s%b" "$1" "$2" "$C_RESET"
}

# Pad string to width
pad_right() {
    local s="$1" w=$2
    printf "%-${w}s" "$s"
}

# Map index
mi() { echo $(( $2 * MAP_W + $1 )); }   # mi x y -> index

# Add message to log
add_msg() {
    local msg="$1"
    local idx=$(( MSG_HEAD % MSG_MAX ))
    MSG_LOG[$idx]="$msg"
    MSG_HEAD=$(( MSG_HEAD + 1 ))
    if (( MSG_COUNT < MSG_MAX )); then
        MSG_COUNT=$(( MSG_COUNT + 1 ))
    fi
}

# =============================================================================
# MAP GENERATION
# =============================================================================

map_init() {
    local i
    local total=$(( MAP_W * MAP_H ))
    for (( i = 0; i < total; i++ )); do
        MAP_TILES[$i]='E'
        MAP_VISIBLE[$i]=0
        MAP_EXPLORED[$i]=0
        MAP_ITEMS[$i]=""
        MAP_MONSTERS[$i]=""
    done
}

map_set() {
    local x=$1 y=$2 v=$3
    local idx=$(( y * MAP_W + x ))
    MAP_TILES[$idx]="$v"
}

map_get() {
    local x=$1 y=$2
    local idx=$(( y * MAP_W + x ))
    echo "${MAP_TILES[$idx]:-E}"
}

map_in_bounds() {
    local x=$1 y=$2
    (( x >= 0 && x < MAP_W && y >= 0 && y < MAP_H ))
}

# Carve a room
carve_room() {
    local rx=$1 ry=$2 rw=$3 rh=$4
    local x y
    for (( y = ry; y < ry + rh; y++ )); do
        for (( x = rx; x < rx + rw; x++ )); do
            map_set $x $y 'F'
        done
    done
}

# Carve horizontal corridor
carve_h_corridor() {
    local x1=$1 x2=$2 y=$3
    local x
    local xmin=$(( x1 < x2 ? x1 : x2 ))
    local xmax=$(( x1 > x2 ? x1 : x2 ))
    for (( x = xmin; x <= xmax; x++ )); do
        local idx=$(( y * MAP_W + x ))
        if [[ "${MAP_TILES[$idx]}" == "E" || "${MAP_TILES[$idx]}" == "W" ]]; then
            MAP_TILES[$idx]='F'
        fi
    done
}

# Carve vertical corridor
carve_v_corridor() {
    local x=$1 y1=$2 y2=$3
    local y
    local ymin=$(( y1 < y2 ? y1 : y2 ))
    local ymax=$(( y1 > y2 ? y1 : y2 ))
    for (( y = ymin; y <= ymax; y++ )); do
        local idx=$(( y * MAP_W + x ))
        if [[ "${MAP_TILES[$idx]}" == "E" || "${MAP_TILES[$idx]}" == "W" ]]; then
            MAP_TILES[$idx]='F'
        fi
    done
}

# Add walls around floor tiles
add_walls() {
    local x y nx ny idx nidx
    local total=$(( MAP_W * MAP_H ))
    for (( idx = 0; idx < total; idx++ )); do
        if [[ "${MAP_TILES[$idx]}" == 'F' ]]; then
            local ty=$(( idx / MAP_W ))
            local tx=$(( idx % MAP_W ))
            for dy in -1 0 1; do
                for dx in -1 0 1; do
                    (( dx == 0 && dy == 0 )) && continue
                    nx=$(( tx + dx ))
                    ny=$(( ty + dy ))
                    if (( nx >= 0 && nx < MAP_W && ny >= 0 && ny < MAP_H )); then
                        nidx=$(( ny * MAP_W + nx ))
                        if [[ "${MAP_TILES[$nidx]}" == 'E' ]]; then
                            MAP_TILES[$nidx]='W'
                        fi
                    fi
                done
            done
        fi
    done
}

generate_dungeon() {
    local floor=$1
    local x y r

    # Reset arrays
    map_init
    ROOMS_X=(); ROOMS_Y=(); ROOMS_W=(); ROOMS_H=()
    ROOM_COUNT=0
    MON_TYPE=(); MON_X=(); MON_Y=(); MON_HP=(); MON_MAX_HP=()
    MON_ATK=(); MON_DEF=(); MON_XP=(); MON_GOLD=(); MON_ALIVE=()
    MON_COUNT=0

    # BSP-style room generation
    local max_rooms=10
    local min_room_w=5 max_room_w=12
    local min_room_h=4 max_room_h=8
    local attempts=0
    local max_attempts=50

    while (( ROOM_COUNT < max_rooms && attempts < max_attempts )); do
        attempts=$(( attempts + 1 ))
        rand_int $min_room_w $max_room_w
        local rw=$RAND_RESULT
        rand_int $min_room_h $max_room_h
        local rh=$RAND_RESULT
        rand_int 1 $(( MAP_W - rw - 1 ))
        local rx=$RAND_RESULT
        rand_int 1 $(( MAP_H - rh - 1 ))
        local ry=$RAND_RESULT

        # Check overlap (with 1-tile margin)
        local overlap=0
        for (( r = 0; r < ROOM_COUNT; r++ )); do
            local ex=${ROOMS_X[$r]} ey=${ROOMS_Y[$r]}
            local ew=${ROOMS_W[$r]} eh=${ROOMS_H[$r]}
            if (( rx < ex + ew + 1 && rx + rw + 1 > ex &&
                  ry < ey + eh + 1 && ry + rh + 1 > ey )); then
                overlap=1
                break
            fi
        done

        if (( !overlap )); then
            ROOMS_X[$ROOM_COUNT]=$rx
            ROOMS_Y[$ROOM_COUNT]=$ry
            ROOMS_W[$ROOM_COUNT]=$rw
            ROOMS_H[$ROOM_COUNT]=$rh
            carve_room $rx $ry $rw $rh
            ROOM_COUNT=$(( ROOM_COUNT + 1 ))
        fi
    done

    # Connect rooms with corridors
    for (( r = 1; r < ROOM_COUNT; r++ )); do
        local prev=$(( r - 1 ))
        local cx1=$(( ROOMS_X[$prev] + ROOMS_W[$prev] / 2 ))
        local cy1=$(( ROOMS_Y[$prev] + ROOMS_H[$prev] / 2 ))
        local cx2=$(( ROOMS_X[$r] + ROOMS_W[$r] / 2 ))
        local cy2=$(( ROOMS_Y[$r] + ROOMS_H[$r] / 2 ))

        rand_int 0 1
        if (( RAND_RESULT == 0 )); then
            carve_h_corridor $cx1 $cx2 $cy1
            carve_v_corridor $cx2 $cy1 $cy2
        else
            carve_v_corridor $cx1 $cy1 $cy2
            carve_h_corridor $cx1 $cx2 $cy2
        fi
    done

    # Add walls
    add_walls

    # Place stairs in last room
    local lr=$(( ROOM_COUNT - 1 ))
    local sx=$(( ROOMS_X[$lr] + ROOMS_W[$lr] / 2 ))
    local sy=$(( ROOMS_Y[$lr] + ROOMS_H[$lr] / 2 ))
    local sidx=$(( sy * MAP_W + sx ))
    MAP_TILES[$sidx]='S'

    # Add doors at corridor entrances (random)
    place_doors

    # Place player in first room center
    PL_X=$(( ROOMS_X[0] + ROOMS_W[0] / 2 ))
    PL_Y=$(( ROOMS_Y[0] + ROOMS_H[0] / 2 ))

    # Populate with monsters and items
    populate_floor $floor

    # Initial FOV
    compute_fov $PL_X $PL_Y 6
}

place_doors() {
    # Place doors between rooms and corridors
    local x y idx
    local total=$(( MAP_W * MAP_H ))
    for (( idx = 0; idx < total; idx++ )); do
        [[ "${MAP_TILES[$idx]}" != 'F' ]] && continue
        local ty=$(( idx / MAP_W ))
        local tx=$(( idx % MAP_W ))
        # Check if this is a choke point (corridor junction)
        local h_walls=0 v_walls=0
        local n_idx=$(( (ty-1) * MAP_W + tx ))
        local s_idx=$(( (ty+1) * MAP_W + tx ))
        local e_idx=$(( ty * MAP_W + tx + 1 ))
        local w_idx=$(( ty * MAP_W + tx - 1 ))

        (( ty > 0 )) && [[ "${MAP_TILES[$n_idx]:-E}" == 'W' ]] && v_walls=$(( v_walls + 1 ))
        (( ty < MAP_H-1 )) && [[ "${MAP_TILES[$s_idx]:-E}" == 'W' ]] && v_walls=$(( v_walls + 1 ))
        (( tx > 0 )) && [[ "${MAP_TILES[$w_idx]:-E}" == 'W' ]] && h_walls=$(( h_walls + 1 ))
        (( tx < MAP_W-1 )) && [[ "${MAP_TILES[$e_idx]:-E}" == 'W' ]] && h_walls=$(( h_walls + 1 ))

        if (( v_walls == 2 || h_walls == 2 )); then
            rand_int 1 8
            if (( RAND_RESULT == 1 )); then
                MAP_TILES[$idx]='D'
            fi
        fi
    done
}

# Populate floor with monsters and items
populate_floor() {
    local floor=$1
    local r midx

    for (( r = 1; r < ROOM_COUNT; r++ )); do  # skip room 0 (player start)
        local rw=${ROOMS_W[$r]} rh=${ROOMS_H[$r]}
        local rx=${ROOMS_X[$r]} ry=${ROOMS_Y[$r]}

        # Monsters per room
        rand_int 0 3
        local num_mon=$RAND_RESULT
        local m
        for (( m = 0; m < num_mon; m++ )); do
            rand_int 0 $(( rw - 1 ))
            local mx=$(( rx + RAND_RESULT ))
            rand_int 0 $(( rh - 1 ))
            local my=$(( ry + RAND_RESULT ))
            local midx2=$(( my * MAP_W + mx ))
            if [[ "${MAP_TILES[$midx2]}" == 'F' && -z "${MAP_MONSTERS[$midx2]:-}" ]]; then
                spawn_monster $mx $my $floor
                MAP_MONSTERS[$midx2]=$((MON_COUNT - 1))
            fi
        done

        # Items per room
        rand_int 0 2
        local num_items=$RAND_RESULT
        local itm
        for (( itm = 0; itm < num_items; itm++ )); do
            rand_int 0 $(( rw - 1 ))
            local ix=$(( rx + RAND_RESULT ))
            rand_int 0 $(( rh - 1 ))
            local iy=$(( ry + RAND_RESULT ))
            local iidx=$(( iy * MAP_W + ix ))
            if [[ "${MAP_TILES[$iidx]}" == 'F' && -z "${MAP_ITEMS[$iidx]:-}" ]]; then
                spawn_item $ix $iy $floor
            fi
        done
    done
}

spawn_monster() {
    local x=$1 y=$2 floor=$3
    local id=$MON_COUNT

    # Monster type based on floor + random
    local types=("rat" "goblin" "skeleton" "orc" "troll" "dragon")
    local max_type=$(( floor < 5 ? floor : 5 ))
    rand_int 0 $max_type
    local tidx=$RAND_RESULT
    local type="${types[$tidx]}"

    MON_TYPE[$id]="$type"
    MON_X[$id]=$x
    MON_Y[$id]=$y
    MON_ALIVE[$id]=1

    case "$type" in
        rat)      MON_MAX_HP[$id]=4;  MON_HP[$id]=4;  MON_ATK[$id]=2; MON_DEF[$id]=0; MON_XP[$id]=2;  MON_GOLD[$id]=1  ;;
        goblin)   MON_MAX_HP[$id]=8;  MON_HP[$id]=8;  MON_ATK[$id]=4; MON_DEF[$id]=1; MON_XP[$id]=5;  MON_GOLD[$id]=3  ;;
        skeleton) MON_MAX_HP[$id]=10; MON_HP[$id]=10; MON_ATK[$id]=5; MON_DEF[$id]=2; MON_XP[$id]=7;  MON_GOLD[$id]=2  ;;
        orc)      MON_MAX_HP[$id]=18; MON_HP[$id]=18; MON_ATK[$id]=7; MON_DEF[$id]=3; MON_XP[$id]=12; MON_GOLD[$id]=6  ;;
        troll)    MON_MAX_HP[$id]=30; MON_HP[$id]=30; MON_ATK[$id]=10;MON_DEF[$id]=4; MON_XP[$id]=20; MON_GOLD[$id]=10 ;;
        dragon)   MON_MAX_HP[$id]=50; MON_HP[$id]=50; MON_ATK[$id]=15;MON_DEF[$id]=6; MON_XP[$id]=40; MON_GOLD[$id]=25 ;;
    esac

    # Scale with floor
    MON_MAX_HP[$id]=$(( MON_MAX_HP[$id] + (floor - 1) * 2 ))
    MON_HP[$id]=${MON_MAX_HP[$id]}
    MON_ATK[$id]=$(( MON_ATK[$id] + (floor - 1) ))

    MON_COUNT=$(( MON_COUNT + 1 ))
}

spawn_item() {
    local x=$1 y=$2 floor=$3
    local idx=$(( y * MAP_W + x ))

    rand_int 1 10
    local roll=$RAND_RESULT

    if (( roll <= 4 )); then
        # Gold
        rand_int $(( floor * 3 )) $(( floor * 10 ))
        MAP_ITEMS[$idx]="gold:$RAND_RESULT"
    elif (( roll <= 6 )); then
        # Potion
        rand_int $(( 8 + floor )) $(( 15 + floor * 2 ))
        MAP_ITEMS[$idx]="potion:$RAND_RESULT"
    elif (( roll <= 8 )); then
        # Weapon
        local weapons=("Dagger:3" "Short Sword:5" "Long Sword:8" "Battle Axe:11" "War Hammer:14" "Dragon Blade:18")
        local widx=$(( floor < 5 ? floor : 5 ))
        rand_int 0 $widx
        MAP_ITEMS[$idx]="weapon:${weapons[$RAND_RESULT]}"
    else
        # Armor
        local armors=("Leather:1" "Studded:2" "Chain Mail:4" "Plate Mail:6" "Dragon Scale:9")
        local aidx=$(( floor < 4 ? floor : 4 ))
        rand_int 0 $aidx
        MAP_ITEMS[$idx]="armor:${armors[$RAND_RESULT]}"
    fi
}

# =============================================================================
# FIELD OF VIEW (Simple Raycasting)
# =============================================================================

compute_fov() {
    local ox=$1 oy=$2 radius=$3
    local idx total x y

    total=$(( MAP_W * MAP_H ))

    # Clear current visibility
    for (( idx = 0; idx < total; idx++ )); do
        MAP_VISIBLE[$idx]=0
    done

    # Cast rays in 360 degrees (using integer angles)
    local angle steps=360
    for (( angle = 0; angle < steps; angle++ )); do
        local dx_f ry_f
        # Use precomputed sin/cos approximation via awk
        local result
        result=$(awk -v a="$angle" -v r="$radius" -v ox="$ox" -v oy="$oy" -v mw="$MAP_W" -v mh="$MAP_H" '
        BEGIN {
            PI = 3.14159265358979
            rad = a * PI / 180
            dx = cos(rad); dy = sin(rad)
            for (i = 0; i <= r * 10; i++) {
                cx = int(ox + dx * i / 10 + 0.5)
                cy = int(oy + dy * i / 10 + 0.5)
                if (cx < 0 || cx >= mw || cy < 0 || cy >= mh) break
                print cx " " cy
            }
        }')
        while IFS=' ' read -r rx ry; do
            local ridx=$(( ry * MAP_W + rx ))
            MAP_VISIBLE[$ridx]=1
            MAP_EXPLORED[$ridx]=1
            # Stop at walls
            local t="${MAP_TILES[$ridx]:-E}"
            if [[ "$t" == 'W' || "$t" == 'E' ]]; then
                break
            fi
        done <<< "$result"
    done

    # Always make player tile visible
    local pidx=$(( oy * MAP_W + ox ))
    MAP_VISIBLE[$pidx]=1
    MAP_EXPLORED[$pidx]=1
}

# =============================================================================
# TUI RENDERING
# =============================================================================

# Draw a box at given terminal position
draw_box() {
    local row=$1 col=$2 height=$3 width=$4
    local color="${5:-$C_WHITE}"
    local y x

    # Top border
    goto $row $col
    printf "%b┌" "$color"
    for (( x = 0; x < width - 2; x++ )); do printf "─"; done
    printf "┐%b" "$C_RESET"

    # Sides
    for (( y = 1; y < height - 1; y++ )); do
        goto $(( row + y )) $col
        printf "%b│%b" "$color" "$C_RESET"
        goto $(( row + y )) $(( col + width - 1 ))
        printf "%b│%b" "$color" "$C_RESET"
    done

    # Bottom border
    goto $(( row + height - 1 )) $col
    printf "%b└" "$color"
    for (( x = 0; x < width - 2; x++ )); do printf "─"; done
    printf "┘%b" "$C_RESET"
}

# Draw map title
draw_map_header() {
    local title=" Floor $PL_FLOOR - The Dungeon "
    goto 1 2
    printf "%b%b%s%b" "$C_BOLD" "$C_BRIGHT_YELLOW" "$title" "$C_RESET"
}

# Get tile display info -> sets TILE_CHAR and TILE_COLOR
get_tile_display() {
    local x=$1 y=$2
    local idx=$(( y * MAP_W + x ))
    local tile="${MAP_TILES[$idx]:-E}"
    local visible=${MAP_VISIBLE[$idx]:-0}
    local explored=${MAP_EXPLORED[$idx]:-0}

    TILE_CHAR=" "
    TILE_COLOR="$C_RESET"

    if (( !explored )); then
        TILE_CHAR=" "
        TILE_COLOR="$C_RESET"
        return
    fi

    if (( !visible )); then
        # Dimmed explored tiles
        case "$tile" in
            'W') TILE_CHAR="#"; TILE_COLOR="${C_DIM}${C_WHITE}" ;;
            'F') TILE_CHAR="."; TILE_COLOR="${C_DIM}${C_WHITE}" ;;
            'D') TILE_CHAR="+"; TILE_COLOR="${C_DIM}${C_YELLOW}" ;;
            'S') TILE_CHAR=">"; TILE_COLOR="${C_DIM}${C_CYAN}" ;;
            *)   TILE_CHAR=" "; TILE_COLOR="$C_RESET" ;;
        esac
        return
    fi

    # Visible tiles
    case "$tile" in
        'W') TILE_CHAR="#"; TILE_COLOR="${C_WHITE}" ;;
        'F') TILE_CHAR="."; TILE_COLOR="${C_DIM}${C_WHITE}" ;;
        'D') TILE_CHAR="+"; TILE_COLOR="${C_BRIGHT_YELLOW}" ;;
        'S') TILE_CHAR=">"; TILE_COLOR="${C_BRIGHT_CYAN}${C_BOLD}" ;;
        *)   TILE_CHAR=" "; TILE_COLOR="$C_RESET" ;;
    esac

    # Check for items (only shown if visible)
    local item="${MAP_ITEMS[$idx]:-}"
    if [[ -n "$item" ]]; then
        local itype="${item%%:*}"
        case "$itype" in
            gold)   TILE_CHAR="*"; TILE_COLOR="${C_BRIGHT_YELLOW}" ;;
            potion) TILE_CHAR="!"; TILE_COLOR="${C_BRIGHT_MAGENTA}" ;;
            weapon) TILE_CHAR="/"; TILE_COLOR="${C_BRIGHT_CYAN}" ;;
            armor)  TILE_CHAR="]"; TILE_COLOR="${C_BRIGHT_GREEN}" ;;
        esac
        return
    fi

    # Check for monsters (only shown if visible)
    local mon_id="${MAP_MONSTERS[$idx]:-}"
    if [[ -n "$mon_id" && "${MON_ALIVE[$mon_id]:-0}" == "1" ]]; then
        local mtype="${MON_TYPE[$mon_id]}"
        case "$mtype" in
            rat)      TILE_CHAR="r"; TILE_COLOR="${C_BRIGHT_RED}" ;;
            goblin)   TILE_CHAR="g"; TILE_COLOR="${C_GREEN}" ;;
            skeleton) TILE_CHAR="s"; TILE_COLOR="${C_WHITE}" ;;
            orc)      TILE_CHAR="o"; TILE_COLOR="${C_BRIGHT_GREEN}" ;;
            troll)    TILE_CHAR="T"; TILE_COLOR="${C_BRIGHT_RED}" ;;
            dragon)   TILE_CHAR="D"; TILE_COLOR="${C_RED}${C_BOLD}" ;;
        esac
    fi
}

TILE_CHAR=" "
TILE_COLOR="$C_RESET"

# Render the full map
render_map() {
    local x y idx

    for (( y = 0; y < MAP_H; y++ )); do
        goto $(( MAP_DRAW_Y + y )) $MAP_DRAW_X
        local line=""
        for (( x = 0; x < MAP_W; x++ )); do
            if (( x == PL_X && y == PL_Y )); then
                line+="${C_BRIGHT_WHITE}${C_BOLD}@${C_RESET}"
            else
                get_tile_display $x $y
                line+="${TILE_COLOR}${TILE_CHAR}${C_RESET}"
            fi
        done
        printf "%b" "$line"
    done
}

# Render the sidebar
render_sidebar() {
    local sx=$SIDEBAR_X

    # Title
    goto 1 $sx
    printf "%b%b╔══════════════════════════╗%b" "$C_BOLD" "$C_BRIGHT_CYAN" "$C_RESET"

    goto 2 $sx
    printf "%b%b║  THE TUI DUNGEON CRAWLER ║%b" "$C_BOLD" "$C_BRIGHT_CYAN" "$C_RESET"

    goto 3 $sx
    printf "%b%b╚══════════════════════════╝%b" "$C_BOLD" "$C_BRIGHT_CYAN" "$C_RESET"

    # Player stats section
    goto 4 $sx
    printf "%b%b┌─[ ADVENTURER ]──────────┐%b" "$C_BOLD" "$C_YELLOW" "$C_RESET"

    goto 5 $sx
    printf "%b%b│%b" "$C_YELLOW" "$C_BOLD" "$C_RESET"
    printf " Lv:%-2d  Floor:%-2d  Turn:%-4d" "$PL_LVL" "$PL_FLOOR" "$TURN"
    printf "%b%b│%b" "$C_YELLOW" "$C_BOLD" "$C_RESET"

    # HP bar
    goto 6 $sx
    printf "%b%b│%b" "$C_YELLOW" "$C_BOLD" "$C_RESET"
    local hp_pct=$(( PL_HP * 20 / (PL_MAX_HP > 0 ? PL_MAX_HP : 1) ))
    local hp_bar=""
    local i
    for (( i = 0; i < 20; i++ )); do
        if (( i < hp_pct )); then
            if (( hp_pct > 13 )); then
                hp_bar+="${C_BRIGHT_GREEN}█"
            elif (( hp_pct > 6 )); then
                hp_bar+="${C_BRIGHT_YELLOW}█"
            else
                hp_bar+="${C_BRIGHT_RED}█"
            fi
        else
            hp_bar+="${C_DIM}${C_WHITE}░"
        fi
    done
    printf " HP: %b%b %b" "$hp_bar" "$C_RESET" "$C_RESET"
    printf "%b%b│%b" "$C_YELLOW" "$C_BOLD" "$C_RESET"

    goto 7 $sx
    printf "%b%b│%b" "$C_YELLOW" "$C_BOLD" "$C_RESET"
    printf " %b%b%3d%b/%b%b%-3d%b                  " \
        "$C_BRIGHT_GREEN" "$C_BOLD" "$PL_HP" "$C_RESET" \
        "$C_WHITE" "$PL_MAX_HP" "$C_RESET"
    printf "%b%b│%b" "$C_YELLOW" "$C_BOLD" "$C_RESET"

    # XP bar
    goto 8 $sx
    printf "%b%b│%b" "$C_YELLOW" "$C_BOLD" "$C_RESET"
    local xp_pct=0
    (( PL_XP_NEXT > 0 )) && xp_pct=$(( PL_XP * 20 / PL_XP_NEXT ))
    local xp_bar=""
    for (( i = 0; i < 20; i++ )); do
        if (( i < xp_pct )); then
            xp_bar+="${C_BRIGHT_CYAN}▪"
        else
            xp_bar+="${C_DIM}${C_WHITE}·"
        fi
    done
    printf " XP: %b%b %b" "$xp_bar" "$C_RESET" "$C_RESET"
    printf "%b%b│%b" "$C_YELLOW" "$C_BOLD" "$C_RESET"

    goto 9 $sx
    printf "%b%b│%b" "$C_YELLOW" "$C_BOLD" "$C_RESET"
    printf "     %b%b%3d%b/%b%b%-3d%b                  " \
        "$C_BRIGHT_CYAN" "$C_BOLD" "$PL_XP" "$C_RESET" \
        "$C_WHITE" "$PL_XP_NEXT" "$C_RESET"
    printf "%b%b│%b" "$C_YELLOW" "$C_BOLD" "$C_RESET"

    goto 10 $sx
    printf "%b%b├─[ COMBAT ]──────────────┤%b" "$C_YELLOW" "$C_BOLD" "$C_RESET"

    goto 11 $sx
    printf "%b%b│%b" "$C_YELLOW" "$C_BOLD" "$C_RESET"
    local weapon_short="${PL_WEAPON:0:14}"
    printf " ATK:%b%b%-3d%b %-14s   " \
        "$C_BRIGHT_RED" "$C_BOLD" "$(( PL_ATK + PL_WEAPON_DMG ))" "$C_RESET" "$weapon_short"
    printf "%b%b│%b" "$C_YELLOW" "$C_BOLD" "$C_RESET"

    goto 12 $sx
    printf "%b%b│%b" "$C_YELLOW" "$C_BOLD" "$C_RESET"
    local armor_short="${PL_ARMOR:0:14}"
    printf " DEF:%b%b%-3d%b %-14s   " \
        "$C_BRIGHT_BLUE" "$C_BOLD" "$(( PL_DEF + PL_ARMOR_DEF ))" "$C_RESET" "$armor_short"
    printf "%b%b│%b" "$C_YELLOW" "$C_BOLD" "$C_RESET"

    goto 13 $sx
    printf "%b%b├─[ INVENTORY ]───────────┤%b" "$C_YELLOW" "$C_BOLD" "$C_RESET"

    goto 14 $sx
    printf "%b%b│%b" "$C_YELLOW" "$C_BOLD" "$C_RESET"
    printf " Gold: %b%b%-5d%b  Potions: %b%b%-2d%b  " \
        "$C_BRIGHT_YELLOW" "$C_BOLD" "$PL_GOLD" "$C_RESET" \
        "$C_BRIGHT_MAGENTA" "$C_BOLD" "$PL_POTIONS" "$C_RESET"
    printf "%b%b│%b" "$C_YELLOW" "$C_BOLD" "$C_RESET"

    goto 15 $sx
    printf "%b%b└─────────────────────────┘%b" "$C_YELLOW" "$C_BOLD" "$C_RESET"

    # Message log section
    goto 16 $sx
    printf "%b%b┌─[ LOG ]─────────────────┐%b" "$C_BRIGHT_WHITE" "$C_BOLD" "$C_RESET"

    local log_lines=8
    local start_idx=$(( MSG_HEAD - log_lines ))
    (( start_idx < 0 )) && start_idx=0

    local row=17
    for (( i = 0; i < log_lines; i++ )); do
        local msg_idx=$(( start_idx + i ))
        local msg=""
        if (( msg_idx < MSG_HEAD && msg_idx >= MSG_HEAD - MSG_COUNT )); then
            local arr_idx=$(( msg_idx % MSG_MAX ))
            msg="${MSG_LOG[$arr_idx]:-}"
        fi
        goto $row $sx
        printf "%b%b│%b" "$C_BRIGHT_WHITE" "$C_BOLD" "$C_RESET"
        # Truncate and pad message
        local msg_disp="${msg:0:26}"
        printf " %-26s" "$msg_disp"
        printf "%b%b│%b" "$C_BRIGHT_WHITE" "$C_BOLD" "$C_RESET"
        row=$(( row + 1 ))
    done

    goto $row $sx
    printf "%b%b└─────────────────────────┘%b" "$C_BRIGHT_WHITE" "$C_BOLD" "$C_RESET"

    # Controls hint (row 26)
    row=$(( row + 1 ))
    goto $row $sx
    printf "%b%b┌─[ CONTROLS ]────────────┐%b" "$C_DIM" "$C_WHITE" "$C_RESET"
    row=$(( row + 1 ))
    goto $row $sx
    printf "%b%b│%b hjkl/arrows:move  %b>%b:stair│%b" \
        "$C_DIM" "$C_WHITE" "$C_RESET" \
        "$C_BRIGHT_CYAN" "$C_RESET" \
        "$C_DIM$C_WHITE" "$C_RESET"
    row=$(( row + 1 ))
    goto $row $sx
    printf "%b%b│%b %b,%b:pickup  %bh%b:heal   %bq%b:quit│%b" \
        "$C_DIM" "$C_WHITE" "$C_RESET" \
        "$C_BRIGHT_GREEN" "$C_RESET" \
        "$C_BRIGHT_MAGENTA" "$C_RESET" \
        "$C_BRIGHT_RED" "$C_RESET" \
        "$C_DIM$C_WHITE" "$C_RESET"
    row=$(( row + 1 ))
    goto $row $sx
    printf "%b%b└─────────────────────────┘%b" "$C_DIM" "$C_WHITE" "$C_RESET"
}

# Render status bar at bottom
render_status() {
    goto $STATUS_ROW 2
    printf "%b%b" "$C_BG_BRIGHT_BLACK" "$C_BRIGHT_WHITE"
    printf " %-$((MAP_W - 2))s " "Press 'q' to quit | ',' to pick up | 'h' to use potion | Arrow keys or hjkl to move"
    printf "%b" "$C_RESET"
}

# Full screen redraw
full_redraw() {
    # Draw outer border for map area
    printf '\e[2J'  # Clear screen

    draw_box 1 1 $(( MAP_H + 2 )) $(( MAP_W + 2 )) "$C_BRIGHT_WHITE"
    draw_map_header
    render_map
    render_sidebar
    render_status
}

# Partial update: just player position and a few surrounding cells
# (Used for movement - full redraw on demand)
partial_redraw() {
    render_map
    render_sidebar
}

# =============================================================================
# GAME OVER / WIN SCREENS
# =============================================================================

show_game_over() {
    printf '\e[2J'
    local msg=(
        "  ▄████  ▄▄▄       ███▄ ▄███▓▓█████     ▒█████   ██▒   █▓▓█████  ██▀███  "
        " ██▒ ▀█▒▒████▄    ▓██▒▀█▀ ██▒▓█   ▀    ▒██▒  ██▒▓██░   █▒▓█   ▀ ▓██ ▒ ██▒"
        "▒██░▄▄▄░▒██  ▀█▄  ▓██    ▓██░▒███      ▒██░  ██▒ ▓██  █▒░▒███   ▓██ ░▄█ ▒"
        "░▓█  ██▓░██▄▄▄▄██ ▒██    ▒██ ▒▓█  ▄    ▒██   ██░  ▒██ █░░▒▓█  ▄ ▒██▀▀█▄  "
        "░▒▓███▀▒ ▓█   ▓██▒▒██▒   ░██▒░▒████▒   ░ ████▓▒░   ▒▀█░  ░▒████▒░██▓ ▒██▒"
    )
    local row=5
    for line in "${msg[@]}"; do
        goto $row 2
        printf "%b%b%s%b" "$C_BOLD" "$C_BRIGHT_RED" "$line" "$C_RESET"
        row=$(( row + 1 ))
    done

    goto 12 20
    printf "%b%b★  YOU HAVE PERISHED IN THE DUNGEON  ★%b" "$C_BOLD" "$C_RED" "$C_RESET"
    goto 14 25
    printf "%b%bFinal Stats:%b" "$C_BOLD" "$C_YELLOW" "$C_RESET"
    goto 15 25
    printf "  Floor: %d  |  Level: %d  |  Gold: %d  |  Turns: %d" "$PL_FLOOR" "$PL_LVL" "$PL_GOLD" "$TURN"
    goto 18 30
    printf "%b%bPress any key to exit...%b" "$C_BOLD" "$C_WHITE" "$C_RESET"
    read -rsn1
}

show_victory() {
    printf '\e[2J'
    goto 5 10
    printf "%b%b╔══════════════════════════════════════════════╗%b" "$C_BOLD" "$C_BRIGHT_YELLOW" "$C_RESET"
    goto 6 10
    printf "%b%b║           VICTORY! YOU ESCAPED!              ║%b" "$C_BOLD" "$C_BRIGHT_YELLOW" "$C_RESET"
    goto 7 10
    printf "%b%b╚══════════════════════════════════════════════╝%b" "$C_BOLD" "$C_BRIGHT_YELLOW" "$C_RESET"
    goto 9 15
    printf "%b%bYou conquered 5 floors of the dungeon!%b" "$C_BOLD" "$C_BRIGHT_GREEN" "$C_RESET"
    goto 11 15
    printf "Final Stats:"
    goto 12 15
    printf "  Level: %d  |  Gold: %d  |  HP: %d/%d  |  Turns: %d" "$PL_LVL" "$PL_GOLD" "$PL_HP" "$PL_MAX_HP" "$TURN"
    goto 15 20
    printf "%b%bPress any key to exit...%b" "$C_BOLD" "$C_WHITE" "$C_RESET"
    read -rsn1
}

# =============================================================================
# COMBAT SYSTEM
# =============================================================================

player_attack() {
    local mon_id=$1
    local total_atk=$(( PL_ATK + PL_WEAPON_DMG ))
    local total_def=${MON_DEF[$mon_id]}

    rand_int 1 $total_atk
    local dmg=$RAND_RESULT
    local actual_dmg=$(( dmg - total_def ))
    (( actual_dmg < 1 )) && actual_dmg=1

    # Critical hit chance (10%)
    rand_int 1 10
    local crit=0
    if (( RAND_RESULT == 1 )); then
        actual_dmg=$(( actual_dmg * 2 ))
        crit=1
    fi

    MON_HP[$mon_id]=$(( MON_HP[$mon_id] - actual_dmg ))

    local mname="${MON_TYPE[$mon_id]}"
    if (( crit )); then
        add_msg "CRITICAL! ${mname} took ${actual_dmg} dmg!"
    else
        add_msg "You hit ${mname} for ${actual_dmg} damage."
    fi

    if (( MON_HP[$mon_id] <= 0 )); then
        kill_monster $mon_id
    fi
}

kill_monster() {
    local mon_id=$1
    MON_ALIVE[$mon_id]=0

    local mx=${MON_X[$mon_id]}
    local my=${MON_Y[$mon_id]}
    local midx=$(( my * MAP_W + mx ))
    MAP_MONSTERS[$midx]=""

    local xp=${MON_XP[$mon_id]}
    local gold=${MON_GOLD[$mon_id]}
    local mname="${MON_TYPE[$mon_id]}"

    PL_XP=$(( PL_XP + xp ))
    PL_GOLD=$(( PL_GOLD + gold ))

    add_msg "${mname} slain! +${xp}xp +${gold}g"

    # Check level up
    while (( PL_XP >= PL_XP_NEXT )); do
        level_up
    done

    # Chance to drop item
    rand_int 1 4
    if (( RAND_RESULT == 1 && -z "${MAP_ITEMS[$midx]:-}" )); then
        spawn_item $mx $my $PL_FLOOR
        add_msg "Monster dropped an item!"
    fi
}

monster_attack() {
    local mon_id=$1
    local total_atk=${MON_ATK[$mon_id]}
    local total_def=$(( PL_DEF + PL_ARMOR_DEF ))

    rand_int 1 $total_atk
    local dmg=$RAND_RESULT
    local actual_dmg=$(( dmg - total_def ))
    (( actual_dmg < 1 )) && actual_dmg=1

    PL_HP=$(( PL_HP - actual_dmg ))

    local mname="${MON_TYPE[$mon_id]}"
    add_msg "${mname} hits you for ${actual_dmg}!"

    if (( PL_HP <= 0 )); then
        PL_HP=0
        GAME_OVER=1
    fi
}

level_up() {
    PL_LVL=$(( PL_LVL + 1 ))
    PL_XP=$(( PL_XP - PL_XP_NEXT ))
    PL_XP_NEXT=$(( PL_XP_NEXT * 2 ))

    # Stat increases
    local hp_gain=5
    rand_int 3 7
    hp_gain=$RAND_RESULT

    PL_MAX_HP=$(( PL_MAX_HP + hp_gain ))
    PL_HP=$(( PL_HP + hp_gain ))
    PL_ATK=$(( PL_ATK + 1 ))
    PL_DEF=$(( PL_DEF + 1 ))

    add_msg "LEVEL UP! Now level ${PL_LVL}!"
    add_msg "+${hp_gain} max HP, +1 ATK, +1 DEF"
}

# =============================================================================
# MONSTER AI
# =============================================================================

monsters_turn() {
    local id
    for (( id = 0; id < MON_COUNT; id++ )); do
        [[ "${MON_ALIVE[$id]:-0}" != "1" ]] && continue

        local mx=${MON_X[$id]}
        local my=${MON_Y[$id]}
        local midx=$(( my * MAP_W + mx ))

        # Only act if visible to player
        if [[ "${MAP_VISIBLE[$midx]:-0}" != "1" ]]; then
            continue
        fi

        # Check distance to player
        local dx=$(( PL_X - mx ))
        local dy=$(( PL_Y - my ))
        local dist_sq=$(( dx*dx + dy*dy ))

        if (( dist_sq <= 1 )); then
            # Adjacent: attack
            monster_attack $id
        else
            # Move toward player
            monster_move_toward $id $PL_X $PL_Y
        fi
    done
}

monster_move_toward() {
    local id=$1 tx=$2 ty=$3
    local mx=${MON_X[$id]} my=${MON_Y[$id]}

    local dx=$(( tx - mx ))
    local dy=$(( ty - my ))

    local nx=$mx ny=$my

    # Determine step direction
    local sdx=0 sdy=0
    (( dx > 0 )) && sdx=1
    (( dx < 0 )) && sdx=-1
    (( dy > 0 )) && sdy=1
    (( dy < 0 )) && sdy=-1

    # Try horizontal first if larger axis
    local abs_dx=$(( dx < 0 ? -dx : dx ))
    local abs_dy=$(( dy < 0 ? -dy : dy ))

    local moved=0

    if (( abs_dx >= abs_dy && sdx != 0 )); then
        local tnx=$(( mx + sdx ))
        if monster_can_move $id $tnx $my; then
            nx=$tnx; ny=$my; moved=1
        elif (( sdy != 0 )); then
            local tny=$(( my + sdy ))
            if monster_can_move $id $mx $tny; then
                nx=$mx; ny=$tny; moved=1
            fi
        fi
    fi

    if (( !moved && sdy != 0 )); then
        local tny=$(( my + sdy ))
        if monster_can_move $id $mx $tny; then
            nx=$mx; ny=$tny; moved=1
        elif (( sdx != 0 )); then
            local tnx=$(( mx + sdx ))
            if monster_can_move $id $tnx $my; then
                nx=$tnx; ny=$my; moved=1
            fi
        fi
    fi

    if (( moved )); then
        local old_idx=$(( my * MAP_W + mx ))
        local new_idx=$(( ny * MAP_W + nx ))
        MAP_MONSTERS[$old_idx]=""
        MAP_MONSTERS[$new_idx]=$id
        MON_X[$id]=$nx
        MON_Y[$id]=$ny
    fi
}

monster_can_move() {
    local id=$1 nx=$2 ny=$3

    # Bounds check
    (( nx < 0 || nx >= MAP_W || ny < 0 || ny >= MAP_H )) && return 1

    local nidx=$(( ny * MAP_W + nx ))
    local tile="${MAP_TILES[$nidx]:-E}"

    # Must be walkable
    [[ "$tile" == 'F' || "$tile" == 'D' || "$tile" == 'S' ]] || return 1

    # Not occupied by another monster
    local occ="${MAP_MONSTERS[$nidx]:-}"
    [[ -n "$occ" && "$occ" != "$id" ]] && return 1

    # Not player position
    (( nx == PL_X && ny == PL_Y )) && return 1

    return 0
}

# =============================================================================
# PLAYER ACTIONS
# =============================================================================

try_move() {
    local dx=$1 dy=$2
    local nx=$(( PL_X + dx ))
    local ny=$(( PL_Y + dy ))

    # Bounds check
    if (( nx < 0 || nx >= MAP_W || ny < 0 || ny >= MAP_H )); then
        return
    fi

    local nidx=$(( ny * MAP_W + nx ))
    local tile="${MAP_TILES[$nidx]:-E}"

    # Check for monster
    local mon_id="${MAP_MONSTERS[$nidx]:-}"
    if [[ -n "$mon_id" && "${MON_ALIVE[$mon_id]:-0}" == "1" ]]; then
        player_attack $mon_id
        TURN=$(( TURN + 1 ))
        monsters_turn
        compute_fov $PL_X $PL_Y 6
        return
    fi

    # Check tile walkability
    case "$tile" in
        'F'|'S')
            PL_X=$nx; PL_Y=$ny
            ;;
        'D')
            # Open door (convert to floor)
            MAP_TILES[$nidx]='F'
            PL_X=$nx; PL_Y=$ny
            add_msg "You open the door."
            ;;
        'W'|'E')
            # Can't move there
            return
            ;;
    esac

    TURN=$(( TURN + 1 ))

    # Auto-pick up gold (silent)
    local item="${MAP_ITEMS[$nidx]:-}"
    if [[ -n "$item" ]]; then
        local itype="${item%%:*}"
        if [[ "$itype" == "gold" ]]; then
            auto_pickup_gold $nidx "$item"
        fi
    fi

    # Check if on stairs
    if [[ "$tile" == 'S' ]]; then
        add_msg "Press '>' to descend the stairs."
    fi

    monsters_turn
    compute_fov $PL_X $PL_Y 6
}

auto_pickup_gold() {
    local idx=$1 item=$2
    local amount="${item#*:}"
    PL_GOLD=$(( PL_GOLD + amount ))
    MAP_ITEMS[$idx]=""
    add_msg "Picked up $amount gold."
}

pickup_item() {
    local idx=$(( PL_Y * MAP_W + PL_X ))
    local item="${MAP_ITEMS[$idx]:-}"

    if [[ -z "$item" ]]; then
        add_msg "Nothing to pick up here."
        return
    fi

    local itype="${item%%:*}"
    local idata="${item#*:}"

    case "$itype" in
        gold)
            PL_GOLD=$(( PL_GOLD + idata ))
            add_msg "Picked up ${idata} gold."
            ;;
        potion)
            PL_POTIONS=$(( PL_POTIONS + 1 ))
            add_msg "Picked up a potion (${idata} HP)."
            ;;
        weapon)
            local wname="${idata%%:*}"
            local wdmg="${idata#*:}"
            if (( wdmg > PL_WEAPON_DMG )); then
                PL_WEAPON="$wname"
                PL_WEAPON_DMG=$wdmg
                add_msg "Equipped ${wname}! (+${wdmg} ATK)"
            else
                add_msg "Found ${wname} (weaker, kept ${PL_WEAPON})"
                PL_GOLD=$(( PL_GOLD + wdmg * 2 ))
            fi
            ;;
        armor)
            local aname="${idata%%:*}"
            local adef="${idata#*:}"
            if (( adef > PL_ARMOR_DEF )); then
                PL_ARMOR="$aname"
                PL_ARMOR_DEF=$adef
                add_msg "Equipped ${aname}! (+${adef} DEF)"
            else
                add_msg "Found ${aname} (weaker, kept ${PL_ARMOR})"
                PL_GOLD=$(( PL_GOLD + adef * 2 ))
            fi
            ;;
    esac

    MAP_ITEMS[$idx]=""
    TURN=$(( TURN + 1 ))
    monsters_turn
    compute_fov $PL_X $PL_Y 6
}

use_potion() {
    if (( PL_POTIONS <= 0 )); then
        add_msg "No potions left!"
        return
    fi

    PL_POTIONS=$(( PL_POTIONS - 1 ))
    local heal=$(( 10 + PL_LVL * 3 ))
    PL_HP=$(( PL_HP + heal ))
    if (( PL_HP > PL_MAX_HP )); then
        PL_HP=$PL_MAX_HP
    fi
    add_msg "Drank potion. Healed ${heal} HP."
    TURN=$(( TURN + 1 ))
    monsters_turn
    compute_fov $PL_X $PL_Y 6
}

descend_stairs() {
    local idx=$(( PL_Y * MAP_W + PL_X ))
    local tile="${MAP_TILES[$idx]:-E}"

    if [[ "$tile" != 'S' ]]; then
        add_msg "You are not on stairs!"
        return
    fi

    if (( PL_FLOOR >= 5 )); then
        GAME_OVER=2
        return
    fi

    PL_FLOOR=$(( PL_FLOOR + 1 ))
    add_msg "You descend to floor ${PL_FLOOR}..."

    # Partially heal on descent
    local heal=$(( PL_MAX_HP / 4 ))
    PL_HP=$(( PL_HP + heal ))
    (( PL_HP > PL_MAX_HP )) && PL_HP=$PL_MAX_HP

    generate_dungeon $PL_FLOOR
    full_redraw
}

# Wait a turn (rest)
wait_turn() {
    # Small HP regen on wait
    if (( PL_HP < PL_MAX_HP )); then
        PL_HP=$(( PL_HP + 1 ))
        add_msg "You rest briefly."
    else
        add_msg "You wait..."
    fi
    TURN=$(( TURN + 1 ))
    monsters_turn
    compute_fov $PL_X $PL_Y 6
}

# =============================================================================
# INPUT HANDLING
# =============================================================================

read_key() {
    local key
    IFS= read -rsn1 key

    # Handle escape sequences (arrow keys)
    if [[ "$key" == $'\e' ]]; then
        IFS= read -rsn1 -t 0.1 key2 || true
        if [[ "$key2" == "[" ]]; then
            IFS= read -rsn1 -t 0.1 key3 || true
            case "$key3" in
                'A') echo "UP"    ;;
                'B') echo "DOWN"  ;;
                'C') echo "RIGHT" ;;
                'D') echo "LEFT"  ;;
                *)   echo "ESC"   ;;
            esac
        else
            echo "ESC"
        fi
    else
        echo "$key"
    fi
}

process_input() {
    local key
    key=$(read_key)

    case "$key" in
        # Movement: hjkl and arrows
        'h'|'LEFT')  try_move -1  0 ;;
        'l'|'RIGHT') try_move  1  0 ;;
        'k'|'UP')    try_move  0 -1 ;;
        'j'|'DOWN')  try_move  0  1 ;;
        # Diagonal movement: yubn
        'y') try_move -1 -1 ;;
        'u') try_move  1 -1 ;;
        'b') try_move -1  1 ;;
        'n') try_move  1  1 ;;
        # Actions
        ',') pickup_item ;;
        'H') use_potion  ;;   # capital H for heal (to avoid conflict with left movement)
        '>') descend_stairs ;;
        '.') wait_turn ;;
        ' ') wait_turn ;;
        # Quit
        'q'|'Q')
            goto $(( WIN_H + 2 )) 1
            printf "\n%bReally quit? (y/n) %b" "$C_BRIGHT_RED" "$C_RESET"
            local confirm
            IFS= read -rsn1 confirm
            if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                GAME_OVER=3
            fi
            ;;
        # Redraw
        'r'|'R')
            full_redraw
            ;;
        # Debug: reveal map
        # 'm') reveal_all ;;
    esac
}

# =============================================================================
# INITIALIZATION
# =============================================================================

init_terminal() {
    _ORIGINAL_STTY=$(stty -g 2>/dev/null || true)
    stty -echo -icanon min 1 time 0 2>/dev/null || true
    tput smcup 2>/dev/null || true
    tput civis 2>/dev/null || true
    _TERM_SETUP=true

    # Check terminal size
    local cols rows
    cols=$(tput cols 2>/dev/null || echo 80)
    rows=$(tput lines 2>/dev/null || echo 24)

    if (( cols < WIN_W || rows < WIN_H )); then
        tput rmcup 2>/dev/null || true
        tput cnorm 2>/dev/null || true
        stty "$_ORIGINAL_STTY" 2>/dev/null || true
        echo "Terminal too small! Need at least ${WIN_W}x${WIN_H}, got ${cols}x${rows}."
        exit 1
    fi
}

init_game() {
    rand_init
    PL_X=1; PL_Y=1
    PL_HP=30; PL_MAX_HP=30
    PL_ATK=5; PL_DEF=2; PL_GOLD=0
    PL_LVL=1; PL_XP=0; PL_XP_NEXT=10
    PL_FLOOR=1
    PL_WEAPON="Fists"; PL_ARMOR="Rags"
    PL_WEAPON_DMG=2; PL_ARMOR_DEF=0
    PL_POTIONS=2
    TURN=0
    GAME_OVER=0
    MSG_LOG=()
    MSG_HEAD=0
    MSG_COUNT=0

    add_msg "Welcome to the Dungeon!"
    add_msg "Find the stairs (>) to descend."
    add_msg "Survive 5 floors to escape!"

    generate_dungeon 1
}

# =============================================================================
# TITLE SCREEN
# =============================================================================

show_title() {
    printf '\e[2J'
    local title_lines=(
        ""
        "  ╔══════════════════════════════════════════════════════════╗"
        "  ║                                                          ║"
        "  ║        ████████╗██╗   ██╗██╗    ██████╗  ██████╗        ║"
        "  ║           ██╔══╝██║   ██║██║    ██╔══██╗██╔════╝        ║"
        "  ║           ██║   ██║   ██║██║    ██║  ██║██║             ║"
        "  ║           ██║   ██║   ██║██║    ██║  ██║██║  ███╗       ║"
        "  ║           ██║   ╚██████╔╝██║    ██████╔╝╚██████╔╝       ║"
        "  ║           ╚═╝    ╚═════╝ ╚═╝    ╚═════╝  ╚═════╝        ║"
        "  ║                                                          ║"
        "  ║            ██████╗ ██╗   ██╗███╗  ██╗ ██████╗           ║"
        "  ║            ██╔══██╗██║   ██║████╗ ██║██╔════╝           ║"
        "  ║            ██║  ██║██║   ██║██╔██╗██║██║  ███╗          ║"
        "  ║            ██║  ██║██║   ██║██║╚████║██║   ██║          ║"
        "  ║            ██████╔╝╚██████╔╝██║ ╚███║╚██████╔╝          ║"
        "  ║            ╚═════╝  ╚═════╝ ╚═╝  ╚══╝ ╚═════╝           ║"
        "  ║                                                          ║"
        "  ║         ██████╗██████╗  █████╗ ██╗    ██╗██╗            ║"
        "  ║        ██╔════╝██╔══██╗██╔══██╗██║    ██║██║            ║"
        "  ║        ██║     ██████╔╝███████║██║ █╗ ██║██║            ║"
        "  ║        ██║     ██╔══██╗██╔══██║██║███╗██║██║            ║"
        "  ║        ╚██████╗██║  ██║██║  ██║╚███╔███╔╝███████╗       ║"
        "  ║         ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚══╝╚══╝ ╚══════╝      ║"
        "  ║                                                          ║"
        "  ╚══════════════════════════════════════════════════════════╝"
    )

    local row=1
    for line in "${title_lines[@]}"; do
        goto $row 1
        printf "%b%b%s%b" "$C_BOLD" "$C_BRIGHT_CYAN" "$line" "$C_RESET"
        row=$(( row + 1 ))
    done

    goto $(( row + 1 )) 20
    printf "%b%b⚔  A TURN-BASED ROGUE-LITE DUNGEON CRAWLER  ⚔%b" "$C_BOLD" "$C_BRIGHT_YELLOW" "$C_RESET"

    goto $(( row + 3 )) 22
    printf "%b%b[ CONTROLS ]%b" "$C_BOLD" "$C_WHITE" "$C_RESET"
    goto $(( row + 4 )) 18
    printf "  hjkl / Arrow Keys : Move"
    goto $(( row + 5 )) 18
    printf "  yubn              : Diagonal movement"
    goto $(( row + 6 )) 18
    printf "  ,                 : Pick up item"
    goto $(( row + 7 )) 18
    printf "  H                 : Use healing potion"
    goto $(( row + 8 )) 18
    printf "  >                 : Descend stairs"
    goto $(( row + 9 )) 18
    printf "  . or SPACE        : Wait a turn"
    goto $(( row + 10 )) 18
    printf "  q                 : Quit"

    goto $(( row + 12 )) 22
    printf "%b%b>> Press any key to begin your descent... <<%b" "$C_BOLD" "$C_BRIGHT_GREEN" "$C_RESET"

    read -rsn1
}

# =============================================================================
# MAIN GAME LOOP
# =============================================================================

main() {
    init_terminal
    show_title

    init_game
    full_redraw

    while true; do
        # Redraw if needed
        if (( NEEDS_REDRAW )); then
            partial_redraw
            NEEDS_REDRAW=0
        else
            partial_redraw
        fi

        # Check game state
        if (( GAME_OVER == 1 )); then
            show_game_over
            break
        elif (( GAME_OVER == 2 )); then
            show_victory
            break
        elif (( GAME_OVER == 3 )); then
            break
        fi

        # Process input
        process_input
    done
}

main "$@"