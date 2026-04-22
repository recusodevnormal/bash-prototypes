# Utilities

This directory contains general-purpose utility scripts.

## Tools

- **random-singles/** - Collection of standalone utility scripts
  - `alarm.sh` - Simple alarm clock using mpv and figlet
  - `extract.sh` - Universal file extraction utility
  - `file_deleter_by_extension.sh` - Safe file deletion by extension
  - `file_deleter_by_name.sh` - Safe file deletion by name pattern
  - `find&copy.sh` - Find files by name and copy to directory
  - `tui-scripts/` - TUI utilities (disk-usage, file-manager, log-viewer, network-info, process-manager, system-monitor, task-manager, text-editor)

- **charb/** - Character-based tools

## Usage

Each tool is a standalone script. Run them directly:

```bash
./utilities/random-singles/alarm.sh 8h
./utilities/random-singles/extract.sh archive.tar.gz
./utilities/random-singles/file_deleter_by_extension.sh .so ~/Downloads
./utilities/random-singles/tui-scripts/disk-usage.sh
```

## Requirements

- Bash 4.0+ (some scripts are POSIX sh compatible)
- Standard GNU/Unix utilities
- Some tools may require specific dependencies (e.g., mpv for alarm.sh, figlet for alarm.sh)
