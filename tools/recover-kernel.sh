#!/bin/sh
# Restore a booting kernel when the phone hangs at boot.
# Put the phone in mass-storage mode (WPinternals), plug it into THIS Linux PC, then:
#   sh ~/talkman/tools/recover-kernel.sh
# Installs the newest kernel package from ~/talkman/ota (r19+: CPU frequency
# scaling is a module, off by default), keeps the old kernel as vmlinuz.prev,
# adds a "previous kernel" GRUB entry and blocks the cpufreq modules from
# auto-loading. Asks for your PC sudo password.
set -eu
dtb=msm8992-msft-lumia-octagon-talkman.dtb
pkg="${1:-$(ls -t "$HOME"/talkman/ota/linux-postmarketos-qcom-msm8994-*.apk | head -1)}"
[ -f "$pkg" ] || { echo "package not found: $pkg" >&2; exit 1; }
B=/dev/disk/by-partlabel/pmOS_boot
R=/dev/disk/by-partlabel/pmOS_root
test -b "$B" && test -b "$R" || { echo "phone partitions not found: is it in mass-storage mode?" >&2; exit 1; }

work=$(mktemp -d); mb=$work/boot; mr=$work/root; mkdir -p "$mb" "$mr" "$work/pkg"
cleanup() { sudo umount "$mb" 2>/dev/null || true; sudo umount "$mr" 2>/dev/null || true; rm -rf "$work"; }
trap cleanup EXIT
tar -xzf "$pkg" -C "$work/pkg" 2>/dev/null
[ -f "$work/pkg/boot/vmlinuz" ] || { echo "no vmlinuz in $pkg" >&2; exit 1; }
echo "== Package: $(basename "$pkg")"

sudo mount "$B" "$mb"
echo "== pmOS_boot contains:"; ls "$mb"
# keep the current kernel as the fallback if it is a different file
if ! cmp -s "$mb/vmlinuz" "$work/pkg/boot/vmlinuz"; then
	[ -f "$mb/vmlinuz.prev" ] || sudo cp "$mb/vmlinuz" "$mb/vmlinuz.prev"
	[ -f "$mb/$dtb.prev" ] || sudo cp "$mb/$dtb" "$mb/$dtb.prev"
fi
sudo cp "$work/pkg/boot/vmlinuz" "$mb/vmlinuz"
sudo cp "$work/pkg/boot/dtbs/qcom/$dtb" "$mb/$dtb"
for cfg in $(sudo find "$mb" -maxdepth 4 -name grub.cfg); do
	echo "== GRUB config: ${cfg#$mb}"
	sudo grep -q 'previous kernel' "$cfg" && continue
	sudo awk '/^menuentry/{f=1} f{print} f&&/^}/{exit}' "$cfg" \
	  | sed -e 's/^menuentry "[^"]*"/menuentry "previous kernel (fallback)"/' \
	        -e 's#/vmlinuz#/vmlinuz.prev#' -e 's#\(/msm8992[^ ]*\.dtb\)#\1.prev#' > "$work/entry"
	[ -s "$work/entry" ] && { echo; cat "$work/entry"; } | sudo tee -a "$cfg" >/dev/null && echo "   fallback entry added"
done
sync; sudo umount "$mb"

sudo mount "$R" "$mr"
sudo mkdir -p "$mr/usr/local/lib/talkman-cpufreq"
sudo cp "$work/pkg/lib/modules/6.16.0/kernel/drivers/clk/qcom/clk-cpu-8994.ko" \
        "$work/pkg/lib/modules/6.16.0/kernel/drivers/cpufreq/cpufreq-dt.ko" "$mr/usr/local/lib/talkman-cpufreq/"
printf 'install clk_cpu_8994 /bin/false\ninstall cpufreq_dt /bin/false\n' | sudo tee "$mr/etc/modprobe.d/talkman-cpufreq.conf" >/dev/null
sync; sudo umount "$mr"
echo "== Done. Unplug, power the phone on and boot normally."
