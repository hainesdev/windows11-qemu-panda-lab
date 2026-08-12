#!/usr/bin/env bash

set -euo pipefail

PANDA_DISK="${PANDA_DISK:-/work/Windows11-panda-active.qcow2}"
PANDA_VARS="${PANDA_VARS:-/work/Windows11-panda-vars.fd}"
PANDA_OVMF_CODE="${PANDA_OVMF_CODE:-/work/Windows11-panda-code.fd}"

for required in "$PANDA_DISK" "$PANDA_VARS" "$PANDA_OVMF_CODE"; do
    if [[ ! -f "$required" ]]; then
        echo "Required PANDA VM file not found: $required" >&2
        exit 1
    fi
done

PANDA_COMMON_ARGS=(
    -name "Windows 11 (PANDA experimental)"
    -machine pc-q35-2.9
    -cpu qemu64,vendor=GenuineIntel,+ssse3,+sse4.1,+sse4.2,+popcnt,+cx16,+aes,+xsave,+arat,-svm
    -smp 1,sockets=1,cores=1,threads=1
    -m 4096
    -nodefaults
    -drive "if=pflash,format=raw,unit=0,readonly=on,file=$PANDA_OVMF_CODE"
    -drive "if=pflash,format=raw,unit=1,snapshot=on,file=$PANDA_VARS"
    -drive "if=none,id=win11,format=qcow2,file=$PANDA_DISK,cache=writeback,discard=unmap"
    -device ide-hd,drive=win11,bus=ide.0,bootindex=1
    -device VGA
    -device qemu-xhci,id=xhci
    -device usb-kbd,bus=xhci.0
    -device usb-tablet,bus=xhci.0
    -netdev "user,id=net0,restrict=${PANDA_NETWORK_RESTRICT:-on},hostfwd=tcp:0.0.0.0:2222-:22"
    -device e1000,netdev=net0,mac=08:00:27:BB:A0:A3
    -rtc base=localtime
    -boot menu=on
    -debugcon file:/work/logs/ovmf-debug.log
    -global isa-debugcon.iobase=0x402
)
