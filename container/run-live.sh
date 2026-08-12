#!/usr/bin/env bash

set -euo pipefail

case "${PANDA_NETWORK:-offline}" in
    offline) export PANDA_NETWORK_RESTRICT=on ;;
    nat) export PANDA_NETWORK_RESTRICT=off ;;
    *) echo "PANDA_NETWORK must be 'offline' or 'nat'." >&2; exit 2 ;;
esac

source /opt/panda-tools/common.sh
mkdir -p /work/logs /work/recordings /work/analyses

websockify --web=/usr/share/novnc 6080 127.0.0.1:5900 \
    > /work/logs/novnc.log 2>&1 &
NOVNC_PID=$!

panda-system-x86_64 \
    "${PANDA_COMMON_ARGS[@]}" \
    -vnc 0.0.0.0:0 \
    -monitor tcp:0.0.0.0:4444,server,nowait \
    -D /work/logs/panda-live.log &
PANDA_PID=$!

cleanup() {
    kill -TERM "$PANDA_PID" 2>/dev/null || true
    kill -TERM "$NOVNC_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM
wait "$PANDA_PID"
