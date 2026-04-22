#!/usr/bin/env bash 

# Written By Woland

# Simple Alarm clock script

# Dependency:
#          mpv
#          figlet 
#          sleep

# https://github.com/wolandark
# https://github.com/wolandark/BASH_Scripts_For_Everyone

set -euo pipefail

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    command -v mpv >/dev/null 2>&1 || missing_deps+=("mpv")
    command -v figlet >/dev/null 2>&1 || missing_deps+=("figlet")
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo "Error: Missing required dependencies: ${missing_deps[*]}" >&2
        echo "Install them with your package manager (e.g., apt, brew, pacman)" >&2
        exit 1
    fi
}

check_dependencies

# Parse arguments
if [[ -z $1 ]]; then
	echo -e "\n\t Usage: $0 8h for 8 hours of sleep"
	echo -e "\t\t$0 20m for 20 minutes of sleep"
	echo -e "\t\t$0 30s for 30 seconds of sleep"
	echo -e "\t\t See man sleep for more options\n"
	exit 0
fi

SLEEP_TIME="$1"

# Validate sleep time format
if ! sleep "$SLEEP_TIME" --dry-run >/dev/null 2>&1; then
    echo "Error: Invalid sleep time format: $SLEEP_TIME" >&2
    echo "Use formats like: 8h, 20m, 30s" >&2
    exit 1
fi

echo "Alarm set for $SLEEP_TIME from now..."
echo "Started at: $(date)"

sleep "$SLEEP_TIME"

figlet "sleep time over"

# Alarm files - can be customized via environment variable
ALARM_DIR="${ALARM_DIR:-.}"
alarm=(
	"${ALARM_DIR}/alarm1.mp3"
	"${ALARM_DIR}/alarm2.mp3"
	"${ALARM_DIR}/alarm3.mp3"
	"${ALARM_DIR}/alarm4.mp3"
	"${ALARM_DIR}/alarm5.mp3"
)

# Filter out non-existent alarm files
valid_alarms=()
for alarm_file in "${alarm[@]}"; do
    if [[ -f "$alarm_file" ]]; then
        valid_alarms+=("$alarm_file")
    else
        echo "Warning: Alarm file not found: $alarm_file" >&2
    fi
done

if [[ ${#valid_alarms[@]} -eq 0 ]]; then
    echo "Error: No valid alarm files found in $ALARM_DIR" >&2
    echo "Place MP3 files named alarm1.mp3, alarm2.mp3, etc. in that directory," >&2
    echo "or set the ALARM_DIR environment variable to the correct path." >&2
    exit 1
fi

for ((i=0; i<${#valid_alarms[@]}; i++)); do
  figlet -f slant "Wake Up-$((i+1))"
  sleep 1
  mpv --no-audio-display --no-resume-playback "${valid_alarms[i]}" &
  MPV_PID=$!
  sleep 45
  if kill -0 $MPV_PID 2>/dev/null; then
      kill $MPV_PID 2>/dev/null || true
  fi
  sleep 5m
done

echo "Alarm sequence complete."
figlet "Time to wake up!"
