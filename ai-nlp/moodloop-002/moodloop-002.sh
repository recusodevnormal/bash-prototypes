#!/usr/bin/env bash
# =============================================================================
# sentiment_mood_loop.sh
# =============================================================================
# A standalone, offline sentiment-analysis chat loop that uses only standard
# GNU/Unix utilities (grep, awk, sed, printf, tput, read).
#
# HOW IT WORKS:
#   1. The user types a message at the prompt.
#   2. The script counts "negative" and "positive" keyword hits via grep -c.
#   3. A running $MOOD integer is adjusted (+positive hits, -negative hits).
#   4. The bot's persona, color scheme, and response all reflect the current mood.
#
# MOOD SCALE:
#   MOOD <= -5  : HOSTILE  (bright red,    very aggressive tone)
#   MOOD -4..-1 : GRUMPY   (yellow,        short/dismissive tone)
#   MOOD  0     : NEUTRAL  (white/default, matter-of-fact tone)
#   MOOD  1.. 4 : HELPFUL  (cyan,          warm/supportive tone)
#   MOOD >= 5   : CHEERFUL (bright green,  enthusiastic tone)
#
# DEPENDENCIES: bash, grep, awk, sed, printf, tput, date, tr, wc
#               All standard on Linux/macOS. No internet required.
# =============================================================================

# ---------------------------------------------------------------------------
# 0. SAFETY FLAGS
# ---------------------------------------------------------------------------
set -euo pipefail          # exit on error, unset var, or pipe failure
IFS=$'\n\t'                # safer word-splitting

# ---------------------------------------------------------------------------
# 1. TERMINAL CAPABILITY DETECTION
#    We use tput to query the terminal; if it fails (non-interactive / dumb
#    terminal) we fall back to empty strings so the script still runs cleanly.
# ---------------------------------------------------------------------------
if tput colors &>/dev/null && [[ "$(tput colors)" -ge 8 ]]; then
    C_RESET="$(tput sgr0)"
    C_BOLD="$(tput bold)"
    C_RED="$(tput setaf 1)"
    C_BRED="$(tput bold)$(tput setaf 1)"      # bright/bold red
    C_YELLOW="$(tput setaf 3)"
    C_WHITE="$(tput setaf 7)"
    C_CYAN="$(tput setaf 6)"
    C_BGREEN="$(tput bold)$(tput setaf 2)"    # bright/bold green
    C_DIM="$(tput dim 2>/dev/null || printf '')"
    C_MAGENTA="$(tput setaf 5)"
    C_BG_BLACK="$(tput setab 0 2>/dev/null || printf '')"
else
    # Graceful degradation: no color codes at all
    C_RESET="" C_BOLD="" C_RED="" C_BRED="" C_YELLOW=""
    C_WHITE="" C_CYAN="" C_BGREEN="" C_DIM="" C_MAGENTA="" C_BG_BLACK=""
fi

# ---------------------------------------------------------------------------
# 2. WORD LISTS
#    Stored as newline-separated strings; grep -iF (fixed, case-insensitive)
#    will count how many lines in the user input match any token.
#    Using process-substitution / here-strings keeps everything offline & pure.
# ---------------------------------------------------------------------------

# Each word is on its own line so grep -c counts *lines that match* correctly.
# We actually pass the whole input as a single line, so we count *matches* with
# grep -oi (each match on its own output line) then count lines with wc -l.

NEGATIVE_WORDS=(
    "fail" "failed" "failing" "failure"
    "broken" "break" "broke" "breaking"
    "error" "errors" "err"
    "bug" "bugs" "buggy"
    "crash" "crashed" "crashing"
    "wrong" "incorrect" "invalid"
    "awful" "terrible" "horrible"
    "hate" "hating" "hated"
    "useless" "garbage" "trash"
    "stuck" "blocked" "issue" "issues"
    "problem" "problems" "trouble"
    "slow" "lag" "lagging" "laggy"
    "bad" "worst" "worse"
    "lost" "confused" "confusing"
    "annoying" "frustrating" "frustrated"
    "damn" "dammit" "crap"
    "abort" "aborted" "aborting"
    "timeout" "deadlock" "leak"
    "hurt" "pain" "sad" "unhappy"
)

POSITIVE_WORDS=(
    "fixed" "fix" "fixing"
    "working" "works" "worked"
    "thanks" "thank" "thankyou" "ty"
    "great" "awesome" "excellent"
    "good" "nice" "cool"
    "solved" "solve" "solution"
    "perfect" "love" "loving"
    "happy" "glad" "pleased"
    "helpful" "help" "helped"
    "success" "succeeded" "succeeding"
    "done" "finished" "complete" "completed"
    "correct" "right" "valid"
    "fast" "quick" "smooth"
    "easy" "simple" "clean"
    "progress" "improved" "improvement"
    "yay" "yes" "yeah" "yep"
    "cheers" "brilliant" "fantastic"
    "resolved" "resolve" "okay" "ok"
)

# ---------------------------------------------------------------------------
# 3. MOOD STATE
#    A single integer; clamped to [-10 .. 10] to prevent runaway scores.
# ---------------------------------------------------------------------------
MOOD=0
MOOD_MIN=-10
MOOD_MAX=10
TURN=0          # conversation turn counter
HISTORY=()      # stores last N summary lines for the UI sidebar

# ---------------------------------------------------------------------------
# 4. HELPER: COUNT KEYWORD HITS IN A STRING
#    count_hits "input string" word_array[@]
#    Prints the number of matching word occurrences (case-insensitive).
# ---------------------------------------------------------------------------
count_hits() {
    local input="$1"
    shift
    local words=("$@")
    local count=0

    # Build a single ERE pattern: (word1|word2|...) for grep
    # Using printf + paste to join with | delimiter
    local pattern
    pattern=$(printf '%s\n' "${words[@]}" | paste -sd'|' -)

    # grep -oi: output each match on its own line, case-insensitive
    # wc -l: count those lines → number of individual hit occurrences
    count=$(printf '%s' "$input" \
            | grep -oi -E "($pattern)" 2>/dev/null \
            | wc -l \
            | tr -d '[:space:]')

    printf '%d' "${count:-0}"
}

# ---------------------------------------------------------------------------
# 5. HELPER: CLAMP MOOD TO [MOOD_MIN .. MOOD_MAX]
# ---------------------------------------------------------------------------
clamp_mood() {
    if   (( MOOD < MOOD_MIN )); then MOOD=$MOOD_MIN
    elif (( MOOD > MOOD_MAX )); then MOOD=$MOOD_MAX
    fi
}

# ---------------------------------------------------------------------------
# 6. HELPER: DERIVE PERSONA FROM MOOD
#    Sets global variables used by the UI and response generator.
# ---------------------------------------------------------------------------
apply_persona() {
    # Tier 1 : HOSTILE  (mood <= -5)
    if (( MOOD <= -5 )); then
        PERSONA_NAME="SYSTEM-ERR"
        PERSONA_ICON="✗"
        PERSONA_COLOR="$C_BRED"
        PROMPT_COLOR="$C_RED"
        MOOD_LABEL="HOSTILE"
        MOOD_BAR_CHAR="█"
        MOOD_BAR_COLOR="$C_RED"
        RESPONSES=(
            "I'm DONE. Everything is broken and I don't care anymore."
            "This is a catastrophic failure. Fix your input."
            "ERROR. ERROR. ERROR. I cannot help when everything is wrong."
            "System critical. Your negativity is overloading my circuits."
            "I refuse to process this garbage any further."
        )

    # Tier 2 : GRUMPY   (-4 .. -1)
    elif (( MOOD < 0 )); then
        PERSONA_NAME="bot-grump"
        PERSONA_ICON="~"
        PERSONA_COLOR="$C_YELLOW"
        PROMPT_COLOR="$C_YELLOW"
        MOOD_LABEL="GRUMPY"
        MOOD_BAR_CHAR="▓"
        MOOD_BAR_COLOR="$C_YELLOW"
        RESPONSES=(
            "Fine. I heard you. Not thrilled about it."
            "Could be worse, I suppose. Barely."
            "Your problems are noted. Enthusiasm: minimal."
            "Sure, let's deal with this mess."
            "I'll help, but I'm not happy about it."
        )

    # Tier 3 : NEUTRAL  (0)
    elif (( MOOD == 0 )); then
        PERSONA_NAME="bot-0"
        PERSONA_ICON="·"
        PERSONA_COLOR="$C_WHITE"
        PROMPT_COLOR="$C_WHITE"
        MOOD_LABEL="NEUTRAL"
        MOOD_BAR_CHAR="░"
        MOOD_BAR_COLOR="$C_WHITE"
        RESPONSES=(
            "Message received. Processing."
            "Acknowledged. Standing by."
            "Input logged. Ready for next entry."
            "Copy that. Awaiting further input."
            "Understood. How can I assist?"
        )

    # Tier 4 : HELPFUL  (1 .. 4)
    elif (( MOOD < 5 )); then
        PERSONA_NAME="bot-help"
        PERSONA_ICON="★"
        PERSONA_COLOR="$C_CYAN"
        PROMPT_COLOR="$C_CYAN"
        MOOD_LABEL="HELPFUL"
        MOOD_BAR_CHAR="▒"
        MOOD_BAR_COLOR="$C_CYAN"
        RESPONSES=(
            "Great news! Things seem to be looking up."
            "I'm here to help — glad we're making progress!"
            "That's the spirit! Keep going, you're doing well."
            "Positive vibes detected. Let's solve this together!"
            "Sounds like things are improving. I'm with you!"
        )

    # Tier 5 : CHEERFUL (mood >= 5)
    else
        PERSONA_NAME="bot-HAPPY!"
        PERSONA_ICON="♥"
        PERSONA_COLOR="$C_BGREEN"
        PROMPT_COLOR="$C_BGREEN"
        MOOD_LABEL="CHEERFUL"
        MOOD_BAR_CHAR="█"
        MOOD_BAR_COLOR="$C_BGREEN"
        RESPONSES=(
            "AMAZING! You absolute legend! Everything is wonderful!"
            "This is the BEST conversation I have EVER had!"
            "You're crushing it! Positivity levels: MAXIMUM!"
            "WOW! Fixed AND happy?! My circuits are overflowing with joy!"
            "I love this energy! Let's keep this momentum going! 🚀"
        )
    fi
}

# ---------------------------------------------------------------------------
# 7. HELPER: PICK A PSEUDO-RANDOM RESPONSE FROM THE CURRENT PERSONA
#    Uses $RANDOM (bash built-in) for simple modulo selection.
# ---------------------------------------------------------------------------
pick_response() {
    local count=${#RESPONSES[@]}
    local idx=$(( RANDOM % count ))
    printf '%s' "${RESPONSES[$idx]}"
}

# ---------------------------------------------------------------------------
# 8. HELPER: DRAW THE MOOD BAR
#    A 20-character bar split into negative (left) and positive (right) halves.
#    The center represents MOOD = 0.
# ---------------------------------------------------------------------------
draw_mood_bar() {
    local bar_width=20          # total characters in the bar
    local half=$(( bar_width / 2 ))   # 10 chars per side
    local abs_mood=$(( MOOD < 0 ? -MOOD : MOOD ))   # absolute value

    # Scale mood [-10..10] → [0..10] blocks on the relevant side
    local filled=$(( abs_mood > half ? half : abs_mood ))
    local empty=$(( half - filled ))

    # Left half: negative side (fills right-to-left from center)
    local left_filled left_empty
    if (( MOOD < 0 )); then
        left_filled=$filled
        left_empty=$empty
    else
        left_filled=0
        left_empty=$half
    fi

    # Right half: positive side (fills left-to-right from center)
    local right_filled right_empty
    if (( MOOD > 0 )); then
        right_filled=$filled
        right_empty=$empty
    else
        right_filled=0
        right_empty=$half
    fi

    # Build the bar string
    local bar_left bar_right
    # Left side: empty spaces, then filled blocks (reversed, so blocks are near center)
    bar_left="$(printf '%*s' "$left_empty" '' | tr ' ' ' ')"  # spaces = unfilled
    local lf_str
    lf_str="$(printf '%*s' "$left_filled" '' | tr ' ' "$MOOD_BAR_CHAR")"
    bar_left="${bar_left}${lf_str}"

    # Right side: filled blocks, then empty spaces
    bar_right="$(printf '%*s' "$right_filled" '' | tr ' ' "$MOOD_BAR_CHAR")"
    local re_str
    re_str="$(printf '%*s' "$right_empty" '' | tr ' ' ' ')"
    bar_right="${bar_right}${re_str}"

    # Print: [negative-side|positive-side]
    printf '%s[%s%s%s|%s%s%s]%s' \
        "$C_DIM" \
        "$C_RED"   "$bar_left"  "$C_DIM" \
        "$MOOD_BAR_COLOR" "$bar_right" "$C_DIM" \
        "$C_RESET"
}

# ---------------------------------------------------------------------------
# 9. HELPER: DRAW THE FULL HEADER / STATUS BAR
# ---------------------------------------------------------------------------
draw_header() {
    # Determine terminal width (fallback to 70)
    local tw
    tw=$(tput cols 2>/dev/null || printf '70')

    local border
    border="$(printf '─%.0s' $(seq 1 "$tw"))"

    printf '\n%s%s%s\n' "$C_BOLD" "$border" "$C_RESET"
    printf ' %sSENTIMENT MOOD LOOP%s  |  ' "$C_BOLD" "$C_RESET"
    printf 'Turn: %s%3d%s  |  ' "$C_BOLD" "$TURN" "$C_RESET"
    printf 'Mood: %s%-8s%s  |  ' "${MOOD_BAR_COLOR}${C_BOLD}" "$MOOD_LABEL" "$C_RESET"
    printf 'Score: %s%+d%s  |  ' "${MOOD_BAR_COLOR}${C_BOLD}" "$MOOD" "$C_RESET"
    draw_mood_bar
    printf '\n%s%s%s\n' "$C_BOLD" "$border" "$C_RESET"
}

# ---------------------------------------------------------------------------
# 10. HELPER: DRAW THE BOT RESPONSE BOX
# ---------------------------------------------------------------------------
draw_bot_response() {
    local message="$1"
    printf '\n  %s%s [%s]%s  %s\n\n' \
        "$PERSONA_COLOR" "$C_BOLD" "$PERSONA_NAME" "$C_RESET" \
        "${PERSONA_COLOR}${PERSONA_ICON}${C_RESET}"

    # Word-wrap the message at 60 chars using fold (standard utility)
    printf '%s' "$message" \
        | fold -s -w 60 \
        | while IFS= read -r line; do
              printf '  %s│%s  %s\n' "$PERSONA_COLOR" "$C_RESET" "$line"
          done

    printf '  %s└──────────────────────────────────────────%s\n\n' \
        "$PERSONA_COLOR" "$C_RESET"
}

# ---------------------------------------------------------------------------
# 11. HELPER: DRAW SENTIMENT BREAKDOWN FOR THE LAST INPUT
# ---------------------------------------------------------------------------
draw_sentiment_breakdown() {
    local neg="$1" pos="$2" delta="$3"

    printf '  %sSentiment breakdown:%s  ' "$C_DIM" "$C_RESET"
    printf '%s-%d neg%s  ' "$C_RED"   "$neg" "$C_RESET"
    printf '%s+%d pos%s  ' "$C_BGREEN" "$pos" "$C_RESET"

    if   (( delta > 0 )); then
        printf '→ Mood %s▲ +%d%s\n' "$C_BGREEN" "$delta" "$C_RESET"
    elif (( delta < 0 )); then
        printf '→ Mood %s▼ %d%s\n' "$C_RED"    "$delta" "$C_RESET"
    else
        printf '→ Mood %s= unchanged%s\n' "$C_WHITE" "$C_RESET"
    fi
}

# ---------------------------------------------------------------------------
# 12. HELPER: DRAW COMMAND HINT BAR (shown below the prompt)
# ---------------------------------------------------------------------------
draw_hint_bar() {
    printf '%s  Commands: %s:quit%s to exit  •  %s:reset%s to reset mood  •  ' \
        "$C_DIM" "$C_WHITE" "$C_DIM" "$C_WHITE" "$C_DIM"
    printf '%s:history%s to show log  •  %s:help%s for word lists%s\n' \
        "$C_WHITE" "$C_DIM" "$C_WHITE" "$C_DIM" "$C_RESET"
}

# ---------------------------------------------------------------------------
# 13. HELPER: SHOW POSITIVE / NEGATIVE WORD LISTS  (:help command)
# ---------------------------------------------------------------------------
show_help() {
    printf '\n%s  ╔══════════════════════════════════════════╗%s\n' \
        "$C_BOLD" "$C_RESET"
    printf '%s  ║           KEYWORD REFERENCE              ║%s\n' \
        "$C_BOLD" "$C_RESET"
    printf '%s  ╚══════════════════════════════════════════╝%s\n\n' \
        "$C_BOLD" "$C_RESET"

    printf '  %s%sNEGATIVE words (each hit → MOOD -1):%s\n' \
        "$C_RED" "$C_BOLD" "$C_RESET"
    printf '%s' "${NEGATIVE_WORDS[@]}" \
        | fmt -w 60 \
        | while IFS= read -r l; do printf '    %s%s%s\n' "$C_RED" "$l" "$C_RESET"; done
    # Simpler approach: print 5 per row
    local i=0
    for w in "${NEGATIVE_WORDS[@]}"; do
        printf '  %s%-16s%s' "$C_RED" "$w" "$C_RESET"
        (( ++i % 4 == 0 )) && printf '\n'
    done
    printf '\n\n'

    printf '  %s%sPOSITIVE words (each hit → MOOD +1):%s\n' \
        "$C_BGREEN" "$C_BOLD" "$C_RESET"
    i=0
    for w in "${POSITIVE_WORDS[@]}"; do
        printf '  %s%-16s%s' "$C_BGREEN" "$w" "$C_RESET"
        (( ++i % 4 == 0 )) && printf '\n'
    done
    printf '\n\n'
}

# ---------------------------------------------------------------------------
# 14. HELPER: SHOW HISTORY LOG (:history command)
# ---------------------------------------------------------------------------
show_history() {
    printf '\n  %s%sCONVERSATION HISTORY%s\n' "$C_BOLD" "$C_MAGENTA" "$C_RESET"
    if (( ${#HISTORY[@]} == 0 )); then
        printf '  %s  (no history yet)%s\n\n' "$C_DIM" "$C_RESET"
        return
    fi
    local i=1
    for entry in "${HISTORY[@]}"; do
        printf '  %s%2d.%s %s\n' "$C_DIM" "$i" "$C_RESET" "$entry"
        (( i++ ))
    done
    printf '\n'
}

# ---------------------------------------------------------------------------
# 15. SPLASH SCREEN — shown once on startup
# ---------------------------------------------------------------------------
show_splash() {
    clear
    printf '\n\n'
    printf '  %s%s' "$C_BGREEN" "$C_BOLD"
    printf '  ███████╗███████╗███╗   ██╗████████╗██╗███╗   ███╗███████╗███╗   ██╗████████╗\n'
    printf '  ██╔════╝██╔════╝████╗  ██║╚══██╔══╝██║████╗ ████║██╔════╝████╗  ██║╚══██╔══╝\n'
    printf '  ███████╗█████╗  ██╔██╗ ██║   ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║   ██║   \n'
    printf '  ╚════██║██╔══╝  ██║╚██╗██║   ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║   ██║   \n'
    printf '  ███████║███████╗██║ ╚████║   ██║   ██║██║ ╚═╝ ██║███████╗██║ ╚████║   ██║   \n'
    printf '  ╚══════╝╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚═╝╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝   ╚═╝   \n'
    printf '%s\n' "$C_RESET"
    printf '               %sMOOD LOOP — Sentiment-Reactive Chat Interface%s\n' \
        "$C_BOLD" "$C_RESET"
    printf '               %sOffline  •  Pure Bash  •  No dependencies%s\n\n' \
        "$C_DIM" "$C_RESET"
    printf '  %sType a message to begin. The bot'\''s mood adapts to your words.%s\n' \
        "$C_WHITE" "$C_RESET"
    printf '  %sType %s:help%s %sfor keyword lists, or %s:quit%s %sto exit.%s\n\n' \
        "$C_DIM" "$C_WHITE" "$C_DIM" "$C_DIM" "$C_WHITE" "$C_DIM" "$C_DIM" "$C_RESET"
    printf '  Press %s[ENTER]%s to start...' "$C_BOLD" "$C_RESET"
    read -r _
    clear
}

# ---------------------------------------------------------------------------
# 16. MAIN LOOP
# ---------------------------------------------------------------------------
main() {
    show_splash

    # Initialise persona with default MOOD=0
    apply_persona

    while true; do
        # ── Draw the status header ─────────────────────────────────────────
        draw_header
        draw_hint_bar

        # ── Prompt the user ────────────────────────────────────────────────
        printf '\n  %s%s%s You%s › %s' \
            "$PROMPT_COLOR" "$C_BOLD" "$PERSONA_ICON" "$C_RESET" "$PROMPT_COLOR"
        IFS= read -r user_input
        printf '%s' "$C_RESET"

        # ── Handle empty input ─────────────────────────────────────────────
        [[ -z "$user_input" ]] && { clear; continue; }

        # ── Handle special commands ────────────────────────────────────────
        case "$user_input" in
            :quit|:exit|:q)
                printf '\n  %sFarewell. Final mood score: %s%+d%s%s\n\n' \
                    "$PERSONA_COLOR" "$C_BOLD" "$MOOD" "$C_RESET" "$C_RESET"
                exit 0
                ;;
            :reset)
                MOOD=0
                TURN=0
                HISTORY=()
                apply_persona
                printf '\n  %sMood reset to 0. Fresh start!%s\n' "$C_CYAN" "$C_RESET"
                sleep 1
                clear
                continue
                ;;
            :history)
                clear
                draw_header
                show_history
                printf '  Press %s[ENTER]%s to continue...' "$C_BOLD" "$C_RESET"
                read -r _
                clear
                continue
                ;;
            :help)
                clear
                show_help
                printf '  Press %s[ENTER]%s to continue...' "$C_BOLD" "$C_RESET"
                read -r _
                clear
                continue
                ;;
        esac

        # ── Increment turn counter ─────────────────────────────────────────
        (( TURN++ ))

        # ── Count sentiment hits ───────────────────────────────────────────
        neg_hits=$(count_hits "$user_input" "${NEGATIVE_WORDS[@]}")
        pos_hits=$(count_hits "$user_input" "${POSITIVE_WORDS[@]}")

        # ── Calculate mood delta & update MOOD ────────────────────────────
        delta=$(( pos_hits - neg_hits ))
        MOOD=$(( MOOD + delta ))
        clamp_mood

        # ── Derive new persona from updated mood ──────────────────────────
        apply_persona

        # ── Pick and display bot response ─────────────────────────────────
        clear
        draw_header

        # Echo what the user said (truncated if very long)
        local display_input
        display_input="$(printf '%s' "$user_input" | cut -c1-70)"
        [[ ${#user_input} -gt 70 ]] && display_input="${display_input}…"
        printf '\n  %sYou:%s %s\n' "$C_DIM" "$C_RESET" "$display_input"

        # Show the sentiment breakdown line
        draw_sentiment_breakdown "$neg_hits" "$pos_hits" "$delta"

        # Show the bot's response box
        response="$(pick_response)"
        draw_bot_response "$response"

        # ── Append to history ──────────────────────────────────────────────
        local ts
        ts="$(date +%H:%M:%S)"
        HISTORY+=("[$ts] T${TURN} | ${MOOD_LABEL}(${MOOD:+$MOOD}) | \"${display_input}\"")

        # Keep history to the last 20 entries to avoid unbounded growth
        if (( ${#HISTORY[@]} > 20 )); then
            HISTORY=("${HISTORY[@]:1}")   # drop the oldest entry
        fi

        # ── Short pause so the user can read, then re-prompt ──────────────
        draw_hint_bar
    done
}

# ---------------------------------------------------------------------------
# 17. ENTRY POINT
# ---------------------------------------------------------------------------
main "$@"