#!/bin/bash
# Install/update GRUB entry for Minimal Bash OS.
# Must be run as root on the target machine (or in a chroot).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_SRC="${KERNEL_SRC:-/boot/vmlinuz-$(uname -r)}"
INITRAMFS_SRC="${INITRAMFS_SRC:-$SCRIPT_DIR/initramfs.cpio.gz}"
BOOT_DIR="${BOOT_DIR:-/boot}"
GRUB_CUSTOM="${GRUB_CUSTOM:-/etc/grub.d/40_custom}"

log() {
    echo "[grub-install] $*"
}

die() {
    echo "[grub-install] ERROR: $*" >&2
    exit 1
}

[[ "$EUID" -eq 0 ]] || die "This script must be run as root"

# --- Copy artifacts to /boot ---
if [[ ! -f "$INITRAMFS_SRC" ]]; then
    die "Initramfs not found: $INITRAMFS_SRC. Run build-initramfs.sh first."
fi

log "Copying kernel -> $BOOT_DIR/vmlinuz-minimal"
cp "$KERNEL_SRC" "$BOOT_DIR/vmlinuz-minimal"

log "Copying initramfs -> $BOOT_DIR/initramfs-minimal.cpio.gz"
cp "$INITRAMFS_SRC" "$BOOT_DIR/initramfs-minimal.cpio.gz"

# --- Inject GRUB custom entry ---
log "Installing GRUB custom entry -> $GRUB_CUSTOM"

# Remove any previous Minimal Bash OS entries to avoid duplicates
if [[ -f "$GRUB_CUSTOM" ]]; then
    sed -i '/### BEGIN_MINIMAL_BASH_OS/,/### END_MINIMAL_BASH_OS/d' "$GRUB_CUSTOM" 2>/dev/null || true
fi

cat >> "$GRUB_CUSTOM" <<'EOF'
### BEGIN_MINIMAL_BASH_OS
menuentry "Minimal Bash OS" {
    #set root='(hd0,1)'
    search --no-floppy --set=root --file /vmlinuz-minimal
    linux /vmlinuz-minimal root=/dev/ram0 rw console=tty0 console=ttyS0,115200n8
    initrd /initramfs-minimal.cpio.gz
}
### END_MINIMAL_BASH_OS
EOF

log "Regenerating GRUB configuration"
if command -v update-grub >/dev/null 2>&1; then
    update-grub
elif command -v grub-mkconfig >/dev/null 2>&1; then
    grub-mkconfig -o /boot/grub/grub.cfg
elif command -v grub2-mkconfig >/dev/null 2>&1; then
    grub2-mkconfig -o /boot/grub2/grub.cfg
else
    die "Could not find update-grub or grub-mkconfig"
fi

log "Done. Reboot and select 'Minimal Bash OS' in GRUB."
