#!/bin/sh
# Install the RPM watch (debug) on the phone: loads early at every boot and
# logs "rpm-watch:" lines to the kernel log. Also runs it once now for 10 s.
#   sh ~/talkman/tools/install-rpm-watch.sh          install
#   sh ~/talkman/tools/install-rpm-watch.sh remove   uninstall
set -e
phone=ankit@172.16.42.1
if [ "${1:-}" = remove ]; then
	ssh -t "$phone" 'sudo systemctl disable rpm-watch.service; sudo rm -f /etc/systemd/system/rpm-watch.service /usr/local/lib/talkman-cpufreq/rpm-watch.ko; sudo rmmod clk_cpu_8994 2>/dev/null; echo removed'
	exit 0
fi
scp "$HOME/talkman/modules/rpm-watch.ko" "$HOME/talkman/tools/rpm-watch.service" "$phone:/tmp/"
ssh -t "$phone" '
sudo install -Dm644 /tmp/rpm-watch.ko /usr/local/lib/talkman-cpufreq/rpm-watch.ko
sudo install -Dm644 /tmp/rpm-watch.service /etc/systemd/system/rpm-watch.service
sudo systemctl daemon-reload && sudo systemctl enable rpm-watch.service
echo "== test run now (12 s):"
sudo rmmod clk_cpu_8994 2>/dev/null; sudo insmod /usr/local/lib/talkman-cpufreq/rpm-watch.ko rpm_watch_secs=6 && sleep 12
dmesg | grep "rpm-watch" | tail -6
sudo rmmod clk_cpu_8994
echo "installed; reboot to record the boot"'
