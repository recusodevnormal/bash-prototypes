#!/usr/bin/env bash
# =============================================================================
# Port-Watch Guardian
# =============================================================================
# Description : Monitors open network ports every minute, compares against a
#               whitelist (known_ports.txt), and alerts on new/unknown ports.
#               Provides an interactive TUI to inspect and close rogue ports
#               using iptables.
#
# Dependencies: bash, netstat (or ss), iptables, grep, awk, sed, printf, tput
#               All standard GNU/Linux utilities — no external packages needed.
#
# Usage       : sudo ./port_watch_guardian.sh
#               (iptables requires root; netstat/ss work without root for basic
#                listening-port enumeration, but root gives fuller detail)
#
# Files       :
#   known_ports.txt   — whitelist of allowed ports (one per line, e.g. "22")
#   port_watch.log    — persistent log of all alerts and actions taken
# =============================================================================

# ---------------------------------------------------------------------------
# STRICT MODE — catch errors early
# ---------------------------------------------------------------------------
set -euo pipefail
IFS=$'\n\t'

# ---------------------------------------------------------------------------
# CONFIGURATION — edit these to suit your environment
# ---------------------------------------------------------------------------
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="Port-Watch Guardian"

readonly KNOWN_PORTS_FILE="./known_ports.txt"   # whitelist file
readonly LOG_FILE="./port_watch.log"            # persistent log
readonly SCAN_INTERVAL=60                       # seconds between scans
readonly MAX_LOG_LINES=500                      # rotate log after this many lines

# ---------------------------------------------------------------------------
# COLOUR PALETTE (gracefully degrade if terminal lacks colour support)
# ---------------------------------------------------------------------------
if tput colors &>/dev/null && [[ $(tput colors) -ge 8 ]]; then
    C_RESET=$(tput sgr0)
    C_BOLD=$(tput bold)
    C_RED=$(tput setaf 1)
    C_GREEN=$(tput setaf 2)
    C_YELLOW=$(tput setaf 3)
    C_BLUE=$(tput setaf 4)
    C_MAGENTA=$(tput setaf 5)
    C_CYAN=$(tput setaf 6)
    C_WHITE=$(tput setaf 7)
    C_BG_RED=$(tput setab 1)
    C_BG_BLUE=$(tput setab 4)
    C_BG_GREEN=$(tput setab 2)
    C_BG_BLACK=$(tput setab 0)
else
    C_RESET="" C_BOLD="" C_RED="" C_GREEN="" C_YELLOW="" C_BLUE=""
    C_MAGENTA="" C_CYAN="" C_WHITE="" C_BG_RED="" C_BG_BLUE=""
    C_BG_GREEN="" C_BG_BLACK=""
fi

# ---------------------------------------------------------------------------
# TERMINAL DIMENSIONS (refreshed on each draw)
# ---------------------------------------------------------------------------
get_term_size() {
    TERM_COLS=$(tput cols  2>/dev/null || echo 80)
    TERM_ROWS=$(tput lines 2>/dev/null || echo 24)
}

# ---------------------------------------------------------------------------
# GLOBAL STATE
# ---------------------------------------------------------------------------
declare -a ALERT_PORTS=()      # ports flagged in the current session
declare -a ALERT_PROTOS=()     # matching protocols (tcp/udp)
declare -a ALERT_ADDRS=()      # matching listen addresses
declare -a ALERT_PROCS=()      # matching process names
LAST_SCAN_TIME="Never"
SCAN_COUNT=0
CLOSED_COUNT=0
STATUS_MSG=""                  # one-line status shown in footer

# ---------------------------------------------------------------------------
# UTILITY: timestamp
# ---------------------------------------------------------------------------
timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

# ---------------------------------------------------------------------------
# UTILITY: log a message to file (with automatic rotation)
# ---------------------------------------------------------------------------
log() {
    local level="$1"; shift
    local msg="$*"
    echo "[$(timestamp)] [${level}] ${msg}" >> "${LOG_FILE}"

    # Rotate: keep only the last MAX_LOG_LINES lines
    local line_count
    line_count=$(wc -l < "${LOG_FILE}" 2>/dev/null || echo 0)
    if (( line_count > MAX_LOG_LINES )); then
        local tmp
        tmp=$(mktemp)
        tail -n "${MAX_LOG_LINES}" "${LOG_FILE}" > "${tmp}"
        mv "${tmp}" "${LOG_FILE}"
    fi
}

# ---------------------------------------------------------------------------
# UTILITY: draw a horizontal rule the full terminal width
# ---------------------------------------------------------------------------
draw_rule() {
    local char="${1:─}"       # default box-drawing dash
    local colour="${2:-${C_BLUE}}"
    printf '%s' "${colour}"
    printf '%*s' "${TERM_COLS}" '' | tr ' ' "${char}"
    printf '%s\n' "${C_RESET}"
}

# ---------------------------------------------------------------------------
# UTILITY: centre-print a string
# ---------------------------------------------------------------------------
centre_print() {
    local text="$1"
    local colour="${2:-}"
    # Strip ANSI from text for length calculation
    local plain
    plain=$(printf '%s' "${text}" | sed 's/\x1b\[[0-9;]*m//g')
    local pad=$(( (TERM_COLS - ${#plain}) / 2 ))
    printf '%*s%s%s%s\n' "${pad}" '' "${colour}" "${text}" "${C_RESET}"
}

# ---------------------------------------------------------------------------
# DRAW: banner / header
# ---------------------------------------------------------------------------
draw_header() {
    get_term_size
    clear
    draw_rule '═' "${C_CYAN}"
    centre_print "🛡  ${SCRIPT_NAME}  v${SCRIPT_VERSION}" "${C_BOLD}${C_CYAN}"
    centre_print "Continuous port surveillance — powered by netstat + iptables" "${C_WHITE}"
    draw_rule '═' "${C_CYAN}"
    printf '\n'
}

# ---------------------------------------------------------------------------
# DRAW: summary stats bar
# ---------------------------------------------------------------------------
draw_stats() {
    local scan_label="${C_BOLD}${C_GREEN}Scans:${C_RESET}"
    local closed_label="${C_BOLD}${C_RED}Closed:${C_RESET}"
    local alert_label="${C_BOLD}${C_YELLOW}Active Alerts:${C_RESET}"
    local time_label="${C_BOLD}${C_CYAN}Last Scan:${C_RESET}"

    printf '  %b %b%d%b   ' \
        "${scan_label}" "${C_WHITE}" "${SCAN_COUNT}" "${C_RESET}"
    printf '%b %b%d%b   ' \
        "${closed_label}" "${C_WHITE}" "${CLOSED_COUNT}" "${C_RESET}"
    printf '%b %b%d%b   ' \
        "${alert_label}" "${C_WHITE}" "${#ALERT_PORTS[@]}" "${C_RESET}"
    printf '%b %b%s%b\n' \
        "${time_label}" "${C_WHITE}" "${LAST_SCAN_TIME}" "${C_RESET}"
    draw_rule '─' "${C_BLUE}"
}

# ---------------------------------------------------------------------------
# DRAW: known ports table
# ---------------------------------------------------------------------------
draw_known_ports() {
    printf '  %b%-20s%b\n' "${C_BOLD}${C_GREEN}" "✔  WHITELISTED PORTS" "${C_RESET}"
    printf '\n'
    if [[ ! -f "${KNOWN_PORTS_FILE}" ]]; then
        printf '  %bNo whitelist file found (%s)%b\n' \
            "${C_YELLOW}" "${KNOWN_PORTS_FILE}" "${C_RESET}"
    else
        # Print in columns of 8 ports each
        local port_list
        mapfile -t port_list < <(grep -Ev '^\s*#|^\s*$' "${KNOWN_PORTS_FILE}" | sort -n)
        local col=0
        printf '  '
        for p in "${port_list[@]}"; do
            printf '%b%-8s%b' "${C_GREEN}" "${p}" "${C_RESET}"
            (( col++ ))
            if (( col % 10 == 0 )); then
                printf '\n  '
            fi
        done
        printf '\n'
    fi
    printf '\n'
    draw_rule '─' "${C_BLUE}"
}

# ---------------------------------------------------------------------------
# DRAW: current open ports (from last netstat scan)
# ---------------------------------------------------------------------------
draw_open_ports() {
    printf '  %b%-20s%b\n\n' "${C_BOLD}${C_CYAN}" "📡  CURRENT OPEN PORTS" "${C_RESET}"

    # Column headers
    printf '  %b%-6s %-8s %-26s %-20s%b\n' \
        "${C_BOLD}${C_WHITE}" "Proto" "Port" "Listen Address" "Status" "${C_RESET}"
    draw_rule '·' "${C_BLUE}"

    local raw_ports
    raw_ports=$(get_open_ports)

    if [[ -z "${raw_ports}" ]]; then
        printf '  %bNo open ports detected.%b\n' "${C_YELLOW}" "${C_RESET}"
    else
        while IFS='|' read -r proto port addr; do
            # Check if this port is in the whitelist
            if is_known_port "${port}"; then
                local colour="${C_GREEN}"
                local status="✔ Known"
            else
                local colour="${C_RED}${C_BOLD}"
                local status="⚠ UNKNOWN"
            fi
            printf '  %b%-6s %-8s %-26s %-20s%b\n' \
                "${colour}" "${proto}" "${port}" "${addr}" "${status}" "${C_RESET}"
        done <<< "${raw_ports}"
    fi
    printf '\n'
    draw_rule '─' "${C_BLUE}"
}

# ---------------------------------------------------------------------------
# DRAW: alert panel (unknown ports requiring action)
# ---------------------------------------------------------------------------
draw_alerts() {
    if [[ ${#ALERT_PORTS[@]} -eq 0 ]]; then
        printf '  %b✅  No unknown ports detected — system clean.%b\n\n' \
            "${C_GREEN}" "${C_RESET}"
        return 0
    fi

    printf '  %b⚠   ALERTS — UNKNOWN PORTS DETECTED%b\n\n' \
        "${C_BOLD}${C_BG_RED}${C_WHITE}" "${C_RESET}"

    # Table header
    printf '  %b%-4s %-6s %-8s %-20s %-20s%b\n' \
        "${C_BOLD}${C_YELLOW}" "#" "Proto" "Port" "Listen Addr" "Process" "${C_RESET}"
    draw_rule '·' "${C_YELLOW}"

    local i=0
    for port in "${ALERT_PORTS[@]}"; do
        local proto="${ALERT_PROTOS[$i]:-tcp}"
        local addr="${ALERT_ADDRS[$i]:-0.0.0.0}"
        local proc="${ALERT_PROCS[$i]:-unknown}"
        # Truncate process name if too long
        if [[ ${#proc} -gt 18 ]]; then
            proc="${proc:0:17}…"
        fi
        printf '  %b[%-2d] %-6s %-8s %-20s %-20s%b\n' \
            "${C_BOLD}${C_RED}" "$((i+1))" "${proto}" "${port}" "${addr}" "${proc}" "${C_RESET}"
        (( i++ ))
    done

    printf '\n'
    draw_rule '─' "${C_YELLOW}"
    # Action buttons (rendered as labelled menu options)
    printf '  %b[C]%b Close a port with iptables   ' \
        "${C_BG_RED}${C_BOLD}${C_WHITE}" "${C_RESET}"
    printf '  %b[A]%b Add port to whitelist   ' \
        "${C_BG_GREEN}${C_BOLD}${C_WHITE}" "${C_RESET}"
    printf '  %b[I]%b Ignore for this session\n\n' \
        "${C_BG_BLUE}${C_BOLD}${C_WHITE}" "${C_RESET}"
}

# ---------------------------------------------------------------------------
# DRAW: main menu footer
# ---------------------------------------------------------------------------
draw_menu() {
    draw_rule '─' "${C_CYAN}"
    printf '  %b[R]%b Rescan now   ' "${C_BOLD}${C_CYAN}" "${C_RESET}"
    printf '  %b[V]%b View log     ' "${C_BOLD}${C_CYAN}" "${C_RESET}"
    printf '  %b[E]%b Edit whitelist   ' "${C_BOLD}${C_CYAN}" "${C_RESET}"
    printf '  %b[Q]%b Quit\n' "${C_BOLD}${C_RED}" "${C_RESET}"
    draw_rule '─' "${C_CYAN}"

    if [[ -n "${STATUS_MSG}" ]]; then
        printf '  ℹ  %b%s%b\n' "${C_YELLOW}" "${STATUS_MSG}" "${C_RESET}"
    fi

    printf '  %bAuto-rescan in %d seconds. Enter choice: %b' \
        "${C_WHITE}" "${SCAN_INTERVAL}" "${C_RESET}"
}

# ---------------------------------------------------------------------------
# CORE: retrieve currently open/listening ports
# Returns lines in format: proto|port|address
# Prefers 'ss' (iproute2) but falls back to 'netstat' (net-tools)
# ---------------------------------------------------------------------------
get_open_ports() {
    if command -v ss &>/dev/null; then
        # ss output example:
        # tcp  LISTEN 0  128  0.0.0.0:22  0.0.0.0:*
        ss -tuln 2>/dev/null \
          | awk 'NR>1 {
                proto = $1
                addr  = $5
                # Extract port: last field after final colon
                n = split(addr, a, ":")
                port = a[n]
                # Reconstruct address without port
                sub(/:[^:]+$/, "", addr)
                if (port ~ /^[0-9]+$/)
                    printf "%s|%s|%s\n", proto, port, addr
            }' \
          | sort -t'|' -k2 -n \
          | uniq
    elif command -v netstat &>/dev/null; then
        # netstat output example:
        # tcp  0  0  0.0.0.0:22  0.0.0.0:*  LISTEN
        netstat -tuln 2>/dev/null \
          | awk '/LISTEN|udp/ && NR>2 {
                proto = $1
                addr  = $4
                n = split(addr, a, ":")
                port = a[n]
                sub(/:[^:]+$/, "", addr)
                if (port ~ /^[0-9]+$/)
                    printf "%s|%s|%s\n", proto, port, addr
            }' \
          | sort -t'|' -k2 -n \
          | uniq
    else
        printf '' # no tool available — return empty
        log "WARN" "Neither 'ss' nor 'netstat' found — cannot scan ports."
    fi
}

# ---------------------------------------------------------------------------
# CORE: get process information for a given port
# Returns: "process_name (PID)" or empty string if not found
# Uses ss -p or falls back to lsof or /proc parsing
# ---------------------------------------------------------------------------
get_process_for_port() {
    local port="$1"
    local proto="${2:-tcp}"
    local result=""
    
    # Try ss with process info first
    if command -v ss &>/dev/null; then
        result=$(ss -tulnp 2>/dev/null | grep ":${port}[[:space:]]" | head -1 | \
            sed -n 's/.*users:(("\([^,"]*\)",\?pid=\?\([0-9]*\).*/\1 (\2)/p')
        [[ -n "$result" ]] && { printf '%s' "$result"; return; }
    fi
    
    # Fallback to lsof
    if command -v lsof &>/dev/null; then
        result=$(lsof -i "${proto}:${port}" 2>/dev/null | awk 'NR==2 {print $1 " (" $2 ")"}')
        [[ -n "$result" ]] && { printf '%s' "$result"; return; }
    fi
    
    # Fallback: parse /proc/net/tcp and /proc/[pid]/fd/
    local hex_port
    hex_port=$(printf '%04X' "$port")
    local inode
    inode=$(awk -v hp=":${hex_port}" '$2 ~ hp {print $10}' /proc/net/tcp 2>/dev/null | head -1)
    if [[ -n "$inode" && "$inode" != "0" ]]; then
        for pid_dir in /proc/[0-9]*; do
            if [[ -d "$pid_dir/fd" ]]; then
                for fd in "$pid_dir"/fd/*; do
                    if [[ "$(readlink "$fd" 2>/dev/null)" == "socket:[${inode}]" ]]; then
                        local pid
                        pid=$(basename "$pid_dir")
                        local comm
                        comm=$(cat "$pid_dir/comm" 2>/dev/null || echo "unknown")
                        printf '%s (%s)' "$comm" "$pid"
                        return
                    fi
                done
            fi
        done
    fi
    
    printf 'unknown'
}

# ---------------------------------------------------------------------------
# CORE: check if a port number is in the whitelist
# ---------------------------------------------------------------------------
is_known_port() {
    local port="$1"
    [[ -f "${KNOWN_PORTS_FILE}" ]] || return 1
    grep -qE "^\s*${port}\s*$" "${KNOWN_PORTS_FILE}"
}

# ---------------------------------------------------------------------------
# CORE: perform a full scan and update alert state
# ---------------------------------------------------------------------------
do_scan() {
    local raw_ports
    raw_ports=$(get_open_ports)

    # Reset alert arrays
    ALERT_PORTS=()
    ALERT_PROTOS=()
    ALERT_ADDRS=()
    ALERT_PROCS=()

    if [[ -n "${raw_ports}" ]]; then
        while IFS='|' read -r proto port addr; do
            if ! is_known_port "${port}"; then
                ALERT_PORTS+=("${port}")
                ALERT_PROTOS+=("${proto}")
                ALERT_ADDRS+=("${addr}")
                local proc
                proc=$(get_process_for_port "$port" "$proto")
                ALERT_PROCS+=("${proc}")
                log "ALERT" "Unknown port detected: ${proto}/${port} on ${addr} (${proc})"
            fi
        done <<< "${raw_ports}"
    fi

    LAST_SCAN_TIME="$(timestamp)"
    (( SCAN_COUNT++ )) || true
    log "INFO" "Scan #${SCAN_COUNT} complete. Found ${#ALERT_PORTS[@]} unknown port(s)."
}

# ---------------------------------------------------------------------------
# ACTION: close a port via iptables (both INPUT and, optionally, OUTPUT)
# ---------------------------------------------------------------------------
action_close_port() {
    if [[ ${#ALERT_PORTS[@]} -eq 0 ]]; then
        STATUS_MSG="No unknown ports to close."
        return
    fi

    # Prompt user to pick which alert entry to close
    printf '\n  %bEnter alert number to close [1-%d]: %b' \
        "${C_YELLOW}" "${#ALERT_PORTS[@]}" "${C_RESET}"
    read -r -t 30 choice || { STATUS_MSG="Timeout — no action taken."; return; }

    # Validate numeric input
    if ! [[ "${choice}" =~ ^[0-9]+$ ]] || \
       (( choice < 1 )) || (( choice > ${#ALERT_PORTS[@]} )); then
        STATUS_MSG="Invalid selection '${choice}'."
        return
    fi

    local idx=$(( choice - 1 ))
    local port="${ALERT_PORTS[$idx]}"
    local proto="${ALERT_PROTOS[$idx]:-tcp}"
    # Normalise protocol: ss sometimes reports "tcp"/"udp" with suffixes
    proto=$(printf '%s' "${proto}" | grep -oE 'tcp|udp' | head -1)
    proto="${proto:-tcp}"

    # Confirm before applying
    printf '\n  %b⚠  Close %s port %s with iptables? [y/N]: %b' \
        "${C_RED}${C_BOLD}" "${proto^^}" "${port}" "${C_RESET}"
    read -r -t 15 confirm || { STATUS_MSG="Timeout — no action taken."; return; }

    if [[ "${confirm,,}" == "y" ]]; then
        if iptables -A INPUT -p "${proto}" --dport "${port}" -j DROP 2>/dev/null; then
            STATUS_MSG="✔ iptables rule added: DROP ${proto^^} INPUT :${port}"
            log "ACTION" "Closed port ${proto}/${port} via iptables INPUT DROP."
            (( CLOSED_COUNT++ )) || true
            # Remove from alert list
            unset 'ALERT_PORTS[$idx]' 'ALERT_PROTOS[$idx]' 'ALERT_ADDRS[$idx]' 'ALERT_PROCS[$idx]'
            ALERT_PORTS=("${ALERT_PORTS[@]}")
            ALERT_PROTOS=("${ALERT_PROTOS[@]}")
            ALERT_ADDRS=("${ALERT_ADDRS[@]}")
            ALERT_PROCS=("${ALERT_PROCS[@]}")
        else
            STATUS_MSG="✘ iptables failed. Are you running as root?"
            log "ERROR" "iptables failed for port ${proto}/${port}."
        fi
    else
        STATUS_MSG="Action cancelled — port ${port} left open."
    fi
}

# ---------------------------------------------------------------------------
# ACTION: add an alerted port to the whitelist
# ---------------------------------------------------------------------------
action_add_to_whitelist() {
    if [[ ${#ALERT_PORTS[@]} -eq 0 ]]; then
        STATUS_MSG="No unknown ports to whitelist."
        return
    fi

    printf '\n  %bEnter alert number to whitelist [1-%d]: %b' \
        "${C_YELLOW}" "${#ALERT_PORTS[@]}" "${C_RESET}"
    read -r -t 30 choice || { STATUS_MSG="Timeout."; return; }

    if ! [[ "${choice}" =~ ^[0-9]+$ ]] || \
       (( choice < 1 )) || (( choice > ${#ALERT_PORTS[@]} )); then
        STATUS_MSG="Invalid selection."
        return
    fi

    local idx=$(( choice - 1 ))
    local port="${ALERT_PORTS[$idx]}"

    printf '%s\n' "${port}" >> "${KNOWN_PORTS_FILE}"
    STATUS_MSG="✔ Port ${port} added to whitelist (${KNOWN_PORTS_FILE})."
    log "ACTION" "Port ${port} added to whitelist by user."

    # Remove from alert list
    unset 'ALERT_PORTS[$idx]' 'ALERT_PROTOS[$idx]' 'ALERT_ADDRS[$idx]' 'ALERT_PROCS[$idx]'
    ALERT_PORTS=("${ALERT_PORTS[@]}")
    ALERT_PROTOS=("${ALERT_PROTOS[@]}")
    ALERT_ADDRS=("${ALERT_ADDRS[@]}")
    ALERT_PROCS=("${ALERT_PROCS[@]}")
}

# ---------------------------------------------------------------------------
# ACTION: ignore an alerted port for this session
# ---------------------------------------------------------------------------
action_ignore_port() {
    if [[ ${#ALERT_PORTS[@]} -eq 0 ]]; then
        STATUS_MSG="No alerts to ignore."
        return
    fi

    printf '\n  %bEnter alert number to ignore [1-%d]: %b' \
        "${C_YELLOW}" "${#ALERT_PORTS[@]}" "${C_RESET}"
    read -r -t 30 choice || { STATUS_MSG="Timeout."; return; }

    if ! [[ "${choice}" =~ ^[0-9]+$ ]] || \
       (( choice < 1 )) || (( choice > ${#ALERT_PORTS[@]} )); then
        STATUS_MSG="Invalid selection."
        return
    fi

    local idx=$(( choice - 1 ))
    local port="${ALERT_PORTS[$idx]}"
    STATUS_MSG="Port ${port} ignored for this session."
    log "INFO" "Port ${port} ignored by user for this session."

    unset 'ALERT_PORTS[$idx]' 'ALERT_PROTOS[$idx]' 'ALERT_ADDRS[$idx]' 'ALERT_PROCS[$idx]'
    ALERT_PORTS=("${ALERT_PORTS[@]}")
    ALERT_PROTOS=("${ALERT_PROTOS[@]}")
    ALERT_ADDRS=("${ALERT_ADDRS[@]}")
    ALERT_PROCS=("${ALERT_PROCS[@]}")
}

# ---------------------------------------------------------------------------
# ACTION: view tail of the log file
# ---------------------------------------------------------------------------
action_view_log() {
    clear
    draw_rule '═' "${C_CYAN}"
    centre_print "📋  Port-Watch Guardian — Event Log" "${C_BOLD}${C_CYAN}"
    draw_rule '═' "${C_CYAN}"
    printf '\n'

    if [[ ! -f "${LOG_FILE}" ]]; then
        printf '  %bLog file not found: %s%b\n' \
            "${C_YELLOW}" "${LOG_FILE}" "${C_RESET}"
    else
        local log_rows=$(( TERM_ROWS - 8 ))
        (( log_rows < 5 )) && log_rows=5
        tail -n "${log_rows}" "${LOG_FILE}" | while IFS= read -r line; do
            # Colour-code by level
            if [[ "${line}" == *"[ALERT]"* ]]; then
                printf '  %b%s%b\n' "${C_RED}" "${line}" "${C_RESET}"
            elif [[ "${line}" == *"[ACTION]"* ]]; then
                printf '  %b%s%b\n' "${C_GREEN}" "${line}" "${C_RESET}"
            elif [[ "${line}" == *"[ERROR]"* ]]; then
                printf '  %b%s%b\n' "${C_BOLD}${C_RED}" "${line}" "${C_RESET}"
            elif [[ "${line}" == *"[WARN]"* ]]; then
                printf '  %b%s%b\n' "${C_YELLOW}" "${line}" "${C_RESET}"
            else
                printf '  %s\n' "${line}"
            fi
        done
    fi

    printf '\n'
    draw_rule '─' "${C_CYAN}"
    printf '  Press %b[Enter]%b to return...' "${C_BOLD}" "${C_RESET}"
    read -r -t 60 || true
}

# ---------------------------------------------------------------------------
# ACTION: open whitelist in a simple line-editor (no $EDITOR required)
# ---------------------------------------------------------------------------
action_edit_whitelist() {
    clear
    draw_rule '═' "${C_CYAN}"
    centre_print "📝  Edit Whitelist — ${KNOWN_PORTS_FILE}" "${C_BOLD}${C_CYAN}"
    draw_rule '═' "${C_CYAN}"
    printf '\n'
    printf '  %bCurrent entries:%b\n\n' "${C_BOLD}" "${C_RESET}"

    if [[ -f "${KNOWN_PORTS_FILE}" ]]; then
        cat -n "${KNOWN_PORTS_FILE}"
    else
        printf '  (file does not exist yet)\n'
    fi

    printf '\n'
    draw_rule '─' "${C_CYAN}"
    printf '  %b[A]%b Add port   %b[D]%b Delete port   %b[Enter]%b Back\n\n' \
        "${C_BOLD}${C_GREEN}" "${C_RESET}" \
        "${C_BOLD}${C_RED}"   "${C_RESET}" \
        "${C_BOLD}${C_CYAN}"  "${C_RESET}"
    printf '  Choice: '
    read -r -t 20 edit_choice || { return; }

    case "${edit_choice,,}" in
        a)
            printf '  Enter port number to add: '
            read -r -t 15 new_port || return
            if [[ "${new_port}" =~ ^[0-9]+$ ]] && \
               (( new_port >= 1 && new_port <= 65535 )); then
                printf '%s\n' "${new_port}" >> "${KNOWN_PORTS_FILE}"
                # Sort and deduplicate the file
                local tmp; tmp=$(mktemp)
                sort -nu "${KNOWN_PORTS_FILE}" > "${tmp}"
                mv "${tmp}" "${KNOWN_PORTS_FILE}"
                STATUS_MSG="Port ${new_port} added to whitelist."
                log "ACTION" "User added port ${new_port} to whitelist."
            else
                STATUS_MSG="Invalid port number."
            fi
            ;;
        d)
            printf '  Enter port number to remove: '
            read -r -t 15 del_port || return
            if [[ "${del_port}" =~ ^[0-9]+$ ]]; then
                local tmp; tmp=$(mktemp)
                grep -vE "^\s*${del_port}\s*$" "${KNOWN_PORTS_FILE}" \
                    > "${tmp}" 2>/dev/null || true
                mv "${tmp}" "${KNOWN_PORTS_FILE}"
                STATUS_MSG="Port ${del_port} removed from whitelist."
                log "ACTION" "User removed port ${del_port} from whitelist."
            else
                STATUS_MSG="Invalid port number."
            fi
            ;;
        *)
            ;;
    esac
}

# ---------------------------------------------------------------------------
# DRAW: full screen redraw
# ---------------------------------------------------------------------------
redraw_screen() {
    draw_header
    draw_stats
    printf '\n'
    draw_known_ports
    draw_open_ports
    draw_alerts
    draw_menu
}

# ---------------------------------------------------------------------------
# SETUP: initialise files and validate environment
# ---------------------------------------------------------------------------
setup() {
    # Create log file if absent
    touch "${LOG_FILE}" 2>/dev/null || {
        printf 'ERROR: Cannot write to %s\n' "${LOG_FILE}" >&2
        exit 1
    }

    # Create a default whitelist if none exists
    if [[ ! -f "${KNOWN_PORTS_FILE}" ]]; then
        cat > "${KNOWN_PORTS_FILE}" <<'EOF'
# Port-Watch Guardian — Whitelist
# Add one port number per line. Lines starting with '#' are ignored.
22
80
443
EOF
        log "INFO" "Created default whitelist: ${KNOWN_PORTS_FILE}"
        printf '%bINFO:%b Created default whitelist at %s\n' \
            "${C_GREEN}" "${C_RESET}" "${KNOWN_PORTS_FILE}"
        sleep 1
    fi

    log "INFO" "Port-Watch Guardian v${SCRIPT_VERSION} started. PID=$$"
}

# ---------------------------------------------------------------------------
# CLEANUP: restore terminal on exit
# ---------------------------------------------------------------------------
cleanup() {
    tput cnorm 2>/dev/null || true   # restore cursor
    printf '\n%b[Port-Watch Guardian] Shutting down. Goodbye.%b\n' \
        "${C_CYAN}" "${C_RESET}"
    log "INFO" "Port-Watch Guardian stopped. PID=$$"
}
trap cleanup EXIT
trap 'STATUS_MSG="Interrupted — type Q to quit cleanly."' INT TERM

# ---------------------------------------------------------------------------
# BACKGROUND TIMER: sends a signal to wake the main read loop for auto-rescan
# ---------------------------------------------------------------------------
start_timer() {
    # Runs in a subshell; sends USR1 to the main process every SCAN_INTERVAL
    local parent_pid="$$"
    (
        while kill -0 "${parent_pid}" 2>/dev/null; do
            sleep "${SCAN_INTERVAL}"
            kill -USR1 "${parent_pid}" 2>/dev/null || true
        done
    ) &
    TIMER_PID=$!
}

# Flag set by USR1 to trigger a rescan
AUTO_RESCAN=false
trap 'AUTO_RESCAN=true' USR1

# ---------------------------------------------------------------------------
# MAIN LOOP
# ---------------------------------------------------------------------------
main() {
    setup

    # Hide cursor for cleaner TUI
    tput civis 2>/dev/null || true

    # Initial scan before entering the loop
    do_scan
    start_timer

    while true; do
        # Redraw full screen
        redraw_screen

        # Non-blocking read with a 1-second timeout so we can check the
        # AUTO_RESCAN flag frequently while still accepting keypresses.
        user_input=""
        if read -r -t 1 -n 1 user_input 2>/dev/null; then
            : # got a keypress
        fi

        # Handle auto-rescan signal from background timer
        if [[ "${AUTO_RESCAN}" == true ]]; then
            AUTO_RESCAN=false
            STATUS_MSG="Auto-rescan triggered…"
            do_scan
            continue
        fi

        # Handle user input
        case "${user_input,,}" in
            q)
                break
                ;;
            r)
                STATUS_MSG="Manual rescan triggered…"
                do_scan
                ;;
            c)
                # Show cursor for interactive prompt
                tput cnorm 2>/dev/null || true
                action_close_port
                tput civis 2>/dev/null || true
                ;;
            a)
                tput cnorm 2>/dev/null || true
                action_add_to_whitelist
                tput civis 2>/dev/null || true
                ;;
            i)
                tput cnorm 2>/dev/null || true
                action_ignore_port
                tput civis 2>/dev/null || true
                ;;
            v)
                tput cnorm 2>/dev/null || true
                action_view_log
                tput civis 2>/dev/null || true
                ;;
            e)
                tput cnorm 2>/dev/null || true
                action_edit_whitelist
                tput civis 2>/dev/null || true
                ;;
            '')
                # Empty — just redraw (covers timeout and Enter key)
                ;;
            *)
                STATUS_MSG="Unknown command '${user_input}'. Use the menu keys above."
                ;;
        esac
    done

    # Kill background timer
    kill "${TIMER_PID}" 2>/dev/null || true
    wait "${TIMER_PID}" 2>/dev/null || true
}

main "$@"