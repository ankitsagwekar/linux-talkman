#!/bin/sh
# Remove the USB experiment script from the phone (mass-storage mode), so
# nothing pokes USB registers at boot. The read-only diagnostics stay.
#   sudo sh ~/talkman/tools/remove-exp.sh
set -eu
dev=/dev/disk/by-partlabel/pmOS_root
[ -b "$dev" ] || { echo "pmOS_root not found: put the phone in mass-storage mode" >&2; exit 1; }
mnt=$(mktemp -d)
mount -t ext4 "$dev" "$mnt"
trap 'umount "$mnt"; rmdir "$mnt"' EXIT
rm -f "$mnt/usr/libexec/talkman-usb-exp.sh" "$mnt/var/lib/talkman-usb-exp.stage" "$mnt/var/lib/talkman-usb-exp.bad"
sync
echo "Removed the USB experiment script from the phone."
