#!/usr/bin/env bash

################################################################################
# Weighted Keyword Intent Scorer
# 
# Description:
#   Analyzes user input and scores it against multiple domain categories.
#   When a category's score exceeds a threshold, the script switches its
#   UI personality to match that domain.
#
# Requirements:
#   - Bash 4.0+ (for associative arrays)
#   - Standard GNU/Unix utilities (awk, grep, sed, printf)
#
# Usage:
#   ./intent_scorer.sh
################################################################################

set -euo pipefail

################################################################################
# CONFIGURATION
################################################################################

# Score threshold to trigger domain switch
readonly THRESHOLD=15

# Color codes for terminal output
readonly COLOR_RESET='\033[0m'
readonly COLOR_BOLD='\033[1m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_MAGENTA='\033[0;35m'
readonly COLOR_CYAN='\033[0;36m'

################################################################################
# KEYWORD WEIGHTS BY DOMAIN
################################################################################

# Networking keywords and their weights
declare -A NETWORKING_KEYWORDS=(
    ["network"]=10
    ["router"]=8
    ["firewall"]=8
    ["tcp"]=7
    ["ip"]=7
    ["dns"]=7
    ["http"]=6
    ["https"]=6
    ["port"]=6
    ["socket"]=6
    ["ping"]=5
    ["wifi"]=5
    ["bandwidth"]=5
    ["proxy"]=5
    ["vpn"]=5
    ["ethernet"]=4
    ["packet"]=4
    ["gateway"]=4
    ["subnet"]=4
    ["protocol"]=3
)

# Security keywords and their weights
declare -A SECURITY_KEYWORDS=(
    ["security"]=10
    ["encryption"]=9
    ["vulnerability"]=9
    ["exploit"]=8
    ["password"]=8
    ["authentication"]=8
    ["certificate"]=7
    ["ssl"]=7
    ["tls"]=7
    ["malware"]=7
    ["virus"]=6
    ["breach"]=6
    ["attack"]=6
    ["hack"]=6
    ["penetration"]=5
    ["firewall"]=5
    ["crypto"]=5
    ["token"]=4
    ["permission"]=4
    ["audit"]=3
)

# Hardware keywords and their weights
declare -A HARDWARE_KEYWORDS=(
    ["hardware"]=10
    ["cpu"]=8
    ["processor"]=8
    ["memory"]=7
    ["ram"]=7
    ["disk"]=7
    ["ssd"]=7
    ["motherboard"]=7
    ["gpu"]=6
    ["graphics"]=6
    ["usb"]=5
    ["monitor"]=5
    ["keyboard"]=4
    ["mouse"]=4
    ["driver"]=5
    ["bios"]=6
    ["firmware"]=6
    ["cooling"]=4
    ["fan"]=3
    ["power"]=3
)

# Software keywords and their weights
declare -A SOFTWARE_KEYWORDS=(
    ["software"]=10
    ["application"]=8
    ["program"]=7
    ["code"]=7
    ["debug"]=7
    ["compile"]=7
    ["library"]=6
    ["framework"]=6
    ["api"]=6
    ["database"]=6
    ["install"]=5
    ["update"]=5
    ["patch"]=5
    ["version"]=4
    ["dependency"]=5
    ["repository"]=4
    ["git"]=4
    ["docker"]=5
    ["container"]=5
    ["script"]=4
)

# General/Default keywords and their weights
declare -A GENERAL_KEYWORDS=(
    ["help"]=5
    ["support"]=5
    ["issue"]=4
    ["problem"]=4
    ["question"]=3
    ["how"]=2
    ["what"]=2
    ["why"]=2
    ["when"]=2
    ["where"]=2
)

################################################################################
# HELPER FUNCTIONS
################################################################################

# Print colored text
print_color() {
    local color="$1"
    local text="$2"
    printf "${color}%s${COLOR_RESET}\n" "$text"
}

# Print banner
print_banner() {
    local color="$1"
    local title="$2"
    local width=60
    
    echo
    printf "${color}"
    printf '═%.0s' $(seq 1 $width)
    printf '\n'
    printf "%-${width}s\n" "  $title"
    printf '═%.0s' $(seq 1 $width)
    printf "${COLOR_RESET}\n"
    echo
}

# Clear screen and show header
show_header() {
    clear
    print_color "$COLOR_CYAN" "╔════════════════════════════════════════════════════════════╗"
    print_color "$COLOR_CYAN" "║         WEIGHTED KEYWORD INTENT SCORER v1.0                ║"
    print_color "$COLOR_CYAN" "║         Analyzes text to determine domain intent           ║"
    print_color "$COLOR_CYAN" "╚════════════════════════════════════════════════════════════╝"
    echo
}

################################################################################
# CORE SCORING FUNCTIONS
################################################################################

# Calculate score for a given domain
# Args: $1=input text, $2=array name reference
calculate_domain_score() {
    local input="$1"
    local -n keywords_ref="$2"
    local score=0
    
    # Convert input to lowercase for case-insensitive matching
    local input_lower
    input_lower=$(echo "$input" | tr '[:upper:]' '[:lower:]')
    
    # Iterate through keywords and sum scores
    for keyword in "${!keywords_ref[@]}"; do
        # Count occurrences of keyword in input
        local count
        count=$(echo "$input_lower" | grep -o "\b$keyword\b" | wc -l)
        
        if [ "$count" -gt 0 ]; then
            local keyword_score=${keywords_ref[$keyword]}
            score=$((score + (keyword_score * count)))
        fi
    done
    
    echo "$score"
}

# Analyze input and determine dominant domain
analyze_input() {
    local input="$1"
    
    # Calculate scores for each domain
    local net_score
    local sec_score
    local hw_score
    local sw_score
    local gen_score
    
    net_score=$(calculate_domain_score "$input" NETWORKING_KEYWORDS)
    sec_score=$(calculate_domain_score "$input" SECURITY_KEYWORDS)
    hw_score=$(calculate_domain_score "$input" HARDWARE_KEYWORDS)
    sw_score=$(calculate_domain_score "$input" SOFTWARE_KEYWORDS)
    gen_score=$(calculate_domain_score "$input" GENERAL_KEYWORDS)
    
    # Display scores
    echo
    print_color "$COLOR_BOLD" "Domain Scores:"
    echo "────────────────────────────────────────────"
    printf "  %-20s %3d\n" "Networking:" "$net_score"
    printf "  %-20s %3d\n" "Security:" "$sec_score"
    printf "  %-20s %3d\n" "Hardware:" "$hw_score"
    printf "  %-20s %3d\n" "Software:" "$sw_score"
    printf "  %-20s %3d\n" "General:" "$gen_score"
    echo "────────────────────────────────────────────"
    
    # Determine dominant domain
    local max_score=0
    local domain="general"
    local domain_color="$COLOR_RESET"
    
    if [ "$net_score" -gt "$max_score" ]; then
        max_score="$net_score"
        domain="networking"
        domain_color="$COLOR_BLUE"
    fi
    
    if [ "$sec_score" -gt "$max_score" ]; then
        max_score="$sec_score"
        domain="security"
        domain_color="$COLOR_RED"
    fi
    
    if [ "$hw_score" -gt "$max_score" ]; then
        max_score="$hw_score"
        domain="hardware"
        domain_color="$COLOR_GREEN"
    fi
    
    if [ "$sw_score" -gt "$max_score" ]; then
        max_score="$sw_score"
        domain="software"
        domain_color="$COLOR_MAGENTA"
    fi
    
    # Check if threshold is met
    echo
    if [ "$max_score" -ge "$THRESHOLD" ]; then
        print_color "$COLOR_YELLOW" "✓ Threshold met! (Score: $max_score ≥ $THRESHOLD)"
        switch_personality "$domain" "$domain_color"
    else
        print_color "$COLOR_YELLOW" "✗ Threshold not met (Score: $max_score < $THRESHOLD)"
        print_color "$COLOR_RESET" "  Remaining in General mode."
    fi
    
    echo
}

################################################################################
# UI PERSONALITY FUNCTIONS
################################################################################

# Switch UI personality based on domain
switch_personality() {
    local domain="$1"
    local color="$2"
    
    echo
    print_banner "$color" "SWITCHING TO ${domain^^} MODE"
    
    case "$domain" in
        networking)
            show_networking_ui
            ;;
        security)
            show_security_ui
            ;;
        hardware)
            show_hardware_ui
            ;;
        software)
            show_software_ui
            ;;
        *)
            show_general_ui
            ;;
    esac
}

# Networking personality
show_networking_ui() {
    print_color "$COLOR_BLUE" "┌─────────────────────────────────────────────────────┐"
    print_color "$COLOR_BLUE" "│  🌐 NETWORK OPERATIONS CENTER                       │"
    print_color "$COLOR_BLUE" "├─────────────────────────────────────────────────────┤"
    print_color "$COLOR_BLUE" "│  Available Commands:                                │"
    print_color "$COLOR_BLUE" "│    • ping <host>    - Test connectivity             │"
    print_color "$COLOR_BLUE" "│    • traceroute     - Trace network path            │"
    print_color "$COLOR_BLUE" "│    • netstat        - Show network statistics       │"
    print_color "$COLOR_BLUE" "│    • iptables       - Configure firewall            │"
    print_color "$COLOR_BLUE" "└─────────────────────────────────────────────────────┘"
}

# Security personality
show_security_ui() {
    print_color "$COLOR_RED" "┌─────────────────────────────────────────────────────┐"
    print_color "$COLOR_RED" "│  🔒 SECURITY OPERATIONS CENTER                      │"
    print_color "$COLOR_RED" "├─────────────────────────────────────────────────────┤"
    print_color "$COLOR_RED" "│  Security Status: ELEVATED                          │"
    print_color "$COLOR_RED" "│  Available Commands:                                │"
    print_color "$COLOR_RED" "│    • scan           - Run vulnerability scan        │"
    print_color "$COLOR_RED" "│    • audit          - Review security logs          │"
    print_color "$COLOR_RED" "│    • encrypt        - Encrypt sensitive data        │"
    print_color "$COLOR_RED" "│    • permissions    - Check file permissions        │"
    print_color "$COLOR_RED" "└─────────────────────────────────────────────────────┘"
}

# Hardware personality
show_hardware_ui() {
    print_color "$COLOR_GREEN" "┌─────────────────────────────────────────────────────┐"
    print_color "$COLOR_GREEN" "│  🔧 HARDWARE DIAGNOSTICS CENTER                     │"
    print_color "$COLOR_GREEN" "├─────────────────────────────────────────────────────┤"
    print_color "$COLOR_GREEN" "│  System Health: NOMINAL                             │"
    print_color "$COLOR_GREEN" "│  Available Commands:                                │"
    print_color "$COLOR_GREEN" "│    • cpuinfo        - Display CPU information       │"
    print_color "$COLOR_GREEN" "│    • memtest        - Test memory modules           │"
    print_color "$COLOR_GREEN" "│    • diskcheck      - Check disk health             │"
    print_color "$COLOR_GREEN" "│    • sensors        - Read hardware sensors         │"
    print_color "$COLOR_GREEN" "└─────────────────────────────────────────────────────┘"
}

# Software personality
show_software_ui() {
    print_color "$COLOR_MAGENTA" "┌─────────────────────────────────────────────────────┐"
    print_color "$COLOR_MAGENTA" "│  💻 SOFTWARE DEVELOPMENT ENVIRONMENT                │"
    print_color "$COLOR_MAGENTA" "├─────────────────────────────────────────────────────┤"
    print_color "$COLOR_MAGENTA" "│  Build Status: READY                                │"
    print_color "$COLOR_MAGENTA" "│  Available Commands:                                │"
    print_color "$COLOR_MAGENTA" "│    • compile        - Build project                 │"
    print_color "$COLOR_MAGENTA" "│    • test           - Run test suite                │"
    print_color "$COLOR_MAGENTA" "│    • deploy         - Deploy application            │"
    print_color "$COLOR_MAGENTA" "│    • debug          - Start debugger                │"
    print_color "$COLOR_MAGENTA" "└─────────────────────────────────────────────────────┘"
}

# General personality
show_general_ui() {
    print_color "$COLOR_RESET" "┌─────────────────────────────────────────────────────┐"
    print_color "$COLOR_RESET" "│  ℹ️  GENERAL ASSISTANT                               │"
    print_color "$COLOR_RESET" "├─────────────────────────────────────────────────────┤"
    print_color "$COLOR_RESET" "│  Available Commands:                                │"
    print_color "$COLOR_RESET" "│    • help           - Show help information         │"
    print_color "$COLOR_RESET" "│    • info           - System information            │"
    print_color "$COLOR_RESET" "│    • status         - Check system status           │"
    print_color "$COLOR_RESET" "└─────────────────────────────────────────────────────┘"
}

################################################################################
# MAIN PROGRAM
################################################################################

main() {
    # Check Bash version (need 4.0+ for associative arrays)
    if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
        print_color "$COLOR_RED" "Error: Bash 4.0 or higher required for associative arrays"
        exit 1
    fi
    
    show_header
    
    print_color "$COLOR_YELLOW" "Enter text to analyze (or 'quit' to exit):"
    print_color "$COLOR_YELLOW" "Threshold for domain switch: $THRESHOLD points"
    echo
    
    while true; do
        printf "${COLOR_CYAN}> ${COLOR_RESET}"
        read -r user_input
        
        # Check for exit command
        if [ "$user_input" = "quit" ] || [ "$user_input" = "exit" ] || [ "$user_input" = "q" ]; then
            echo
            print_color "$COLOR_GREEN" "Thank you for using Intent Scorer. Goodbye!"
            exit 0
        fi
        
        # Skip empty input
        if [ -z "$user_input" ]; then
            continue
        fi
        
        # Analyze the input
        analyze_input "$user_input"
        
        # Prompt for next input
        echo
        print_color "$COLOR_YELLOW" "Enter more text to analyze (or 'quit' to exit):"
        echo
    done
}

# Run main program
main "$@"