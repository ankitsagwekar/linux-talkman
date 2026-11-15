#!/bin/sh
# Copy the USB experiment tools onto the phone (mass-storage mode).
#   sudo sh ~/talkman/tools/install-exp.sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
dev=/dev/disk/by-partlabel/pmOS_root
[ -b "$dev" ] || { echo "pmOS_root not found: put the phone in mass-storage mode" >&2; exit 1; }
mnt=$(mktemp -d)
mount -t ext4 "$dev" "$mnt"
trap 'umount "$mnt"; rmdir "$mnt"' EXIT
install -D -m755 -o0 -g0 "$here/regpoke" "$mnt/usr/local/bin/regpoke"
install -D -m755 -o0 -g0 "$here/talkman-usb-exp.sh" "$mnt/usr/libexec/talkman-usb-exp.sh"
install -D -m755 -o0 -g0 "$here/../device-microsoft-talkman/talkman-usb-debug.sh" "$mnt/usr/libexec/talkman-usb-debug.sh"
rm -f "$mnt/var/lib/talkman-usb-exp.stage" "$mnt/var/lib/talkman-usb-exp.bad" "$mnt/var/log/talkman-usb-exp.txt"
sync
echo "Installed regpoke + USB experiment scripts on the phone."
