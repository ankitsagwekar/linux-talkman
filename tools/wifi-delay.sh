#!/bin/sh
# Find what ath10k_pci waits on during probe: rebind it and sample kernel stacks.
#   sh ~/talkman/tools/wifi-delay.sh      (needs the chip enumerated: 0000:01:00.0)
set -u
phone=ankit@172.16.42.1
out="$HOME/talkman/logs/wifi-delay-$(date +%Y%m%d-%H%M%S).txt"
cat > /tmp/wifi-delay-phone.sh <<'PHONE'
#!/bin/sh
BD=0000:01:00.0
D=/sys/bus/pci/drivers/ath10k_pci
[ -e /sys/bus/pci/devices/$BD ] || { echo "chip not enumerated"; exit 1; }
echo "===== $(date) $(uname -v)"
echo "DELAY-LAB start" > /dev/kmsg
[ -e $D/$BD ] && echo $BD > $D/unbind
sleep 1
( echo $BD > $D/bind ) &
t0=$(cut -d. -f1 /proc/uptime)
n=0
while [ $n -lt 50 ]; do
	sleep 3; n=$((n+1))
	now=$(cut -d. -f1 /proc/uptime)
	echo "--- t=+$((now-t0))s"
	for p in /proc/[0-9]*; do
		s=$(cat $p/stack 2>/dev/null) || continue
		case "$s" in *ath10k*|*firmware*|*request_firmware*|*fw_*|*pci_*) echo "[$(basename $p) $(cat $p/comm)]"; echo "$s" | head -14;; esac
	done
	[ -d /sys/class/ieee80211/phy0 ] && { echo "phy0 present"; break; }
done
echo "--- dmesg"; dmesg | sed -n '/DELAY-LAB start/,$p' | cut -c1-200
PHONE
scp /tmp/wifi-delay-phone.sh $phone:/tmp/ || exit 1
timeout --foreground 220 ssh -t $phone 'sudo sh /tmp/wifi-delay-phone.sh > /tmp/wifi-delay.txt 2>&1; sudo chmod a+r /tmp/wifi-delay.txt; wc -l < /tmp/wifi-delay.txt'
scp $phone:/tmp/wifi-delay.txt "$out" && echo "== Saved: $out"
