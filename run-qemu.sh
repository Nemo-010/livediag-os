#!/bin/sh
# Boot a built livediag image in QEMU for a quick look.
#
# usage: ./run-qemu.sh [x86_64|aarch64] [image.qcow2]
#
# Environment: RAM (MiB, default 4096), CPUS (default 2).

set -eu

arch=${1:-$(uname -m)}
image=${2:-livediag-alpine-$arch.qcow2}
RAM=${RAM:-4096}
CPUS=${CPUS:-2}

if [ ! -f "$image" ]; then
    echo "run-qemu: no such image: $image" >&2
    echo "usage: $0 [x86_64|aarch64] [image.qcow2]" >&2
    exit 1
fi

# shellcheck disable=SC2086
common="-m $RAM -smp $CPUS -device virtio-net-pci,netdev=n0 -netdev user,id=n0"

find_file() {
    for f in "$@"; do
        if [ -f "$f" ]; then
            printf '%s\n' "$f"
            return 0
        fi
    done
    return 1
}

case "$arch" in
x86_64)
    code=$(find_file \
        /usr/share/OVMF/OVMF_CODE.fd \
        /usr/share/OVMF/OVMF_CODE.secboot.fd \
        /usr/share/edk2/x64/OVMF_CODE.fd \
        /usr/share/edk2-ovmf/x64/OVMF_CODE.fd) || {
        echo "run-qemu: OVMF firmware not found (install ovmf / edk2-ovmf)" >&2
        exit 1
    }
    vars_src=$(find_file \
        /usr/share/OVMF/OVMF_VARS.fd \
        /usr/share/edk2/x64/OVMF_VARS.fd \
        /usr/share/edk2-ovmf/x64/OVMF_VARS.fd) || vars_src=

    if [ -n "$vars_src" ]; then
        cp "$vars_src" ./OVMF_VARS.fd
        set -- -drive if=pflash,format=raw,readonly=on,file="$code" \
            -drive if=pflash,format=raw,file=./OVMF_VARS.fd
    else
        set -- -bios "$code"
    fi
    exec qemu-system-x86_64 $common "$@" \
        -drive file="$image",if=virtio,format=qcow2
    ;;
aarch64)
    efi=$(find_file \
        /usr/share/AAVMF/QEMU_EFI.fd \
        /usr/share/edk2/aarch64/QEMU_EFI.fd \
        /usr/share/qemu-efi-aarch64/QEMU_EFI.fd) || {
        echo "run-qemu: aarch64 UEFI firmware not found (install qemu-efi-aarch64)" >&2
        exit 1
    }
    exec qemu-system-aarch64 -M virt -cpu max -bios "$efi" $common \
        -drive file="$image",if=virtio,format=qcow2
    ;;
*)
    echo "run-qemu: unsupported architecture: $arch" >&2
    exit 1
    ;;
esac
