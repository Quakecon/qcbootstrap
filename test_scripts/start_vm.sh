#!/bin/bash

set -e
set -u

RAM=2048 # Megabytes

RANDOM_MAC=$( printf 'DE:AD:BE:EF:%02X:%02X' $((RANDOM%256)) $((RANDOM%256)))

if [ $# -lt 1 ]; then
    echo "Usage: start_vm.sh <image_file> [other args passed to qemu]"
    exit 1
fi

qemu-system-x86_64 -enable-kvm -m $RAM \
		   -drive file=${1},if=virtio,format=raw \
		   -net bridge,br=qc0  -net nic,model=virtio,macaddr="$RANDOM_MAC" "${@:2}" &


