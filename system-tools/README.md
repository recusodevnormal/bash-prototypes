# System Tools

This directory contains system administration and monitoring tools implemented in Bash.

## Tools

- **basha** - Bash services collection (console, httpd, logger)
- **portwatch** - Network port monitoring guardian with whitelist and TUI
- **tweaker** - Snapshot-based system configuration tweak TUI
- **noteb** - Single-script note organizer and library for Alpine Linux

## Usage

Each tool is a standalone script. Run them directly:

```bash
./basha/init
./portwatch/portwatch.sh
./tweaker/tweaker.sh
./noteb/noteb.sh menu
```

## Requirements

- Bash 4.0+ (noteb is POSIX sh compatible)
- Standard GNU/Unix utilities
- Some tools may require root privileges (e.g., portwatch for iptables)
