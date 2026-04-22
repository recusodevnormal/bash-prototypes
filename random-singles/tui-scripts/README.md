# TUI Scripts for Alpine Linux

A comprehensive library of useful Terminal User Interface (TUI) scripts for Alpine Linux. All scripts have **no external dependencies** and work with standard busybox utilities.

## Requirements

- Alpine Linux (or any Linux with busybox)
- Bash shell
- Standard terminal with ANSI support
- No network connection required

## Installation

1. Clone or download the scripts:
```bash
cd tui-scripts
chmod +x *.sh
```

2. (Optional) Add to PATH:
```bash
export PATH="$PATH:$(pwd)"
```

## Scripts

### 1. File Manager (`file-manager.sh`)

A full-featured file manager with TUI interface.

**Features:**
- Navigate directories
- View files and folders
- Delete files/directories
- Create directories (mkdir)
- Create files (touch)
- View file contents

**Controls:**
- `↑/↓` - Navigate
- `Enter` - Open directory/file
- `q` - Quit
- `d` - Delete selected
- `m` - Create directory
- `t` - Create file
- `v` - View file

**Usage:**
```bash
./file-manager.sh
```

---

### 2. System Monitor (`system-monitor.sh`)

Real-time system monitoring dashboard.

**Features:**
- CPU usage (with progress bar)
- Memory usage (with progress bar)
- Disk usage (with progress bar)
- System uptime
- Load average
- Temperature (if available)
- Process count
- Active users

**Controls:**
- `r` - Force refresh
- `q` - Quit
- Auto-refreshes every 1 second

**Usage:**
```bash
./system-monitor.sh
```

---

### 3. Process Manager (`process-manager.sh`)

Interactive process manager.

**Features:**
- View all running processes
- Filter processes by name
- Kill processes
- Sort by PID, CPU, memory
- Real-time process list

**Controls:**
- `↑/↓` - Navigate
- `k` - Kill selected process
- `f` - Set filter
- `c` - Clear filter
- `r` - Refresh
- `q` - Quit

**Usage:**
```bash
./process-manager.sh
```

---

### 4. Log Viewer (`log-viewer.sh`)

View and search system logs with syntax highlighting.

**Features:**
- View common log files
- Follow mode (tail -f style)
- Search within logs
- Syntax highlighting (ERROR, WARN, INFO, DEBUG)
- Open custom log files
- Scroll through large files

**Controls:**
- `↑/↓` - Scroll line by line
- `Page Up/Down` - Scroll page
- `o` - Open custom file
- `l` - Select from common logs
- `f` - Toggle follow mode
- `r` - Refresh
- `/` - Search
- `q` - Quit

**Usage:**
```bash
./log-viewer.sh
```

---

### 5. Network Info (`network-info.sh`)

Network information and diagnostic tool.

**Features:**
- Display all network interfaces
- Show IP addresses
- Show MAC addresses
- RX/TX statistics
- DNS servers
- Default gateway
- Active connections
- Ping test

**Controls:**
- `r` - Refresh
- `p` - Ping test
- `q` - Quit
- Auto-refreshes every 1 second

**Usage:**
```bash
./network-info.sh
```

---

### 6. Disk Usage (`disk-usage.sh`)

Disk space analyzer with visual progress bars.

**Features:**
- View all mount points
- Disk usage with progress bars
- Color-coded usage (green/yellow/red)
- Analyze directory sizes
- Sort by usage

**Controls:**
- `↑/↓` - Navigate
- `d` - Analyze selected directory
- `r` - Refresh
- `q` - Quit

**Usage:**
```bash
./disk-usage.sh
```

---

### 7. Text Editor (`text-editor.sh`)

Simple text editor with TUI interface.

**Features:**
- Create and edit text files
- Save and load files
- Basic navigation
- Character insertion/deletion
- Line insertion
- Modified file indicator

**Controls:**
- `↑/↓/←/→` - Navigate
- `Enter` - New line
- `Backspace` - Delete character
- `s` - Save file
- `o` - Open file
- `q` - Quit (prompts if modified)

**Usage:**
```bash
./text-editor.sh [filename]
```

---

### 8. Task Manager (`task-manager.sh`)

Simple todo/task manager.

**Features:**
- Add tasks
- Toggle task completion
- Delete tasks
- Persistent storage (~/.tui-tasks.txt)
- Statistics (total, done, pending)

**Controls:**
- `↑/↓` - Navigate
- `Space` - Toggle completion
- `a` - Add task
- `d` - Delete task
- `q` - Quit

**Usage:**
```bash
./task-manager.sh
```

---

## Common Features

All scripts share these characteristics:
- **No external dependencies** - Uses only bash and busybox
- **No network required** - Works offline
- **ANSI colors** - Beautiful terminal UI
- **Keyboard navigation** - Intuitive controls
- **Error handling** - Graceful failure handling
- **Terminal size detection** - Adapts to window size

## Terminal Requirements

Scripts require a terminal that supports:
- ANSI escape codes
- Terminal size detection (LINES/COLUMNS)
- Standard keyboard input

Tested with:
- Alpine Linux default terminal
- Busybox terminal
- SSH sessions

## Troubleshooting

**"Terminal size not detected" error:**
- Ensure you're running in a proper terminal (not just a shell)
- Try running with `stty size` to verify terminal support

**Colors not displaying:**
- Some terminals may not support ANSI colors
- Scripts will still work, just without colors

**Performance issues:**
- Some scripts (like log viewer) may be slow with very large files
- Consider using `tail` or `head` to preprocess large files

## Contributing

These scripts are designed to be minimal and dependency-free. When modifying:
- Keep bash/sh compatible with busybox
- Avoid external dependencies
- Maintain TUI interface consistency
- Test on Alpine Linux

## License

Free to use and modify for any purpose.
