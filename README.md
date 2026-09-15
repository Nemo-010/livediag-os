# livediag-os

A small Alpine Linux image that boots straight into
[livediag](https://github.com/Nemo-010/livediag), the live hardware
diagnostics suite.  There is no installer to click through and no greeter to
log into: the machine comes up on a quiet Wayland desktop and asks, in plain
words, whether you would like to see how this computer feels under Linux.

It is meant for install parties and for anyone who wants to test a laptop
risk-free before touching the disks.

## What you get when it boots

* an automatic login as `root` on the first virtual console,
* a lightweight **labwc** Wayland desktop: a soft wallpaper, a small bar with
  the clock and network, a menu and a couple of key bindings,
* a friendly welcome window, and then `livediag` itself,
* Wi-Fi, Bluetooth, audio and mobile broadband already running underneath,
* and the whole livediag checklist: Wi-Fi, sound, keyboard, camera, battery,
  charger, storage integrity, thermals, sensors and the rest.

The desktop is deliberately small.  It is a place to run the tests, not a
daily driver.

## Default credentials

Autologin is enabled for `root`.  The password is `livediag`, so you can also
log in on another virtual console (`Ctrl+Alt+F2`) if the desktop ever has
trouble.  Change it before using the image for anything but testing.

## How it is built

The image is produced with Alpine's own
[`alpine-make-vm-image`](https://github.com/alpinelinux/alpine-make-vm-image),
which installs packages into a chroot and writes a bootable disk image:
BIOS/extlinux for the fast QEMU image, UEFI for real laptops and aarch64.
The livediag repository is cloned **during the build**, inside the chroot, and
installed with its `make install`.  Nothing is vendored.

```
configure.sh                 runs inside the chroot: services, autologin, install
packages                     shared package list
packages.x86_64              extra packages for one architecture
repositories                 Alpine main + community for a pinned branch
overlay/                     files copied verbatim into the image
  etc/profile.d/             starts the session on tty1
  usr/local/bin/             the session, wallpaper and welcome helpers
  root/.config/labwc/        compositor config, autostart and menu
  root/.config/waybar/       the little bar at the top
.github/workflows/build.yml  builds and releases both architectures
run-qemu.sh                  boots a built image for a quick look
```

The desktop is labwc plus `swaybg`, `waybar`, `fuzzel` and `foot`; the
session runs as root with libseat and seatd, so there is no login manager and
no desktop shell to fight with.

## Download

From the [releases](../../releases), pick the one that matches the machine:

| File | Use it for |
| --- | --- |
| `livediag-alpine-x86_64-uefi-*.img.gz` | **a real laptop or desktop** (UEFI, the normal case) |
| `livediag-alpine-x86_64-*.img.gz` | QEMU or an old BIOS machine |
| `livediag-alpine-aarch64-*.img.gz` | ARM machines and VMs |
| `*.qcow2` | QEMU only, do not write it to a stick |

`livediag-alpine-x86_64-uefi-*.img.gz` is the one to hand someone at an
install party.  The default `x86_64` image is BIOS-only because it boots in
seconds in CI; UEFI firmware on a modern laptop will not see it at all.

### Writing it to a USB stick

```sh
gzip -dc livediag-alpine-x86_64-uefi-*.img.gz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
```

Replace `/dev/sdX` with the **USB stick**, never the internal disk.  Check
with `lsblk` first and say it out loud.  Etcher accepts the `.img.gz`
directly if you prefer a GUI.

Secure Boot must be off: this image is unsigned, as most test media is.  The
greeter will not mention it, but `core-firmware` in the report will tell you
whether it is on.

## Try it in QEMU

```sh
./run-qemu.sh x86_64
./run-qemu.sh aarch64
```

Or by hand, for x86_64:

```sh
qemu-system-x86_64 -m 4G -smp 2 \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE.fd \
    -drive if=pflash,format=raw,file=OVMF_VARS.fd \
    -drive file=livediag-alpine-x86_64.qcow2,if=virtio,format=qcow2 \
    -device virtio-net-pci,netdev=n0 -netdev user,id=n0
```

and for aarch64:

```sh
qemu-system-aarch64 -M virt -cpu max -m 4G -smp 2 \
    -bios /usr/share/AAVMF/QEMU_EFI.fd \
    -drive file=livediag-alpine-aarch64.qcow2,if=virtio,format=qcow2 \
    -device virtio-net-pci,netdev=n0 -netdev user,id=n0
```

On Debian/Ubuntu the firmware packages are `ovmf` and `qemu-efi-aarch64`.

## Build it yourself

On any Linux host with `qemu-img`, `qemu-nbd`, `e2fsprogs`, `dosfstools`,
`sfdisk` and `rsync`:

```sh
curl -fsSLO https://raw.githubusercontent.com/alpinelinux/alpine-make-vm-image/v0.13.4/alpine-make-vm-image
chmod +x alpine-make-vm-image
sudo ./alpine-make-vm-image \
    --arch x86_64 \
    --kernel-flavor lts \
    --boot-mode UEFI \
    --image-format qcow2 \
    --image-size 5G \
    --repositories-file repositories \
    --packages "$(grep -vE '^[[:space:]]*(#|$)' packages | tr '\n' ' ')" \
    --fs-skel-dir overlay \
    --fs-skel-chown root:root \
    --script-chroot \
    livediag-alpine-x86_64.qcow2 -- ./configure.sh \
    https://github.com/Nemo-010/livediag main
```

For aarch64, register the architecture in `binfmt_misc` first (on Alpine:
`apk add qemu-aarch64 qemu-openrc && rc-service qemu-binfmt start`) and pass
`--arch aarch64`.

## Releases

`.github/workflows/build.yml` builds x86_64 and aarch64 on every push and
pull request, and on a `v*` tag it attaches the qcow2 and raw images to a
GitHub release.  The aarch64 build runs under QEMU user emulation, the same
way Alpine's own CI does it.

## Customising

* **Different livediag fork or branch** - change `LIVEDIAG_REPO` and
  `LIVEDIAG_REF` in the workflow, or pass them as the last two arguments to
  `configure.sh`.
* **More or fewer packages** - edit `packages`.  `packages.<arch>` is
  appended for that architecture only (`intel-ucode` for x86_64 is the
  example).
* **A different desktop** - replace the labwc configuration in `overlay/`
  and swap the packages; `configure.sh` does not assume a particular
  compositor beyond starting it on tty1.
* **Trim the image** - the curated firmware list is there so real laptops
  have working Wi-Fi and graphics.  Drop the `linux-firmware-*` lines if you
  only care about machines without them.
