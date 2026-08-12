#!/usr/bin/env bash

set -euo pipefail

RECORDING_NAME="${1:-}"
if [[ ! "$RECORDING_NAME" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "Recording name must contain only letters, numbers, dot, underscore, or hyphen." >&2
    exit 2
fi

export PANDA_NETWORK_RESTRICT=on
source /opt/panda-tools/common.sh

RECORDING="/work/recordings/$RECORDING_NAME"
COVERAGE="/work/analyses/$RECORDING_NAME-coverage.csv"
PANDALOG="/work/analyses/$RECORDING_NAME.plog"

if [[ ! -s "$RECORDING-rr-snp" || ! -s "$RECORDING-rr-nondet.log" ]]; then
    echo "Nonempty recording files not found for: $RECORDING" >&2
    exit 1
fi

mkdir -p /work/analyses /work/logs
exec panda-system-x86_64 \
    "${PANDA_COMMON_ARGS[@]}" \
    -display none \
    -monitor none \
    -replay "$RECORDING" \
    -panda "coverage:mode=asid-block,filename=$COVERAGE" \
    -pandalog "$PANDALOG" \
    -D "/work/logs/$RECORDING_NAME-replay.log"
