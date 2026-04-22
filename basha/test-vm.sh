#!/bin/bash
# Deprecated: use ./vm.sh instead.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/vm.sh" "$@"
