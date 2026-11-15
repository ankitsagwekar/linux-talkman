#!/bin/sh
# Copy kernel modules from the newest kernel package in ~/talkman/ota into the
# phone's /lib/modules and refresh the module index, so they auto-load.
#   sh ~/talkman/tools/install-modules.sh path/inside/kernel/dir.ko [...]
#   e.g. sh ~/talkman/tools/install-modules.sh drivers/power/supply/qcom-pmi8994-fg.ko
set -eu
phone=ankit@172.16.42.1
pkg=$(ls -t "$HOME"/talkman/ota/linux-postmarketos-qcom-msm8994-*.apk | head -1)
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
tar -xzf "$pkg" -C "$work" 2>/dev/null
K=lib/modules/6.16.0/kernel
cmd="set -e"
for m in "$@"; do
	[ -f "$work/$K/$m" ] || { echo "not in $(basename "$pkg"): $m" >&2; exit 1; }
	scp "$work/$K/$m" "$phone:/tmp/$(basename "$m")"
	cmd="$cmd; sudo install -Dm644 /tmp/$(basename "$m") /$K/$m; rm -f /tmp/$(basename "$m")"
done
echo "== Installing $# module(s) from $(basename "$pkg") (sudo password for ankit on the phone)"
ssh -t "$phone" "$cmd; sudo depmod -a 6.16.0; echo installed"
