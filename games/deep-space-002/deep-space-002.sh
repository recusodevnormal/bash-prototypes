#!/usr/bin/env bash
# =============================================================================
#  DEEP SPACE SCAVENGER - TUI Dashboard
#  A full space RPG in one Bash script
#
# DEPENDENCIES: bash, tput, stty
#               All standard GNU/Unix utilities. No network access.
#
# USAGE:  chmod +x deep-space-002.sh && ./deep-space-002.sh
# =============================================================================

# ---------------------------------------------------------------------------
# STRICT MODE — catch errors early
# ---------------------------------------------------------------------------
set -euo pipefail
IFS=$'\n\t'

trap 'tput reset; stty sane; echo -e "\nThanks for playing Deep Space Scavenger." ; exit 0' EXIT INT TERM

# ========================== CONFIG & COLORS ==========================
bold='\e[1m'
green='\e[32m'
cyan='\e[36m'
yellow='\e[33m'
red='\e[31m'
reset='\e[0m'

# ========================== GAME STATE ==========================
fuel=92
max_fuel=120
credits=680
hull=100
current_system="Sol"
minerals=4
tech=2
artifacts=0
cargo_max=25
total_cargo=6

# Inventory associative array for safe access
declare -A inventory=(
    [minerals]=4
    [tech]=2
    [artifacts]=0
)

log_message="Welcome, Scavenger. NSS Vanguard systems online."

game_running=true

# ========================== DATA ==========================
systems=("Sol" "Proxima Centauri" "Sirius" "Vega")

get_connected() {
  case "$current_system" in
    "Sol") echo "Proxima Centauri Sirius Vega" ;;
    "Proxima Centauri") echo "Sol Sirius" ;;
    "Sirius") echo "Sol Proxima Centauri Vega" ;;
    "Vega") echo "Sol Sirius" ;;
  esac
}

get_travel_cost() {
  local from="$current_system"
  local to="$1"
  case "$from" in
    "Sol")
      [[ "$to" == "Proxima Centauri" ]] && echo 14
      [[ "$to" == "Sirius" ]] && echo 19
      [[ "$to" == "Vega" ]] && echo 27
      ;;
    "Proxima Centauri")
      [[ "$to" == "Sol" ]] && echo 14
      [[ "$to" == "Sirius" ]] && echo 23
      ;;
    "Sirius")
      [[ "$to" == "Sol" ]] && echo 19
      [[ "$to" == "Proxima Centauri" ]] && echo 23
      [[ "$to" == "Vega" ]] && echo 15
      ;;
    "Vega")
      [[ "$to" == "Sol" ]] && echo 27
      [[ "$to" == "Sirius" ]] && echo 15
      ;;
  esac
}

get_buy_price() {
  local sys="$1" good="$2"
  case "$sys" in
    "Sol")          [[ $good -eq 1 ]] && echo 16; [[ $good -eq 2 ]] && echo 45; [[ $good -eq 3 ]] && echo 135 ;;
    "Proxima Centauri") [[ $good -eq 1 ]] && echo 13; [[ $good -eq 2 ]] && echo 38; [[ $good -eq 3 ]] && echo 105 ;;
    "Sirius")       [[ $good -eq 1 ]] && echo 19; [[ $good -eq 2 ]] && echo 33; [[ $good -eq 3 ]] && echo 165 ;;
    "Vega")         [[ $good -eq 1 ]] && echo 23; [[ $good -eq 2 ]] && echo 68; [[ $good -eq 3 ]] && echo 92 ;;
  esac
}

get_sell_price() {
  local buy
  buy=$(get_buy_price "$1" "$2")
  echo $((buy - 7 - RANDOM % 5))
}

# ========================== DRAW DASHBOARD ==========================
draw_dashboard() {
  clear
  total_cargo=$((inventory[minerals] + inventory[tech] + inventory[artifacts]))

  fuel_pct=$((fuel * 100 / max_fuel))
  fuel_bar=$(printf '█%.0s' $(seq 1 $((fuel_pct/10))); printf '░%.0s' $(seq 1 $((10 - fuel_pct/10))))
  hull_bar=$(printf '█%.0s' $(seq 1 $((hull/10))); printf '░%.0s' $(seq 1 $((10 - hull/10))))

  cat << EOF
${green}╔══════════════════════════════════════════════════════════════════════════════════╗${reset}
${green}║${reset}               ${bold}DEEP SPACE SCAVENGER${reset}  —  ${cyan}NSS VANGUARD${reset}                     ${green}║${reset}
${green}╠══════════════════════════════════════════════════════════════════════════════════╣${reset}
${green}║${reset} FUEL [${cyan}${fuel_bar}${reset}] ${fuel}/${max_fuel}   CREDITS: ${yellow}${credits}${reset}   HULL [${red}${hull_bar}${reset}] ${hull}%     ${green}║${reset}
${green}╠═══════════════════════╦══════════════════════════════════════════════════════════╣${reset}
${green}║${reset}      ${bold}STAR MAP${reset}         ${green}║${reset}  ${bold}CURRENT SYSTEM:${reset} ${current_system}                      ${green}║${reset}
EOF

  # Dynamic map with current location marker
  if [[ "$current_system" == "Sol" ]]; then
    echo -e "${green}║${reset}   Proxima             ${green}║${reset}    (*) SOL ───── Sirius                       ${green}║${reset}"
    echo -e "${green}║${reset}     \\                ${green}║${reset}       │                                       ${green}║${reset}"
    echo -e "${green}║${reset}      \\               ${green}║${reset}       │                                       ${green}║${reset}"
    echo -e "${green}║${reset}       Vega            ${green}║${reset}       Proxima ── Sirius ── Vega               ${green}║${reset}"
  elif [[ "$current_system" == "Proxima Centauri" ]]; then
    echo -e "${green}║${reset}   Proxima(*)          ${green}║${reset}      SOL ───── Sirius                       ${green}║${reset}"
    echo -e "${green}║${reset}     \\                ${green}║${reset}       │                                       ${green}║${reset}"
    echo -e "${green}║${reset}      \\               ${green}║${reset}       │                                       ${green}║${reset}"
    echo -e "${green}║${reset}       Vega            ${green}║${reset}       Proxima ── Sirius ── Vega               ${green}║${reset}"
  elif [[ "$current_system" == "Sirius" ]]; then
    echo -e "${green}║${reset}   Proxima             ${green}║${reset}      SOL ───── Sirius(*)                   ${green}║${reset}"
    echo -e "${green}║${reset}     \\                ${green}║${reset}       │                                       ${green}║${reset}"
    echo -e "${green}║${reset}      \\               ${green}║${reset}       │                                       ${green}║${reset}"
    echo -e "${green}║${reset}       Vega            ${green}║${reset}       Proxima ── Sirius ── Vega               ${green}║${reset}"
  else
    echo -e "${green}║${reset}   Proxima             ${green}║${reset}      SOL ───── Sirius                       ${green}║${reset}"
    echo -e "${green}║${reset}     \\                ${green}║${reset}       │                                       ${green}║${reset}"
    echo -e "${green}║${reset}      \\               ${green}║${reset}       │                                       ${green}║${reset}"
    echo -e "${green}║${reset}       Vega(*)         ${green}║${reset}       Proxima ── Sirius ── Vega               ${green}║${reset}"
  fi

  cat << EOF
${green}╠═══════════════════════╩══════════════════════════════════════════════════════════╣${reset}
${green}║${reset} CARGO: Min:${inventory[minerals]} Tech:${inventory[tech]} Art:${inventory[artifacts]}  (${total_cargo}/${cargo_max})                    ${green}║${reset}
${green}║${reset} LOG: ${log_message}                                            ${green}║${reset}
${green}╠══════════════════════════════════════════════════════════════════════════════════╣${reset}
${green}║${reset}  [${bold}N${reset}]avigate  [${bold}T${reset}]rade  [${bold}R${reset}]efuel  [${bold}Q${reset}]uit                               ${green}║${reset}
${green}╚══════════════════════════════════════════════════════════════════════════════════╝${reset}
EOF
}

# ========================== GAME FUNCTIONS ==========================
navigate_menu() {
  clear
  echo -e "${bold}NAVIGATION COMPUTER${reset}\n"
  echo "Current: $current_system"
  echo -e "\nConnected systems:\n"

  local i=1
  local dests=($(get_connected))
  for dest in "${dests[@]}"; do
    cost=$(get_travel_cost "$dest")
    printf "  %d. %-18s  Fuel: %d\n" $i "$dest" "$cost"
    ((i++))
  done
  echo -e "\n  0. Cancel"

  read -p "> " choice
  [[ $choice -eq 0 ]] && return

  # Input validation
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 0 ] || [ "$choice" -gt "${#dests[@]}" ]; then
    log_message="${red}Invalid selection${reset}"
    return
  fi

  local target="${dests[$((choice-1))]}"
  local cost=$(get_travel_cost "$target")

  if [[ $fuel -lt $cost ]]; then
    log_message="${red}INSUFFICIENT FUEL${reset}"
    return
  fi

  fuel=$((fuel - cost))
  log_message="Jumping to ${target}..."

  sleep 1.2

  current_system="$target"

  # Random event
  local roll=$((RANDOM % 100))
  if [[ $roll -lt 32 ]]; then
    log_message="${red}PIRATE INTERCEPT DETECTED!${reset}"
    sleep 1
    pirate_encounter
  elif [[ $roll -lt 50 ]]; then
    log_message="Found derelict cargo pod. +280 credits"
    credits=$((credits + 280))
  else
    log_message="Safe arrival at ${target}."
  fi
}

refuel_menu() {
  clear
  echo -e "${bold}REFUELING DOCK${reset}\n"
  echo "Current fuel: $fuel/$max_fuel"
  echo "Price: 9 credits per unit"
  read -p "Units to buy (max $((max_fuel-fuel))): " amt

  [[ -z "$amt" || $amt -le 0 ]] && return
  # Input validation - ensure numeric
  if ! [[ "$amt" =~ ^[0-9]+$ ]]; then
    log_message="${red}Invalid amount${reset}"
    return
  fi
  [[ $amt -gt $((max_fuel-fuel)) ]] && amt=$((max_fuel-fuel))

  local cost=$((amt * 9))
  if [[ $credits -ge $cost ]]; then
    credits=$((credits - cost))
    fuel=$((fuel + amt))
    log_message="Refueled $amt units."
  else
    log_message="${red}Not enough credits${reset}"
  fi
}

trade_menu() {
  while true; do
    clear
    echo -e "${bold}MARKET — ${current_system}${reset}\n"
    echo "Credits: ${yellow}$credits${reset}   Cargo: ${total_cargo}/${cargo_max}"
    echo

    local m_buy tech_buy a_buy
    m_buy=$(get_buy_price "$current_system" 1)
    tech_buy=$(get_buy_price "$current_system" 2)
    a_buy=$(get_buy_price "$current_system" 3)

    local m_sell tech_sell a_sell
    m_sell=$(get_sell_price "$current_system" 1)
    tech_sell=$(get_sell_price "$current_system" 2)
    a_sell=$(get_sell_price "$current_system" 3)

    echo "1. Minerals    Buy $m_buy   Sell $m_sell   Owned: ${inventory[minerals]}"
    echo "2. Tech        Buy $tech_buy Sell $tech_sell Owned: ${inventory[tech]}"
    echo "3. Artifacts   Buy $a_buy   Sell $a_sell   Owned: ${inventory[artifacts]}"
    echo -e "\nB1/B2/B3 = buy, S1/S2/S3 = sell, 0 = exit"

    read -p "> " act
    [[ $act == "0" ]] && break

    local cmd=${act:0:1}
    local g=${act:1:1}
    local qty=${act:2}
    [[ -z $qty ]] && qty=1

    # Input validation for quantity
    if ! [[ "$qty" =~ ^[0-9]+$ ]] || [[ "$qty" -lt 1 ]]; then
      log_message="${red}Invalid quantity${reset}"
      continue
    fi

    case $cmd in
      b|B)
        case $g in
          1) price=$m_buy; item=minerals ;;
          2) price=$tech_buy; item=tech ;;
          3) price=$a_buy; item=artifacts ;;
          *) continue ;;
        esac
        if [[ $total_cargo + qty -gt $cargo_max ]]; then
          log_message="${red}Cargo hold full${reset}"; continue
        fi
        cost=$((price * qty))
        if [[ $credits -ge $cost ]]; then
          credits=$((credits - cost))
          inventory[$item]=$((${inventory[$item]} + qty))
          total_cargo=$((total_cargo + qty))
          log_message="Purchased $qty units."
        else
          log_message="${red}Insufficient credits${reset}"
        fi
        ;;
      s|S)
        case $g in
          1) price=$m_sell; item=minerals ;;
          2) price=$tech_sell; item=tech ;;
          3) price=$a_sell; item=artifacts ;;
          *) continue ;;
        esac
        if [[ ${inventory[$item]} -lt $qty ]]; then
          log_message="${red}Not enough cargo${reset}"; continue
        fi
        credits=$((credits + price * qty))
        inventory[$item]=$((${inventory[$item]} - qty))
        total_cargo=$((total_cargo - qty))
        log_message="Sold $qty units."
        ;;
    esac
  done
}

pirate_encounter() {
  local enemy_hull=62
  while [[ $enemy_hull -gt 0 && $hull -gt 0 ]]; do
    clear
    echo -e "${red}╔═══════════════════════ PIRATE ENGAGEMENT ═══════════════════════╗${reset}"
    printf " ${bold}YOUR SHIP${reset}                          ${bold}PIRATE RAIDER${reset}\n"
    printf " Hull: %3d/100                     Hull: %3d/62\n" $hull $enemy_hull
    echo
    echo " 1. Laser Cannon     (15-25 dmg)"
    echo " 2. Missile          (35 dmg, 6 fuel)"
    echo " 3. Emergency Flee"
    echo " 4. Hail (risky)"
    read -s -n1 choice

    case $choice in
      1)
        dmg=$((RANDOM % 11 + 15))
        enemy_hull=$((enemy_hull - dmg))
        log_message="Laser hit for $dmg damage!"
        ;;
      2)
        if [[ $fuel -ge 6 ]]; then
          fuel=$((fuel-6))
          enemy_hull=$((enemy_hull-35))
          log_message="Missile direct hit!"
        else
          log_message="Not enough fuel for missile."
        fi
        ;;
      3)
        if (( RANDOM % 3 == 0 )); then
          log_message="You escaped!"
          return
        else
          log_message="Flee failed!"
        fi
        ;;
      4)
        if (( RANDOM % 8 == 0 )); then
          log_message="They took 300 credits and left."
          credits=$((credits-300))
          return
        else
          log_message="They laughed and opened fire."
        fi
        ;;
    esac

    # Enemy turn
    if [[ $enemy_hull -gt 0 ]]; then
      edmg=$((RANDOM % 17 + 9))
      hull=$((hull - edmg))
      log_message="${log_message} Enemy hit for $edmg!"
    fi
    sleep 1.1
  done

  if [[ $hull -le 0 ]]; then
    game_over
  else
    log_message="${green}PIRATES DESTROYED! +450 credits & 3 minerals${reset}"
    credits=$((credits + 450))
    inventory[minerals]=$((${inventory[minerals]} + 3))
    total_cargo=$((total_cargo + 3))
  fi
}

game_over() {
  clear
  echo -e "${red}╔══════════════════════════════════════════════════════════════════════════════╗${reset}"
  echo -e "${red}║${reset}                          ${bold}HULL BREACH - CRITICAL${reset}                          ${red}║${reset}"
  echo -e "${red}║${reset}                    Your journey ends in the black...                       ${red}║${reset}"
  echo -e "${red}╚══════════════════════════════════════════════════════════════════════════════╝${reset}"
  echo -e "\nFinal Credits: ${yellow}$credits${reset}"
  echo "Systems visited: All major routes"
  echo -e "\nPress any key to exit..."
  read -n1
  game_running=false
}

# ========================== MAIN LOOP ==========================
main() {
  while $game_running; do
    draw_dashboard
    read -s -n1 input
    case "$input" in
      [Nn]) navigate_menu ;;
      [Tt]) trade_menu ;;
      [Rr]) refuel_menu ;;
      [Qq]) game_running=false ;;
      *) log_message="Command not recognized." ;;
    esac
  done
}

# Start game
echo -e "${green}Initializing Vanguard systems...${reset}"
sleep 1.2
main