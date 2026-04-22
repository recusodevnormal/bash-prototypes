#!/bin/bash
# Self-sustained Alpine Terminal OS VM launcher.
# Usage: ./vm.sh
#   - Stages the host kernel into ./vmlinuz if not present
#   - Builds the initramfs if missing or stale (uses cache/ for offline builds)
#   - Launches QEMU with an interactive console + optional HTTP service
#
# Works offline: if cache/ contains alpine-minirootfs and bash-static,
# no internet connection is required to build or run.
#
# Requirements: Linux host with QEMU installed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

KERNEL="$SCRIPT_DIR/vmlinuz"
INITRAMFS="$SCRIPT_DIR/initramfs.cpio.gz"

# --- Stage kernel ---
if [[ ! -f "$KERNEL" ]]; then
    HOST_KERNEL="/boot/vmlinuz-$(uname -r)"
    if [[ -f "$HOST_KERNEL" ]]; then
        echo "[vm] Staging host kernel -> vmlinuz"
        cp "$HOST_KERNEL" "$KERNEL"
    else
        echo "[vm] ERROR: No kernel found."
        echo ""
        echo "Please provide a kernel binary, for example:"
        echo "  cp /boot/vmlinuz-<version> $SCRIPT_DIR/vmlinuz"
        echo "  ln -s /boot/vmlinuz-\$(uname -r) $SCRIPT_DIR/vmlinuz"
        echo ""
        exit 1
    fi
fi

# --- Build initramfs ---
if [[ ! -f "$INITRAMFS" ]] || [[ "$SCRIPT_DIR/init" -nt "$INITRAMFS" ]] || [[ "$SCRIPT_DIR/services" -nt "$INITRAMFS" ]]; then
    echo "[vm] Building initramfs..."
    ./build-initramfs.sh
fi

# --- Prepare persistence share ---
mkdir -p "$SCRIPT_DIR/persist"/{var,etc,root}

# --- Find QEMU ---
if command -v qemu-system-x86_64 >/dev/null 2>&1; then
    QEMU="qemu-system-x86_64"
elif command -v qemu-kvm >/dev/null 2>&1; then
    QEMU="qemu-kvm"
else
    echo "[vm] ERROR: QEMU not found. Install qemu-system-x86."
    exit 1
fi

# --- Launch ---
echo "[vm] Kernel:     $KERNEL"
echo "[vm] Initramfs:  $INITRAMFS"
echo "[vm] QEMU:       $QEMU"
echo "[vm]"
echo "[vm] Interactive console available in QEMU terminal"
echo "[vm] Guest HTTP service at http://localhost:8080 (when networking is up)"
echo "[vm] Persistence share mounted at /persist (maps to ./persist/)"
echo "[vm] Press Ctrl+A then X to quit QEMU"
echo ""

exec "$QEMU" \
    -m 512 \
    -kernel "$KERNEL" \
    -initrd "$INITRAMFS" \
    -append "root=/dev/ram0 rw console=ttyS0,115200n8" \
    -nographic \
    -no-reboot \
    -netdev user,id=net0,hostfwd=tcp::8080-:8080 \
    -device e1000,netdev=net0 \
    -virtfs local,path="$SCRIPT_DIR/persist",mount_tag=persist,security_model=none \
    "$@"
