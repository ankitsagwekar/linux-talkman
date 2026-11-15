#!/bin/sh
# Collect and fix up the images that "pmbootstrap install --split" produced.
#   1. pmbootstrap shutdown && pmbootstrap install --split      (you: asks passwords)
#   2. sh ~/talkman/tools/make-image.sh [output-dir]
# Writes root image, boot image and the loose boot files (vmlinuz, initramfs,
# dtb, grub.cfg) to the output dir (default ~/talkman/stable/r39/image).
set -eu
out="${1:-$HOME/talkman/stable/r39/image}"
W="$HOME/.local/var/pmbootstrap"
src="$W/chroot_native/home/pmos/rootfs"
root="$src/microsoft-talkman-root.img"; boot="$src/microsoft-talkman-boot.img"
[ -f "$root" ] || { echo "no $root: run pmbootstrap install --split first" >&2; exit 1; }
DBG=/usr/sbin/debugfs
mkdir -p "$out"; tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
echo "== Copying images ..."
cp "$root" "$out/microsoft-talkman-root.img"
[ -f "$boot" ] && cp "$boot" "$out/microsoft-talkman-boot.img"
img="$out/microsoft-talkman-root.img"

echo "== fstab: mount by label (the UUIDs do not survive dd onto the phone)"
$DBG -R 'cat /etc/fstab' "$img" 2>/dev/null > "$tmp/fstab"
sed -E 's#^UUID=[0-9A-Fa-f-]+ /boot #LABEL=pmOS_boot /boot #; s#^UUID=[0-9a-f-]+ / #LABEL=pmOS_root / #' "$tmp/fstab" > "$tmp/fstab.new"
$DBG -w -R "rm /etc/fstab" "$img" 2>/dev/null
$DBG -w -R "write $tmp/fstab.new /etc/fstab" "$img" 2>/dev/null
$DBG -w -R "sif /etc/fstab mode 0100644" "$img" 2>/dev/null
$DBG -R 'cat /etc/fstab' "$img" 2>/dev/null

echo "== services: make sure the talkman units are enabled"
for u in talkman-wifi talkman-cpufreq talkman-usb-debug; do
	if $DBG -R "stat /usr/lib/systemd/system/$u.service" "$img" 2>/dev/null | grep -q "Inode:"; then
		$DBG -R "stat /etc/systemd/system/multi-user.target.wants/$u.service" "$img" 2>/dev/null | grep -q "Inode:" || \
			$DBG -w -R "symlink /etc/systemd/system/multi-user.target.wants/$u.service /usr/lib/systemd/system/$u.service" "$img" 2>/dev/null
		echo "   $u: $($DBG -R "stat /etc/systemd/system/multi-user.target.wants/$u.service" "$img" 2>/dev/null | grep -c 'Type: symlink') symlink"
	fi
done
/usr/sbin/e2fsck -fn "$img" 2>&1 | tail -1

echo "== loose boot files (for the existing GRUB on pmOS_boot)"
rb="$W/chroot_rootfs_microsoft-talkman/boot"
for f in vmlinuz initramfs; do sudo cp "$rb/$f" "$out/$f" 2>/dev/null || cp "$rb/$f" "$out/$f"; done
dtb=msm8992-msft-lumia-octagon-talkman.dtb
d=$(sudo find "$rb" -name "$dtb" | head -1); sudo cp "$d" "$out/$dtb"
sudo chown "$(id -u):$(id -g)" "$out"/vmlinuz "$out"/initramfs "$out/$dtb"
cp "$HOME/talkman/update/grub.cfg" "$out/grub.cfg"
( cd "$out" && sha256sum * > SHA256SUMS && ls -la )
echo "== Done: $out"
