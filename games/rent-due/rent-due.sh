#!/usr/bin/env bash
# Rent's Due Tomorrow - A Street-Level Heist

if [ -z "$BASH_VERSION" ]; then
    echo "Error: This game requires bash."
    exit 1
fi

if [ ! -t 0 ]; then
    echo "Error: This game requires an interactive terminal."
    exit 1
fi

set -euo pipefail
IFS=$'\n\t'

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
ORANGE='\033[38;5;208m'

clear_screen() { printf '\033[2J\033[H'; }
hide_cursor() { printf '\033[?25l'; }
show_cursor() { printf '\033[?25h'; }
play_sound() { printf '\007'; }

draw_header() {
    clear_screen
    local day_color=$GREEN
    if [ $DAYS_LEFT -eq 2 ]; then day_color=$YELLOW
    elif [ $DAYS_LEFT -eq 1 ]; then day_color=$RED
    fi

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${BOLD}${RED}RENT'S DUE TOMORROW${NC}                                      ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} Day $DAY | ${day_color}Days Left: $DAYS_LEFT${NC} | ${WHITE}Rent: $TARGET_RENT${NC}                              ${CYAN}║${NC}"
}

draw_status() {
    local heat_color=$GREEN
    if [ $HEAT -gt 30 ]; then heat_color=$YELLOW
    elif [ $HEAT -gt 60 ]; then heat_color=$RED
    fi

    echo -e "${CYAN}║${NC} ${YELLOW}Cash: ${WHITE}$$${CASH}${NC} ${CYAN}│${NC} ${RED}Heat: ${heat_color}$HEAT%${NC} ${CYAN}│${NC} ${BLUE}Rep: ${WHITE}$REPUTATION${NC}            ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════╣${NC}"
}

draw_footer() {
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
}

draw_box() {
    local text="$1"
    local len=${#text}
    local padding=$(( (60 - len) / 2 ))
    echo -e "${CYAN}║${NC}$(printf ' %.0s' $(seq 1 $padding))${BOLD}${WHITE}$text${NC}$(printf ' %.0s' $(seq 1 $((60 - padding - len))))${CYAN}║${NC}"
}

CASH=12
HEAT=0
REPUTATION=0
DAYS_LEFT=3
DAY=1
TARGET_RENT=800
PLAYER_NAME=""
KNOWN_FACE=false

declare -A TARGETS
TARGETS=(
    [car]="Wheels of Misfortune:20:80:10:Car break-in:Evergreen:car"
    [store]="6-To-9 Minimart:100:200:40:Corner store:Evergreen:store"
    [pawn]="Pawn Out Your Dignity:200:500:50:Pawn shop:Eastburn:pawn"
    [gas]="B.P.:80:150:30:Gas station:Industrial:gas"
    [shop]="Mister Lube:150:300:35:Auto shop:Eastburn:shop"
    [warehouse]="Save-More Storage:500:1500:60:Warehouse:Industrial:warehouse"
    [house]="The Hills:300:600:45:House:Evergreen:house"
)

declare -A CREW_LOYALTY
CREW_LOYALTY=(
    [Dizzy]=2
    [Kit]=2
    [Brick]=2
    [Mouse]=2
    [Raven]=2
)

declare -A NEIGHBORHOOD_HEAT
NEIGHBORHOOD_HEAT=(
    [Evergreen]=0
    [Eastburn]=0
    [Industrial]=0
)

declare -A CREW
CREW=(
    [Dizzy]="Dizzy:50:0:0:Your old contact."
    [Kit]="Kit:75:3:2:Tech kid."
    [Brick]="Brick:100:1:4:Muscle."
    [Mouse]="Mouse:60:2:1:Wheelman."
    [Raven]="Raven:80:4:3:The face."
)

trigger_random_event() {
    local key=$1
    local event_roll=$((RANDOM % 100))
    
    if [ $event_roll -lt 30 ]; then
        local event=$((RANDOM % 6))
        
        draw_header
        draw_status
        
        case $event in
            0)
                echo -e "${CYAN}║${NC} ${YELLOW}Guard patrol walks by...${NC}                                ${CYAN}║${NC}"
                echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════╣${NC}"
                echo -e "${CYAN}║${NC} 1) Duck and wait (safe, -20 payout)                          ${CYAN}║${NC}"
                echo -e "${CYAN}║${NC} 2) Move fast (risky)                                        ${CYAN}║${NC}"
                echo -e "${CYAN}║${NC} 3) Run (abandon job)                                        ${CYAN}║${NC}"
                draw_footer
                printf "Choice [1-3]: "
                read -t 4 -r event_choice
                case "$event_choice" in
                    1) return 20 ;;
                    2)
                        if [ $((RANDOM % 2)) -eq 0 ]; then
                            echo -e "${RED}Guard caught a glimpse.${NC}"
                            HEAT=$((HEAT + 15))
                        fi
                        return 0
                        ;;
                    *) return -1 ;;
                esac
                ;;
            1)
                echo -e "${CYAN}║${NC} ${GREEN}Lucky find!${NC}                                                        ${CYAN}║${NC}"
                echo -e "${CYAN}║${NC} You spot extra cash in a drawer.                                ${CYAN}║${NC}"
                draw_footer
                sleep 1
                return 50
                ;;
            2)
                echo -e "${CYAN}║${NC} ${RED}Security camera spots you!${NC}                                 ${CYAN}║${NC}"
                echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════╣${NC}"
                echo -e "${CYAN}║${NC} 1) Smash it (adds heat)                                     ${CYAN}║${NC}"
                echo -e "${CYAN}║${NC} 2) Cut and run                                               ${CYAN}║${NC}"
                draw_footer
                printf "Choice [1-2]: "
                read -t 3 -r event_choice
                case "$event_choice" in
                    1)
                        echo -e "Camera destroyed."
                        HEAT=$((HEAT + 20))
                        return 0
                        ;;
                    *) return -1 ;;
                esac
                ;;
            3)
                echo -e "${CYAN}║${NC} ${ORANGE}Dog starts barking!${NC}                                        ${CYAN}║${NC}"
                echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════╣${NC}"
                echo -e "${CYAN}║${NC} 1) Calm it down (requires low heat)                          ${CYAN}║${NC}"
                echo -e "${CYAN}║${NC} 2) Leave quickly                                             ${CYAN}║${NC}"
                draw_footer
                printf "Choice [1-2]: "
                read -t 3 -r event_choice
                case "$event_choice" in
                    1)
                        if [ $HEAT -lt 30 ]; then
                            echo -e "${GREEN}Dog settles.${NC}"
                            return 0
                        else
                            echo -e "${RED}Dog smells your nerves.${NC}"
                            HEAT=$((HEAT + 15))
                            return -1
                        fi
                        ;;
                    *) return -1 ;;
                esac
                ;;
            4)
                echo -e "${CYAN}║${NC} Someone pulls into the lot...                                  ${CYAN}║${NC}"
                echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════╣${NC}"
                echo -e "${CYAN}║${NC} 1) Play it cool                                              ${CYAN}║${NC}"
                echo -e "${CYAN}║${NC} 2) duck out back                                            ${CYAN}║${NC}"
                draw_footer
                printf "Choice [1-2]: "
                read -t 3 -r event_choice
                case "$event_choice" in
                    1)
                        if [ $((RANDOM % 2)) -eq 0 ]; then
                            echo -e "${GREEN}Just a customer.${NC}"
                            return 0
                        else
                            HEAT=$((HEAT + 25))
                            return -1
                        fi
                        ;;
                    *) return -1 ;;
                esac
                ;;
            5)
                echo -e "${CYAN}║${NC} ${MAGENTA}Alarm glitches!${NC}                                           ${CYAN}║${NC}"
                echo -e "${CYAN}║${NC} You have a window.                                          ${CYAN}║${NC}"
                echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════╣${NC}"
                echo -e "${CYAN}║${NC} 1) Move FAST (double payout possible)                      ${CYAN}║${NC}"
                echo -e "${CYAN}║${NC} 2) Take your time                                            ${CYAN}║${NC}"
                draw_footer
                printf "Choice [1-2]: "
                read -t 3 -r event_choice
                case "$event_choice" in
                    1)
                        if [ $((RANDOM % 3)) -ne 0 ]; then
                            echo -e "${GREEN}Jackpot!${NC}"
                            return 100
                        else
                            echo -e "${RED}Alarm reset. You're caught.${NC}"
                            HEAT=$((HEAT + 30))
                            return -1
                        fi
                        ;;
                    *) return 0 ;;
                esac
                ;;
        esac
    fi
    return 0
}

check_neighborhood_heat() {
    local area_heat=${NEIGHBORHOOD_HEAT[$1]}
    if [ $area_heat -gt 70 ]; then
        return 1
    fi
    return 0
}

update_neighborhood_heat() {
    local current=${NEIGHBORHOOD_HEAT[$1]}
    local new_heat=$(($2))
    [ $new_heat -gt 100 ] && new_heat=100
    [ $new_heat -lt 0 ] && new_heat=0
    NEIGHBORHOOD_HEAT[$1]=$new_heat
}

update_crew_loyalty() {
    local current=${CREW_LOYALTY[$1]}
    local new_loyalty=$(($2))
    [ $new_loyalty -gt 5 ] && new_loyalty=5
    [ $new_loyalty -lt 0 ] && new_loyalty=0
    CREW_LOYALTY[$1]=$new_loyalty
}

check_rival_crew() {
    if [ $REPUTATION -gt 8 ]; then
        if [ $((RANDOM % 100)) -lt 30 ]; then
            draw_header
            draw_status
            echo -e "${CYAN}║${NC} ${RED}RIVAL CREW!${NC}                                                     ${CYAN}║${NC}"
            echo -e "${CYAN}║${NC} Word's gotten around. Another crew hit your target first.        ${CYAN}║${NC}"
            HEAT=$((HEAT + 20))
            draw_footer
            sleep 2
            return 1
        fi
    fi
    return 0
}

check_known_face() {
    if [ "$KNOWN_FACE" = true ]; then
        if [ $((RANDOM % 100)) -lt 40 ]; then
            draw_header
            draw_status
            echo -e "${CYAN}║${NC} ${YELLOW}CLERK RECOGNIZES YOU!${NC}                                           ${CYAN}║${NC}"
            echo -e "${CYAN}║${NC} \"$PLAYER_NAME\"? Ain't seen you in a while...                      ${CYAN}║${NC}"
            HEAT=$((HEAT + 15))
            draw_footer
            sleep 2
            return 1
        fi
    fi
    return 0
}

show_title() {
    clear_screen
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}         ${BOLD}${RED}RENT'S DUE TOMORROW${NC}                                      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}             Street-Level Heist                                   ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} Rent due in 3 days. You got a kid. You got 12 bucks.            ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} Need $TARGET_RENT by Friday or you're out.                          ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════���═══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} 1-7=Target S=Save L=Load H=Help Q=Quit                           ${CYAN}║${NC}"
    draw_footer
    
    echo ""
    printf "What's your name? "
    read -r PLAYER_NAME
    [ -z "$PLAYER_NAME" ] && PLAYER_NAME="Nobody"
}

show_help() {
    draw_header
    draw_status
    draw_box "HELP"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} You need $TARGET_RENT in 3 days. Options worsen daily.                  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                                 ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} Cash - money for bribes/retries                                   ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} Heat - blocks jobs eventually                                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} Rep - unlocks targets, attracts rivals at high levels              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                                 ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} Areas track their own heat. Stay low or get locked out.       ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                                 ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} Tips: Start small. Lay low to cool areas.                       ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} Press any key...                                               ${CYAN}║${NC}"
    draw_footer
    read -rsn1
}

save_game() {
    local save_dir="$HOME/.rentdue_saves"
    mkdir -p "$save_dir" 2>/dev/null
    cat > "$save_dir/save.dat" << EOF
CASH=$CASH
HEAT=$HEAT
REPUTATION=$REPUTATION
DAYS_LEFT=$DAYS_LEFT
DAY=$DAY
PLAYER_NAME=$PLAYER_NAME
KNOWN_FACE=$KNOWN_FACE
NEIGHBORHOOD_HEAT[Evergreen]=${NEIGHBORHOOD_HEAT[Evergreen]}
NEIGHBORHOOD_HEAT[Eastburn]=${NEIGHBORHOOD_HEAT[Eastburn]}
NEIGHBORHOOD_HEAT[Industrial]=${NEIGHBORHOOD_HEAT[Industrial]}
CREW_LOYALTY[Dizzy]=${CREW_LOYALTY[Dizzy]}
CREW_LOYALTY[Kit]=${CREW_LOYALTY[Kit]}
CREW_LOYALTY[Brick]=${CREW_LOYALTY[Brick]}
CREW_LOYALTY[Mouse]=${CREW_LOYALTY[Mouse]}
CREW_LOYALTY[Raven]=${CREW_LOYALTY[Raven]}
EOF
    echo -e "${GREEN}Game saved!${NC}"
    sleep 1
}

load_game() {
    local save_dir="$HOME/.rentdue_saves"
    if [ -f "$save_dir/save.dat" ]; then
        source "$save_dir/save.dat"
        echo -e "${GREEN}Game loaded!${NC}"
        sleep 1
        return 0
    else
        echo -e "${RED}No save found.${NC}"
        sleep 1
        return 1
    fi
}

select_target() {
    local target_keys=("${!TARGETS[@]}")
    local count=0
    local available=()

    draw_header
    draw_status

    local i=1
    for key in "${target_keys[@]}"; do
        local info="${TARGETS[$key]}"
        local name="${info%%:*}"
        local rest="${info#*:}"
        local payout="${rest%%:*}"
        rest="${rest#*:}"; rest="${rest#*:}"; rest="${rest#*:}"
        local neighborhood="${rest%%:*}"
        
        local rep_needed=0
        [ "$key" = "warehouse" ] && rep_needed=5
        [ "$key" = "house" ] && rep_needed=2

        if [ $REPUTATION -ge $rep_needed ]; then
            check_neighborhood_heat "$neighborhood"
            if [ $? -eq 0 ]; then
                count=$((count + 1))
                available+=("$key")
                
                local area_heat=${NEIGHBORHOOD_HEAT[$neighborhood]}
                local heat_indicator=""
                [ $area_heat -gt 50 ] && heat_indicator="${RED}[HOT]${NC}"
                [ $area_heat -gt 30 ] && [ $area_heat -le 50 ] && heat_indicator="${YELLOW}[WARM]${NC}"

                echo -e "${CYAN}║${NC} ${WHITE}$count)${NC} $name ${GRAY}$neighborhood${NC}$heat_indicator"
                echo -e "${CYAN}║${NC}     Payout: $YELLOW\$$payout${NC}"
            fi
        fi
    done

    if [ $count -eq 0 ]; then
        echo -e "${CYAN}║${NC} ${RED}No targets. Build rep or lay low.${NC}                         ${CYAN}║${NC}"
    fi

    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} 5) Call contact | 6) Lay low | S) Save | H) Help                 ${CYAN}║${NC}"
    draw_footer

    printf "Choose [1-$count, 5-6]: "
    read -t 4 -r choice

    case "$choice" in
        1) execute_job "${available[0]}" ;;
        2) execute_job "${available[1]}" ;;
        3) execute_job "${available[2]}" ;;
        4) execute_job "${available[3]}" ;;
        5) call_contact ;;
        6) lay_low ;;
        s|S) save_game; select_target ;;
        h|H) show_help; select_target ;;
        q|Q) show_cursor; clear_screen; exit 0 ;;
        *) return ;;
    esac
}

execute_job() {
    local key=$1
    local info="${TARGETS[$key]}"
    local name="${info%%:*}"
    local rest="${info#*:}"
    local payout="${rest%%:*}"
    rest="${rest#*:}"; rest="${rest#*:}"; rest="${rest#*:}"
    local neighborhood="${rest%%:*}"

    check_rival_crew && return
    check_known_face && return

    draw_header
    draw_status
    draw_box "$name"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${GRAY}$neighborhood${NC}                                                  ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} 1) Go for it                                                   ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} 2) Scout first (+10 heat, reveals payout)                        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} 3) Forget it                                                    ${CYAN}║${NC}"
    draw_footer

    printf "Choice [1-3]: "
    read -t 4 -r choice

    local heat_gen=10
    [ "$key" = "store" ] && heat_gen=25
    [ "$key" = "warehouse" ] && heat_gen=35
    [ "$key" = "house" ] && heat_gen=30

    case "$choice" in
        1) do_job "$key" "$payout" "$neighborhood" "$heat_gen" ;;
        2)
            update_neighborhood_heat "$neighborhood" 10
            local new_payout=$((payout + RANDOM % 50 - 25))
            [ $new_payout -lt 10 ] && new_payout=10
            draw_header
            draw_status
            echo -e "${CYAN}║${NC} You case the joint...                                          ${CYAN}║${NC}"
            echo -e "${CYAN}║${NC} Potential payout: $YELLOW\$$new_payout${NC}                                   ${CYAN}║${NC}"
            draw_footer
            sleep 1
            printf "Do the job? [y/N]: "
            read -t 3 -r confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                do_job "$key" "$new_payout" "$neighborhood" "$heat_gen"
            else
                update_neighborhood_heat "$neighborhood" -5
            fi
            ;;
        *) return ;;
    esac
}

do_job() {
    local key=$1 payout=$2 neighborhood=$3 heat_gen=$4

    trigger_random_event "$key"
    local event_result=$?
    
    if [ $event_result -eq -1 ]; then
        draw_header
        draw_status
        echo -e "${CYAN}║${NC} You bailed.                                                   ${CYAN}║${NC}"
        draw_footer
        sleep 1
        update_neighborhood_heat "$neighborhood" 5
        return
    fi

    local adjusted_payout=$((payout + event_result))
    [ $adjusted_payout -lt 10 ] && adjusted_payout=10

    draw_header
    draw_status
    echo -e "${CYAN}║${NC} Making the move...                                             ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════╣${NC}"

    play_sound
    sleep 0.3

    local risk=30
    [ "$key" = "car" ] && risk=15
    [ "$key" = "store" ] && risk=40
    [ "$key" = "warehouse" ] && risk=55
    [ "$key" = "house" ] && risk=45

    local roll=$((RANDOM % 100 + 1))
    local adjusted_risk=$((risk + HEAT/3))

    if [ $roll -le $adjusted_risk ]; then
        echo -e "${CYAN}║${NC} ${RED}Things went sideways.${NC}                                           ${CYAN}║${NC}"
        local fail_msg=("Cops showed." "Alarm tripped." "Someone knew." "Dog started barking.")
        echo -e "${CYAN}║${NC} ${WHITE}${fail_msg[$((RANDOM % 4))]}${NC}                                     ${CYAN}║${NC}"
        HEAT=$((HEAT + heat_gen + 15))
        [ $HEAT -gt 100 ] && HEAT=100
        update_neighborhood_heat "$neighborhood" 30

        if [ $HEAT -gt 75 ]; then
            echo -e "${CYAN}║${NC} ${BOLD}${RED}Heat's too high. You're done.${NC}                                ${CYAN}║${NC}"
            draw_footer
            sleep 2
            game_over "busted"
        fi
    else
        local actual_payout=$((adjusted_payout - RANDOM % 20))
        [ $actual_payout -lt 10 ] && actual_payout=10

        echo -e "${CYAN}║${NC} ${GREEN}You made out with $${NC}$actual_payout!${NC}                                      ${CYAN}║${NC}"
        CASH=$((CASH + actual_payout))
        
        local base_heat=$heat_gen
        [ $base_heat -lt 5 ] && base_heat=5
        HEAT=$((HEAT + base_heat))
        [ $HEAT -gt 100 ] && HEAT=100

        update_neighborhood_heat "$neighborhood" $base_heat
        REPUTATION=$((REPUTATION + 1))

        [ $REPUTATION -gt 5 ] && KNOWN_FACE=true
    fi

    draw_footer
    sleep 2
}

call_contact() {
    draw_header
    draw_status
    draw_box "CONTACTS"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════╣${NC}"

    local contact_keys=("${!CREW[@]}")
    local i=0
    for key in "${contact_keys[@]}"; do
        local info="${CREW[$key]}"
        local crew_name="${info%%:*}"
        local rest="${info#*:}"; rest="${rest%%:*}"
        local loyalty=${CREW_LOYALTY[$crew_name]}
        
        local loyalty_bar=""
        for ((j=0; j<loyalty; j++)); do loyalty_bar="${loyalty_bar}█"; done
        for ((j=loyalty; j<5; j++)); do loyalty_bar="${loyalty_bar}░"; done

        echo -e "${CYAN}║${NC} ${WHITE}$((i+1))${NC} $crew_name - \$${rest} | [$loyalty_bar]"
        i=$((i + 1))
    done

    echo -e "${CYAN}║${NC} 0) Back                                                        ${CYAN}║${NC}"
    draw_footer

    printf "Choose contact: "
    read -t 4 -r choice

    if [ -z "$choice" ] || [ "$choice" = "0" ]; then
        return
    fi

    local idx=$((choice - 1))
    if [ $idx -ge 0 ] && [ $idx -lt ${#contact_keys[@]} ]; then
        local key="${contact_keys[$idx]}"
        local info="${CREW[$key]}"
        local crew_name="${info%%:*}"
        local rest="${info#*:}"; rest="${rest%%:*}"

        if [ $CASH -ge $rest ]; then
            CASH=$((CASH - rest))
            update_crew_loyalty "$crew_name" 1
            draw_header
            draw_status
            echo -e "${CYAN}║${NC} ${GREEN}$crew_name is in.${NC}                                             ${CYAN}║${NC}"
            HEAT=$((HEAT - 10))
            [ $HEAT -lt 0 ] && HEAT=0
            draw_footer
            sleep 1
        else
            echo -e "${RED}Not enough cash.${NC}"
            sleep 1
        fi
    fi
}

lay_low() {
    draw_header
    draw_status
    draw_box "LAY LOW"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════���═���═╣${NC}"
    echo -e "${CYAN}║${NC} 1) Evergreen  2) Eastburn  3) Industrial                       ${CYAN}║${NC}"
    draw_footer

    printf "Choice [1-3]: "
    read -t 4 -r choice

    case "$choice" in
        1) update_neighborhood_heat "Evergreen" -40 ;;
        2) update_neighborhood_heat "Eastburn" -40 ;;
        3) update_neighborhood_heat "Industrial" -40 ;;
        *) 
            HEAT=$((HEAT - 20))
            [ $HEAT -lt 0 ] && HEAT=0
            ;;
    esac

    draw_header
    draw_status
    echo -e "${CYAN}║${NC} ${BLUE}You lay low. Heat goes down.${NC}                                   ${CYAN}║${NC}"
    draw_footer
    sleep 1

    DAYS_LEFT=$((DAYS_LEFT - 1))
    DAY=$((DAY + 1))
}

check_win() {
    if [ $CASH -ge $TARGET_RENT ]; then
        draw_header
        draw_status
        echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${BOLD}${GREEN}RENT'S PAID!${NC}                                                   ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} You made it. Your kid doesn't have to sleep outside.            ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}Leftover: $CASH${NC}                                                      ${CYAN}║${NC}"
        draw_footer
        play_sound
        read -rsn1
        show_cursor; clear_screen; exit 0
    fi
}

game_over() {
    local reason=$1
    draw_header
    draw_status
    draw_box "GAME OVER"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════╣${NC}"

    case $reason in
        busted)
            echo -e "${CYAN}║${NC} ${RED}You got picked up.${NC}                                                 ${CYAN}║${NC}"
            echo -e "${CYAN}║${NC} Public defender says 18 months.                                      ${CYAN}║${NC}"
            echo -e "${CYAN}║${NC} Your kid's with your sister. She doesn't call.                   ${CYAN}║${NC}"
            ;;
        hospital)
            echo -e "${CYAN}║${NC} ${RED}You woke up in the ICU.${NC}                                           ${CYAN}║${NC}"
            echo -e "${CYAN}║${NC} Nurse asks if you have anyone to call. They don't pick up.          ${CYAN}║${NC}"
            echo -e "${CYAN}║${NC} Your kid's at Child Services. Good luck.                             ${CYAN}║${NC}"
            ;;
        worse)
            echo -e "${CYAN}║${NC} ${RED}Things got worse.${NC}                                                  ${CYAN}║${NC}"
            echo -e "${CYAN}║${NC} Landlord changed the locks. Your stuff's on the curb.                    ${CYAN}║${NC}"
            echo -e "${CYAN}║${NC} At least the baby's used to sleeping rough.                    ${CYAN}║${NC}"
            ;;
    esac

    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} Press any key...                                               ${CYAN}║${NC}"
    draw_footer
    read -rsn1
    show_cursor; clear_screen; exit 0
}

hide_cursor
trap 'show_cursor; clear_screen; exit' INT TERM
trap 'game_over worse' EXIT

show_title

echo ""
echo -e "Press 's' to load save, or any key to start fresh..."
read -rsn1 load_choice
[ "$load_choice" = "s" ] && load_game

draw_header
draw_status
draw_box "YOU'RE IN"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC} You: $PLAYER_NAME                                                    ${CYAN}║${NC}"
echo -e "${CYAN}║${NC} You need $TARGET_RENT in 3 days.                                       ${CYAN}║${NC}"
echo -e "${CYAN}║${NC} Your kid's photo's on the wall. They got your eyes.                       ${CYAN}║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC} Press any key...                                               ${CYAN}║${NC}"
draw_footer
read -rsn1

while [ $CASH -lt $TARGET_RENT ]; do
    [ $DAYS_LEFT -le 0 ] && game_over "worse"

    check_win
    select_target

    DAYS_LEFT=$((DAYS_LEFT - 1))
    DAY=$((DAY + 1))

    if [ $HEAT -gt 50 ] && [ $((RANDOM % 100)) -lt $((HEAT - 50)) ]; then
        draw_header
        draw_status
        echo -e "${CYAN}║${NC} ${RED}Cop car rolls up.${NC}                                             ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} You know what happens next.                                          ${CYAN}║${NC}"
        draw_footer
        sleep 2
        game_over "busted"
    fi
done

game_over "worse"