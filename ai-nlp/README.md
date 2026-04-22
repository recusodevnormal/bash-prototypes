# AI/NLP Tools

This directory contains artificial intelligence and natural language processing tools implemented in Bash.

## Tools

- **boolean-logic** - Rule-based expert system with forward chaining inference
- **slot-filler-001** - Regex-based named entity recognition for natural language commands
- **slot-filler-002** - Lightweight deterministic command parser with confirmation UI
- **hfsm-001** - Hierarchical Finite State Machine for interactive terminal AI assistant
- **hfsm-002** - HFSM implementation with conversation trees and technical tips
- **markov-001** - Markov chain personality mimic with model building
- **markov-002** - Enhanced Markov chain mimic with awk-based logic and chat interface
- **levenshtein** - Levenshtein edit distance with phonetic similarity ("Did you mean?" tool)
- **moodloop-001** - Real-time sentiment analyzer for stdin/log files
- **moodloop-002** - Enhanced sentiment-analysis chat loop with mood-based persona
- **keyword-scorer-001** - Weighted keyword intent scorer with domain-adaptive TUI
- **keyword-scorer-002** - Simplified keyword intent scorer with associative arrays
- **history-buffer** - Contextual history buffer chatbot with circular memory

## Usage

Each tool is a standalone script. Run them directly:

```bash
./boolean-logic/boolean-logic.sh
./markov-001/markov-001.sh <corpus_file>
```

## Requirements

- Bash 4.0+ (for associative arrays)
- Standard GNU/Unix utilities (grep, awk, sed, printf, tput)
- No external dependencies or internet required
