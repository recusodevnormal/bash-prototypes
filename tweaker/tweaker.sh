#!/usr/bin/env bash
# =============================================================================
# snapshot_tweak.sh — Snapshot-Based System Tweak TUI
# =============================================================================
# A terminal dashboard for safely editing /etc/ config files and dotfiles.
# Before every change, the current file is snapshotted to /tmp/snapshot_<ID>.
# Press Ctrl+Z at any prompt to undo the last change (swap back the snapshot).
#
# Dependencies: bash, grep, awk, sed, printf, cp, mv, diff, tput, date, mktemp
# Tested on: Alpine Linux (ash/bash), Debian, Arch
# Usage: bash snapshot_tweak.sh
# =============================================================================

# ── Strict mode ───────────────────────────────────────────────────────────────
set -euo pipefail
IFS=$'\n\t'

# ── Terminal colours (tput with fallback) ─────────────────────────────────────
if tput colors &>/dev/null && [ "$(tput colors)" -ge 8 ]; then
    C_RESET=$(tput sgr0)
    C_BOLD=$(tput bold)
    C_DIM=$(tput dim 2>/dev/null || printf '')
    C_BLK=$(tput setaf 0)
    C_RED=$(tput setaf 1)
    C_GRN=$(tput setaf 2)
    C_YLW=$(tput setaf 3)
    C_BLU=$(tput setaf 4)
    C_MAG=$(tput setaf 5)
    C_CYN=$(tput setaf 6)
    C_WHT=$(tput setaf 7)
    C_BGRN=$(tput setab 2)
    C_BBLU=$(tput setab 4)
    C_BRED=$(tput setab 1)
    C_BYLW=$(tput setab 3)
    C_BMAG=$(tput setab 5)
    C_BCYN=$(tput setab 6)
else
    # No colour support — everything is empty strings
    C_RESET='' C_BOLD='' C_DIM='' C_BLK='' C_RED='' C_GRN='' C_YLW=''
    C_BLU='' C_MAG='' C_CYN='' C_WHT='' C_BGRN='' C_BBLU='' C_BRED=''
    C_BYLW='' C_BMAG='' C_BCYN=''
fi

# ── Global state ──────────────────────────────────────────────────────────────
SNAP_DIR="/tmp/snapshots_tweak"          # Where snapshots live
SNAP_LOG="${SNAP_DIR}/snap.log"          # Tab-separated: ID|original_path|timestamp
CURRENT_FILE=""                          # File currently being edited
TERM_W=80                                # Terminal width (updated on draw)
TERM_H=24                                # Terminal height (updated on draw)

# Preset file list shown in the dashboard (user can also type a custom path)
PRESET_FILES=(
    "/etc/hostname"
    "/etc/hosts"
    "/etc/resolv.conf"
    "/etc/fstab"
    "/etc/apk/repositories"
    "/etc/profile"
    "/etc/ssh/sshd_config"
    "$HOME/.bashrc"
    "$HOME/.profile"
    "$HOME/.vimrc"
    "$HOME/.tmux.conf"
    "$HOME/.gitconfig"
)

# ── Initialisation ────────────────────────────────────────────────────────────
init() {
    mkdir -p "$SNAP_DIR"
    # Create log with header if it doesn't exist
    [ -f "$SNAP_LOG" ] || printf "ID\tORIGINAL_PATH\tTIMESTAMP\tSNAP_PATH\n" > "$SNAP_LOG"
    # Hide cursor for cleaner UI
    tput civis 2>/dev/null || true
    # Restore cursor on exit
    trap cleanup EXIT INT TERM
    # Handle Ctrl+Z for undo
    trap undo_last SIGTSTP
}

cleanup() {
    tput cnorm 2>/dev/null || true   # Restore cursor
    tput rmcup 2>/dev/null || true   # Restore screen (if alt-screen used)
    printf '\n'
}

# ── Terminal geometry ─────────────────────────────────────────────────────────
update_term_size() {
    TERM_W=$(tput cols  2>/dev/null || printf '80')
    TERM_H=$(tput lines 2>/dev/null || printf '24')
    # Enforce minimums to prevent layout breakage
    [ "$TERM_W" -lt 60 ] && TERM_W=60
    [ "$TERM_H" -lt 20 ] && TERM_H=20
}

# ── Drawing helpers ───────────────────────────────────────────────────────────

# Move cursor to row, col (1-based)
goto() { tput cup "$(( $1 - 1 ))" "$(( $2 - 1 ))" 2>/dev/null || true; }

# Clear entire screen and move home
clear_screen() { tput clear 2>/dev/null || printf '\033[2J\033[H'; }

# Print a horizontal line of a given character, padded to width
hline() {
    local char="${1:─}" width="${2:-$TERM_W}" colour="${3:-}"
    local line
    line=$(printf "%${width}s" | tr ' ' "${char}")
    printf '%s%s%s' "$colour" "$line" "$C_RESET"
}

# Centre a string within a given width, returning it (no newline)
centre_str() {
    local str="$1" width="${2:-$TERM_W}"
    # Strip ANSI codes to get visible length
    local visible
    visible=$(printf '%s' "$str" | sed 's/\x1b\[[0-9;]*m//g')
    local vlen=${#visible}
    local pad=$(( (width - vlen) / 2 ))
    [ "$pad" -lt 0 ] && pad=0
    printf '%*s%s%*s' "$pad" '' "$str" "$pad" ''
}

# Print a banner box
banner() {
    local title="$1"
    local w=$TERM_W
    printf '\n'
    printf '%s' "${C_BOLD}${C_BBLU}${C_WHT}"
    hline '─' "$w"
    printf '\n'
    centre_str " 📸  Snapshot Tweak TUI  —  $title " "$w"
    printf '\n'
    hline '─' "$w"
    printf '%s\n' "${C_RESET}"
}

# Coloured status bar at bottom
status_bar() {
    local msg="$1" colour="${2:-$C_BCYN}"
    local w=$TERM_W
    printf '%s' "${colour}${C_BLK}${C_BOLD}"
    # Pad message to full width
    printf ' %-*s' $(( w - 1 )) "$msg"
    printf '%s\n' "${C_RESET}"
}

# Print a labelled key hint
key_hint() {
    local key="$1" desc="$2"
    printf '  %s[%s]%s %s' "${C_BOLD}${C_YLW}" "$key" "${C_RESET}" "$desc"
}

# ── Snapshot engine ───────────────────────────────────────────────────────────

# Generate a unique snapshot ID: timestamp + random suffix
new_snap_id() {
    printf '%s_%s' "$(date +%Y%m%d_%H%M%S)" "$(tr -dc 'a-f0-9' < /dev/urandom 2>/dev/null | head -c 6 || printf '%06x' $RANDOM)"
}

# Take a snapshot of a file before modifying it
# Usage: take_snapshot "/path/to/file"
# Returns the snapshot path via stdout
take_snapshot() {
    local src="$1"
    if [ ! -f "$src" ]; then
        # File doesn't exist yet; create an empty placeholder snapshot
        local id snap_path
        id=$(new_snap_id)
        snap_path="${SNAP_DIR}/${id}__EMPTY__"
        touch "$snap_path"
        printf '%s\t%s\t%s\t%s\n' \
            "$id" "$src" "$(date '+%Y-%m-%d %H:%M:%S')" "$snap_path" >> "$SNAP_LOG"
        printf '%s' "$snap_path"
        return 0
    fi
    local id snap_path ts
    id=$(new_snap_id)
    # Encode path in filename: replace / with __ so it's one flat filename
    local encoded_name
    encoded_name=$(printf '%s' "$src" | sed 's|/|__|g')
    snap_path="${SNAP_DIR}/${id}__${encoded_name}"
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    cp -p "$src" "$snap_path"
    printf '%s\t%s\t%s\t%s\n' "$id" "$src" "$ts" "$snap_path" >> "$SNAP_LOG"
    printf '%s' "$snap_path"
}

# Undo the most recent snapshot for a given file (or global last if no arg)
# Triggered by Ctrl+Z (SIGTSTP)
undo_last() {
    # Re-enable cursor during undo UI
    tput cnorm 2>/dev/null || true

    # Find the last snapshot log entry that matches CURRENT_FILE (if set)
    local target_file="$CURRENT_FILE"
    local last_entry snap_path original_path

    if [ -z "$target_file" ]; then
        # No specific file context — undo global last snapshot
        last_entry=$(grep -v '^ID' "$SNAP_LOG" 2>/dev/null | tail -1 || true)
    else
        last_entry=$(grep -v '^ID' "$SNAP_LOG" 2>/dev/null | awk -F'\t' -v f="$target_file" '$2==f' | tail -1 || true)
    fi

    if [ -z "$last_entry" ]; then
        printf '\n%s⚠  No snapshot found to undo.%s\n' "${C_YLW}" "${C_RESET}"
        sleep 2
        tput civis 2>/dev/null || true
        return
    fi

    snap_path=$(printf '%s' "$last_entry" | cut -f4)
    original_path=$(printf '%s' "$last_entry" | cut -f2)

    clear_screen
    banner "UNDO"
    printf '\n  %sUndoing last change to:%s %s\n' "${C_YLW}${C_BOLD}" "${C_RESET}" "$original_path"
    printf '  %sSnapshot:%s              %s\n\n' "${C_CYN}${C_BOLD}" "${C_RESET}" "$snap_path"

    # Show diff between current and snapshot
    if [ -f "$original_path" ] && [ -f "$snap_path" ]; then
        printf '  %s── Diff (snapshot → current) ──%s\n' "${C_MAG}${C_BOLD}" "${C_RESET}"
        diff --color=never "$snap_path" "$original_path" | head -30 | \
        while IFS= read -r line; do
            case "${line:0:1}" in
                '+') printf '  %s+%s %s\n' "${C_GRN}" "${C_RESET}" "${line:1}" ;;
                '-') printf '  %s-%s %s\n' "${C_RED}" "${C_RESET}" "${line:1}" ;;
                *)   printf '  %s\n' "$line" ;;
            esac
        done
        printf '\n'
    fi

    printf '  %sRestore snapshot? [y/N]:%s ' "${C_YLW}${C_BOLD}" "${C_RESET}"
    tput cnorm 2>/dev/null || true
    local confirm
    read -r confirm

    if [ "${confirm,,}" = "y" ]; then
        if [ -f "$snap_path" ]; then
            # Check if snapshot is an "EMPTY" placeholder
            if printf '%s' "$snap_path" | grep -q '__EMPTY__'; then
                rm -f "$original_path"
                printf '\n  %s✔  File removed (restored to non-existent state).%s\n' \
                    "${C_GRN}" "${C_RESET}"
            else
                cp -p "$snap_path" "$original_path"
                printf '\n  %s✔  Restored successfully.%s\n' "${C_GRN}" "${C_RESET}"
            fi
            # Remove the last log entry for this snapshot
            # (use temp file to avoid in-place issues on Alpine/busybox)
            local tmplog
            tmplog=$(mktemp)
            grep -v "$(printf '%s' "$last_entry" | cut -f1)" "$SNAP_LOG" > "$tmplog" || true
            mv "$tmplog" "$SNAP_LOG"
        else
            printf '\n  %s✘  Snapshot file missing: %s%s\n' \
                "${C_RED}" "$snap_path" "${C_RESET}"
        fi
    else
        printf '\n  %sCancelled.%s\n' "${C_YLW}" "${C_RESET}"
    fi
    sleep 2
    tput civis 2>/dev/null || true
    # Redraw main menu after undo
    main_menu
}

# ── File helpers ──────────────────────────────────────────────────────────────

# Check if we need sudo to write a file
needs_sudo() {
    local file="$1"
    local dir
    dir=$(dirname "$file")
    # If file exists, check write permission on it directly
    if [ -e "$file" ]; then
        [ ! -w "$file" ] && return 0
    else
        # File doesn't exist; check parent directory
        [ ! -w "$dir" ] && return 0
    fi
    return 1
}

# Safely write content to a file (via temp + mv for atomicity)
# Usage: safe_write_file "/path/to/file" "/tmp/tempfile_with_new_content"
safe_write_file() {
    local dest="$1" src_tmp="$2"
    if needs_sudo "$dest"; then
        if command -v sudo &>/dev/null; then
            sudo cp "$src_tmp" "$dest"
        else
            printf '%s✘  Need elevated privileges to write %s but sudo not found.%s\n' \
                "${C_RED}" "$dest" "${C_RESET}"
            return 1
        fi
    else
        cp "$src_tmp" "$dest"
    fi
}

# ── Snapshot viewer ───────────────────────────────────────────────────────────
view_snapshots() {
    clear_screen
    update_term_size
    banner "Snapshot History"

    if [ ! -s "$SNAP_LOG" ] || [ "$(wc -l < "$SNAP_LOG")" -le 1 ]; then
        printf '\n  %sNo snapshots recorded yet.%s\n' "${C_YLW}" "${C_RESET}"
        printf '\n'
        status_bar "  Press Enter to return..."
        tput cnorm 2>/dev/null || true
        read -r
        tput civis 2>/dev/null || true
        return
    fi

    # Header
    printf '\n  %s%-20s  %-35s  %-19s%s\n' \
        "${C_BOLD}${C_CYN}" "SNAP ID" "ORIGINAL FILE" "TIMESTAMP" "${C_RESET}"
    hline '─' $(( TERM_W - 2 )) "  ${C_DIM}"
    printf '\n'

    # Print log entries (skip header row)
    local count=0
    while IFS=$'\t' read -r id orig ts snap; do
        [ "$id" = "ID" ] && continue    # Skip header
        local exists_mark="${C_GRN}●${C_RESET}"
        [ ! -f "$snap" ] && exists_mark="${C_RED}✘${C_RESET}"
        printf '  %s  %-35s  %s\n' \
            "${C_YLW}${id:0:18}${C_RESET}" \
            "$(printf '%.35s' "$orig")" \
            "${C_DIM}$ts${C_RESET}  $exists_mark"
        count=$(( count + 1 ))
    done < "$SNAP_LOG"

    printf '\n'
    printf '  %sTotal snapshots: %s%s%s\n' \
        "${C_DIM}" "${C_BOLD}${C_WHT}" "$count" "${C_RESET}"
    printf '\n'
    status_bar "  [D] Diff compare  |  Press Enter to return  |  Snapshots in: ${SNAP_DIR}"
    tput cnorm 2>/dev/null || true
    local choice
    read -r choice
    if [ "${choice,,}" = "d" ]; then
        diff_snapshots
    fi
    tput civis 2>/dev/null || true
}

# ── Snapshot diff viewer ──────────────────────────────────────────────────────
# Compare any two snapshots side-by-side with syntax highlighting
diff_snapshots() {
    clear_screen
    update_term_size
    banner "Compare Snapshots"

    printf '\n  %sEnter two snapshot IDs to compare (oldest first):%s\n\n' \
        "${C_BOLD}${C_CYN}" "${C_RESET}"

    # List available snapshots
    printf '  %sAvailable snapshots:%s\n' "${C_DIM}" "${C_RESET}"
    grep -v '^ID' "$SNAP_LOG" 2>/dev/null | while IFS=$'\t' read -r id orig ts snap; do
        printf '    %s%-20s%s %s\n' "${C_YLW}" "$id" "${C_RESET}" "$(basename "$orig")"
    done
    printf '\n'

    tput cnorm 2>/dev/null || true
    local snap1_id snap2_id
    printf '  %sFirst snapshot ID:%s  ' "${C_BOLD}" "${C_RESET}"
    read -r snap1_id
    printf '  %sSecond snapshot ID:%s ' "${C_BOLD}" "${C_RESET}"
    read -r snap2_id

    # Find snapshot paths
    local snap1_path snap2_path orig_file
    snap1_path=$(awk -F'\t' -v id="$snap1_id" '$1==id {print $4}' "$SNAP_LOG" 2>/dev/null)
    snap2_path=$(awk -F'\t' -v id="$snap2_id" '$1==id {print $4}' "$SNAP_LOG" 2>/dev/null)
    orig_file=$(awk -F'\t' -v id="$snap1_id" '$1==id {print $2}' "$SNAP_LOG" 2>/dev/null)

    if [ -z "$snap1_path" ] || [ -z "$snap2_path" ]; then
        printf '\n  %s✘  Invalid snapshot ID(s).%s\n' "${C_RED}" "${C_RESET}"
        sleep 2
        tput civis 2>/dev/null || true
        return
    fi

    if [ ! -f "$snap1_path" ] || [ ! -f "$snap2_path" ]; then
        printf '\n  %s✘  One or both snapshot files are missing.%s\n' "${C_RED}" "${C_RESET}"
        sleep 2
        tput civis 2>/dev/null || true
        return
    fi

    clear_screen
    banner "Diff: $snap1_id → $snap2_id"
    printf '\n  %sFile:%s %s\n\n' "${C_DIM}" "${C_RESET}" "$orig_file"

    # Show diff with color highlighting
    printf '  %s─── Diff Output ───%s\n' "${C_BOLD}${C_MAG}" "${C_RESET}"
    printf '\n'
    diff -u "$snap1_path" "$snap2_path" 2>/dev/null | head -100 | \
    while IFS= read -r line; do
        case "${line:0:1}" in
            '+')
                printf '  %s+%s %s\n' "${C_GRN}" "${C_RESET}" "${line:1}" ;;
            '-')
                if [ "${line:0:3}" = "---" ]; then
                    printf '  %s%s%s\n' "${C_DIM}" "$line" "${C_RESET}"
                else
                    printf '  %s-%s %s\n' "${C_RED}" "${C_RESET}" "${line:1}"
                fi
                ;;
            '@')
                printf '  %s@%s\n' "${C_CYN}" "${line:1}${C_RESET}" ;;
            *)
                printf '  %s\n' "$line" ;;
        esac
    done

    printf '\n'
    status_bar "  Press Enter to return..."
    read -r
    tput civis 2>/dev/null || true
}

# ── In-script line editor ─────────────────────────────────────────────────────
# Opens the file in a simple line-listing editor; user can:
#   • View all lines with numbers
#   • Replace a specific line
#   • Append a new line
#   • Delete a line
#   • Insert a blank line
#   • Save & exit, or discard changes

line_editor() {
    local file="$1"
    CURRENT_FILE="$file"

    # Load file content into an array (line by line)
    local -a lines=()
    if [ -f "$file" ]; then
        while IFS= read -r line; do
            lines+=("$line")
        done < "$file"
    fi

    local dirty=0      # 1 = unsaved changes exist
    local page=0       # Current page (0-based)
    local page_size    # Lines per page (calculated from terminal)
    local message=""   # Status message to display

    while true; do
        update_term_size
        clear_screen
        banner "Line Editor — $file"
        page_size=$(( TERM_H - 14 ))   # Reserve rows for chrome
        [ "$page_size" -lt 5 ] && page_size=5

        local total_lines=${#lines[@]}
        local total_pages=$(( (total_lines + page_size - 1) / page_size ))
        [ "$total_pages" -lt 1 ] && total_pages=1

        # Clamp page index
        [ "$page" -ge "$total_pages" ] && page=$(( total_pages - 1 ))
        [ "$page" -lt 0 ] && page=0

        local start=$(( page * page_size ))
        local end=$(( start + page_size - 1 ))
        [ "$end" -ge "$total_lines" ] && end=$(( total_lines - 1 ))

        # ── File info row ──
        printf '  %sFile:%s %-40s  %sLines:%s %d  %sPage:%s %d/%d\n' \
            "${C_CYN}${C_BOLD}" "${C_RESET}" "$file" \
            "${C_CYN}${C_BOLD}" "${C_RESET}" "$total_lines" \
            "${C_CYN}${C_BOLD}" "${C_RESET}" $(( page + 1 )) "$total_pages"

        [ "$dirty" -eq 1 ] && printf '  %s● Unsaved changes%s\n' "${C_YLW}" "${C_RESET}" \
                           || printf '  %s✔ Saved%s\n' "${C_GRN}" "${C_RESET}"
        printf '\n'

        # ── Line listing ──
        hline '─' $(( TERM_W - 2 )) "  ${C_DIM}"
        printf '\n'

        if [ "$total_lines" -eq 0 ]; then
            printf '  %s(empty file)%s\n' "${C_DIM}" "${C_RESET}"
        else
            local i
            for (( i = start; i <= end; i++ )); do
                local lnum=$(( i + 1 ))
                # Alternate row shading for readability
                if (( i % 2 == 0 )); then
                    printf '  %s%4d%s │ %s\n' \
                        "${C_YLW}${C_BOLD}" "$lnum" "${C_RESET}" "${lines[$i]}"
                else
                    printf '  %s%4d%s │ %s%s%s\n' \
                        "${C_YLW}${C_BOLD}" "$lnum" "${C_RESET}" \
                        "${C_DIM}" "${lines[$i]}" "${C_RESET}"
                fi
            done
        fi

        printf '\n'
        hline '─' $(( TERM_W - 2 )) "  ${C_DIM}"
        printf '\n'

        # ── Key hints ──
        key_hint "r" "Replace line"
        key_hint "a" "Append line"
        key_hint "d" "Delete line"
        key_hint "i" "Insert before"
        printf '\n'
        key_hint "n" "Next page"
        key_hint "p" "Prev page"
        key_hint "s" "Save"
        key_hint "q" "Quit/discard"
        printf '\n\n'

        # ── Status message ──
        if [ -n "$message" ]; then
            status_bar "  $message" "${C_BYLW}${C_BLK}"
            message=""
        else
            status_bar "  Ctrl+Z = Undo last save  |  Enter choice:"
        fi

        # ── Input ──
        tput cnorm 2>/dev/null || true
        printf '  %s▶ %s' "${C_GRN}${C_BOLD}" "${C_RESET}"
        local choice
        read -r choice
        tput civis 2>/dev/null || true

        case "${choice,,}" in
            # ── Navigation ──
            n) page=$(( page + 1 )) ;;
            p) page=$(( page - 1 )) ;;

            # ── Replace line ──
            r)
                tput cnorm 2>/dev/null || true
                printf '  %sLine number to replace:%s ' "${C_CYN}" "${C_RESET}"
                local lnum_r
                read -r lnum_r
                if printf '%s' "$lnum_r" | grep -qE '^[0-9]+$' && \
                   [ "$lnum_r" -ge 1 ] && [ "$lnum_r" -le "$total_lines" ]; then
                    local idx=$(( lnum_r - 1 ))
                    printf '  %sCurrent:%s %s\n' "${C_DIM}" "${C_RESET}" "${lines[$idx]}"
                    printf '  %sNew content:%s ' "${C_CYN}" "${C_RESET}"
                    local new_line
                    read -r new_line
                    lines[$idx]="$new_line"
                    dirty=1
                    message="Line $lnum_r replaced."
                else
                    message="Invalid line number."
                fi
                tput civis 2>/dev/null || true
                ;;

            # ── Append line ──
            a)
                tput cnorm 2>/dev/null || true
                printf '  %sNew line content:%s ' "${C_CYN}" "${C_RESET}"
                local new_line_a
                read -r new_line_a
                lines+=("$new_line_a")
                dirty=1
                page=$(( (${#lines[@]} - 1) / page_size ))   # Jump to last page
                message="Line appended (line ${#lines[@]})."
                tput civis 2>/dev/null || true
                ;;

            # ── Delete line ──
            d)
                tput cnorm 2>/dev/null || true
                printf '  %sLine number to delete:%s ' "${C_CYN}" "${C_RESET}"
                local lnum_d
                read -r lnum_d
                if printf '%s' "$lnum_d" | grep -qE '^[0-9]+$' && \
                   [ "$lnum_d" -ge 1 ] && [ "$lnum_d" -le "$total_lines" ]; then
                    local idx_d=$(( lnum_d - 1 ))
                    printf '  %sDelete: %s"%s"%s ? [y/N]:%s ' \
                        "${C_RED}" "${C_BOLD}" "${lines[$idx_d]}" "${C_RESET}${C_RED}" "${C_RESET}"
                    local confirm_d
                    read -r confirm_d
                    if [ "${confirm_d,,}" = "y" ]; then
                        # Remove element from array
                        lines=("${lines[@]:0:$idx_d}" "${lines[@]:$(( idx_d + 1 ))}")
                        dirty=1
                        message="Line $lnum_d deleted."
                    else
                        message="Delete cancelled."
                    fi
                else
                    message="Invalid line number."
                fi
                tput civis 2>/dev/null || true
                ;;

            # ── Insert before line ──
            i)
                tput cnorm 2>/dev/null || true
                printf '  %sInsert BEFORE line number:%s ' "${C_CYN}" "${C_RESET}"
                local lnum_i
                read -r lnum_i
                if printf '%s' "$lnum_i" | grep -qE '^[0-9]+$' && \
                   [ "$lnum_i" -ge 1 ] && [ "$lnum_i" -le "$(( total_lines + 1 ))" ]; then
                    printf '  %sContent to insert:%s ' "${C_CYN}" "${C_RESET}"
                    local new_line_i
                    read -r new_line_i
                    local idx_i=$(( lnum_i - 1 ))
                    lines=("${lines[@]:0:$idx_i}" "$new_line_i" "${lines[@]:$idx_i}")
                    dirty=1
                    message="Line inserted at position $lnum_i."
                else
                    message="Invalid line number."
                fi
                tput civis 2>/dev/null || true
                ;;

            # ── Save ──
            s)
                # Snapshot before saving
                local snap
                snap=$(take_snapshot "$file")
                # Write lines to a temp file
                local tmp_out
                tmp_out=$(mktemp)
                local first=1
                for l in "${lines[@]}"; do
                    if [ "$first" -eq 1 ]; then
                        printf '%s' "$l" > "$tmp_out"
                        first=0
                    else
                        printf '\n%s' "$l" >> "$tmp_out"
                    fi
                done
                # Ensure trailing newline
                printf '\n' >> "$tmp_out"
                if safe_write_file "$file" "$tmp_out"; then
                    rm -f "$tmp_out"
                    dirty=0
                    message="✔ Saved. Snapshot: $(basename "$snap")"
                else
                    rm -f "$tmp_out"
                    message="✘ Save failed. Check permissions."
                fi
                ;;

            # ── Quit ──
            q)
                if [ "$dirty" -eq 1 ]; then
                    tput cnorm 2>/dev/null || true
                    printf '\n  %sUnsaved changes! Discard? [y/N]:%s ' "${C_YLW}" "${C_RESET}"
                    local confirm_q
                    read -r confirm_q
                    tput civis 2>/dev/null || true
                    [ "${confirm_q,,}" = "y" ] && break
                else
                    break
                fi
                ;;

            '') ;; # Just Enter — refresh
            *) message="Unknown command: '$choice'" ;;
        esac
    done

    CURRENT_FILE=""
}

# ── Quick-add a key=value pair ────────────────────────────────────────────────
# Searches for a key in the file; replaces if found, appends if not.
quick_set_key_value() {
    local file="$1"
    CURRENT_FILE="$file"

    clear_screen
    update_term_size
    banner "Quick Set  key=value  —  $file"

    if [ ! -f "$file" ]; then
        printf '\n  %s⚠  File does not exist: %s%s\n' "${C_YLW}" "$file" "${C_RESET}"
        printf '  %sCreate it? [y/N]:%s ' "${C_CYN}" "${C_RESET}"
        tput cnorm 2>/dev/null || true
        local c; read -r c
        tput civis 2>/dev/null || true
        [ "${c,,}" != "y" ] && { CURRENT_FILE=""; return; }
        touch "$file" || { printf '%s✘ Cannot create file%s\n' "${C_RED}" "${C_RESET}"; sleep 2; return; }
    fi

    printf '\n  %sKey name (e.g. MAX_RETRY):%s ' "${C_CYN}${C_BOLD}" "${C_RESET}"
    tput cnorm 2>/dev/null || true
    local key; read -r key
    [ -z "$key" ] && { tput civis 2>/dev/null || true; CURRENT_FILE=""; return; }

    # Show current value if it exists
    local current_val
    current_val=$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$file" 2>/dev/null | tail -1 | \
                  sed 's/^[^=]*=\s*//' || true)
    if [ -n "$current_val" ]; then
        printf '  %sCurrent value:%s %s\n' "${C_DIM}" "${C_RESET}" "$current_val"
    else
        printf '  %s(key not found — will append)%s\n' "${C_DIM}" "${C_RESET}"
    fi

    printf '  %sNew value:%s ' "${C_CYN}${C_BOLD}" "${C_RESET}"
    local value; read -r value
    tput civis 2>/dev/null || true

    # Separator (= or space-separated like /etc/hosts)
    printf '  %sSeparator [= (default) / space]:%s ' "${C_DIM}" "${C_RESET}"
    tput cnorm 2>/dev/null || true
    local sep_choice; read -r sep_choice
    tput civis 2>/dev/null || true
    local sep='='
    [ "${sep_choice,,}" = "space" ] || [ "$sep_choice" = " " ] && sep=' '

    # Take snapshot
    local snap
    snap=$(take_snapshot "$file")

    local tmp_kv
    tmp_kv=$(mktemp)

    if [ -n "$current_val" ]; then
        # Replace existing key
        sed "s|^[[:space:]]*${key}[[:space:]]*=.*|${key}${sep}${value}|" "$file" > "$tmp_kv"
    else
        # Append new key
        cp "$file" "$tmp_kv"
        printf '%s%s%s\n' "$key" "$sep" "$value" >> "$tmp_kv"
    fi

    if safe_write_file "$file" "$tmp_kv"; then
        rm -f "$tmp_kv"
        printf '\n  %s✔  Written: %s%s%s%s%s\n' \
            "${C_GRN}" "${C_BOLD}" "$key" "$sep" "$value" "${C_RESET}"
        printf '  %sSnapshot: %s%s\n' "${C_DIM}" "$(basename "$snap")" "${C_RESET}"
    else
        rm -f "$tmp_kv"
        # Restore snapshot on failure
        cp "$snap" "$file" 2>/dev/null || true
        printf '\n  %s✘  Write failed. Snapshot restored.%s\n' "${C_RED}" "${C_RESET}"
    fi

    sleep 2
    CURRENT_FILE=""
}

# ── Comment/uncomment a line ──────────────────────────────────────────────────
toggle_comment() {
    local file="$1"
    CURRENT_FILE="$file"

    clear_screen
    update_term_size
    banner "Toggle Comment  —  $file"

    if [ ! -f "$file" ]; then
        printf '\n  %s✘  File not found.%s\n' "${C_RED}" "${C_RESET}"
        sleep 2; CURRENT_FILE=""; return
    fi

    # Show numbered lines
    printf '\n'
    local i=1
    while IFS= read -r line; do
        if printf '%s' "$line" | grep -qE '^[[:space:]]*#'; then
            printf '  %s%4d%s │ %s%s%s\n' \
                "${C_YLW}" "$i" "${C_RESET}" "${C_DIM}" "$line" "${C_RESET}"
        else
            printf '  %s%4d%s │ %s\n' "${C_YLW}" "$i" "${C_RESET}" "$line"
        fi
        i=$(( i + 1 ))
    done < "$file"

    printf '\n'
    printf '  %sLine number to toggle comment:%s ' "${C_CYN}${C_BOLD}" "${C_RESET}"
    tput cnorm 2>/dev/null || true
    local lnum; read -r lnum
    tput civis 2>/dev/null || true

    if ! printf '%s' "$lnum" | grep -qE '^[0-9]+$'; then
        printf '  %sInvalid input.%s\n' "${C_RED}" "${C_RESET}"
        sleep 2; CURRENT_FILE=""; return
    fi

    local total
    total=$(wc -l < "$file")
    if [ "$lnum" -lt 1 ] || [ "$lnum" -gt "$total" ]; then
        printf '  %sLine out of range.%s\n' "${C_RED}" "${C_RESET}"
        sleep 2; CURRENT_FILE=""; return
    fi

    local snap
    snap=$(take_snapshot "$file")

    local tmp_tc
    tmp_tc=$(mktemp)

    # Toggle: if line starts with #, remove it; otherwise prepend #
    awk -v n="$lnum" '
        NR == n {
            if ($0 ~ /^[[:space:]]*#/) {
                # Uncomment: remove first #
                sub(/^([[:space:]]*)#[[:space:]]?/, "\\1")
            } else {
                # Comment: prepend #
                sub(/^([[:space:]]*)/, "\\1# ")
            }
        }
        { print }
    ' "$file" > "$tmp_tc"

    if safe_write_file "$file" "$tmp_tc"; then
        rm -f "$tmp_tc"
        printf '\n  %s✔  Line %d toggled. Snapshot: %s%s\n' \
            "${C_GRN}" "$lnum" "$(basename "$snap")" "${C_RESET}"
    else
        rm -f "$tmp_tc"
        printf '\n  %s✘  Failed. Snapshot preserved.%s\n' "${C_RED}" "${C_RESET}"
    fi

    sleep 2
    CURRENT_FILE=""
}

# ── Search & replace across a file ───────────────────────────────────────────
search_replace() {
    local file="$1"
    CURRENT_FILE="$file"

    clear_screen
    update_term_size
    banner "Search & Replace  —  $file"

    if [ ! -f "$file" ]; then
        printf '\n  %s✘  File not found.%s\n' "${C_RED}" "${C_RESET}"
        sleep 2; CURRENT_FILE=""; return
    fi

    tput cnorm 2>/dev/null || true
    printf '\n  %sSearch pattern (regex):%s '  "${C_CYN}${C_BOLD}" "${C_RESET}"
    local pattern; read -r pattern
    [ -z "$pattern" ] && { tput civis 2>/dev/null || true; CURRENT_FILE=""; return; }

    printf '  %sReplacement string:%s '  "${C_CYN}${C_BOLD}" "${C_RESET}"
    local replacement; read -r replacement
    tput civis 2>/dev/null || true

    # Preview matches
    printf '\n  %sMatching lines:%s\n' "${C_MAG}${C_BOLD}" "${C_RESET}"
    local match_count=0
    while IFS= read -r line; do
        if printf '%s' "$line" | grep -qE "$pattern" 2>/dev/null; then
            printf '  %s→%s %s\n' "${C_YLW}" "${C_RESET}" "$line"
            match_count=$(( match_count + 1 ))
        fi
    done < "$file"

    if [ "$match_count" -eq 0 ]; then
        printf '  %s(no matches found)%s\n' "${C_DIM}" "${C_RESET}"
        sleep 2; CURRENT_FILE=""; return
    fi

    printf '\n  %s%d match(es). Proceed? [y/N]:%s ' \
        "${C_YLW}${C_BOLD}" "$match_count" "${C_RESET}"
    tput cnorm 2>/dev/null || true
    local confirm; read -r confirm
    tput civis 2>/dev/null || true

    if [ "${confirm,,}" != "y" ]; then
        printf '  %sCancelled.%s\n' "${C_YLW}" "${C_RESET}"
        sleep 1; CURRENT_FILE=""; return
    fi

    local snap
    snap=$(take_snapshot "$file")

    local tmp_sr
    tmp_sr=$(mktemp)
    sed "s|${pattern}|${replacement}|g" "$file" > "$tmp_sr"

    if safe_write_file "$file" "$tmp_sr"; then
        rm -f "$tmp_sr"
        printf '\n  %s✔  Replaced %d occurrence(s). Snapshot: %s%s\n' \
            "${C_GRN}" "$match_count" "$(basename "$snap")" "${C_RESET}"
    else
        rm -f "$tmp_sr"
        printf '\n  %s✘  Failed. Snapshot preserved.%s\n' "${C_RED}" "${C_RESET}"
    fi

    sleep 2
    CURRENT_FILE=""
}

# ── File action submenu ────────────────────────────────────────────────────────
file_actions_menu() {
    local file="$1"

    while true; do
        clear_screen
        update_term_size
        banner "File Actions"

        # File info block
        printf '\n  %sFile:%s %s\n' "${C_CYN}${C_BOLD}" "${C_RESET}" "$file"

        if [ -f "$file" ]; then
            local fsize flines fperms
            fsize=$(wc -c < "$file" 2>/dev/null || printf '?')
            flines=$(wc -l < "$file" 2>/dev/null || printf '?')
            fperms=$(ls -la "$file" 2>/dev/null | awk '{print $1, $3, $4}' || printf '?')
            printf '  %sSize:%s %-10s  %sLines:%s %-6s  %sPerms:%s %s\n' \
                "${C_DIM}" "${C_RESET}" "${fsize}B" \
                "${C_DIM}" "${C_RESET}" "$flines" \
                "${C_DIM}" "${C_RESET}" "$fperms"
        else
            printf '  %s⚠  File does not exist yet.%s\n' "${C_YLW}" "${C_RESET}"
        fi

        # Snapshot count for this file
        local snap_count
        snap_count=$(grep -c "$file" "$SNAP_LOG" 2>/dev/null || printf '0')
        printf '  %sSnapshots for this file:%s %s\n' \
            "${C_DIM}" "${C_RESET}" "$snap_count"

        printf '\n'
        hline '─' $(( TERM_W - 4 )) "  ${C_DIM}"
        printf '\n\n'

        # Action list
        printf '  %s[1]%s  📝  Line Editor (view / edit / save)\n' \
            "${C_YLW}${C_BOLD}" "${C_RESET}"
        printf '  %s[2]%s  🔑  Quick set  key=value\n' \
            "${C_YLW}${C_BOLD}" "${C_RESET}"
        printf '  %s[3]%s  #   Toggle comment on a line\n' \
            "${C_YLW}${C_BOLD}" "${C_RESET}"
        printf '  %s[4]%s  🔍  Search & replace\n' \
            "${C_YLW}${C_BOLD}" "${C_RESET}"
        printf '  %s[5]%s  👁   Preview file (cat with line numbers)\n' \
            "${C_YLW}${C_BOLD}" "${C_RESET}"
        printf '  %s[6]%s  🗂   View snapshots for this file\n' \
            "${C_YLW}${C_BOLD}" "${C_RESET}"
        printf '  %s[0]%s  ←   Back to main menu\n' \
            "${C_MAG}${C_BOLD}" "${C_RESET}"
        printf '\n'
        status_bar "  Ctrl+Z = Undo last change  |  Choose action:"

        tput cnorm 2>/dev/null || true
        printf '  %s▶ %s' "${C_GRN}${C_BOLD}" "${C_RESET}"
        local choice; read -r choice
        tput civis 2>/dev/null || true

        case "$choice" in
            1) line_editor "$file" ;;
            2) quick_set_key_value "$file" ;;
            3) toggle_comment "$file" ;;
            4) search_replace "$file" ;;
            5)
                clear_screen
                banner "Preview  —  $file"
                if [ -f "$file" ]; then
                    cat -n "$file" | head -100 | \
                    while IFS= read -r line; do
                        printf '  %s\n' "$line"
                    done
                    local total_l; total_l=$(wc -l < "$file")
                    [ "$total_l" -gt 100 ] && \
                        printf '\n  %s… (%d more lines not shown)%s\n' \
                            "${C_DIM}" $(( total_l - 100 )) "${C_RESET}"
                else
                    printf '\n  %s(file not found)%s\n' "${C_DIM}" "${C_RESET}"
                fi
                printf '\n'
                status_bar "  Press Enter to return..."
                tput cnorm 2>/dev/null || true; read -r; tput civis 2>/dev/null || true
                ;;
            6)
                # Show snapshots only for this file
                clear_screen
                banner "Snapshots for  $file"
                local found=0
                while IFS=$'\t' read -r id orig ts snap; do
                    [ "$id" = "ID" ] && continue
                    [ "$orig" = "$file" ] || continue
                    found=1
                    local exists_mark="${C_GRN}exists${C_RESET}"
                    [ ! -f "$snap" ] && exists_mark="${C_RED}MISSING${C_RESET}"
                    printf '  %s%s%s  %s  %s\n' \
                        "${C_YLW}" "${id:0:28}" "${C_RESET}" \
                        "${C_DIM}$ts${C_RESET}" "$exists_mark"
                done < "$SNAP_LOG"
                [ "$found" -eq 0 ] && printf '\n  %sNo snapshots for this file.%s\n' \
                    "${C_DIM}" "${C_RESET}"
                printf '\n'
                status_bar "  Press Enter to return..."
                tput cnorm 2>/dev/null || true; read -r; tput civis 2>/dev/null || true
                ;;
            0|q|Q) break ;;
            *) ;;
        esac
    done
}

# ── File picker ───────────────────────────────────────────────────────────────
pick_file() {
    local selected=""

    while true; do
        clear_screen
        update_term_size
        banner "Pick a File to Edit"
        printf '\n'

        # List presets
        local i=1
        for f in "${PRESET_FILES[@]}"; do
            local exists_mark
            if [ -f "$f" ]; then
                exists_mark="${C_GRN}✔${C_RESET}"
            else
                exists_mark="${C_RED}✘${C_RESET}"
            fi
            printf '  %s[%2d]%s  %s  %s\n' \
                "${C_YLW}${C_BOLD}" "$i" "${C_RESET}" "$exists_mark" "$f"
            i=$(( i + 1 ))
        done

        printf '\n'
        hline '─' $(( TERM_W - 4 )) "  ${C_DIM}"
        printf '\n'
        printf '  %s[c]%s  Type a custom path\n' "${C_CYN}${C_BOLD}" "${C_RESET}"
        printf '  %s[0]%s  Back to main menu\n'  "${C_MAG}${C_BOLD}" "${C_RESET}"
        printf '\n'
        status_bar "  Enter number or 'c' for custom:"

        tput cnorm 2>/dev/null || true
        printf '  %s▶ %s' "${C_GRN}${C_BOLD}" "${C_RESET}"
        local choice; read -r choice
        tput civis 2>/dev/null || true

        case "$choice" in
            0|q|Q) return ;;
            c|C)
                tput cnorm 2>/dev/null || true
                printf '  %sEnter full path:%s ' "${C_CYN}" "${C_RESET}"
                read -r selected
                tput civis 2>/dev/null || true
                [ -n "$selected" ] && { file_actions_menu "$selected"; return; }
                ;;
            *)
                if printf '%s' "$choice" | grep -qE '^[0-9]+$'; then
                    local idx=$(( choice - 1 ))
                    if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#PRESET_FILES[@]}" ]; then
                        file_actions_menu "${PRESET_FILES[$idx]}"
                        return
                    else
                        printf '\n  %sInvalid selection.%s\n' "${C_RED}" "${C_RESET}"
                        sleep 1
                    fi
                fi
                ;;
        esac
    done
}

# ── Purge old snapshots ───────────────────────────────────────────────────────
purge_snapshots() {
    clear_screen
    update_term_size
    banner "Purge Snapshots"

    local count
    count=$(find "$SNAP_DIR" -maxdepth 1 -type f ! -name 'snap.log' 2>/dev/null | wc -l)
    local log_entries
    log_entries=$(grep -c '' "$SNAP_LOG" 2>/dev/null || printf '0')
    log_entries=$(( log_entries - 1 ))   # Subtract header
    [ "$log_entries" -lt 0 ] && log_entries=0

    printf '\n  %sSnapshot directory:%s %s\n'   "${C_CYN}" "${C_RESET}" "$SNAP_DIR"
    printf '  %sSnapshot files:%s    %d\n'      "${C_CYN}" "${C_RESET}" "$count"
    printf '  %sLog entries:%s       %d\n\n'    "${C_CYN}" "${C_RESET}" "$log_entries"

    printf '  %s[1]%s  Delete snapshots older than 7 days\n' "${C_YLW}${C_BOLD}" "${C_RESET}"
    printf '  %s[2]%s  Delete ALL snapshots (irreversible!)\n' "${C_RED}${C_BOLD}" "${C_RESET}"
    printf '  %s[0]%s  Back\n\n' "${C_MAG}${C_BOLD}" "${C_RESET}"
    status_bar "  Choose:"

    tput cnorm 2>/dev/null || true
    printf '  %s▶ %s' "${C_GRN}${C_BOLD}" "${C_RESET}"
    local choice; read -r choice
    tput civis 2>/dev/null || true

    case "$choice" in
        1)
            local removed=0
            while IFS= read -r f; do
                rm -f "$f"
                removed=$(( removed + 1 ))
            done < <(find "$SNAP_DIR" -maxdepth 1 -type f ! -name 'snap.log' -mtime +7 2>/dev/null)
            # Rebuild log: keep only entries whose snap_path still exists
            local tmp_log; tmp_log=$(mktemp)
            head -1 "$SNAP_LOG" > "$tmp_log"
            while IFS=$'\t' read -r id orig ts snap; do
                [ "$id" = "ID" ] && continue
                [ -f "$snap" ] && printf '%s\t%s\t%s\t%s\n' "$id" "$orig" "$ts" "$snap" >> "$tmp_log"
            done < "$SNAP_LOG"
            mv "$tmp_log" "$SNAP_LOG"
            printf '\n  %s✔  Removed %d old snapshot(s).%s\n' "${C_GRN}" "$removed" "${C_RESET}"
            sleep 2
            ;;
        2)
            tput cnorm 2>/dev/null || true
            printf '  %sTHIS WILL DELETE ALL SNAPSHOTS. Type "yes" to confirm:%s ' \
                "${C_RED}${C_BOLD}" "${C_RESET}"
            local confirm; read -r confirm
            tput civis 2>/dev/null || true
            if [ "$confirm" = "yes" ]; then
                find "$SNAP_DIR" -maxdepth 1 -type f ! -name 'snap.log' -delete 2>/dev/null || true
                printf 'ID\tORIGINAL_PATH\tTIMESTAMP\tSNAP_PATH\n' > "$SNAP_LOG"
                printf '\n  %s✔  All snapshots deleted.%s\n' "${C_GRN}" "${C_RESET}"
            else
                printf '\n  %sCancelled.%s\n' "${C_YLW}" "${C_RESET}"
            fi
            sleep 2
            ;;
        *) ;;
    esac
}

# ── Main menu ─────────────────────────────────────────────────────────────────
main_menu() {
    while true; do
        update_term_size
        clear_screen
        banner "Main Menu"

        # Quick stats
        local snap_count=0
        [ -f "$SNAP_LOG" ] && snap_count=$(grep -vc '^ID' "$SNAP_LOG" 2>/dev/null || printf '0')
        local snap_size="0K"
        snap_size=$(du -sh "$SNAP_DIR" 2>/dev/null | cut -f1 || printf '?')

        printf '\n'
        printf '  %s📂 Snapshot dir:%s %-30s  %s📸 Snapshots:%s %d  %s💾 Size:%s %s\n' \
            "${C_DIM}" "${C_RESET}" "$SNAP_DIR" \
            "${C_DIM}" "${C_RESET}" "$snap_count" \
            "${C_DIM}" "${C_RESET}" "$snap_size"
        printf '\n'
        hline '─' $(( TERM_W - 4 )) "  ${C_DIM}"
        printf '\n\n'

        # Menu items
        printf '  %s[1]%s  📁  Browse & edit files\n' \
            "${C_YLW}${C_BOLD}" "${C_RESET}"
        printf '  %s[2]%s  📸  View all snapshots\n' \
            "${C_YLW}${C_BOLD}" "${C_RESET}"
        printf '  %s[3]%s  ↩   Undo last snapshot (any file)\n' \
            "${C_CYN}${C_BOLD}" "${C_RESET}"
        printf '  %s[4]%s  🗑   Purge old snapshots\n' \
            "${C_YLW}${C_BOLD}" "${C_RESET}"
        printf '  %s[5]%s  ℹ   About / help\n' \
            "${C_YLW}${C_BOLD}" "${C_RESET}"
        printf '  %s[q]%s  ✖   Quit\n\n' \
            "${C_MAG}${C_BOLD}" "${C_RESET}"

        # Key hints row
        key_hint "Ctrl+Z" "undo last change"
        printf '\n\n'

        status_bar "  Snapshot Tweak TUI  |  All changes are reversible  |  Choose:"

        tput cnorm 2>/dev/null || true
        printf '  %s▶ %s' "${C_GRN}${C_BOLD}" "${C_RESET}"
        local choice; read -r choice
        tput civis 2>/dev/null || true

        case "${choice,,}" in
            1) pick_file ;;
            2) view_snapshots ;;
            3) undo_last ;;
            4) purge_snapshots ;;
            5)
                clear_screen
                banner "About"
                cat <<'HELP'

  Snapshot Tweak TUI
  ──────────────────
  Safely edit /etc/ config files and dotfiles from the terminal.

  HOW IT WORKS
  ────────────
  Before every write, the tool creates a timestamped copy of the
  original file under /tmp/snapshots_tweak/. If a change breaks
  something, press Ctrl+Z or choose option [3] to instantly swap
  the file back to its pre-edit state.

  SNAPSHOT LOG
  ────────────
  /tmp/snapshots_tweak/snap.log  — tab-separated record of every
  snapshot: ID, original path, timestamp, snapshot path.

  EDITING OPERATIONS
  ──────────────────
  • Line Editor      — view, replace, insert, delete lines; then save
  • Quick key=value  — set or update a key in a config file
  • Toggle comment   — prefix/remove # on any line
  • Search & replace — sed-powered regex find & replace

  UNDO
  ────
  Ctrl+Z (SIGTSTP) at any prompt triggers undo for the current file.
  Option [3] in the main menu undoes the last snapshot globally.

  SUDO
  ────
  If a file requires elevated privileges, the tool will attempt
  to use sudo automatically.

HELP
                printf '\n'
                status_bar "  Press Enter to return..."
                tput cnorm 2>/dev/null || true; read -r; tput civis 2>/dev/null || true
                ;;
            q|0|exit|quit)
                clear_screen
                printf '\n  %s👋  Goodbye! Snapshots preserved in %s%s\n\n' \
                    "${C_GRN}${C_BOLD}" "$SNAP_DIR" "${C_RESET}"
                exit 0
                ;;
            '') ;;
            *) ;;
        esac
    done
}

# ── Entry point ───────────────────────────────────────────────────────────────
main() {
    init
    main_menu
}

main "$@"