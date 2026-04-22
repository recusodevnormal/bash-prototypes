# Bash Scripts Collection

A comprehensive collection of single-file Bash scripts for games, AI/NLP tools, system utilities, and general-purpose utilities.

## Directory Structure

```
.
├── ai-nlp/           # AI and Natural Language Processing tools
├── system-tools/     # System administration and monitoring tools
├── utilities/        # General-purpose utility scripts
├── games/            # Games implemented in Bash
└── offline-packages/ # Offline package transfer utilities
```

## Categories

### AI/NLP Tools (`ai-nlp/`)
Artificial intelligence and natural language processing tools:
- **boolean-logic** - Rule-based expert system with forward chaining inference
- **slot-filler-001/002** - Regex-based named entity recognition for natural language commands
- **hfsm-001/002** - Hierarchical Finite State Machine for interactive terminal AI
- **markov-001/002** - Markov chain personality mimics
- **levenshtein** - Edit distance with phonetic similarity ("Did you mean?" tool)
- **moodloop-001/002** - Real-time sentiment analyzers
- **keyword-scorer-001/002** - Weighted keyword intent scorers
- **history-buffer** - Contextual history buffer chatbot

### System Tools (`system-tools/`)
System administration and monitoring tools:
- **basha** - Bash services collection
- **portwatch** - Network port monitoring guardian
- **tweaker** - Snapshot-based system configuration TUI
- **noteb** - Note organizer and library

### Utilities (`utilities/`)
General-purpose utility scripts:
- **random-singles/** - Standalone utilities (alarm, extract, file deletion, etc.)
- **random-singles/tui-scripts/** - TUI utilities (disk-usage, file-manager, process-manager, etc.)
- **charb/** - Character-based tools

### Games (`games/`)
Games implemented in Bash:
- **acolyte** - TUI adventure game
- **another-dungeon-crawler** - Dungeon crawler RPG
- **ashen-king** - Survival horror RPG
- **bashmon-001/002** - Monster tamer RPGs
- **blood-banners** - Banner-based game
- **cyber-breach-001/002** - Cyberpunk hacking RPGs
- **deep-space-001/002** - Space scavenger RPGs
- **infinite-tundra** - Survival game
- **mud-lite-001/002** - Text adventure MUDs
- **neon-net** - Cyberpunk hacker RPG
- **outpost-42** - Survival horror RPG
- **sector-7** - Post-apocalyptic scavenger RPG
- **tui-dungeon-crawler** - TUI rogue-lite dungeon crawler
- **tui-stardew** - TUI farming RPG

## Requirements

- Bash 4.0+ (some scripts are POSIX sh compatible)
- Standard GNU/Unix utilities (grep, awk, sed, printf, tput)
- No external dependencies or internet required for most scripts
- Some tools may require specific dependencies (e.g., mpv for alarm.sh, figlet for alarm.sh)

## Usage

Each tool is a standalone script. Navigate to the directory and run:

```bash
./script-name.sh [arguments]
```

For example:
```bash
./ai-nlp/boolean-logic/boolean-logic.sh
./utilities/random-singles/alarm.sh 8h
./games/deep-space-002/deep-space-002.sh
```

## License

These scripts are provided as-is for educational and practical use.
