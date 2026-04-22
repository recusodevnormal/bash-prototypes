#!/bin/bash

# Written By Woland

# Delete all matching files by extension 

# https://github.com/wolandark
# https://github.com/wolandark/BASH_Scripts_For_Everyone

# Usage: ./file_deleter_by_extension.sh [extension] [path] [--dry-run]
# Example: ./file_deleter_by_extension.sh .so ~/Downloads
#          ./file_deleter_by_extension.sh .so ~/Downloads --dry-run

set -euo pipefail

# Parse arguments
EXTENSION="${1:-.so}"
PATH_TO_SEARCH="${2:-$HOME/Downloads}"
DRY_RUN=""

if [[ "$3" == "--dry-run" ]] || [[ "$#" -ge 3 && "$3" == "--dry-run" ]]; then
    DRY_RUN="--dry-run"
fi

# Validate path
if [[ ! -d "$PATH_TO_SEARCH" ]]; then
    echo "Error: Directory does not exist: $PATH_TO_SEARCH" >&2
    exit 1
fi

# Show what will be deleted
echo "Searching in: $PATH_TO_SEARCH"
echo "Extension: $EXTENSION"
if [[ -n "$DRY_RUN" ]]; then
    echo "Mode: DRY RUN (no files will be deleted)"
fi
echo

# Count files first
FILE_COUNT=$(find "$PATH_TO_SEARCH" -name "*$EXTENSION" -type f 2>/dev/null | wc -l)
if [[ "$FILE_COUNT" -eq 0 ]]; then
    echo "No files found with extension $EXTENSION"
    exit 0
fi

echo "Found $FILE_COUNT file(s) with extension $EXTENSION"

# Confirmation prompt
if [[ -z "$DRY_RUN" ]]; then
    read -p "Delete these files? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

# Use the find command to locate all files with the specified extension
find "$PATH_TO_SEARCH" -name "*$EXTENSION" -type f -print0 2>/dev/null |

# Delete each file found
DELETED_COUNT=0
while IFS= read -r -d '' file; do
    if [[ -n "$DRY_RUN" ]]; then
        echo "[DRY RUN] Would delete: $file"
    else
        echo "Deleting file: $file"
        if rm "$file"; then
            ((DELETED_COUNT++))
        else
            echo "Warning: Failed to delete $file" >&2
        fi
    fi
done

if [[ -n "$DRY_RUN" ]]; then
    echo "Dry run complete. No files were deleted."
else
    echo "Done. Deleted $DELETED_COUNT file(s)."
fi
