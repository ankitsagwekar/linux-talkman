#!/bin/sh
# Capture which PCIe transaction the root port rejects during an ath10k probe.
#   sh ~/talkman/tools/wifi-lab2.sh
# Clears the root port's error registers, runs ONE ath10k_pci probe, then
# reads the error status and the logged header of the offending TLP.
set -u

phone=ankit@172.16.42.1
logdir="$HOME/talkman/logs"
mkdir -p "$logdir"
out="$logdir/wifi-lab2-$(date +%Y%m%d-%H%M%S).txt"

cat > /tmp/wifi-lab2-phone.sh <<'EOF'
#!/bin/sh
RP=/usr/local/bin/regpoke
BD=0000:01:00.0
P=/sys/module/ath10k_pci/parameters
r() { printf '%s=%s ' "$1" "$($RP r "$2" 2>&1)"; }
rcregs() {
	r DEVCTL_STA 0xff000078; r AER_UE 0xff000104; r AER_UE_MASK 0xff000108; r AER_UE_SEV 0xff00010c
	r AER_CE 0xff000110; r AER_CAP_CTL 0xff000118; echo
	r HDRLOG0 0xff00011c; r HDRLOG1 0xff000120; r HDRLOG2 0xff000124; r HDRLOG3 0xff000128; echo
	r ROOT_CMD 0xff00012c; r ROOT_STA 0xff000130; r ERR_SRC_ID 0xff000134; echo
	r PARF_INT_ALL_STATUS 0xfc520224; r PARF_INT_MASK 0xfc52022c; echo
}
clear_errs() {
	$RP w 0xff000104 0xffffffff > /dev/null 2>&1
	$RP w 0xff000110 0xffffffff > /dev/null 2>&1
	$RP w 0xff000130 0xffffffff > /dev/null 2>&1
	d=$($RP r 0xff000078); $RP w 0xff000078 $(printf '0x%x' $((d | 0x000f0000))) > /dev/null 2>&1
	$RP w 0xfc520228 0xffffffff > /dev/null 2>&1
}

echo "===== $(date) kernel $(uname -v)"
[ -d /sys/bus/pci/devices/$BD ] || { echo "endpoint $BD not present: bring PCIe up and rescan first"; exit 1; }
echo "--- before clearing"; rcregs
clear_errs
echo "--- after clearing"; rcregs
echo 0 > $P/reset_mode; echo 0 > $P/irq_mode
echo "WIFI-LAB2 start" > /dev/kmsg
echo $BD > /sys/bus/pci/drivers/ath10k_pci/unbind 2>/dev/null
sleep 1
echo "--- after unbind"; rcregs
clear_errs
echo $BD > /sys/bus/pci/drivers/ath10k_pci/bind 2>/dev/null
sleep 5
echo "--- after one probe"; rcregs
echo "--- dmesg"
dmesg | sed -n '/WIFI-LAB2 start/,$p' | tail -n +2 | head -30
echo "===== done"
EOF

echo "== Copying the script to the phone ..."
scp /tmp/wifi-lab2-phone.sh "$phone:/tmp/wifi-lab2-phone.sh" || exit 1
echo "== Running it as root (sudo password for ankit on the phone) ..."
timeout --foreground 90 ssh -t "$phone" 'sudo sh /tmp/wifi-lab2-phone.sh > /tmp/wifi-lab2.txt 2>&1; sudo chmod a+r /tmp/wifi-lab2.txt; echo "written: $(wc -l < /tmp/wifi-lab2.txt) lines"'
scp "$phone:/tmp/wifi-lab2.txt" "$out" && echo "== Saved: $out"
