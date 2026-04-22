#!/bin/sh
# noteb - Single-script note organizer and library for Alpine Linux
# No network required. Self-contained. Busybox-compatible.
# Usage: ./noteb.sh <command> [args...]   or   ./noteb.sh menu

set -e

VERSION="1.0.0"
APP_NAME="noteb"

# --- Directories ---
CONFIG_DIR="${HOME}/.config/${APP_NAME}"
DATA_DIR="${HOME}/.local/share/${APP_NAME}"
CONFIG_FILE="${CONFIG_DIR}/config"
TEMPLATE_DIR="${DATA_DIR}/templates"
NOTES_DIR="${DATA_DIR}/notes"

# --- Defaults ---
EDITOR="${EDITOR:-vi}"
PAGER="${PAGER:-cat}"
ID_LENGTH=8
DATE_FORMAT="%Y-%m-%d %H:%M"
COLOR_ENABLED="yes"

# --- Colors ---
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_MAGENTA='\033[0;35m'
C_CYAN='\033[0;36m'
C_BOLD='\033[1m'
C_DIM='\033[2m'
C_RESET='\033[0m'

# --- Utility ---
msg()   { printf "${C_GREEN}[+] %s${C_RESET}\n" "$*"; }
warn()  { printf "${C_YELLOW}[!] %s${C_RESET}\n" "$*"; }
err()   { printf "${C_RED}[x] %s${C_RESET}\n" "$*" >&2; }
info()  { printf "${C_BLUE}[*] %s${C_RESET}\n" "$*"; }
dim()   { printf "${C_DIM}%s${C_RESET}\n" "$*"; }
die()   { err "$*"; exit 1; }

ensure_dirs() {
    mkdir -p "$CONFIG_DIR" "$DATA_DIR" "$TEMPLATE_DIR" "$NOTES_DIR"
}

generate_id() {
    tr -dc 'a-z0-9' < /dev/urandom | head -c "$ID_LENGTH"
}

get_date() {
    date "+$DATE_FORMAT"
}

clear_screen() {
    if command -v clear >/dev/null 2>&1; then
        clear
    else
        printf '\033[2J\033[H'
    fi
}

# --- Config ---

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck source=/dev/null
        . "$CONFIG_FILE"
    fi
    if [ "$COLOR_ENABLED" = "no" ]; then
        C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_MAGENTA=''; C_CYAN=''
        C_BOLD=''; C_DIM=''; C_RESET=''
    fi
}

save_config() {
    ensure_dirs
    cat > "$CONFIG_FILE" <<EOF
# noteb configuration
EDITOR='$EDITOR'
PAGER='$PAGER'
NOTES_DIR='$NOTES_DIR'
ID_LENGTH='$ID_LENGTH'
DATE_FORMAT='$DATE_FORMAT'
COLOR_ENABLED='$COLOR_ENABLED'
EOF
    msg "Config saved to $CONFIG_FILE"
}

init_config() {
    ensure_dirs
    [ -f "$CONFIG_FILE" ] || save_config
}

# --- Note metadata ---

note_get_field() {
    sed -n '/^---$/,/^---$/p' "$1" | grep "^$2:" | head -n 1 | cut -d':' -f2- | sed 's/^ *//'
}

note_set_field() {
    _tmp=$(mktemp)
    awk -v field="$2" -v value="$3" '
    BEGIN { pat = "^" field ":" }
    $0 ~ pat { print field ": " value; next }
    { print }
    ' "$1" > "$_tmp"
    mv "$_tmp" "$1"
}

note_content() {
    awk 'BEGIN{p=0} /^---$/ && p<2 {p++; next} p>=2 {print}' "$1" | sed '1{/^$/d}'
}

note_path_by_id() {
    find "$NOTES_DIR" -maxdepth 1 -type f -name '*.md' | while read -r f; do
        if [ "$(note_get_field "$f" "id")" = "$1" ]; then
            printf '%s\n' "$f"
            break
        fi
    done
}

note_path_by_title() {
    find "$NOTES_DIR" -maxdepth 1 -type f -name '*.md' | while read -r f; do
        if [ "$(note_get_field "$f" "title")" = "$1" ]; then
            printf '%s\n' "$f"
            break
        fi
    done
}

note_paths_by_title() {
    find "$NOTES_DIR" -maxdepth 1 -type f -name '*.md' | while read -r f; do
        if note_get_field "$f" "title" | grep -qi "$1"; then
            printf '%s\n' "$f"
        fi
    done
}

resolve_note() {
    _f=$(note_path_by_id "$1")
    if [ -n "$_f" ]; then
        printf '%s' "$_f"
        return
    fi
    _f=$(note_path_by_title "$1")
    if [ -n "$_f" ]; then
        printf '%s' "$_f"
        return
    fi
    _tmp=$(mktemp)
    note_paths_by_title "$1" > "$_tmp"
    _count=$(grep -c . < "$_tmp" || echo 0)
    if [ "$_count" -eq 0 ]; then
        rm -f "$_tmp"
        return
    elif [ "$_count" -eq 1 ]; then
        head -n 1 "$_tmp"
        rm -f "$_tmp"
        return
    fi
    _n=0
    while read -r f; do
        _n=$((_n + 1))
        _id=$(note_get_field "$f" "id")
        _title=$(note_get_field "$f" "title")
        printf '  [%s] %s (%s)\n' "$_n" "$_title" "$_id"
    done < "$_tmp"
    printf '\n  %sChoice:%s ' "$C_BOLD" "$C_RESET"
    read -r _sel
    if printf '%s' "$_sel" | grep -q '^[0-9]\+$'; then
        sed -n "${_sel}p" "$_tmp"
    else
        rm -f "$_tmp"
        die "Invalid selection"
    fi
    rm -f "$_tmp"
}

backup_note() {
    _file="$1"
    _max=5
    _i=$_max
    while [ "$_i" -gt 1 ]; do
        _prev=$((_i - 1))
        [ -f "${_file}.bak.${_prev}" ] && mv "${_file}.bak.${_prev}" "${_file}.bak.${_i}"
        _i=$((_i - 1))
    done
    [ -f "${_file}.bak" ] && mv "${_file}.bak" "${_file}.bak.1"
    cp "$_file" "${_file}.bak"
}

# --- Core commands ---

cmd_add() {
    _title=""
    _category=""
    _tags=""
    _template=""

    while [ $# -gt 0 ]; do
        case "$1" in
            -t|--title)
                [ -z "${2:-}" ] && die "Missing argument for $1"
                _title="$2"; shift; shift ;;
            -c|--category)
                [ -z "${2:-}" ] && die "Missing argument for $1"
                _category="$2"; shift; shift ;;
            -g|--tags)
                [ -z "${2:-}" ] && die "Missing argument for $1"
                _tags="$2"; shift; shift ;;
            --template)
                [ -z "${2:-}" ] && die "Missing argument for $1"
                _template="$2"; shift; shift ;;
            *) die "Unknown option: $1" ;;
        esac
    done

    if [ -z "$_title" ]; then
        printf 'Title: '
        read -r _title
    fi
    [ -z "$_title" ] && die "Title cannot be empty"

    if [ -z "$_category" ]; then
        printf 'Category [general]: '
        read -r _category
        [ -z "$_category" ] && _category="general"
    fi

    if [ -z "$_tags" ]; then
        printf 'Tags (comma separated): '
        read -r _tags
    fi

    _id=$(generate_id)
    _created=$(get_date)
    _file="${NOTES_DIR}/${_id}.md"
    ensure_dirs

    _content=""
    if [ -n "$_template" ]; then
        _tfile="${TEMPLATE_DIR}/${_template}.md"
        if [ -f "$_tfile" ]; then
            _content=$(cat "$_tfile")
        else
            warn "Template '$_template' not found"
        fi
    fi

    cat > "$_file" <<EOF
---
id: ${_id}
title: ${_title}
category: ${_category}
tags: ${_tags}
created: ${_created}
modified: ${_created}
---

${_content}
EOF

    msg "Note created: $_id"
}

cmd_edit() {
    [ -z "${1:-}" ] && die "Usage: edit <id|title>"
    _f=$(resolve_note "$1")
    [ -z "$_f" ] && die "Note not found: $1"
    backup_note "$_f"
    "$EDITOR" "$_f"
    note_set_field "$_f" "modified" "$(get_date)"
    msg "Note updated: $1"
}

cmd_append() {
    [ -z "${1:-}" ] && die "Usage: append <id|title> [text]"
    _f=$(resolve_note "$1")
    [ -z "$_f" ] && die "Note not found: $1"
    shift
    _text="$*"
    backup_note "$_f"
    if [ -z "$_text" ]; then
        printf '%s' "Text to append (Ctrl+D to finish): "
        _text=$(cat)
    fi
    printf '\n%s\n' "$_text" >> "$_f"
    note_set_field "$_f" "modified" "$(get_date)"
    msg "Appended to note"
}

cmd_show() {
    [ -z "${1:-}" ] && die "Usage: show <id|title>"
    _f=$(resolve_note "$1")
    [ -z "$_f" ] && die "Note not found: $1"

    _title=$(note_get_field "$_f" "title")
    _cat=$(note_get_field "$_f" "category")
    _tags=$(note_get_field "$_f" "tags")
    _created=$(note_get_field "$_f" "created")
    _modified=$(note_get_field "$_f" "modified")

    printf "${C_BOLD}${C_BLUE}%s${C_RESET}\n" "$_title"
    printf "${C_DIM}ID:${C_RESET} %s  ${C_DIM}Category:${C_RESET} %s  ${C_DIM}Tags:${C_RESET} %s\n" "$1" "$_cat" "$_tags"
    printf "${C_DIM}Created:${C_RESET} %s  ${C_DIM}Modified:${C_RESET} %s\n\n" "$_created" "$_modified"
    note_content "$_f"
}

cmd_list() {
    _category=""
    _tag=""
    _filter=""

    while [ $# -gt 0 ]; do
        case "$1" in
            -c|--category)
                [ -z "${2:-}" ] && die "Missing argument for $1"
                _category="$2"; shift; shift ;;
            -t|--tag)
                [ -z "${2:-}" ] && die "Missing argument for $1"
                _tag="$2"; shift; shift ;;
            *) _filter="$1"; shift ;;
        esac
    done

    _tmpf=$(mktemp)
    find "$NOTES_DIR" -maxdepth 1 -type f -name '*.md' | sort > "$_tmpf"
    [ -s "$_tmpf" ] || { rm -f "$_tmpf"; dim "No notes found."; return; }

    while read -r f; do
        _id=$(note_get_field "$f" "id")
        _title=$(note_get_field "$f" "title")
        _cat=$(note_get_field "$f" "category")
        _tags=$(note_get_field "$f" "tags")
        _modified=$(note_get_field "$f" "modified")

        [ -n "$_category" ] && [ "$_cat" != "$_category" ] && continue
        [ -n "$_tag" ] && ! printf '%s' "$_tags" | grep -qw "$_tag" && continue
        [ -n "$_filter" ] && ! printf '%s' "$_title" | grep -qi "$_filter" && continue

        printf "${C_CYAN}[%s]${C_RESET} ${C_BOLD}%s${C_RESET} ${C_DIM}(%s)${C_RESET} [%s] {tags: %s}\n" \
            "$_id" "$_title" "$_modified" "$_cat" "$_tags"
    done < "$_tmpf"
    rm -f "$_tmpf"
}

cmd_delete() {
    [ -z "${1:-}" ] && die "Usage: delete <id|title>"
    _f=$(resolve_note "$1")
    [ -z "$_f" ] && die "Note not found: $1"
    _title=$(note_get_field "$_f" "title")
    printf "Delete '${C_BOLD}%s${C_RESET}'? [y/N]: " "$_title"
    read -r _confirm
    case "$_confirm" in
        y|Y)
            rm -f "$_f" "${_f}.bak"
            _i=1
            while [ "$_i" -le 5 ]; do
                rm -f "${_f}.bak.${_i}"
                _i=$((_i + 1))
            done
            msg "Deleted: $1"
            ;;
        *) warn "Cancelled" ;;
    esac
}

cmd_search() {
    [ -z "${1:-}" ] && die "Usage: search <term>"
    _tmp=$(mktemp)
    find "$NOTES_DIR" -maxdepth 1 -type f -name '*.md' | while read -r f; do
        if grep -qi "$1" "$f"; then
            _id=$(note_get_field "$f" "id")
            _title=$(note_get_field "$f" "title")
            _line=$(grep -ni "$1" "$f" | head -n 1 | cut -d':' -f2-)
            printf "${C_CYAN}[%s]${C_RESET} ${C_BOLD}%s${C_RESET}\n" "$_id" "$_title"
            printf "  > %s\n" "$_line"
        fi
    done > "$_tmp"
    if [ ! -s "$_tmp" ]; then
        dim "No results."
    else
        cat "$_tmp"
    fi
    rm -f "$_tmp"
}

cmd_tags() {
    _tmp=$(mktemp)
    find "$NOTES_DIR" -maxdepth 1 -type f -name '*.md' | while read -r f; do
        note_get_field "$f" "tags"
    done | tr ',' '\n' | sed 's/^ *//;s/ *$//' | grep -v '^$' | sort | uniq -c | sort -rn > "$_tmp"
    [ -s "$_tmp" ] || { rm -f "$_tmp"; dim "No tags found."; return; }
    while read -r line; do
        _num=$(printf '%s' "$line" | awk '{print $1}')
        _tag=$(printf '%s' "$line" | cut -d' ' -f2-)
        printf "${C_BOLD}%s${C_RESET} ${C_DIM}(%s notes)${C_RESET}\n" "$_tag" "$_num"
    done < "$_tmp"
    rm -f "$_tmp"
}

cmd_categories() {
    _tmp=$(mktemp)
    find "$NOTES_DIR" -maxdepth 1 -type f -name '*.md' | while read -r f; do
        note_get_field "$f" "category"
    done | sort | uniq -c | sort -rn > "$_tmp"
    [ -s "$_tmp" ] || { rm -f "$_tmp"; dim "No categories found."; return; }
    while read -r line; do
        _num=$(printf '%s' "$line" | awk '{print $1}')
        _cat=$(printf '%s' "$line" | cut -d' ' -f2-)
        printf "${C_BOLD}%s${C_RESET} ${C_DIM}(%s notes)${C_RESET}\n" "$_cat" "$_num"
    done < "$_tmp"
    rm -f "$_tmp"
}

cmd_links() {
    [ -z "${1:-}" ] && die "Usage: links <id|title>"
    _f=$(resolve_note "$1")
    [ -z "$_f" ] && die "Note not found: $1"
    _title=$(note_get_field "$_f" "title")
    printf '%s\n' "Links in: $_title"
    note_content "$_f" | grep -o '\[\[[^]]*\]\]' | sed 's/^\[\[//;s/\]\]$//' | while read -r link; do
        _target=$(resolve_note "$link")
        if [ -n "$_target" ]; then
            _tid=$(note_get_field "$_target" "id")
            _ttitle=$(note_get_field "$_target" "title")
            printf '  -> %s (%s)\n' "$_ttitle" "$_tid"
        else
            printf '  -> %s (broken link)\n' "$link"
        fi
    done
}

cmd_backlinks() {
    [ -z "${1:-}" ] && die "Usage: backlinks <id|title>"
    _f=$(resolve_note "$1")
    [ -z "$_f" ] && die "Note not found: $1"
    _id=$(note_get_field "$_f" "id")
    _title=$(note_get_field "$_f" "title")
    printf '%s\n' "Notes linking to: $_title"
    find "$NOTES_DIR" -maxdepth 1 -type f -name '*.md' | while read -r n; do
        [ "$n" = "$_f" ] && continue
        if note_content "$n" | grep -q "\[\[$_id\]\]"; then
            _sid=$(note_get_field "$n" "id")
            _stitle=$(note_get_field "$n" "title")
            printf '  <- %s (%s)\n' "$_stitle" "$_sid"
        fi
    done
}

cmd_revert() {
    [ -z "${1:-}" ] && die "Usage: revert <id|title>"
    _f=$(resolve_note "$1")
    [ -z "$_f" ] && die "Note not found: $1"
    _title=$(note_get_field "$_f" "title")
    printf '%s\n' "Available backups for: $_title"
    if [ -f "${_f}.bak" ]; then
        printf '  [1] %s (latest)\n' "$(note_get_field "${_f}.bak" "modified")"
    fi
    _i=1
    while [ "$_i" -le 5 ]; do
        if [ -f "${_f}.bak.${_i}" ]; then
            printf '  [%s] %s (snapshot %s)\n' "$((_i + 1))" "$(note_get_field "${_f}.bak.${_i}" "modified")" "$_i"
        fi
        _i=$((_i + 1))
    done
    printf '\n  %sRestore [0 to cancel]:%s ' "$C_BOLD" "$C_RESET"
    read -r _sel
    [ "$_sel" = "0" ] && { warn "Cancelled"; return; }
    if [ "$_sel" = "1" ] && [ -f "${_f}.bak" ]; then
        cp "${_f}.bak" "$_f"
    elif [ -f "${_f}.bak.$((_sel - 1))" ]; then
        cp "${_f}.bak.$((_sel - 1))" "$_f"
    else
        die "Invalid selection"
    fi
    note_set_field "$_f" "modified" "$(get_date)"
    msg "Restored from backup"
}

cmd_recent() {
    _n="${1:-10}"
    _tmp=$(mktemp)
    find "$NOTES_DIR" -maxdepth 1 -type f -name '*.md' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -n "$_n" | cut -d' ' -f2- > "$_tmp" 2>/dev/null
    # Fallback for busybox find without -printf
    if [ ! -s "$_tmp" ]; then
        find "$NOTES_DIR" -maxdepth 1 -type f -name '*.md' | while read -r f; do
            _mod=$(stat -c '%Y' "$f" 2>/dev/null || stat -f '%m' "$f" 2>/dev/null || echo '0')
            printf '%s %s\n' "$_mod" "$f"
        done | sort -rn | head -n "$_n" | cut -d' ' -f2- > "$_tmp"
    fi
    [ -s "$_tmp" ] || { rm -f "$_tmp"; dim "No notes found."; return; }
    while read -r f; do
        _id=$(note_get_field "$f" "id")
        _title=$(note_get_field "$f" "title")
        _modified=$(note_get_field "$f" "modified")
        printf "${C_CYAN}[%s]${C_RESET} ${C_BOLD}%s${C_RESET} ${C_DIM}(%s)${C_RESET}\n" "$_id" "$_title" "$_modified"
    done < "$_tmp"
    rm -f "$_tmp"
}

cmd_stats() {
    _total=$(find "$NOTES_DIR" -maxdepth 1 -type f -name '*.md' | wc -l)
    _categories=$(cmd_categories 2>/dev/null | wc -l)
    _tags=$(cmd_tags 2>/dev/null | wc -l)
    printf "${C_BOLD}Statistics${C_RESET}\n"
    printf "  Total notes:     %s\n" "$_total"
    printf "  Categories:      %s\n" "$_categories"
    printf "  Unique tags:     %s\n" "$_tags"
}

cmd_export() {
    _dest="${1:-noteb-export-$(date +%Y%m%d-%H%M%S).tar.gz}"
    tar -czf "$_dest" -C "$DATA_DIR" notes templates 2>/dev/null || die "Export failed"
    msg "Exported to $_dest"
}

cmd_import() {
    [ -z "${1:-}" ] && die "Usage: import <tar.gz|directory>"
    ensure_dirs
    if [ -f "$1" ]; then
        tar -xzf "$1" -C "$DATA_DIR" || die "Import failed"
    elif [ -d "$1" ]; then
        [ -d "$1/notes" ] && cp -r "$1/notes/"* "$NOTES_DIR/" 2>/dev/null || true
        [ -d "$1/templates" ] && cp -r "$1/templates/"* "$TEMPLATE_DIR/" 2>/dev/null || true
    else
        die "Unknown source: $1"
    fi
    msg "Imported from $1"
}

cmd_config() {
    if [ $# -eq 0 ]; then
        cat "$CONFIG_FILE"
        return
    fi
    case "$1" in
        --edit|-e) "$EDITOR" "$CONFIG_FILE" ;;
        --reset) save_config ;;
        *) die "Usage: config [--edit|--reset]" ;;
    esac
}

cmd_template() {
    case "${1:-}" in
        list|ls)
            for f in "$TEMPLATE_DIR"/*.md; do
                [ -f "$f" ] || continue
                basename "$f" .md
            done
            ;;
        add|new)
            [ -z "${2:-}" ] && die "Usage: template add <name>"
            ensure_dirs
            "$EDITOR" "${TEMPLATE_DIR}/${2}.md"
            msg "Template created: $2"
            ;;
        edit)
            [ -z "${2:-}" ] && die "Usage: template edit <name>"
            [ -f "${TEMPLATE_DIR}/${2}.md" ] || die "Template not found: $2"
            "$EDITOR" "${TEMPLATE_DIR}/${2}.md"
            ;;
        delete|rm|del)
            [ -z "${2:-}" ] && die "Usage: template delete <name>"
            rm -f "${TEMPLATE_DIR}/${2}.md"
            msg "Template deleted: $2"
            ;;
        *) die "Usage: template <list|add|edit|delete> [name]" ;;
    esac
}

# --- Interactive Menu ---

menu_header() {
    clear_screen
    printf "${C_BOLD}${C_BLUE}"
    printf '%s\n' '  _   _       _   _      '
    printf '%s\n' ' | \ | | ___ | |_| |__   '
    printf '%s\n' ' |  \| |/ _ \| __| |_ \  '
    printf '%s\n' ' | |\  |  __/| |_| | | | '
    printf '%s\n' ' |_| \_|\___| \__|_| |_| '
    printf "${C_RESET}\n"
    printf "  ${C_DIM}v%s - Note Organizer & Library${C_RESET}\n" "$VERSION"
    printf "\n"
}

menu_stats() {
    _total=$(find "$NOTES_DIR" -maxdepth 1 -type f -name '*.md' 2>/dev/null | wc -l)
    printf "  ${C_DIM}Notes:${C_RESET} %s\n" "$_total"
    printf "\n"
}

menu_prompt() {
    printf "  ${C_BOLD}[1]${C_RESET} Add note        ${C_BOLD}[7]${C_RESET}  List tags\n"
    printf "  ${C_BOLD}[2]${C_RESET} Edit note       ${C_BOLD}[8]${C_RESET}  List categories\n"
    printf "  ${C_BOLD}[3]${C_RESET} Show note       ${C_BOLD}[9]${C_RESET}  Templates\n"
    printf "  ${C_BOLD}[4]${C_RESET} List notes      ${C_BOLD}[10]${C_RESET} Export\n"
    printf "  ${C_BOLD}[5]${C_RESET} Search notes    ${C_BOLD}[11]${C_RESET} Import\n"
    printf "  ${C_BOLD}[6]${C_RESET} Delete note     ${C_BOLD}[12]${C_RESET} Config\n"
    printf "  ${C_BOLD}[a]${C_RESET} Append          ${C_BOLD}[l]${C_RESET}  Links\n"
    printf "  ${C_BOLD}[b]${C_RESET} Backlinks       ${C_BOLD}[v]${C_RESET}  Revert\n"
    printf "  ${C_BOLD}[r]${C_RESET} Recent          ${C_BOLD}[s]${C_RESET}  Stats\n"
    printf "  ${C_BOLD}[0]${C_RESET} Exit\n"
    printf "\n"
    printf "  ${C_BOLD}Choice:${C_RESET} "
}

menu_pick_note() {
    _tmp=$(mktemp)
    find "$NOTES_DIR" -maxdepth 1 -type f -name '*.md' | sort > "$_tmp"
    if [ ! -s "$_tmp" ]; then
        rm -f "$_tmp"
        dim "No notes available."
        return
    fi
    _n=0
    while read -r f; do
        _n=$((_n + 1))
        _id=$(note_get_field "$f" "id")
        _title=$(note_get_field "$f" "title")
        printf "  [%s] %s (%s)\n" "$_n" "$_title" "$_id"
    done < "$_tmp"
    printf "\n  ${C_BOLD}Select number (or type ID/title):${C_RESET} "
    read -r _sel
    if printf '%s' "$_sel" | grep -q '^[0-9]\+$'; then
        _file=$(sed -n "${_sel}p" "$_tmp")
    else
        _file=$(resolve_note "$_sel")
    fi
    rm -f "$_tmp"
    printf '%s' "$_file"
}

menu_continue() {
    printf "\n  ${C_DIM}Press Enter to continue...${C_RESET}"
    read -r _dummy
}

interactive() {
    while true; do
        menu_header
        menu_stats
        menu_prompt
        read -r choice
        case "$choice" in
            1)
                printf '\n'
                cmd_add
                menu_continue
                ;;
            2)
                printf '\n'
                _f=$(menu_pick_note)
                if [ -n "$_f" ] && [ -f "$_f" ]; then
                    _id=$(note_get_field "$_f" "id")
                    cmd_edit "$_id"
                else
                    err "Invalid selection"
                fi
                menu_continue
                ;;
            3)
                printf '\n'
                _f=$(menu_pick_note)
                if [ -n "$_f" ] && [ -f "$_f" ]; then
                    _id=$(note_get_field "$_f" "id")
                    cmd_show "$_id"
                else
                    err "Invalid selection"
                fi
                menu_continue
                ;;
            4)
                printf '\n'
                cmd_list
                menu_continue
                ;;
            5)
                printf '\n  Search term: '
                read -r term
                [ -n "$term" ] && cmd_search "$term"
                menu_continue
                ;;
            6)
                printf '\n'
                _f=$(menu_pick_note)
                if [ -n "$_f" ] && [ -f "$_f" ]; then
                    _id=$(note_get_field "$_f" "id")
                    cmd_delete "$_id"
                else
                    err "Invalid selection"
                fi
                menu_continue
                ;;
            7)
                printf '\n'
                cmd_tags
                menu_continue
                ;;
            8)
                printf '\n'
                cmd_categories
                menu_continue
                ;;
            9)
                printf '\n  Subcommand (list|add|edit|delete) [name]: '
                read -r tcmd tname
                cmd_template "$tcmd" "$tname"
                menu_continue
                ;;
            10)
                printf '\n  Destination [noteb-export.tar.gz]: '
                read -r dest
                [ -z "$dest" ] && dest="noteb-export.tar.gz"
                cmd_export "$dest"
                menu_continue
                ;;
            11)
                printf '\n  Source (tar.gz or dir): '
                read -r src
                [ -n "$src" ] && cmd_import "$src"
                menu_continue
                ;;
            12)
                printf '\n'
                cmd_config
                menu_continue
                ;;
            r|R)
                printf '\n  How many? [10]: '
                read -r n
                [ -z "$n" ] && n="10"
                cmd_recent "$n"
                menu_continue
                ;;
            a|A)
                printf '\n'
                _f=$(menu_pick_note)
                if [ -n "$_f" ] && [ -f "$_f" ]; then
                    _id=$(note_get_field "$_f" "id")
                    printf '  Text to append: '
                    read -r _text
                    [ -n "$_text" ] && cmd_append "$_id" "$_text"
                else
                    err "Invalid selection"
                fi
                menu_continue
                ;;
            l|L)
                printf '\n'
                _f=$(menu_pick_note)
                if [ -n "$_f" ] && [ -f "$_f" ]; then
                    _id=$(note_get_field "$_f" "id")
                    cmd_links "$_id"
                else
                    err "Invalid selection"
                fi
                menu_continue
                ;;
            b|B)
                printf '\n'
                _f=$(menu_pick_note)
                if [ -n "$_f" ] && [ -f "$_f" ]; then
                    _id=$(note_get_field "$_f" "id")
                    cmd_backlinks "$_id"
                else
                    err "Invalid selection"
                fi
                menu_continue
                ;;
            v|V)
                printf '\n'
                _f=$(menu_pick_note)
                if [ -n "$_f" ] && [ -f "$_f" ]; then
                    _id=$(note_get_field "$_f" "id")
                    cmd_revert "$_id"
                else
                    err "Invalid selection"
                fi
                menu_continue
                ;;
            s|S)
                printf '\n'
                cmd_stats
                menu_continue
                ;;
            0|q|Q)
                printf "\n  ${C_GREEN}Goodbye.${C_RESET}\n\n"
                exit 0
                ;;
            *)
                err "Invalid choice: $choice"
                sleep 1
                ;;
        esac
    done
}

# --- Help & Main ---

usage() {
    printf "Usage: %s <command> [args...]\n\n" "$0"
    printf "Commands:\n"
    printf "  add [-t title] [-c category] [-g tags] [--template name]  Add a new note\n"
    printf "  edit <id|title>                                            Edit a note\n"
    printf "  show <id|title>                                            Show a note\n"
    printf "  list [-c category] [-t tag] [filter]                       List notes\n"
    printf "  search <term>                                              Search notes\n"
    printf "  delete <id|title>                                          Delete a note\n"
    printf "  tags                                                       List all tags\n"
    printf "  categories                                                 List all categories\n"
    printf "  recent [n]                                                 Show n recent notes (default 10)\n"
    printf "  append <id|title> [text]                                   Append text to a note\n"
    printf "  links <id|title>                                           Show outgoing note links\n"
    printf "  backlinks <id|title>                                       Show notes linking here\n"
    printf "  revert <id|title>                                          Restore from a backup snapshot\n"
    printf "  stats                                                      Show statistics\n"
    printf "  template <list|add|edit|delete> [name]                       Manage templates\n"
    printf "  export [file.tar.gz]                                       Export notes\n"
    printf "  import <tar.gz|dir>                                        Import notes\n"
    printf "  config [--edit|--reset]                                    Show/edit config\n"
    printf "  menu                                                       Interactive menu\n"
    printf "\n"
    printf "Environment: EDITOR, PAGER\n"
    printf "Config: %s\n" "$CONFIG_FILE"
    printf "Notes:  %s\n" "$NOTES_DIR"
    exit 1
}

main() {
    init_config
    load_config

    [ $# -eq 0 ] && usage

    cmd="$1"
    shift

    case "$cmd" in
        add|new) cmd_add "$@" ;;
        edit) cmd_edit "$@" ;;
        show|cat|view) cmd_show "$@" ;;
        list|ls) cmd_list "$@" ;;
        search|find) cmd_search "$@" ;;
        delete|rm|del) cmd_delete "$@" ;;
        tags|tag) cmd_tags ;;
        categories|cats) cmd_categories ;;
        recent) cmd_recent "$@" ;;
        append|a) cmd_append "$@" ;;
        links|lnk) cmd_links "$@" ;;
        backlinks|bl) cmd_backlinks "$@" ;;
        revert|rev) cmd_revert "$@" ;;
        stats) cmd_stats ;;
        template|tpl) cmd_template "$@" ;;
        export|exp) cmd_export "$@" ;;
        import|imp) cmd_import "$@" ;;
        config|cfg) cmd_config "$@" ;;
        menu|interactive|ui) interactive ;;
        help|--help|-h) usage ;;
        *) err "Unknown command: $cmd"; usage ;;
    esac
}

main "$@"
