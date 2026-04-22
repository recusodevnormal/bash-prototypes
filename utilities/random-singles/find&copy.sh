#!/bin/bash

# Written By Woland

# Find files by name and copy them to a directory

# https://github.com/wolandark
# https://github.com/wolandark/BASH_Scripts_For_Everyone

# Usage: ./find&copy.sh [search_path] [file_list] [destination_dir]
# Example: ./find&copy.sh ~/Scripts file_list.txt ~/FOUNDFILES

set -euo pipefail

# Parse arguments
SEARCH_PATH="${1:-~/Scripts/BASH_Scripts_For_Everyone}"
FILE_LIST="${2:-file_list}"
DEST_DIR="${3:-$HOME/FOUNDFILES}"

# Expand tilde in paths
SEARCH_PATH="${SEARCH_PATH/#\~/$HOME}"
DEST_DIR="${DEST_DIR/#\~/$HOME}"

# Validate search path
if [[ ! -d "$SEARCH_PATH" ]]; then
    echo "Error: Search path does not exist: $SEARCH_PATH" >&2
    exit 1
fi

# Validate file list
if [[ ! -f "$FILE_LIST" ]]; then
    echo "Error: File list not found: $FILE_LIST" >&2
    echo "Usage: $0 [search_path] [file_list] [destination_dir]" >&2
    exit 1
fi

# Create the destination directory if it doesn't already exist
mkdir -p "$DEST_DIR"

echo "Searching in: $SEARCH_PATH"
echo "Reading file list from: $FILE_LIST"
echo "Copying to: $DEST_DIR"
echo

# Counters
COPIED_COUNT=0
NOT_FOUND_COUNT=0
ERROR_COUNT=0

# Read the list of files from the file list
while read -r file_name; do
    # Skip empty lines and comments
    [[ -z "$file_name" || "$file_name" =~ ^[[:space:]]*# ]] && continue
    
    # Trim whitespace
    file_name=$(echo "$file_name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [[ -z "$file_name" ]] && continue
    
    # Search for the file
    SEARCH_RESULT=$(find "$SEARCH_PATH" -name "$file_name" -type f 2>/dev/null | head -n 1)
    
    # If the file was found, copy it to the destination directory
    if [[ -n "$SEARCH_RESULT" ]]; then
        if cp "$SEARCH_RESULT" "$DEST_DIR/" 2>/dev/null; then
            echo "✓ Copied: $file_name"
            ((COPIED_COUNT++))
        else
            echo "✗ Error copying: $file_name" >&2
            ((ERROR_COUNT++))
        fi
    else
        echo "✗ Not found: $file_name"
        ((NOT_FOUND_COUNT++))
    fi
done < "$FILE_LIST"

echo
echo "Summary:"
echo "  Copied: $COPIED_COUNT"
echo "  Not found: $NOT_FOUND_COUNT"
echo "  Errors: $ERROR_COUNT"
echo "  Destination: $DEST_DIR"
