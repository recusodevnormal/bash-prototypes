#!/bin/bash
# Network Info TUI - No external dependencies
# Works with standard Alpine Linux busybox

# Terminal control
clear_screen() {
    printf '\033[2J\033[H'
}

move_cursor() {
    printf '\033[%d;%dH' "$1" "$2"
}

hide_cursor() {
    printf '\033[?25l'
}

show_cursor() {
    printf '\033[?25h'
}

# Colors
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
MAGENTA='\033[35m'
CYAN='\033[36m'
WHITE='\033[37m'
BOLD='\033[1m'
RESET='\033[0m'

# Get network interfaces
get_interfaces() {
    local interfaces=()
    for iface in /sys/class/net/*; do
        if [ -d "$iface" ]; then
            interfaces+=("$(basename "$iface")")
        fi
    done
    echo "${interfaces[@]}"
}

# Get interface info
get_iface_info() {
    local iface=$1
    local info=""
    
    # State
    if [ -f "/sys/class/net/$iface/operstate" ]; then
        local state=$(cat "/sys/class/net/$iface/operstate" 2>/dev/null)
        info="${info}State: $state\n"
    fi
    
    # IP address
    local ip=$(ip addr show "$iface" 2>/dev/null | grep "inet " | awk '{print $2}' | head -1)
    if [ -n "$ip" ]; then
        info="${info}IP: $ip\n"
    fi
    
    # MAC address
    if [ -f "/sys/class/net/$iface/address" ]; then
        local mac=$(cat "/sys/class/net/$iface/address" 2>/dev/null)
        info="${info}MAC: $mac\n"
    fi
    
    # RX/TX bytes
    if [ -f "/sys/class/net/$iface/statistics/rx_bytes" ]; then
        local rx=$(cat "/sys/class/net/$iface/statistics/rx_bytes" 2>/dev/null)
        local tx=$(cat "/sys/class/net/$iface/statistics/tx_bytes" 2>/dev/null)
        local rx_mb=$((rx / 1024 / 1024))
        local tx_mb=$((tx / 1024 / 1024))
        info="${info}RX: ${rx_mb}MB  TX: ${tx_mb}MB\n"
    fi
    
    echo -e "$info"
}

# Get routing table
get_routes() {
    ip route 2>/dev/null || route -n 2>/dev/null
}

# Get active connections
get_connections() {
    local conns=()
    while IFS= read -r line; do
        if echo "$line" | grep -q "ESTABLISHED\|LISTEN"; then
            conns+=("$line")
        fi
    done < <(netstat -tn 2>/dev/null | tail -n +3)
    echo "${conns[@]}"
}

# Get DNS servers
get_dns() {
    local dns=""
    if [ -f /etc/resolv.conf ]; then
        dns=$(grep "^nameserver" /etc/resolv.conf | awk '{print $2}')
    fi
    echo "$dns"
}

# Draw UI
draw_ui() {
    clear_screen
    
    # Header
    move_cursor 1 1
    printf "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${RESET}"
    move_cursor 2 1
    printf "${BOLD}${CYAN}║${RESET} ${BOLD}${YELLOW}Network Information${RESET} ${BOLD}${CYAN}                                        ║${RESET}"
    move_cursor 3 1
    printf "${BOLD}${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"
    
    local line=5
    
    # Hostname
    move_cursor $line 3
    printf "${BOLD}${WHITE}Hostname:${RESET} $(hostname)"
    ((line++))
    
    # DNS
    local dns=$(get_dns)
    if [ -n "$dns" ]; then
        move_cursor $line 3
        printf "${BOLD}${WHITE}DNS:${RESET} $dns"
        ((line++))
    fi
    
    # Separator
    ((line++))
    move_cursor $line 1
    printf "${BOLD}${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"
    ((line++))
    
    # Network interfaces
    move_cursor $line 3
    printf "${BOLD}${WHITE}Network Interfaces:${RESET}"
    ((line++))
    
    local interfaces=($(get_interfaces))
    for iface in "${interfaces[@]}"; do
        move_cursor $line 5
        printf "${GREEN}${BOLD}$iface${RESET}"
        
        local info=$(get_iface_info "$iface")
        local info_lines=($(echo -e "$info"))
        for info_line in "${info_lines[@]}"; do
            ((line++))
            move_cursor $line 7
            printf "$info_line"
        done
        ((line++))
    done
    
    # Separator
    ((line++))
    move_cursor $line 1
    printf "${BOLD}${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"
    ((line++))
    
    # Default gateway
    move_cursor $line 3
    printf "${BOLD}${WHITE}Default Gateway:${RESET} $(ip route | grep default | awk '{print $3}')"
    ((line++))
    
    # Separator
    ((line++))
    move_cursor $line 1
    printf "${BOLD}${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"
    ((line++))
    
    # Active connections (first few)
    move_cursor $line 3
    printf "${BOLD}${WHITE}Active Connections (first 5):${RESET}"
    ((line++))
    
    local conns=($(get_connections))
    local count=0
    for conn in "${conns[@]}"; do
        if [ $count -ge 5 ]; then
            break
        fi
        move_cursor $line 5
        printf "$conn"
        ((line++))
        ((count++))
    done
    
    # Fill remaining lines
    while [ $line -lt $((LINES - 1)) ]; do
        move_cursor $line 1
        printf "${BOLD}${CYAN}║${RESET} "
        printf '\033[K'
        ((line++))
    done
    
    # Footer
    move_cursor $((LINES - 1)) 1
    printf "${BOLD}${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"
    move_cursor $LINES 1
    printf "${BOLD}${CYAN}║${RESET} ${YELLOW}r:${RESET} Refresh ${YELLOW}p:${RESET} Ping test ${YELLOW}q:${RESET} Quit"
    printf '\033[K'
}

# Ping test
ping_test() {
    clear_screen
    move_cursor 5 1
    printf "${YELLOW}Enter host to ping:${RESET} "
    read -r host
    
    if [ -z "$host" ]; then
        host="8.8.8.8"
    fi
    
    clear_screen
    move_cursor 1 1
    printf "${BOLD}${YELLOW}Pinging $host...${RESET}\n\n"
    
    ping -c 4 "$host"
    
    printf "\n\n${YELLOW}Press any key to continue...${RESET}"
    read -rsn1
}

# Read single key
read_key() {
    local key
    IFS= read -rsn1 -t 1 key
    if [ "$key" = $'\x1b' ]; then
        read -rsn2 -t 1 key
    fi
    echo "$key"
}

# Main loop
main() {
    while true; do
        draw_ui
        local key
        key=$(read_key)
        
        case "$key" in
            "r")
                # Refresh
                ;;
            "p")
                ping_test
                ;;
            "q")
                clear_screen
                show_cursor
                exit 0
                ;;
        esac
    done
}

# Check terminal size
if [ -z "$LINES" ] || [ -z "$COLUMNS" ]; then
    printf "Error: Terminal size not detected. Please run in a proper terminal.\n"
    exit 1
fi

main
