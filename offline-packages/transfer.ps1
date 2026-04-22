# Alpine Minimal Offline Package Downloader
# For x86_64 terminal-based systems
$alpineVersion = "3.20"  # Change if using different version
$architecture = "x86_64"
$repoUrl = "https://dl-cdn.alpinelinux.org/alpine/v${alpineVersion}/main/${architecture}"
$communityRepoUrl = "https://dl-cdn.alpinelinux.org/alpine/v${alpineVersion}/community/${architecture}"

# Create workspace
$path = "$HOME\Desktop\AlpineOffline"
New-Item -ItemType Directory -Force -Path $path
Set-Location -Path $path

Write-Host "--- Alpine Minimal Offline Package Downloader ---" -ForegroundColor Cyan
Write-Host "Version: $alpineVersion | Arch: $architecture" -ForegroundColor Gray
Write-Host ""

# Create directories
$apksDir = New-Item -ItemType Directory -Force -Path "$path\apks"
$scriptsDir = New-Item -ItemType Directory -Force -Path "$path\scripts"

# Essential terminal-based packages with their typical dependencies
$packages = @(
    # Core utilities
    "bash",
    "coreutils",
    "grep",
    "sed",
    "awk",
    "ca-certificates",
    "ca-certificates-bundle",

    # Text editors
    "nano",

    # Network tools
    "curl",
    "wget",
    "openssh-client",
    "openssh-server",
    "openssh-sftp-server",

    # File tools
    "tar",
    "gzip",
    "zip",
    "unzip",
    "xz",

    # Process management
    "htop",
    "procps",
    "psmisc",

    # Version control
    "git",

    # Privilege escalation
    "sudo",

    # Build tools (for compiling if needed)
    "build-base",
    "gcc",
    "make",
    "musl-dev",

    # Python
    "python3",
    "py3-pip",

    # Terminal multiplexing
    "tmux",

    # System monitoring
    "iotop",
    "strace",
    "lsof",

    # Additional useful tools
    "vim",
    "man-db",
    "less",
    "tree",
    "rsync",
    "jq",
    "fzf"
)

Write-Host ">> Downloading APK packages..." -ForegroundColor Yellow

$downloaded = 0
$failed = 0

# Function to get/download package from repo
function Get-Package {
    param($pkgName, $baseUrl)
    try {
        # Get directory listing
        $response = Invoke-WebRequest -Uri "$baseUrl/" -ErrorAction Stop
        $content = $response.Content
        
        # Find APK file matching package name
        $pattern = "href=`"$pkgName-[\d\w\.\-\_]+\.apk`""
        if ($content -match $pattern) {
            # Extract the actual filename
            $apkMatch = [regex]::Match($content, $pattern)
            $apkFile = $apkMatch.Value -replace 'href="', '' -replace '"', ''
            $downloadUrl = "$baseUrl/$apkFile"
            
            Invoke-WebRequest -Uri $downloadUrl -OutFile "$apksDir\$apkFile" -ErrorAction Stop
            return $true
        }
        return $false
    } catch {
        return $false
    }
}

foreach ($pkg in $packages) {
    Write-Host "   Downloading $pkg..." -NoNewline
    
    # Try main repo first
    $success = Get-Package -pkgName $pkg -baseUrl $repoUrl
    
    if (-not $success) {
        # Try community repo
        $success = Get-Package -pkgName $pkg -baseUrl $communityRepoUrl
        if ($success) {
            Write-Host " OK (community)" -ForegroundColor Green
            $downloaded++
        } else {
            Write-Host " SKIP (not found)" -ForegroundColor Gray
        }
    } else {
        Write-Host " OK" -ForegroundColor Green
        $downloaded++
    }
}

Write-Host ""
Write-Host "Downloaded: $downloaded | Failed: $failed" -ForegroundColor Cyan
Write-Host ""

# Create Alpine installation script
Write-Host ">> Creating Alpine installation script..." -ForegroundColor Yellow
$installScript = @'
#!/bin/sh
# Alpine Offline Package Installer
# Run this on the target Alpine system

set -e

echo "--- Alpine Offline Package Installer ---"
echo ""

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Use: sudo ./install.sh"
    exit 1
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APKS_DIR="$SCRIPT_DIR/apks"

echo "Installing packages from: $APKS_DIR"
echo ""

# Install all APK files
for apk in "$APKS_DIR"/*.apk; do
    if [ -f "$apk" ]; then
        echo "Installing: $(basename "$apk")"
        apk add --allow-untrusted "$apk" || echo "Warning: Failed to install $(basename "$apk")"
    fi
done

echo ""
echo "--- Installation Complete ---"
echo ""
echo "Verify installation with:"
echo "  apk info"
echo ""
echo "Start SSH server:"
echo "  rc-service sshd start"
echo "  rc-update add sshd"
'@
$installScript | Out-File -FilePath "$scriptsDir\install.sh" -Encoding UTF8

# Create README
Write-Host ">> Creating README..." -ForegroundColor Yellow
$readme = @'
# Alpine Offline Package Bundle

## Contents
- `apks/` - Downloaded Alpine APK packages
- `scripts/install.sh` - Installation script for Alpine

## Transfer to Alpine
1. Copy this entire folder to your Alpine system (USB, network transfer, etc.)
2. On Alpine: `cd /path/to/AlpineOffline`
3. Make script executable: `chmod +x scripts/install.sh`
4. Run as root: `sudo ./scripts/install.sh`

## Included Packages
- Core utilities: bash, coreutils, grep, sed, awk
- Text editors: nano, vim
- Network: curl, wget, openssh
- File tools: tar, gzip, zip, unzip, xz
- Process management: htop, procps
- Version control: git
- Build tools: build-base, gcc, make, musl-dev
- Python: python3, py3-pip
- Terminal: tmux
- Monitoring: iotop, strace, lsof
- Utilities: man-db, less, tree, rsync, jq, fzf

## Post-Installation
- Start SSH: `rc-service sshd start && rc-update add sshd`
- Add user to sudo: `EDITOR=nano visudo` (uncomment wheel group)
- Create user: `adduser -G wheel username`
'@
$readme | Out-File -FilePath "$path\README.md" -Encoding UTF8

Write-Host "--- SETUP COMPLETE ---" -ForegroundColor Green
Write-Host "Package location: $path"
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Review downloaded APKs in: $apksDir"
Write-Host "2. Copy entire 'AlpineOffline' folder to USB"
Write-Host "3. On Alpine, run: sudo ./scripts/install.sh"
Write-Host ""