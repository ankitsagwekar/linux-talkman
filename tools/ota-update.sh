#!/bin/sh
# Update the kernel image + device tree on the phone over USB networking.
#   sh ~/talkman/tools/ota-update.sh [package.apk]
# Run on the PC with the phone booted and reachable at 172.16.42.1.
# Only vmlinuz and the .dtb are replaced (no apk, no network on the phone
# needed): modules and initramfs are unchanged between these builds.
# Asks for the phone's sudo password.
set -eu

phone=ankit@172.16.42.1
pkg="${1:-$(ls -t "$HOME"/talkman/ota/linux-postmarketos-qcom-msm8994-*.apk | head -1)}"
[ -f "$pkg" ] || { echo "package not found: $pkg" >&2; exit 1; }
dtb=msm8992-msft-lumia-octagon-talkman.dtb

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
tar -xzf "$pkg" -C "$work" 2>/dev/null
[ -f "$work/boot/vmlinuz" ] || { echo "no boot/vmlinuz in package" >&2; exit 1; }
[ -f "$work/boot/dtbs/qcom/$dtb" ] || { echo "no $dtb in package" >&2; exit 1; }

echo "== Package: $(basename "$pkg")"
echo "== Phone now:"
ssh "$phone" 'uname -v'

echo "== Copying vmlinuz and $dtb ..."
scp "$work/boot/vmlinuz" "$work/boot/dtbs/qcom/$dtb" "$HOME/talkman/tools/ota-phone-install.sh" "$phone:/tmp/"

echo "== Installing (sudo password for ankit on the phone) ..."
ssh -t "$phone" "sudo sh /tmp/ota-phone-install.sh; rm -f /tmp/ota-phone-install.sh"

echo
echo "== Done. Reboot the phone when ready:"
echo "     ssh -t $phone 'sudo reboot'"
echo "   then pick UEFI -> GRUB as usual."
