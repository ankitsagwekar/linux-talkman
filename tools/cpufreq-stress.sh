#!/bin/sh
# Load CPU frequency scaling with a given A57 cap / ACC mode, then run a 60 s
# all-core load and sample frequencies + temperatures. Kernel log is streamed
# to this PC, so a freeze still leaves a log.
#   sh ~/talkman/tools/cpufreq-stress.sh <a57-max-kHz> <acc-mode>
#      acc-mode: 0 = SCM (unsupported on Lumia), 1 = skip, 2 = direct MMIO
#   e.g. sh ~/talkman/tools/cpufreq-stress.sh 960000 2
set -u
max="${1:-960000}"; acc="${2:-1}"; secs="${3:-60}"
phone=ankit@172.16.42.1
logdir="$HOME/talkman/logs"; mkdir -p "$logdir"
log="$logdir/cpufreq-stress-${max}-acc${acc}-$(date +%H%M%S).log"
ko="${KO:-$HOME/talkman/modules/clk-cpu-8994-trace2.ko}"

scp "$ko" "$phone:/tmp/clk-cpu-8994.ko" || exit 1
cat > /tmp/cpufreq-stress-phone.sh <<PHONE
#!/bin/sh
M=/usr/local/lib/talkman-cpufreq
echo "STRESS-TEST a57max=$max acc=$acc" > /dev/kmsg
if [ ! -d /sys/devices/system/cpu/cpu4/cpufreq ]; then
	rmmod clk_cpu_8994 2>/dev/null
	insmod /tmp/clk-cpu-8994.ko || exit 1
	P=/sys/module/clk_cpu_8994/parameters; [ -w \$P/trace_pause_ms ] && echo ${PAUSE:-0} > \$P/trace_pause_ms
	sleep 1
	insmod \$M/cpufreq-dt.ko || exit 1
	sleep 2
else
	P=/sys/module/clk_cpu_8994/parameters
	[ -w \$P/a57_acc ] && echo $acc > \$P/a57_acc
	[ -w \$P/a57_pause_ms ] && echo 0 > \$P/a57_pause_ms
	[ -w \$P/trace_pause_ms ] && echo ${PAUSE:-0} > \$P/trace_pause_ms
fi
echo $max > /sys/devices/system/cpu/cpu4/cpufreq/scaling_max_freq
echo "cpu4 max now \$(cat /sys/devices/system/cpu/cpu4/cpufreq/scaling_max_freq)"
for i in 1 2 3 4 5 6; do timeout $secs sh -c 'while :; do :; done' & done
t=0; while [ \$t -lt $secs ]; do t=\$((t + 10));
	sleep 10
	echo "t=\${t}s a53=\$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq) a57=\$(cat /sys/devices/system/cpu/cpu4/cpufreq/scaling_cur_freq) temp=\$(cat /sys/class/thermal/thermal_zone*/temp | tr '\n' ' ')" | tee /dev/kmsg
done
wait
echo "STRESS-TEST passed" | tee /dev/kmsg
PHONE
scp /tmp/cpufreq-stress-phone.sh "$phone:/tmp/" || exit 1
ssh -o ServerAliveInterval=2 -o ServerAliveCountMax=3 "$phone" 'dmesg -w' > "$log" 2>&1 &
streamer=$!
sleep 2
echo "== A57 cap ${max} kHz, ACC mode ${acc}; 60 s load (sudo password for ankit on the phone)"
timeout --foreground $((secs + 60)) ssh -t -o ServerAliveInterval=2 -o ServerAliveCountMax=3 "$phone" 'sudo sh /tmp/cpufreq-stress-phone.sh'
rc=$?
sleep 2; kill $streamer 2>/dev/null
echo "== ssh exit code: $rc (0 = survived)"
grep -E "STRESS-TEST|t=[0-9]+s|acc mmio now|Oops|Internal error" "$log" | tail -12
echo "Full log: $log"
