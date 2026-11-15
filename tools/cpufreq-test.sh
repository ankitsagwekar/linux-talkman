#!/bin/sh
# Load the CPU frequency scaling modules on the phone on demand, one stage at a
# time, with the kernel log streamed to this PC.
#   sh ~/talkman/tools/cpufreq-test.sh 1     # stage 1: CPU clock driver only
#   sh ~/talkman/tools/cpufreq-test.sh 1 ~/talkman/modules/clk-cpu-8994-debug.ko   # use another .ko
#   sh ~/talkman/tools/cpufreq-test.sh 2     # stage 2: cpufreq-dt (starts changing frequency)
# Needs kernel r19+. If the phone freezes, photograph the screen, then hold
# power + volume down ~10 s: the modules are blocked from auto-loading.
set -u
stage="${1:-1}"
ko="${2:-}"
phone=ankit@172.16.42.1
logdir="$HOME/talkman/logs"; mkdir -p "$logdir"
log="$logdir/cpufreq-stage$stage-$(date +%Y%m%d-%H%M%S).log"
M=/usr/local/lib/talkman-cpufreq

echo "== Checking the phone ..."
ssh -o ConnectTimeout=5 "$phone" 'uname -v; ls '$M || { echo "phone not reachable" >&2; exit 1; }
echo "== Streaming the kernel log to $log"
ssh -o ServerAliveInterval=2 -o ServerAliveCountMax=3 "$phone" 'dmesg -w' > "$log" 2>&1 &
streamer=$!
sleep 2
echo "== Loading stage $stage (sudo password for ankit on the phone)"
case "$stage" in
1) if [ -n "$ko" ]; then scp "$ko" "$phone:/tmp/clk-cpu-8994.ko" || exit 1; K=/tmp/clk-cpu-8994.ko; else K=$M/clk-cpu-8994.ko; fi
   cmd="rmmod clk_cpu_8994 2>/dev/null; insmod $K" ;;
2) cmd="insmod $M/cpufreq-dt.ko" ;;
*) echo "stage must be 1 or 2" >&2; kill $streamer; exit 1 ;;
esac
timeout --foreground 90 ssh -t -o ServerAliveInterval=2 -o ServerAliveCountMax=3 "$phone" "
	sudo sh -c 'echo \"CPUFREQ-TEST stage $stage\" > /dev/kmsg; $cmd'; echo \"insmod returned: \$?\"
	sleep 4
	echo; echo cpufreq:; ls /sys/devices/system/cpu/cpu0/cpufreq /sys/devices/system/cpu/cpu4/cpufreq 2>&1 | head -30
	for c in 0 4; do f=/sys/devices/system/cpu/cpu\$c/cpufreq; [ -r \$f/scaling_cur_freq ] && echo \"cpu\$c: \$(cat \$f/scaling_cur_freq) kHz, governor \$(cat \$f/scaling_governor), available \$(cat \$f/scaling_available_frequencies 2>/dev/null)\"; done
"
rc=$?
sleep 3
kill "$streamer" 2>/dev/null
echo
echo "== ssh exit code: $rc  (124/255 = the phone probably froze)"
echo "== Log since the marker:"
sed -n '/CPUFREQ-TEST/,$p' "$log" | cut -c1-200 | head -40
echo "Full log: $log"
