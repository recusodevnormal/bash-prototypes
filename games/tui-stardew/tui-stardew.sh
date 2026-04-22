#!/usr/bin/env bash
# =============================================================================
# TUI STARDEW - A Lightweight Farming RPG in Pure Bash
# =============================================================================
# Controls:
#   Arrow Keys / WASD  - Move cursor
#   P                  - Plant seed (costs 10g, uses 5 energy)
#   W                  - Water crop (uses 3 energy)
#   H                  - Harvest (uses 2 energy, earns gold)
#   S                  - Sleep (restore energy, advance day)
#   B                  - Buy seeds (10g each, max 20)
#   Q                  - Quit
# =============================================================================

# ── Terminal Setup ────────────────────────────────────────────────────────────
export TERM=xterm-256color
stty -echo -icanon min 1 time 0 2>/dev/null

trap cleanup EXIT INT TERM

cleanup() {
    tput rmcup
    tput cnorm
    stty echo icanon 2>/dev/null
    echo "Thanks for playing TUI Stardew! 🌾"
}

# ── Constants ─────────────────────────────────────────────────────────────────
readonly GRID_ROWS=8
readonly GRID_COLS=12
readonly GRID_TOP=3
readonly GRID_LEFT=4
readonly CELL_W=5
readonly CELL_H=2
readonly SIDEBAR_X=70
readonly MIN_TERM_W=120
readonly MIN_TERM_H=32

# Crop growth stages (turns to mature)
readonly TURNS_TURNIP=3
readonly TURNS_CARROT=4
readonly TURNS_PUMPKIN=6
readonly TURNS_CORN=5

# Sell prices
readonly PRICE_TURNIP=30
readonly PRICE_CARROT=50
readonly PRICE_PUMPKIN=90
readonly PRICE_CORN=70

# ── Colors (256-color) ────────────────────────────────────────────────────────
C_RESET=$(tput sgr0)
C_BOLD=$(tput bold)

# Foreground colors
fg() { tput setaf "$1"; }
bg() { tput setab "$1"; }

C_BLACK=$(fg 0)
C_WHITE=$(fg 15)
C_BROWN=$(fg 130)
C_DARK_BROWN=$(fg 94)
C_GREEN=$(fg 34)
C_BRIGHT_GREEN=$(fg 82)
C_YELLOW=$(fg 226)
C_GOLD=$(fg 220)
C_ORANGE=$(fg 208)
C_CYAN=$(fg 51)
C_BLUE=$(fg 27)
C_PURPLE=$(fg 141)
C_RED=$(fg 196)
C_GRAY=$(fg 245)
C_LIGHT_GRAY=$(fg 250)
C_PINK=$(fg 213)
C_SKY=$(fg 117)
C_DARK_GREEN=$(fg 22)

BG_BROWN=$(bg 94)
BG_DARK=$(bg 235)
BG_DARKER=$(bg 232)
BG_SIDEBAR=$(bg 234)
BG_HEADER=$(bg 22)
BG_WATER=$(bg 27)
BG_TILLED=$(bg 130)
BG_CURSOR=$(bg 226)
BG_GRASS=$(bg 22)

# ── Game State ────────────────────────────────────────────────────────────────
GOLD=150
ENERGY=100
MAX_ENERGY=100
DAY=1
HOUR=6
MINUTE=0
SEASON=0          # 0=Spring 1=Summer 2=Fall 3=Winter
SEASON_DAY=1
SEEDS=5           # starting seeds
TOTAL_HARVESTS=0
MSG=""
MSG_TIMER=0
SCORE=0

declare -a SEASONS=("Spring" "Summer" "Fall" "Winter")
declare -a SEASON_COLORS=(82 226 208 117)

# Cursor position
CUR_ROW=0
CUR_COL=0

# Grid arrays (flat: index = row*GRID_COLS + col)
TOTAL_CELLS=$(( GRID_ROWS * GRID_COLS ))

# Cell state: 0=empty 1=tilled 2=planted 3=watered 4=growing 5=mature 6=dead
declare -a CELL_STATE
# Cell crop type: 0=none 1=turnip 2=carrot 3=pumpkin 4=corn
declare -a CELL_CROP
# Cell growth counter
declare -a CELL_GROWTH
# Cell was watered this turn
declare -a CELL_WATERED

for (( i=0; i<TOTAL_CELLS; i++ )); do
    CELL_STATE[$i]=0
    CELL_CROP[$i]=0
    CELL_GROWTH[$i]=0
    CELL_WATERED[$i]=0
done

declare -a CROP_NAMES=("" "Turnip" "Carrot" "Pumpkin" "Corn")
declare -a CROP_ICONS=("" "🌱" "🥕" "🎃" "🌽")
declare -a CROP_SEEDS=(0 1 1 1 1)  # 1=player has seeds of this type
declare -a SEED_COSTS=(0 10 15 25 20)
declare -a SEED_COUNTS=(0 5 0 0 0)  # starting inventory
SELECTED_CROP=1  # which crop to plant

# Weather
WEATHER=0   # 0=Sunny 1=Cloudy 2=Rainy 3=Windy
declare -a WEATHER_NAMES=("☀  Sunny" "☁  Cloudy" "🌧 Rainy" "💨 Windy")
declare -a WEATHER_COLORS=(226 250 51 245)

# Log/notifications ring buffer
declare -a LOG_LINES
LOG_SIZE=6
LOG_HEAD=0
for (( i=0; i<LOG_SIZE; i++ )); do LOG_LINES[$i]=""; done

# ── Utility Functions ─────────────────────────────────────────────────────────
goto() { tput cup "$1" "$2"; }
clrline() { tput el; }
clrscr() { tput clear; }

log_add() {
    local msg="$1"
    LOG_LINES[$LOG_HEAD]="$msg"
    LOG_HEAD=$(( (LOG_HEAD + 1) % LOG_SIZE ))
}

# Print centered text within a given width
center_text() {
    local text="$1" width="$2"
    local len=${#text}
    local pad=$(( (width - len) / 2 ))
    printf "%${pad}s%s%${pad}s" "" "$text" ""
}

# Get crop turns to mature
crop_turns() {
    case $1 in
        1) echo $TURNS_TURNIP ;;
        2) echo $TURNS_CARROT ;;
        3) echo $TURNS_PUMPKIN ;;
        4) echo $TURNS_CORN ;;
        *) echo 99 ;;
    esac
}

crop_sell_price() {
    case $1 in
        1) echo $PRICE_TURNIP ;;
        2) echo $PRICE_CARROT ;;
        3) echo $PRICE_PUMPKIN ;;
        4) echo $PRICE_CORN ;;
        *) echo 0 ;;
    esac
}

random_range() {
    local min=$1 max=$2
    echo $(( RANDOM % (max - min + 1) + min ))
}

# ── Time & Weather ────────────────────────────────────────────────────────────
advance_time() {
    local mins=30
    MINUTE=$(( MINUTE + mins ))
    if (( MINUTE >= 60 )); then
        MINUTE=$(( MINUTE - 60 ))
        HOUR=$(( HOUR + 1 ))
    fi
    if (( HOUR >= 22 )); then
        log_add "${C_YELLOW}Getting late... Press S to sleep!${C_RESET}"
    fi
}

do_sleep() {
    # Process all crops: grow if watered
    local grew=0
    for (( i=0; i<TOTAL_CELLS; i++ )); do
        local state=${CELL_STATE[$i]}
        local crop=${CELL_CROP[$i]}
        local watered=${CELL_WATERED[$i]}

        if (( state >= 2 && state <= 4 )); then
            if (( watered == 1 )); then
                CELL_GROWTH[$i]=$(( CELL_GROWTH[$i] + 1 ))
                local needed
                needed=$(crop_turns "$crop")
                if (( CELL_GROWTH[$i] >= needed )); then
                    CELL_STATE[$i]=5
                else
                    CELL_STATE[$i]=4
                fi
                (( grew++ ))
            elif (( WEATHER == 2 )); then
                # Rain waters crops automatically
                CELL_GROWTH[$i]=$(( CELL_GROWTH[$i] + 1 ))
                local needed
                needed=$(crop_turns "$crop")
                if (( CELL_GROWTH[$i] >= needed )); then
                    CELL_STATE[$i]=5
                else
                    CELL_STATE[$i]=4
                fi
                (( grew++ ))
            fi
        fi
        CELL_WATERED[$i]=0  # reset watered status
    done

    # Advance day
    DAY=$(( DAY + 1 ))
    HOUR=6
    MINUTE=0
    ENERGY=$MAX_ENERGY

    # Season change every 28 days
    SEASON_DAY=$(( SEASON_DAY + 1 ))
    if (( SEASON_DAY > 28 )); then
        SEASON_DAY=1
        SEASON=$(( (SEASON + 1) % 4 ))
        log_add "${C_CYAN}A new season begins: ${SEASONS[$SEASON]}!${C_RESET}"
    fi

    # New weather
    WEATHER=$(random_range 0 3)

    # Energy bonus on rainy day
    if (( WEATHER == 2 )); then
        log_add "${C_BLUE}It's raining - crops water themselves!${C_RESET}"
    fi

    log_add "${C_YELLOW}Day $DAY begins. ${WEATHER_NAMES[$WEATHER]}${C_RESET}"
    if (( grew > 0 )); then
        log_add "${C_GREEN}$grew crops grew overnight!${C_RESET}"
    fi

    SCORE=$(( SCORE + GOLD / 10 ))
}

# ── Drawing Functions ─────────────────────────────────────────────────────────

draw_header() {
    local term_w
    term_w=$(tput cols)

    # Background bar
    goto 0 0
    printf "%s%s" "$BG_HEADER$C_WHITE$C_BOLD" "$(printf '%*s' "$term_w" '')"
    goto 0 0
    printf "%s 🌾 TUI STARDEW  " "$BG_HEADER$C_BRIGHT_GREEN$C_BOLD"

    # Day & Season
    local season_fg
    season_fg=$(tput setaf "${SEASON_COLORS[$SEASON]}")
    printf "%s Day %-3d %s%-8s" \
        "${C_GOLD}" "$DAY" \
        "${season_fg}" "${SEASONS[$SEASON]}"

    # Clock
    local ampm="AM"
    local disp_h=$HOUR
    (( HOUR >= 12 )) && ampm="PM"
    (( HOUR > 12 ))  && disp_h=$(( HOUR - 12 ))
    (( HOUR == 0 ))  && disp_h=12
    printf "%s  🕐 %02d:%02d %s  " \
        "${C_CYAN}" "$disp_h" "$MINUTE" "$ampm"

    # Weather
    local w_fg
    w_fg=$(tput setaf "${WEATHER_COLORS[$WEATHER]}")
    printf "%s%s  " "${w_fg}" "${WEATHER_NAMES[$WEATHER]}"

    # Gold & Energy
    printf "%s💰 %5dg  " "${C_GOLD}" "$GOLD"

    local energy_color=$C_GREEN
    (( ENERGY < 50 )) && energy_color=$C_YELLOW
    (( ENERGY < 25 )) && energy_color=$C_RED
    printf "%s⚡ %3d/%d  " \
        "${energy_color}" "$ENERGY" "$MAX_ENERGY"

    printf "%s" "$C_RESET"

    # Separator line
    goto 1 0
    printf "%s%s%s" "$C_DARK_GREEN" \
        "$(printf '─%.0s' $(seq 1 "$term_w"))" "$C_RESET"

    # Controls hint
    goto 2 0
    printf "%s P:Plant  W:Water  H:Harvest  S:Sleep  B:Buy Seeds  C:Crop  Q:Quit  %s" \
        "${C_GRAY}" "${C_RESET}"
}

draw_grid() {
    local top=$GRID_TOP
    local left=$GRID_LEFT

    # Draw border around grid
    local border_top=$(( top - 1 ))
    local border_left=$(( left - 2 ))
    local grid_pixel_w=$(( GRID_COLS * CELL_W + 1 ))
    local grid_pixel_h=$(( GRID_ROWS * CELL_H + 1 ))

    # Top border with title
    goto $border_top $border_left
    printf "%s┌" "$C_BROWN$C_BOLD"
    printf "─%.0s" $(seq 1 $(( grid_pixel_w - 1 )))
    printf "┐%s" "$C_RESET"

    # Bottom border
    local border_bot=$(( top + grid_pixel_h ))
    goto $border_bot $border_left
    printf "%s└" "$C_BROWN$C_BOLD"
    printf "─%.0s" $(seq 1 $(( grid_pixel_w - 1 )))
    printf "┘%s" "$C_RESET"

    # Side borders
    for (( r=0; r<grid_pixel_h; r++ )); do
        goto $(( border_top + 1 + r )) $border_left
        printf "%s│%s" "$C_BROWN$C_BOLD" "$C_RESET"
        goto $(( border_top + 1 + r )) $(( border_left + grid_pixel_w ))
        printf "%s│%s" "$C_BROWN$C_BOLD" "$C_RESET"
    done

    # Draw each cell
    for (( row=0; row<GRID_ROWS; row++ )); do
        for (( col=0; col<GRID_COLS; col++ )); do
            local idx=$(( row * GRID_COLS + col ))
            local state=${CELL_STATE[$idx]}
            local crop=${CELL_CROP[$idx]}
            local growth=${CELL_GROWTH[$idx]}
            local watered=${CELL_WATERED[$idx]}
            local is_cursor=0
            (( row == CUR_ROW && col == CUR_COL )) && is_cursor=1

            # Cell top-left pixel position
            local cy=$(( top + row * CELL_H ))
            local cx=$(( left + col * CELL_W ))

            # Determine cell appearance
            local bg_c cell_top cell_bot icon prog_bar
            local fg_c=$C_WHITE

            case $state in
                0)  # Empty (grass)
                    bg_c=$(bg 22)
                    cell_top="     "
                    cell_bot="     "
                    fg_c=$C_BRIGHT_GREEN
                    ;;
                1)  # Tilled
                    bg_c=$(bg 94)
                    cell_top="~~~~~"
                    cell_bot="~~~~~"
                    fg_c=$C_DARK_BROWN
                    ;;
                2|3|4)  # Planted / Watered / Growing
                    if (( watered == 1 )); then
                        bg_c=$(bg 24)  # blue tint when watered
                    else
                        bg_c=$(bg 94)
                    fi
                    fg_c=$C_GREEN
                    local needed
                    needed=$(crop_turns "$crop")
                    local pct=0
                    (( needed > 0 )) && pct=$(( growth * 5 / needed ))
                    (( pct > 5 )) && pct=5
                    prog_bar=""
                    for (( p=0; p<5; p++ )); do
                        if (( p < pct )); then
                            prog_bar+="▓"
                        else
                            prog_bar+="░"
                        fi
                    done
                    local cicon
                    case $crop in
                        1) cicon="T" ;;
                        2) cicon="C" ;;
                        3) cicon="P" ;;
                        4) cicon="N" ;;
                        *) cicon="?" ;;
                    esac
                    if (( growth == 0 )); then
                        cell_top=" ,$cicon, "
                        cell_bot=" ,,, "
                    elif (( growth < needed / 2 )); then
                        cell_top="  ${cicon}  "
                        cell_bot=" ↑↑↑ "
                    else
                        cell_top=" ${cicon}${cicon}${cicon} "
                        cell_bot="↑↑↑↑↑"
                    fi
                    cell_bot="$prog_bar"
                    ;;
                5)  # Mature - ready to harvest!
                    bg_c=$(bg 28)
                    fg_c=$C_YELLOW
                    case $crop in
                        1) cell_top=" TT! " ; cell_bot="★★★★★" ;;
                        2) cell_top=" CC! " ; cell_bot="★★★★★" ;;
                        3) cell_top=" PP! " ; cell_bot="★★★★★" ;;
                        4) cell_top=" NN! " ; cell_bot="★★★★★" ;;
                        *) cell_top=" ??! " ; cell_bot="★★★★★" ;;
                    esac
                    ;;
                6)  # Dead
                    bg_c=$(bg 52)
                    fg_c=$C_GRAY
                    cell_top=" xxx "
                    cell_bot="  ✗  "
                    ;;
                *)
                    bg_c=$(bg 22)
                    cell_top="     "
                    cell_bot="     "
                    ;;
            esac

            # Cursor highlight override
            local cur_bg=$bg_c
            local cur_fg=$fg_c
            if (( is_cursor )); then
                cur_bg=$(bg 226)
                cur_fg=$(tput setaf 0)
            fi

            # Draw top row of cell
            goto $cy $cx
            printf "%s%s%s%s%s" \
                "$cur_bg" "$cur_fg" \
                "$cell_top" \
                "$C_RESET" ""

            # Draw bottom row of cell
            goto $(( cy + 1 )) $cx
            if (( state == 5 && !is_cursor )); then
                # Flashing for mature crops
                printf "%s%s%s%s" \
                    "$(bg 28)$C_YELLOW$C_BOLD" \
                    "$cell_bot" "$C_RESET" ""
            else
                printf "%s%s%s%s%s" \
                    "$cur_bg" "$cur_fg" \
                    "$cell_bot" \
                    "$C_RESET" ""
            fi
        done
    done

    # Column numbers
    for (( col=0; col<GRID_COLS; col++ )); do
        local cx=$(( left + col * CELL_W ))
        goto $(( top - 1 )) $cx
        printf "%s%-5d%s" "$C_GRAY" "$(( col + 1 ))" "$C_RESET"
    done

    # Row labels
    for (( row=0; row<GRID_ROWS; row++ )); do
        local ry=$(( top + row * CELL_H ))
        goto $ry $(( left - 2 ))
        printf "%s%c%s" "$C_GRAY" "$(printf "\\x$(printf '%02x' $(( 65 + row )))")" "$C_RESET"
    done
}

draw_sidebar() {
    local sx=$SIDEBAR_X
    local sy=3
    local sw=48

    # ── Title ──
    goto $sy $sx
    printf "%s%s╔%s╗%s" \
        "$C_BOLD" "$C_BROWN" \
        "$(printf '═%.0s' $(seq 1 $(( sw - 2 ))))" \
        "$C_RESET"
    goto $(( sy + 1 )) $sx
    local title="🌾  FARM DASHBOARD  🌾"
    printf "%s%s║%s%-$((sw-2))s║%s" \
        "$C_BOLD" "$C_BROWN" \
        "$(tput setaf 220)$(tput bold)" \
        "$title" "$C_RESET"
    goto $(( sy + 2 )) $sx
    printf "%s%s╠%s╣%s" \
        "$C_BOLD" "$C_BROWN" \
        "$(printf '═%.0s' $(seq 1 $(( sw - 2 ))))" \
        "$C_RESET"

    local row=$(( sy + 3 ))

    # ── Stats ──
    sidebar_row() {
        goto "$1" $sx
        printf "%s║%s%-$((sw-2))s%s║%s" \
            "$C_BROWN$C_BOLD" \
            "$2" "$3" \
            "$C_BROWN$C_BOLD" "$C_RESET"
    }

    # Energy bar
    local energy_pct=$(( ENERGY * 20 / MAX_ENERGY ))
    local energy_bar=""
    for (( i=0; i<20; i++ )); do
        if (( i < energy_pct )); then
            if (( i < 4 ));       then energy_bar+="$(tput setaf 196)█"
            elif (( i < 8 ));     then energy_bar+="$(tput setaf 208)█"
            elif (( i < 14 ));    then energy_bar+="$(tput setaf 226)█"
            else                       energy_bar+="$(tput setaf 46)█"
            fi
        else
            energy_bar+="$(tput setaf 238)░"
        fi
    done
    energy_bar+="$C_RESET"
    sidebar_row $row "$C_CYAN" " ⚡ Energy: ${energy_bar} ${ENERGY}/${MAX_ENERGY}"
    (( row++ ))

    # Gold
    sidebar_row $row "$C_GOLD" " 💰 Gold:   ${C_YELLOW}${GOLD}g${C_GRAY} (Score: ${SCORE})"
    (( row++ ))

    # Day/Season
    local scolor
    scolor=$(tput setaf "${SEASON_COLORS[$SEASON]}")
    sidebar_row $row "$scolor" " 📅 Day ${DAY}, ${scolor}${SEASONS[$SEASON]}${C_RESET} (Day ${SEASON_DAY}/28)"
    (( row++ ))

    # Weather
    local wcolor
    wcolor=$(tput setaf "${WEATHER_COLORS[$WEATHER]}")
    sidebar_row $row "$wcolor" " ${WEATHER_NAMES[$WEATHER]}   Harvests: ${C_YELLOW}${TOTAL_HARVESTS}"
    (( row++ ))

    # Divider
    goto $row $sx
    printf "%s╠%s╣%s" \
        "$C_BROWN$C_BOLD" \
        "$(printf '═%.0s' $(seq 1 $(( sw - 2 ))))" \
        "$C_RESET"
    (( row++ ))

    # ── Inventory ──
    goto $row $sx
    printf "%s║%s  📦 INVENTORY%-$((sw-16))s%s║%s" \
        "$C_BROWN$C_BOLD" "$C_WHITE$C_BOLD" "" "$C_BROWN$C_BOLD" "$C_RESET"
    (( row++ ))

    sidebar_row $row "$C_YELLOW" "  Seeds in hand: ${C_WHITE}${SEEDS:-0} generic seeds"
    (( row++ ))

    for (( c=1; c<=4; c++ )); do
        local sel_mark="  "
        (( c == SELECTED_CROP )) && sel_mark="${C_YELLOW}▶ ${C_RESET}"
        local cname="${CROP_NAMES[$c]}"
        local cnt="${SEED_COUNTS[$c]}"
        local price="${SEED_COSTS[$c]}"
        local sp
        sp=$(crop_sell_price "$c")
        local bar=""
        case $c in
            1) bar="${C_GREEN}" ;;
            2) bar="${C_ORANGE}" ;;
            3) bar="${C_ORANGE}" ;;
            4) bar="${C_YELLOW}" ;;
        esac
        goto $row $sx
        printf "%s║%s%s%-7s%s %3d seeds  Buy:%3dg Sell:%3dg%s%*s%s║%s" \
            "$C_BROWN$C_BOLD" \
            "$sel_mark" "$bar" "$cname" "$C_RESET" \
            "$cnt" "$price" "$sp" \
            "$C_RESET" \
            $(( sw - 46 )) "" \
            "$C_BROWN$C_BOLD" "$C_RESET"
        (( row++ ))
    done

    # Divider
    goto $row $sx
    printf "%s╠%s╣%s" \
        "$C_BROWN$C_BOLD" \
        "$(printf '═%.0s' $(seq 1 $(( sw - 2 ))))" \
        "$C_RESET"
    (( row++ ))

    # ── Legend ──
    goto $row $sx
    printf "%s║%s  🗺  LEGEND%-$((sw-13))s%s║%s" \
        "$C_BROWN$C_BOLD" "$C_WHITE$C_BOLD" "" "$C_BROWN$C_BOLD" "$C_RESET"
    (( row++ ))

    local legends=(
        "$(bg 22)     $C_RESET ${C_BRIGHT_GREEN}Grass   (empty land)$C_RESET"
        "$(bg 94)     $C_RESET ${C_BROWN}Tilled  (ready to plant)$C_RESET"
        "$(bg 24)     $C_RESET ${C_CYAN}Watered (growing)$C_RESET"
        "$(bg 94)T↑↑▓░$C_RESET ${C_GREEN}Growing (water daily)$C_RESET"
        "$(bg 28)★★★★★$C_RESET ${C_YELLOW}Mature! (press H)$C_RESET"
        "$(bg 226)     $C_RESET ${C_BLACK}Cursor  (your position)$C_RESET"
    )
    for leg in "${legends[@]}"; do
        goto $row $sx
        printf "%s║%s  %s%-$((sw-5))s%s║%s" \
            "$C_BROWN$C_BOLD" "$C_RESET" \
            "$leg" "" \
            "$C_BROWN$C_BOLD" "$C_RESET"
        (( row++ ))
    done

    # Divider
    goto $row $sx
    printf "%s╠%s╣%s" \
        "$C_BROWN$C_BOLD" \
        "$(printf '═%.0s' $(seq 1 $(( sw - 2 ))))" \
        "$C_RESET"
    (( row++ ))

    # ── Activity Log ──
    goto $row $sx
    printf "%s║%s  📜 ACTIVITY LOG%-$((sw-18))s%s║%s" \
        "$C_BROWN$C_BOLD" "$C_WHITE$C_BOLD" "" "$C_BROWN$C_BOLD" "$C_RESET"
    (( row++ ))

    for (( i=0; i<LOG_SIZE; i++ )); do
        local lidx=$(( (LOG_HEAD - LOG_SIZE + i + LOG_SIZE) % LOG_SIZE ))
        local ltext="${LOG_LINES[$lidx]}"
        # Strip ANSI for length calculation
        local plain
        plain=$(echo -e "$ltext" | sed 's/\x1B\[[0-9;]*[a-zA-Z]//g')
        local plen=${#plain}
        local pad=$(( sw - 4 - plen ))
        (( pad < 0 )) && pad=0
        goto $row $sx
        printf "%s║%s  %b%${pad}s%s║%s" \
            "$C_BROWN$C_BOLD" "$C_RESET" \
            "$ltext" "" \
            "$C_BROWN$C_BOLD" "$C_RESET"
        (( row++ ))
    done

    # Bottom border
    goto $row $sx
    printf "%s╚%s╝%s" \
        "$C_BROWN$C_BOLD" \
        "$(printf '═%.0s' $(seq 1 $(( sw - 2 ))))" \
        "$C_RESET"
}

draw_status_bar() {
    local term_h
    term_h=$(tput lines)
    goto $(( term_h - 1 )) 0
    tput el
    if [[ -n "$MSG" ]]; then
        printf "%s%s  ★ %s  ★%s" \
            "$C_BOLD$(bg 22)$C_BRIGHT_GREEN" \
            "" "$MSG" "$C_RESET"
    else
        local cname="${CROP_NAMES[$SELECTED_CROP]}"
        local cidx=$(( CUR_ROW * GRID_COLS + CUR_COL ))
        local cstate=${CELL_STATE[$cidx]}
        local state_name
        case $cstate in
            0) state_name="Grass" ;;
            1) state_name="Tilled" ;;
            2) state_name="Planted" ;;
            3) state_name="Watered" ;;
            4) state_name="Growing (${CELL_GROWTH[$cidx]}/${CROP_NAMES[${CELL_CROP[$cidx]}]})" ;;
            5) state_name="READY! Press H to harvest" ;;
            6) state_name="Dead crop" ;;
            *) state_name="Unknown" ;;
        esac
        printf "%s  Cell [%c%d] State: %-20s  Selected Crop: %-8s  Seeds: %d  Gold: %dg%s" \
            "${C_GRAY}" \
            "$(printf "\\x$(printf '%02x' $(( 65 + CUR_ROW )))")" \
            "$(( CUR_COL + 1 ))" \
            "$state_name" \
            "$cname" \
            "${SEED_COUNTS[$SELECTED_CROP]}" \
            "$GOLD" \
            "$C_RESET"
    fi
}

draw_screen() {
    tput civis  # hide cursor
    draw_header
    draw_grid
    draw_sidebar
    draw_status_bar
}

# ── Actions ───────────────────────────────────────────────────────────────────

do_plant() {
    local idx=$(( CUR_ROW * GRID_COLS + CUR_COL ))
    local state=${CELL_STATE[$idx]}
    local sc=$SELECTED_CROP
    local cnt=${SEED_COUNTS[$sc]}

    if (( ENERGY < 5 )); then
        MSG="Not enough energy! Sleep to recover."
        return
    fi
    if (( cnt < 1 )); then
        MSG="No ${CROP_NAMES[$sc]} seeds! Press B to buy."
        return
    fi
    if (( state == 0 )); then
        # Auto-till first
        CELL_STATE[$idx]=1
        ENERGY=$(( ENERGY - 2 ))
        log_add "${C_BROWN}Tilled soil at $(printf '%c' $(( 65 + CUR_ROW )))$(( CUR_COL + 1 ))${C_RESET}"
    fi
    if (( state == 1 || (state == 0) )); then
        CELL_STATE[$idx]=2
        CELL_CROP[$idx]=$sc
        CELL_GROWTH[$idx]=0
        CELL_WATERED[$idx]=0
        SEED_COUNTS[$sc]=$(( cnt - 1 ))
        ENERGY=$(( ENERGY - 5 ))
        advance_time
        log_add "${C_GREEN}Planted ${CROP_NAMES[$sc]} at $(printf '%c' $(( 65 + CUR_ROW )))$(( CUR_COL + 1 ))${C_RESET}"
        MSG="Planted ${CROP_NAMES[$sc]}! Water it daily."
    else
        MSG="Can't plant here! Tile state: $state"
    fi
}

do_water() {
    local idx=$(( CUR_ROW * GRID_COLS + CUR_COL ))
    local state=${CELL_STATE[$idx]}

    if (( ENERGY < 3 )); then
        MSG="Not enough energy to water!"
        return
    fi
    if (( state >= 2 && state <= 4 )); then
        CELL_WATERED[$idx]=1
        CELL_STATE[$idx]=3
        ENERGY=$(( ENERGY - 3 ))
        advance_time
        log_add "${C_CYAN}Watered crop at $(printf '%c' $(( 65 + CUR_ROW )))$(( CUR_COL + 1 ))${C_RESET}"
        MSG="Watered! Sleep to let it grow."
    elif (( state == 5 )); then
        MSG="Crop is mature - harvest it! (H)"
    elif (( state == 0 )); then
        MSG="No crop here. Plant something first! (P)"
    else
        MSG="Nothing to water here."
    fi
}

do_harvest() {
    local idx=$(( CUR_ROW * GRID_COLS + CUR_COL ))
    local state=${CELL_STATE[$idx]}
    local crop=${CELL_CROP[$idx]}

    if (( ENERGY < 2 )); then
        MSG="Too tired to harvest! Sleep first."
        return
    fi
    if (( state == 5 )); then
        local price
        price=$(crop_sell_price "$crop")
        # Bonus for weather/season
        local bonus=0
        (( WEATHER == 0 )) && bonus=$(( price / 10 ))
        local total=$(( price + bonus ))
        GOLD=$(( GOLD + total ))
        ENERGY=$(( ENERGY - 2 ))
        TOTAL_HARVESTS=$(( TOTAL_HARVESTS + 1 ))
        CELL_STATE[$idx]=1  # back to tilled
        CELL_CROP[$idx]=0
        CELL_GROWTH[$idx]=0
        CELL_WATERED[$idx]=0
        advance_time
        local bonus_str=""
        (( bonus > 0 )) && bonus_str=" (+${bonus}g sunny bonus)"
        log_add "${C_GOLD}Harvested ${CROP_NAMES[$crop]} for ${total}g${bonus_str}${C_RESET}"
        MSG="Sold ${CROP_NAMES[$crop]} for ${total}g!${bonus_str}"
    elif (( state == 0 || state == 1 )); then
        MSG="Nothing growing here."
    else
        local crop_name="${CROP_NAMES[$crop]}"
        local needed
        needed=$(crop_turns "$crop")
        local growth=${CELL_GROWTH[$idx]}
        MSG="Not ready yet! ${crop_name}: ${growth}/${needed} days"
    fi
}

do_buy_seeds() {
    local sc=$SELECTED_CROP
    local cost=${SEED_COSTS[$sc]}

    if (( GOLD < cost )); then
        MSG="Not enough gold! Need ${cost}g, have ${GOLD}g."
        return
    fi
    if (( SEED_COUNTS[$sc] >= 20 )); then
        MSG="Carrying max seeds for ${CROP_NAMES[$sc]}!"
        return
    fi
    GOLD=$(( GOLD - cost ))
    SEED_COUNTS[$sc]=$(( SEED_COUNTS[$sc] + 1 ))
    log_add "${C_PINK}Bought 1 ${CROP_NAMES[$sc]} seed for ${cost}g${C_RESET}"
    MSG="Bought ${CROP_NAMES[$sc]} seed! (${SEED_COUNTS[$sc]} total)"
}

do_change_crop() {
    SELECTED_CROP=$(( (SELECTED_CROP % 4) + 1 ))
    MSG="Selected: ${CROP_NAMES[$SELECTED_CROP]} (Sell: $(crop_sell_price $SELECTED_CROP)g)"
}

do_till() {
    local idx=$(( CUR_ROW * GRID_COLS + CUR_COL ))
    local state=${CELL_STATE[$idx]}

    if (( ENERGY < 4 )); then
        MSG="Too tired to till! Sleep first."
        return
    fi
    if (( state == 0 )); then
        CELL_STATE[$idx]=1
        ENERGY=$(( ENERGY - 4 ))
        advance_time
        log_add "${C_BROWN}Tilled at $(printf '%c' $(( 65 + CUR_ROW )))$(( CUR_COL + 1 ))${C_RESET}"
        MSG="Tilled soil. Ready to plant!"
    else
        MSG="Already tilled (or has a crop)."
    fi
}

# ── Main Loop ─────────────────────────────────────────────────────────────────

main() {
    # Terminal size check
    local tw th
    tw=$(tput cols)
    th=$(tput lines)
    if (( tw < MIN_TERM_W || th < MIN_TERM_H )); then
        echo "Terminal too small! Need ${MIN_TERM_W}x${MIN_TERM_H}, have ${tw}x${th}"
        exit 1
    fi

    tput smcup    # alternate screen
    tput civis    # hide cursor
    clrscr

    # Initial log
    log_add "${C_BRIGHT_GREEN}Welcome to TUI Stardew!${C_RESET}"
    log_add "${C_YELLOW}You start with ${GOLD}g and ${SEED_COUNTS[1]} Turnip seeds.${C_RESET}"
    log_add "${C_CYAN}Plant(P) Water(W) Harvest(H) Sleep(S)${C_RESET}"
    WEATHER=$(random_range 0 3)

    MSG="Welcome! Move with arrows, P to plant, W to water, H to harvest."
    MSG_TIMER=5

    draw_screen

    local key esc_seq
    while true; do
        # Read input (1 char at a time, handle escape sequences)
        IFS= read -r -s -n1 key

        # Clear old message
        if (( MSG_TIMER > 0 )); then
            (( MSG_TIMER-- ))
            (( MSG_TIMER == 0 )) && MSG=""
        fi

        case "$key" in
            # Arrow key escape sequences
            $'\x1b')
                IFS= read -r -s -n1 -t 0.1 esc_seq
                if [[ "$esc_seq" == "[" ]]; then
                    IFS= read -r -s -n1 -t 0.1 esc_seq
                    case "$esc_seq" in
                        A) # Up
                            (( CUR_ROW > 0 )) && (( CUR_ROW-- ))
                            MSG=""
                            ;;
                        B) # Down
                            (( CUR_ROW < GRID_ROWS - 1 )) && (( CUR_ROW++ ))
                            MSG=""
                            ;;
                        C) # Right
                            (( CUR_COL < GRID_COLS - 1 )) && (( CUR_COL++ ))
                            MSG=""
                            ;;
                        D) # Left
                            (( CUR_COL > 0 )) && (( CUR_COL-- ))
                            MSG=""
                            ;;
                    esac
                fi
                ;;

            # WASD movement (but W/S/A/D also used for actions - use lowercase)
            'k'|'K') (( CUR_ROW > 0 )) && (( CUR_ROW-- )) ;;
            'j'|'J') (( CUR_ROW < GRID_ROWS - 1 )) && (( CUR_ROW++ )) ;;
            'l') (( CUR_COL < GRID_COLS - 1 )) && (( CUR_COL++ )) ;;
            'h') (( CUR_COL > 0 )) && (( CUR_COL-- )) ;;

            # Actions (uppercase to avoid WASD conflict)
            'P'|'p')
                do_plant
                MSG_TIMER=4
                ;;
            'W'|'w')
                do_water
                MSG_TIMER=4
                ;;
            'H')
                do_harvest
                MSG_TIMER=4
                ;;
            'S'|'s')
                do_sleep
                MSG_TIMER=4
                ;;
            'B'|'b')
                do_buy_seeds
                MSG_TIMER=4
                ;;
            'C'|'c')
                do_change_crop
                MSG_TIMER=3
                ;;
            'T'|'t')
                do_till
                MSG_TIMER=3
                ;;

            # Quit
            'Q'|'q')
                # Final score screen
                clrscr
                tput cup 5 10
                printf "%s%s╔══════════════════════════════════════╗%s\n" \
                    "$C_BOLD" "$C_GOLD" "$C_RESET"
                tput cup 6 10
                printf "%s%s║         GAME OVER - FINAL STATS      ║%s\n" \
                    "$C_BOLD" "$C_GOLD" "$C_RESET"
                tput cup 7 10
                printf "%s%s╠══════════════════════════════════════╣%s\n" \
                    "$C_BOLD" "$C_GOLD" "$C_RESET"
                tput cup 8 10
                printf "%s%s║  Days Survived  : %-4d               ║%s\n" \
                    "$C_BOLD" "$C_YELLOW" "$DAY" "$C_RESET"
                tput cup 9 10
                printf "%s%s║  Final Gold     : %-4dg              ║%s\n" \
                    "$C_BOLD" "$C_YELLOW" "$GOLD" "$C_RESET"
                tput cup 10 10
                printf "%s%s║  Total Harvests : %-4d               ║%s\n" \
                    "$C_BOLD" "$C_YELLOW" "$TOTAL_HARVESTS" "$C_RESET"
                tput cup 11 10
                printf "%s%s║  Final Season   : %-10s         ║%s\n" \
                    "$C_BOLD" "$C_YELLOW" "${SEASONS[$SEASON]}" "$C_RESET"
                tput cup 12 10
                printf "%s%s║  Score          : %-4d               ║%s\n" \
                    "$C_BOLD" "$C_YELLOW" "$SCORE" "$C_RESET"
                tput cup 13 10
                printf "%s%s╚══════════════════════════════════════╝%s\n" \
                    "$C_BOLD" "$C_GOLD" "$C_RESET"
                tput cup 15 10
                printf "%s Thanks for playing TUI Stardew! 🌾%s\n" \
                    "$C_GREEN$C_BOLD" "$C_RESET"
                sleep 2
                exit 0
                ;;
        esac

        # Redraw
        draw_screen
    done
}

main