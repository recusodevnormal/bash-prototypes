# Minimal Alpine Terminal OS

A self-sustained, **offline-capable** minimal Linux terminal OS built on the **Alpine Linux** toolchain (musl libc + BusyBox) with a static Bash binary for the PID 1 supervisor. Boots directly into an interactive shell on the console — no internet required. Everything lives in a custom initramfs whose `/init` is a Bash script: it mounts essential filesystems, starts services, reaps zombies, restarts failed services with backoff, and handles graceful shutdown.

## Quickstart

On a Linux host with QEMU installed:

```bash
./vm.sh
```

That's it. The script will:
1. Copy the host kernel into `./vmlinuz` (first run only).
2. Build the initramfs if missing or stale (downloads Alpine minirootfs + static bash, or reuses cached files if offline).
3. Launch QEMU and drop you into an interactive **Alpine terminal**.

Press **Ctrl+A then X** to quit QEMU.

### Offline builds

If you have no internet, pre-download the dependencies into `cache/`:

```bash
mkdir -p cache
# Download once on a machine with internet:
curl -L -o cache/alpine-minirootfs-3.19.tar.gz \
  https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-minirootfs-3.19.0-x86_64.tar.gz
curl -L -o cache/bash-linux-x86_64 \
  https://github.com/robxu9/bash-static/releases/download/5.2.21-1/bash-linux-x86_64

# Build and run offline:
./vm.sh
```

---

## Project Layout

- `vm.sh` — **One-script VM launcher**. Stages the kernel, builds the initramfs (with `cache/` support), and runs QEMU.
- `init` — PID 1 Bash supervisor. Mounts `/proc`, `/sys`, `/dev`, starts services, reaps zombies, handles `SIGTERM` shutdown.
- `services/` — Service scripts. The supervisor runs them in dependency order (use `# depends: svc1 svc2` headers). Includes:
  - `network` — Brings up loopback (always) and `eth0` + DHCP (best-effort). **Works fully offline.**
  - `console` — Spawns an interactive login shell on `/dev/console`. The main user-facing service.
  - `logger` — Simple FIFO-to-file logger.
  - `httpd` — Minimal `nc`-based HTTP server on port 8080 (optional, no internet required).
- `build-initramfs.sh` — Builds the `cpio.gz` initramfs from **Alpine minirootfs** + static Bash. Uses `cache/` for offline operation.
- `grub.cfg` — Example GRUB menu entry (for bare-metal install).
- `install-grub.sh` — Copies kernel + initramfs to `/boot` and injects a GRUB custom entry.
- `test-vm.sh` — Deprecated wrapper that calls `vm.sh`.

---

## Architecture

### PID 1 Supervisor (`init`)

- **Mounts**: `proc`, `sysfs`, `devtmpfs`, `tmpfs` for `/run` and `/tmp`, `devpts`.
- **Persistence layer**: Tries to mount a `virtiofs` or `9p` share tagged `persist` at `/persist`, then bind-mounts `/persist/var`, `/persist/etc`, and `/persist/root` over the initramfs directories so logs and config survive reboots.
- **cgroups v2**: Creates a cgroup per service under `/sys/fs/cgroup/mininit/<svc>`. Supports `cpu.max` and `memory.max` limits declared in service headers.
- **Namespace isolation**: Services can declare `# isolate: pid,mount,uts,ipc,net,user` to run inside `unshare` namespaces (sandboxing without containers).
- **Readiness probes**: Before starting a dependent service, the supervisor waits for the dependency to signal readiness via TCP port, file existence, Unix socket, or custom command.
- **Service lifecycle**:
  1. Scans `services/` for executable scripts (skips `_*` and `*.disabled`).
  2. Sorts by simple `# depends: …` declarations.
  3. Starts each service, applies cgroup limits, optionally enters `unshare` namespaces, then blocks until the readiness probe succeeds.
  4. Every second: reaps zombie children, checks for exited services, and restarts them with exponential-ish backoff (max 30s).
  5. On `SIGTERM`/`SIGINT`: stops services in reverse dependency order, tears down cgroups, then halts.

### Service Scripts

Services are plain Bash scripts. The supervisor will:
- Call `start` if defined, otherwise execute the script body.
- Call `stop` on shutdown if defined.

Example minimal service:
```bash
#!/bin/bash
# depends: network
# isolate: pid,mount,net
# ready: tcp:3000
# ready_timeout: 10
# cgroup.memory.max: 64M
start() {
    echo "My service is running"
    while true; do sleep 60; done
}
stop() {
    echo "My service is stopping"
}
case "${1:-start}" in start) start;; stop) stop;; esac
```

**Supported service headers**:
- `# depends: svc1 svc2` — topological dependency ordering
- `# isolate: pid,mount,uts,ipc,net,user` — Linux namespace flags passed to `unshare`
- `# ready: tcp:<port> | file:<path> | unix:<path> | sleep:<seconds> | cmd:<command>` — readiness probe
- `# ready_timeout: <seconds>` — max time to wait for readiness (default: 10)
- `# cgroup.cpu.max: <quota> <period>` — cgroups v2 CPU limit (e.g. `50000 100000` for 50%)
- `# cgroup.memory.max: <bytes>` — cgroups v2 memory limit (e.g. `64M`)

### Initramfs Build (`build-initramfs.sh`)

1. Fetches the **Alpine Linux minirootfs** (~3 MB compressed) — provides musl libc, BusyBox, and base filesystem layout.
2. Fetches a **statically linked Bash** binary (~1.5 MB) and installs it as `/bin/bash`.
3. Copies your custom `/init` and `services/` into the rootfs.
4. Optionally uses `apk.static` to install extra Alpine packages (e.g. `iproute2`) if you place the binary at `/tmp/apk.static`.
5. Packs with `cpio + gzip`.

**Offline support**: All downloads are cached to `cache/` in the project directory. If a cached file exists, it is reused instead of downloading. Pre-populate `cache/` to build on an air-gapped machine.

No host library chasing, no glibc dependencies, and the resulting initramfs works on any x86_64 Linux kernel regardless of the build host's distro.

Override Alpine version, architecture, or cache directory:
```bash
ALPINE_VERSION=3.19 ARCH=x86_64 CACHE_DIR=./cache ./build-initramfs.sh
```

### GRUB Integration (`install-grub.sh`)

- Copies the running kernel to `/boot/vmlinuz-minimal`.
- Copies your initramfs to `/boot/initramfs-minimal.cpio.gz`.
- Appends a menu entry to `/etc/grub.d/40_custom` between `BEGIN/END` markers.
- Runs `update-grub` (or `grub-mkconfig` / `grub2-mkconfig`).

Kernel command line used:
```
root=/dev/ram0 rw console=tty0 console=ttyS0,115200n8
```
Because everything lives in the initramfs, `root=/dev/ram0` keeps the initramfs as the root filesystem.

---

## Configuration

### Runtime (init)

| Variable | Meaning | Default |
|----------|---------|---------|
| `SVC_DIR` | Directory containing service scripts | `/services` |
| `MAX_RESTARTS` | Max restart attempts per service | `10` |
| `BACKOFF_BASE` | Base backoff in seconds | `1` |
| `NET_IFACE` | Interface for `network` service | `eth0` |
| `HTTP_PORT` | Port for `httpd` service | `8080` |
| `HTTP_ROOT` | Document root for `httpd` | `/var/www` |
| `CGROUP_BASE` | cgroups v2 hierarchy path | `/sys/fs/cgroup/mininit` |
| `PERSIST_TAG` | virtiofs/9p mount tag for persistence | `persist` |

### Build-time (build-initramfs.sh)

| Variable | Meaning | Default |
|----------|---------|---------|
| `ALPINE_VERSION` | Alpine release to fetch | `3.19` |
| `ARCH` | Target architecture | `x86_64` |
| `BASH_STATIC_URL` | Static bash binary URL | `github.com/robxu9/bash-static` release |
| `CACHE_DIR` | Local cache directory for offline builds | `./cache` |
| `APK_STATIC` | Path to static `apk` binary for extra packages | `/tmp/apk.static` |

Set runtime variables by extending `init` to parse `/proc/cmdline`, or bake them into service scripts.

---

## Design Decisions

### Built-in vs Module Drivers

For a minimal initramfs, **build drivers into the kernel** (`=y`) when possible: filesystems (ext4, tmpfs), disk controllers (AHCI, NVMe, VirtIO), network (e1000, VirtIO-net). If you must use modules, copy them into the initramfs and run `modprobe` from `init`.

### Alpine Toolchain

We use **Alpine Linux minirootfs** as the base instead of fetching individual BusyBox binaries or copying host glibc tools. Alpine gives us:
- A battle-tested **musl libc + BusyBox** userland in one tarball.
- No dependency on the build host's libc or library paths.
- A static **Bash** binary handles the supervisor script; BusyBox `ash` is available as `/bin/sh` for simpler scripts.

### Service Model

This project intentionally avoids `systemd`, `runit`, or `s6` to demonstrate that a small Bash loop is sufficient for simple service supervision. Trade-offs:
- **Pros**: Tiny, easy to read, no external dependencies, fast boot.
- **Cons**: No socket activation (we have readiness probes instead), no built-in logging framework, less battle-tested than systemd/s6.

### Initramfs as Root

The simplest path is to keep the initramfs as the root filesystem (`root=/dev/ram0`). This avoids needing a real root disk and switch_root. For a multi-stage boot, extend `init` to mount a real root and `exec switch_root /mnt/root /sbin/init`.

### Total Isolation Without Containers

Each service can run in its own Linux namespaces via `unshare`, giving PID, mount, UTS, IPC, network, and user isolation without pulling in a container runtime. Combine with cgroups limits for resource boundary enforcement. The parent PID 1 still owns all processes for reaping and signaling, so you get container-like isolation with supervisor-like simplicity.

---

## Testing & Risks

- **Test in QEMU first** with `./vm.sh`. It uses `-no-reboot` so crashes are visible.
- **Size**: The initramfs loads entirely into RAM. Alpine minirootfs + static bash typically produces a 4–7 MB `cpio.gz`.
- **Kernel compatibility**: If you upgrade the kernel, re-run `build-initramfs.sh` (and `install-grub.sh` for bare-metal installs).
- **Security**: `/boot` is often unencrypted. Do not embed secrets (keys, passwords) in the initramfs.
- **Stability**: A Bash PID 1 is fine for embedded/demo use. For production workloads, consider a dedicated init system (e.g. `s6-init`, `runit`, or `systemd`).

---

## Extending

- **Real root filesystem**: Modify `init` to `mount /dev/sda1 /mnt/root` and `exec switch_root /mnt/root /sbin/init`.
- **Kernel modules**: Add `lib/modules/$(uname -r)` to the initramfs tree and call `modprobe` in `init`.
- **Logging**: Forward service stdout/stderr to a central pipe or to the host via `virtio-console`.
- **Networking**: Replace `udhcpc` with a static config or embed `dhcpcd`/`systemd-networkd` if desired.
- **Persistence tuning**: `vm.sh` creates `./persist/` on the host and exposes it via `-virtfs`. On bare metal, replace this with a real disk partition mounted at `/persist` and bind-mounted over `/var`, `/etc`, `/root`.
- **More controllers**: Add `# cgroup.io.max`, `# cgroup.pids.max`, or other cgroups v2 controllers by extending `setup_cgroup_limits()` in `init`.
- **Seccomp / capabilities**: Combine namespace isolation with `capsh` or a small seccomp BPF loader for even tighter sandboxing.
