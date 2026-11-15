#!/bin/sh
# Start the Wi-Fi PCIe bring-up on the phone on demand and capture the log.
#   sh ~/talkman/tools/pcie-test.sh
# The kernel must be r14 or newer (driver gated by msm8994_enable).
# If the phone freezes, note the LAST "pcie-trace:" line on its screen (a
# photo is ideal), then hold power + volume down ~10 s and boot again: PCIe
# is off by default after every boot.
set -u

phone=ankit@172.16.42.1
logdir="$HOME/talkman/logs"
mkdir -p "$logdir"
log="$logdir/pcie-$(date +%Y%m%d-%H%M%S).log"

echo "== Checking the phone ..."
ssh -o ConnectTimeout=5 "$phone" 'uname -v; ls /sys/module/*/parameters/msm8994_enable 2>&1' || {
	echo "phone not reachable" >&2; exit 1; }

echo "== Streaming the phone's kernel log to $log"
ssh -o ServerAliveInterval=2 -o ServerAliveCountMax=3 "$phone" 'dmesg -w' > "$log" 2>&1 &
streamer=$!
sleep 2
echo "(log stream started, pid $streamer)"
echo
echo "== Starting the PCIe bring-up (sudo password for ankit on the phone)"
echo "   If the phone freezes, photograph its screen, then hold power + volume down ~10 s."
timeout --foreground 120 ssh -t -o ServerAliveInterval=2 -o ServerAliveCountMax=3 "$phone" '
	p=$(ls /sys/module/*/parameters/msm8994_enable | head -1)
	echo "parameter: $p"
	sudo sh -c "echo 1 > $p; echo fc520000.pcie > /sys/bus/platform/drivers/qcom-pcie/bind"
	echo "bind returned: $?"
	sleep 5
	echo; echo "PCI devices:"; ls /sys/bus/pci/devices/ 2>&1
	for d in /sys/bus/pci/devices/*; do [ -e "$d" ] && echo "$d vendor=$(cat $d/vendor) device=$(cat $d/device)"; done
	echo; echo "Wi-Fi interfaces:"; ls /sys/class/ieee80211/ 2>&1; ls /sys/class/net
'
rc=$?
sleep 3
kill "$streamer" 2>/dev/null
echo
echo "== ssh exit code: $rc  (124 = timed out, i.e. the phone probably froze)"
echo "== Last trace lines captured:"
grep -E 'pcie-trace|qcom-pcie|pci |ath10k|PME|link' "$log" | tail -30
echo
echo "Full log: $log"
