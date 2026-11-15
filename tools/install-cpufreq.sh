#!/bin/sh
# Install CPU frequency scaling on the phone: the two modules from the newest
# kernel package in ~/talkman/ota plus the after-boot loader service.
#   sh ~/talkman/tools/install-cpufreq.sh
# Install the matching kernel first (ota-update.sh), then reboot.
set -eu
phone=ankit@172.16.42.1
pkg="${1:-$(ls -t "$HOME"/talkman/ota/linux-postmarketos-qcom-msm8994-*.apk | head -1)}"
dev="$HOME/talkman/device-microsoft-talkman"
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
tar -xzf "$pkg" -C "$work" 2>/dev/null
k="$work/lib/modules/6.16.0/kernel/drivers"
cp "$k/clk/qcom/clk-cpu-8994.ko" "$k/cpufreq/cpufreq-dt.ko" \
   "$dev/talkman-cpufreq.sh" "$dev/talkman-cpufreq.service" "$dev/talkman-cpufreq.conf" "$work/"
echo "== Modules from $(basename "$pkg")"
cd "$work" && scp clk-cpu-8994.ko cpufreq-dt.ko talkman-cpufreq.sh talkman-cpufreq.service talkman-cpufreq.conf "$phone:/tmp/"
ssh -t "$phone" '
set -e
sudo install -Dm644 /tmp/clk-cpu-8994.ko /usr/local/lib/talkman-cpufreq/clk-cpu-8994.ko
sudo install -Dm644 /tmp/cpufreq-dt.ko /usr/local/lib/talkman-cpufreq/cpufreq-dt.ko
sudo rm -f /usr/local/lib/talkman-cpufreq/rpm-watch.ko /var/lib/talkman-cpufreq.loading
sudo install -Dm755 /tmp/talkman-cpufreq.sh /usr/libexec/talkman-cpufreq.sh
sudo install -Dm644 /tmp/talkman-cpufreq.service /etc/systemd/system/talkman-cpufreq.service
sudo install -Dm644 /tmp/talkman-cpufreq.conf /etc/modprobe.d/talkman-cpufreq.conf
sudo systemctl daemon-reload
sudo systemctl enable talkman-cpufreq.service
rm -f /tmp/clk-cpu-8994.ko /tmp/cpufreq-dt.ko /tmp/talkman-cpufreq.*
echo "installed; reboot to start it"'
