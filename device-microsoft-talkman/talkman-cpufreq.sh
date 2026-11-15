#!/bin/sh
# Load CPU frequency scaling (clk-cpu-8994 + cpufreq-dt) once the phone is up.
# Both are modules kept from auto-loading (/etc/modprobe.d/talkman-cpufreq.conf)
# so a bad clock setup can never stop the phone from booting. If a previous
# boot died while they were loading, skip them until the guard is removed.
M=/usr/local/lib/talkman-cpufreq
G=/var/lib/talkman-cpufreq.loading

if [ -e "$G" ]; then
	echo "previous boot crashed while loading CPU frequency scaling: skipped (rm $G to retry)"
	exit 0
fi
[ -f "$M/clk-cpu-8994.ko" ] && [ -f "$M/cpufreq-dt.ko" ] || exit 0

mkdir -p /var/lib
touch "$G"; sync
insmod "$M/clk-cpu-8994.ko" || { rm -f "$G"; exit 1; }
# let the clock driver finish parking the clusters before cpufreq starts
sleep 2
insmod "$M/cpufreq-dt.ko" || { rm -f "$G"; exit 1; }
echo "CPU frequency scaling on: A53 $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies 2>/dev/null)/ A57 $(cat /sys/devices/system/cpu/cpu4/cpufreq/scaling_available_frequencies 2>/dev/null)"
# a minute of normal frequency switching without a crash clears the guard
sleep 60
rm -f "$G"; sync
