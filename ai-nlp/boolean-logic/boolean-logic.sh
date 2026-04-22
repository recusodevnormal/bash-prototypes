#!/usr/bin/env bash
# =============================================================================
#  BOOLEAN LOGIC EXPERT SYSTEM
# =============================================================================
#  A standalone, offline diagnostic engine in the style of 1980s rule-based
#  AI.  It embeds a flat-file Knowledge Base (KB) of If-Then rules, asks
#  the user a series of Yes/No questions, and traverses a binary decision
#  tree until a deterministic conclusion is reached.
#
#  DEPENDENCIES: bash (>=4), sed, cut, tr, printf, cat, read
#                All are standard GNU/Unix utilities.  No network access.
#
#  DESIGN NOTES:
#    - The KB is a flat-file section embedded at the tail of this script.
#    - Each rule has an ID, a type (Q=Question, C=Conclusion), text, and
#      two branches (YES_TARGET, NO_TARGET) that point to the next rule.
#    - The inference engine performs sequential forward chaining: it loads
#      the KB into associative arrays, starts at Rule 1, and follows the
#      path dictated by user answers until a Conclusion node is hit.
#
#  USAGE:  chmod +x expert.sh && ./expert.sh
# =============================================================================

set -euo pipefail

# --- Configuration -----------------------------------------------------------
readonly KB_MARKER='__KB_BEGIN__'   # Sentinel that marks the start of KB data
readonly KB_DELIM='|'               # Field separator (must not appear in text)

# --- Terminal Capability Detection -------------------------------------------
# We probe for color support so the UI degrades gracefully on dumb terminals
# or when output is piped to a file.
if command -v tput >/dev/null 2>&1 && [ -t 1 ] && [ -t 0 ]; then
    BOLD=$(tput bold)
    UL=$(tput smul)          # underline
    RESET=$(tput sgr0)
    CYAN=$(tput setaf 6)
    YELLOW=$(tput setaf 3)
    GREEN=$(tput setaf 2)
    RED=$(tput setaf 1)
else
    BOLD='' UL='' RESET='' CYAN='' YELLOW='' GREEN='' RED=''
fi
readonly BOLD UL RESET CYAN YELLOW GREEN RED

# --- UI Primitives -----------------------------------------------------------
# Draw a horizontal rule across the terminal width (default 80 columns).
hr() {
    local width=${COLUMNS:-80}
    printf '%*s\n' "$width" '' | tr ' ' '-'
}

# Clear screen using ANSI escapes (works even when the 'clear' binary is absent)
# and paint the application banner.
banner() {
    printf '\033[2J\033[H'
    hr
    printf '%s%s  BOOLEAN LOGIC EXPERT SYSTEM v1.0  %s\n' "$BOLD" "$CYAN" "$RESET"
    printf '  %sRule-Based Diagnostic Engine // 1985 AI Lab%s\n' "$YELLOW" "$RESET"
    hr
    echo
}

# Prompt the user for a strict boolean answer.
# Accepts: y, n, yes, no (case-insensitive).  Re-prompts on invalid input.
# Sets global variable ANSWER to 'y' or 'n'.
prompt_bool() {
    local query="$1"
    local input=''

    while :; do
        printf '%s%s%s\n' "$UL" "$query" "$RESET"
        printf '  %s[Y/n]%s ' "$BOLD" "$RESET"
        IFS= read -r input

        # Normalise: lower-case, strip leading/trailing whitespace
        input=$(printf '%s' "$input" \
                | tr '[:upper:]' '[:lower:]' \
                | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        case "$input" in
            y|yes)  ANSWER='y'; echo; return ;;
            n|no)   ANSWER='n'; echo; return ;;
            *)      printf '  %s>> Invalid input.  Please answer Y or N.%s\n\n' \
                        "$RED" "$RESET" ;;
        esac
    done
}

# Render the final conclusion with a little 1980s flair.
conclusion() {
    local text="$1"
    echo
    hr
    printf '%s%s  DETERMINISTIC CONCLUSION  %s\n' "$BOLD" "$GREEN" "$RESET"
    hr
    echo
    printf '%s%s%s\n\n' "$BOLD" "$text" "$RESET"
    printf '%sCertainty Factor: %s1.0%s (Definite, rule-based)\n' \
        "$CYAN" "$BOLD" "$RESET"
    printf '%sInference chain: Sequential forward chaining through If-Then rules.%s\n\n' \
        "$CYAN" "$RESET"
}

# --- Knowledge Base Loader ---------------------------------------------------
# Reads the embedded flat-file KB (found after KB_MARKER in this script) and
# populates four associative arrays indexed by Rule ID.
declare -A R_TYPE    # 'Q' = Question, 'C' = Conclusion
declare -A R_TEXT    # Prompt text or conclusion text
declare -A R_YES     # Target Rule ID when answer is Yes
declare -A R_NO      # Target Rule ID when answer is No

load_kb() {
    local parsing=0
    local line=''
    local count=0

    # We read from $0 (the script itself) so the file is entirely self-contained.
    while IFS= read -r line || [ -n "$line" ]; do
        [ "$line" = "$KB_MARKER" ] && { parsing=1; continue; }
        [ "$parsing" -eq 0 ] && continue

        # Skip blank lines and comment lines
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue

        # Parse the five pipe-delimited fields.
        # Because we author the KB, we guarantee the delimiter never appears
        # inside the text fields.
        local id qtype text yes no
        id=$(printf '%s' "$line" | cut -d "$KB_DELIM" -f1  | sed 's/[[:space:]]//g')
        qtype=$(printf '%s' "$line" | cut -d "$KB_DELIM" -f2 | sed 's/[[:space:]]//g')
        text=$(printf '%s' "$line" | cut -d "$KB_DELIM" -f3  | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        yes=$(printf '%s' "$line" | cut -d "$KB_DELIM" -f4   | sed 's/[[:space:]]//g')
        no=$(printf '%s' "$line" | cut -d "$KB_DELIM" -f5    | sed 's/[[:space:]]//g')

        R_TYPE["$id"]="$qtype"
        R_TEXT["$id"]="$text"
        R_YES["$id"]="$yes"
        R_NO["$id"]="$no"
        ((count++))
    done < "$0"

    printf '%sKnowledge Base loaded:%s %d rules indexed.\n\n' "$CYAN" "$RESET" "$count"
}

# --- Inference Engine --------------------------------------------------------
# Classic forward-chaining evaluator.
# Starts at Rule 1 and walks the binary tree until a Conclusion (type 'C')
# is encountered.
infer() {
    local node="1"      # Entry point rule ID
    local depth=1       # Human-readable step counter

    while :; do
        # Defensive: ensure the target rule actually exists in the KB
        if [ -z "${R_TYPE[$node]+x}" ]; then
            printf '%sError: Undefined rule ID "%s".%s\n' "$RED" "$node" "$RESET"
            exit 1
        fi

        local qt="${R_TYPE[$node]}"
        local txt="${R_TEXT[$node]}"

        # -----------------------------------------------------------------
        # If this node is a Conclusion, emit it and halt.
        # -----------------------------------------------------------------
        if [ "$qt" = "C" ]; then
            conclusion "$txt"
            return
        fi

        # -----------------------------------------------------------------
        # Otherwise it is a Question: display it and branch.
        # -----------------------------------------------------------------
        printf '%sQuery %02d:%s %s\n\n' "$BOLD" "$depth" "$RESET" "$txt"
        prompt_bool "Your diagnosis input:"

        if [ "$ANSWER" = "y" ]; then
            node="${R_YES[$node]}"
        else
            node="${R_NO[$node]}"
        fi

        # Defensive: catch malformed KBs with missing branch targets
        if [ -z "$node" ] || [ "$node" = "-" ]; then
            printf '%sError: Null branch from rule. KB may be incomplete.%s\n' \
                "$RED" "$RESET"
            exit 1
        fi

        echo
        ((depth++))
    done
}

# --- Main --------------------------------------------------------------------
main() {
    banner
    load_kb
    infer
    hr
    printf '\n%sSession terminated.  Expert system halting.%s\n\n' "$YELLOW" "$RESET"
}

main "$@"
exit 0

# =============================================================================
#  EMBEDDED KNOWLEDGE BASE — Computer Hardware Diagnostic Tree
#  Format: ID|TYPE|TEXT|YES_BRANCH|NO_BRANCH
#  TYPE: Q=Question, C=Conclusion.  Branch IDs must reference existing rules.
# =============================================================================
__KB_BEGIN__
# Rule 1: Entry point
1|Q|Is the computer completely unresponsive when you press the power button?|2|3
# Branch 2: Some sign of life (power is on)
2|Q|Do you hear any beep codes from the internal speaker?|4|5
# Branch 3: No response at all
3|Q|Is the power LED indicator lit on the case or motherboard?|6|7
# Branch 4: Beeps heard
4|Q|Are the beep codes continuous (repeating indefinitely)?|8|9
# Branch 5: No beeps, but power is on
5|Q|Does the system successfully boot into the operating system?|10|11
# Branch 6: LED is on, yet machine is unresponsive
6|Q|Is the power cable firmly connected to both the wall outlet and the PSU?|13|12
# Branch 7: No LED at all
7|C|Your power supply unit (PSU) may be faulty or inadequately connected. Check the 24-pin motherboard power connector and the CPU power connector.||
# Branch 8: Continuous beeps
8|C|Critical hardware failure detected. Continuous beeps typically indicate a severe issue with the CPU, motherboard, or RAM seating. Reseat all components.||
# Branch 9: Patterned or irregular beeps
9|Q|Are the beeps in a specific pattern (for example, 3 long and 2 short)?|14|15
# Branch 10: Boots to OS successfully
10|C|System appears to be functioning normally. If you are experiencing intermittent issues, consider thermal monitoring and driver updates.||
# Branch 11: Fails before reaching the OS
11|Q|Does the display show any output during the boot process?|16|17
# Branch 12: Cable was loose (NO to firm connection)
12|C|Power connection issue resolved. Ensure cable retention and consider using a surge protector.||
# Branch 13: Cable is fine, LED on, still dead (YES to firm connection)
13|C|Power supply unit (PSU) has likely failed. Test with a multimeter or replacement PSU.||
# Branch 14: Specific beep pattern
14|C|Patterned beep codes indicate specific hardware faults. Consult your motherboard manual beep code chart for exact diagnosis.||
# Branch 15: Irregular or single beep
15|C|Single or irregular beeps may indicate a minor POST error. Check peripheral connections and BIOS settings.||
# Branch 16: Display works, but OS misbehaves
16|Q|Does the operating system load but crash or freeze shortly after?|18|19
# Branch 17: No display output at all
17|C|Display output failure. Check GPU seating, monitor cable, and ensure the monitor is powered on and set to the correct input.||
# Branch 18: OS crashes after loading
18|Q|Does the freezing or crashing occur under heavy load (gaming, video rendering, compiling)?|20|21
# Branch 19: OS does not load or freezes immediately
19|C|Software or driver issue likely. Boot into Safe Mode and review recent changes, updates, or malware.||
# Branch 20: Crash under heavy load
20|C|Thermal throttling or insufficient power delivery. Clean dust filters, reseat the heatsink with fresh thermal paste, and verify PSU wattage.||
# Branch 21: Crash at idle or light load
21|C|Potential faulty RAM stick or motherboard issue. Run memtest86+ and test RAM sticks individually in different slots.||