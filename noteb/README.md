# noteb

Single-script note organizer and library for Alpine Linux. No network required.

## Install

```sh
# Copy to a directory in $PATH
cp noteb.sh /usr/local/bin/noteb
chmod +x /usr/local/bin/noteb

# Or run directly
./noteb.sh menu
```

## Requirements

- Alpine Linux (BusyBox `sh`, `awk`, `sed`, `grep`, `find`, `tar`)
- An editor (`vi` is default; set via `EDITOR` env or config)

## Usage

```sh
noteb add                           # Interactive add
noteb add -t "Title" -c work -g ideas
noteb list                        # List all notes
noteb list -c work                  # Filter by category
noteb search "term"               # Full-text search
noteb edit <id|title>             # Edit a note
noteb show <id|title>             # Display a note
noteb delete <id|title>           # Remove a note
noteb tags                        # List all tags
noteb categories                  # List all categories
noteb recent 5                    # Show 5 recent notes
noteb append <id> "quick thought"   # Append text without editor
noteb links <id|title>            # Show outgoing [[links]]
noteb backlinks <id|title>          # Show notes linking here
noteb revert <id|title>             # Restore from backup snapshot
noteb stats                       # Show statistics
noteb template add daily          # Create a template
noteb export backup.tar.gz        # Export archive
noteb import backup.tar.gz        # Import archive
noteb config --edit               # Edit configuration
noteb menu                        # Interactive TUI menu
```

## Storage

- Config: `~/.config/noteb/config`
- Notes: `~/.local/share/noteb/notes/*.md`
- Templates: `~/.local/share/noteb/templates/*.md`

## Note Format

Each note is a Markdown file with YAML-like frontmatter:

```markdown
---
id: a1b2c3d4
title: My Note
category: ideas
tags: tag1, tag2
created: 2024-01-15 10:30
modified: 2024-01-15 10:30
---

Your content here.

Link to other notes with wikilink syntax: [[other-note-id]] or [[Other Note Title]]
```
