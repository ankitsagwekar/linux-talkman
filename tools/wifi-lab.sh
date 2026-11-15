#!/bin/sh
# Wi-Fi experiments on the phone (PCIe already brought up and the chip
# enumerated, e.g. after pcie-test.sh + a PCI rescan). Non-destructive:
# reads PCIe error/status registers, then retries ath10k_pci with different
# reset_mode / irq_mode values and records what happens.
#   sh ~/talkman/tools/wifi-lab.sh
set -u

phone=ankit@172.16.42.1
logdir="$HOME/talkman/logs"
mkdir -p "$logdir"
out="$logdir/wifi-lab-$(date +%Y%m%d-%H%M%S).txt"

cat > /tmp/wifi-lab-phone.sh <<'EOF'
#!/bin/sh
RP=/usr/local/bin/regpoke
BD=0000:01:00.0
D=/sys/bus/pci/devices/$BD
P=/sys/module/ath10k_pci/parameters
r() { printf '%s=%s ' "$1" "$($RP r "$2" 2>&1)"; }

echo "===== $(date) kernel $(uname -v)"
if [ ! -d $D ]; then
	echo "Endpoint $BD not present: bring PCIe up and rescan first"; exit 1
fi
echo "--- endpoint config space (first 64 bytes)"; od -A x -t x1 -N 64 $D/config
echo "--- root port + endpoint PCI state"
r RC_DEVCTL_STA 0xff000078; r RC_LNKSTA 0xff000080; r RC_AER_UE 0xff000104; r RC_AER_CE 0xff000110; r RC_AER_HDR0 0xff00011c; echo
r PARF_MHI_CLK_RST 0xfc520174; r PARF_AXI_WR_HALT 0xfc520178; r PARF_PM_CTRL 0xfc520020; r PARF_SYS_CTRL 0xfc520000; echo
echo "--- endpoint BAR0 window (0xff400000): first dwords"
for o in 0x0 0x4 0x8 0xc 0x10; do printf '%s ' "$($RP r $((0xff400000 + o)) 2>&1)"; done; echo
echo "--- params: irq_mode=$(cat $P/irq_mode) reset_mode=$(cat $P/reset_mode)"

try() { # reset_mode irq_mode
	echo "$1" > $P/reset_mode; echo "$2" > $P/irq_mode
	echo "WIFI-LAB reset_mode=$1 irq_mode=$2" > /dev/kmsg
	echo $BD > /sys/bus/pci/drivers/ath10k_pci/unbind 2>/dev/null
	sleep 1
	echo $BD > /sys/bus/pci/drivers/ath10k_pci/bind 2>/dev/null
	sleep 5
	echo "=== reset_mode=$1 irq_mode=$2"
	dmesg | sed -n '/WIFI-LAB reset_mode='"$1"' irq_mode='"$2"'/,$p' | tail -n +2 | grep -v 'WIFI-LAB' | head -25
	ls /sys/class/ieee80211/ 2>/dev/null | sed 's/^/ieee80211: /'
}
for rm in 0 1 2; do
	for im in 0 1 2; do try $rm $im; done
done
echo "--- final: PCI error state"
r RC_DEVCTL_STA 0xff000078; r RC_AER_UE 0xff000104; echo
od -A x -t x1 -s 0 -N 8 $D/config | head -0
echo "===== done"
EOF

echo "== Copying the experiment script to the phone ..."
scp /tmp/wifi-lab-phone.sh "$phone:/tmp/wifi-lab-phone.sh" || exit 1
echo "== Running it as root (sudo password for ankit on the phone); takes about a minute ..."
timeout --foreground 180 ssh -t "$phone" 'sudo sh /tmp/wifi-lab-phone.sh > /tmp/wifi-lab.txt 2>&1; sudo chmod a+r /tmp/wifi-lab.txt; echo "written: $(wc -l < /tmp/wifi-lab.txt) lines"'
scp "$phone:/tmp/wifi-lab.txt" "$out" && echo "== Saved: $out"
