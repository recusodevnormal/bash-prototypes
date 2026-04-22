#!/bin/bash
# Build an Alpine-based initramfs cpio.gz with Bash PID 1 and service scripts.
# Uses the Alpine minirootfs as the musl+BusyBox base and drops in a static
# bash binary so complex supervisor scripts work without chasing glibc libs.
# Run this on any Linux build host.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${BUILD_DIR:-$SCRIPT_DIR/build/initramfs}"
OUTPUT="${OUTPUT:-$SCRIPT_DIR/initramfs.cpio.gz}"
CACHE_DIR="${CACHE_DIR:-$SCRIPT_DIR/cache}"
ALPINE_VERSION="${ALPINE_VERSION:-3.19}"
ARCH="${ARCH:-x86_64}"
ALPINE_REPO="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}"
MINIROOTFS_URL="${ALPINE_REPO}/releases/${ARCH}/alpine-minirootfs-${ALPINE_VERSION}.0-${ARCH}.tar.gz"
BASH_STATIC_URL="${BASH_STATIC_URL:-https://github.com/robxu9/bash-static/releases/download/5.2.21-1/bash-linux-x86_64}"

log() {
    echo "[build] $*"
}

# --- Cache-aware fetch ---
# Downloads to cache/ first, reuses cached files when offline.
fetch_cached() {
    local url="$1" dest="$2"
    local cache_file="$CACHE_DIR/$(basename "$dest")"
    mkdir -p "$CACHE_DIR"

    if [[ -f "$cache_file" ]] && [[ -s "$cache_file" ]]; then
        log "Using cached: $(basename "$cache_file")"
        cp "$cache_file" "$dest"
        return 0
    fi

    log "Downloading: $url"
    if command -v wget >/dev/null 2>&1; then
        wget -q "$url" -O "$cache_file" 2>/dev/null || curl -fsSL "$url" -o "$cache_file" 2>/dev/null
    else
        curl -fsSL "$url" -o "$cache_file" 2>/dev/null
    fi

    if [[ -f "$cache_file" ]] && [[ -s "$cache_file" ]]; then
        cp "$cache_file" "$dest"
        return 0
    fi

    log "ERROR: Could not download $(basename "$cache_file") and no cached copy found."
    log "Place the file at: $cache_file"
    return 1
}

# --- Prepare build directory ---
log "Cleaning build directory: $BUILD_DIR"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# --- Download and extract Alpine minirootfs ---
MINIROOTFS_TAR="/tmp/alpine-minirootfs-${ALPINE_VERSION}.tar.gz"
fetch_cached "$MINIROOTFS_URL" "$MINIROOTFS_TAR"
log "Extracting minirootfs..."
tar -xzf "$MINIROOTFS_TAR" -C "$BUILD_DIR"

# --- Install static bash ---
log "Installing static bash..."
BASH_BIN="$BUILD_DIR/bin/bash"
fetch_cached "$BASH_STATIC_URL" "$BASH_BIN"
chmod +x "$BASH_BIN"
# Ensure /bin/sh also points to something useful (Alpine already has busybox sh)
ln -sf bash "$BUILD_DIR/bin/sh" 2>/dev/null || true

# --- Install init ---
log "Installing /init"
cp "$SCRIPT_DIR/init" "$BUILD_DIR/init"
chmod +x "$BUILD_DIR/init"

# --- Install services ---
log "Installing services"
if [[ -d "$SCRIPT_DIR/services" ]]; then
    cp -r "$SCRIPT_DIR/services/"* "$BUILD_DIR/services/"
    chmod +x "$BUILD_DIR/services/"* 2>/dev/null || true
fi

# --- Optional: install extra Alpine packages via static apk ---
# If apk.static is available locally or downloadable, we can install packages
# (e.g. iproute2, dhcpcd) into the rootfs. Otherwise busybox applets suffice.
APK_STATIC="${APK_STATIC:-/tmp/apk.static}"
if [[ -x "$APK_STATIC" ]] || [[ -f "$APK_STATIC" ]]; then
    log "Using local apk.static to install extra packages"
    mkdir -p "$BUILD_DIR/etc/apk"
    printf '%s\n' "${ALPINE_REPO}/main" "${ALPINE_REPO}/community" > "$BUILD_DIR/etc/apk/repositories"
    "$APK_STATIC" --root "$BUILD_DIR" --repositories-file "$BUILD_DIR/etc/apk/repositories" --update-cache add iproute2 2>/dev/null || true
else
    log "No apk.static found; relying on busybox applets (sufficient for basic services)"
fi

# --- Clean up Alpine boot artifacts we do not need in initramfs ---
rm -f "$BUILD_DIR/boot"/* 2>/dev/null || true

# --- Package initramfs ---
log "Packaging initramfs -> $OUTPUT"
(
    cd "$BUILD_DIR"
    find . -print0 | cpio --null -o --format=newc | gzip -9 > "$OUTPUT"
)

SIZE=$(du -h "$OUTPUT" | cut -f1)
log "Done. Initramfs size: $SIZE"
