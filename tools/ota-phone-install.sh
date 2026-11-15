#!/bin/sh
# Runs on the phone as root (called by ota-update.sh): installs the new kernel
# from /tmp, keeping the currently running (known-good) one as a GRUB fallback.
set -e
dtb=msm8992-msft-lumia-octagon-talkman.dtb
mkdir -p /root/boot-backup
[ -f /root/boot-backup/vmlinuz.orig ] || cp /boot/vmlinuz /root/boot-backup/vmlinuz.orig
[ -f /root/boot-backup/$dtb.orig ] || cp /boot/$dtb /root/boot-backup/$dtb.orig
rm -f /usr/libexec/talkman-usb-exp.sh /var/lib/talkman-usb-exp.stage /var/lib/talkman-usb-exp.bad
# the phone is reachable, so the kernel in /boot works: keep it as the fallback
cp /boot/vmlinuz /boot/vmlinuz.prev
cp /boot/$dtb /boot/$dtb.prev
cp /tmp/vmlinuz /boot/vmlinuz
cp /tmp/$dtb /boot/$dtb
for cfg in $(find /boot -maxdepth 3 -name grub.cfg); do
	grep -q 'previous kernel' "$cfg" && continue
	awk '/^menuentry/{f=1} f{print} f&&/^}/{exit}' "$cfg" \
	  | sed -e 's/^menuentry "[^"]*"/menuentry "previous kernel (fallback)"/' \
	        -e 's#/vmlinuz#/vmlinuz.prev#' \
	        -e 's#\(/msm8992[^ ]*\.dtb\)#\1.prev#' > /tmp/grub-fallback.entry
	if [ -s /tmp/grub-fallback.entry ]; then
		{ echo; cat /tmp/grub-fallback.entry; } >> "$cfg"
		echo "added fallback entry to $cfg"
	fi
done
sync
rm -f /tmp/vmlinuz /tmp/$dtb /tmp/grub-fallback.entry
echo; echo '/boot now:'; ls -la /boot/vmlinuz /boot/vmlinuz.prev /boot/$dtb /boot/$dtb.prev
sha256sum /boot/vmlinuz /boot/$dtb
