#!/bin/sh
# livediag-os: turn a freshly unpacked Alpine rootfs into the test image.
#
# Run inside the image chroot by alpine-make-vm-image --script-chroot.
# Arguments: [livediag-repo] [livediag-ref]

set -eu

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH

LIVEDIAG_REPO="${1:-https://github.com/Nemo-010/livediag}"
LIVEDIAG_REF="${2:-main}"

step() {
    printf '\n\033[1;36m==> %s\033[0m\n' "$*" >&2
}

step "Hostname, timezone and a recovery password"
printf 'livediag\n' > /etc/hostname
setup-timezone -z UTC 2>/dev/null || cp /usr/share/zoneinfo/UTC /etc/localtime
printf 'root:livediag\n' | chpasswd 2>/dev/null || true

step "Use udev instead of mdev"
# Wayland needs a real udev to enumerate DRM and input devices.
for svc in udev udev-trigger udev-settle; do
    rc-update add "$svc" sysinit 2>/dev/null || true
done
rc-update add udev-postmount default 2>/dev/null || true
rc-update del mdev sysinit 2>/dev/null || true
rc-update del hwdrivers sysinit 2>/dev/null || true

step "Enable services"
for svc in dbus seatd networkmanager bluetooth modemmanager local; do
    rc-update add "$svc" default 2>/dev/null || true
done

step "Autologin root on tty1"
sed -i 's#^tty1::respawn:.*#tty1::respawn:/sbin/agetty --autologin root --noclear tty1 38400 linux#' \
    /etc/inittab
if ! grep -q 'agetty --autologin' /etc/inittab; then
    printf 'tty1::respawn:/sbin/agetty --autologin root --noclear tty1 38400 linux\n' \
        >> /etc/inittab
fi
# Leave the serial port free for CI output instead of a getty prompt.
sed -i 's#^ttyS0::respawn:#\#ttyS0::respawn:#' /etc/inittab 2>/dev/null || true

step "Install livediag from $LIVEDIAG_REPO ($LIVEDIAG_REF)"
tmp=$(mktemp -d)
if ! git clone --depth 1 --branch "$LIVEDIAG_REF" "$LIVEDIAG_REPO" "$tmp" 2>/dev/null; then
    git clone --depth 1 "$LIVEDIAG_REPO" "$tmp"
fi
make -C "$tmp" install
rm -rf "$tmp"

step "Friendly touches"
printf 'livediag: nothing here touches your disks.  Look around.\n' > /etc/motd

step "Image configured"
