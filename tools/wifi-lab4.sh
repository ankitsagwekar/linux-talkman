#!/bin/sh
# Test: bring the Wi-Fi chip up WITHOUT Bluetooth touching it first.
#   sh ~/talkman/tools/wifi-lab4.sh
# Sequence on the phone (as root):
#   1. unbind the PCIe controller (powers the chip off)
#   2. stop Bluetooth and unload its driver (hci_uart), so it cannot load
#      its firmware onto the chip
#   3. bind the PCIe controller again (powers the chip, trains the link)
#   4. wait, rescan the PCI bus, let ath10k_pci probe
set -u

phone=ankit@172.16.42.1
logdir="$HOME/talkman/logs"
mkdir -p "$logdir"
out="$logdir/wifi-lab4-$(date +%Y%m%d-%H%M%S).txt"

cat > /tmp/wifi-lab4-phone.sh <<'EOF'
#!/bin/sh
RP=/usr/local/bin/regpoke
RC=fc520000.pcie
BD=0000:01:00.0
P=$(ls /sys/module/*/parameters/msm8994_enable | head -1)
r() { printf '%s=%s ' "$1" "$($RP r "$2" 2>&1)"; }

echo "===== $(date) kernel $(uname -v)"
echo "WIFI-LAB4 start" > /dev/kmsg

echo "--- 1. stop Bluetooth first (so nothing loads firmware onto the chip)"
systemctl stop bluetooth 2>&1 | head -2
rmmod hci_uart 2>&1 | head -2
lsmod | grep -E 'hci_uart|btqca|bluetooth' | head -5

echo "--- 2. power the chip off: unbind the PCIe controller"
echo $RC > /sys/bus/platform/drivers/qcom-pcie/unbind 2>&1 | head -2
sleep 3
ls /sys/bus/pci/devices/ 2>&1

echo "--- 3. bring PCIe up again"
echo 1 > $P
echo $RC > /sys/bus/platform/drivers/qcom-pcie/bind 2>&1 | head -2
echo "waiting 12 s for the link ..."
sleep 12
r LTSSM_STATE 0xff000728; r LNKSTA 0xff000080; echo
echo "--- 4. rescan"
echo 1 > /sys/bus/pci/rescan
sleep 8
ls /sys/bus/pci/devices/
echo "--- dmesg since start"
dmesg | sed -n '/WIFI-LAB4 start/,$p' | tail -n +2 | grep -vE 'pcie-trace' | head -50
echo "--- result"
ls /sys/class/ieee80211/ 2>&1; ls /sys/class/net
echo "===== done"
EOF

echo "== Copying the script to the phone ..."
scp /tmp/wifi-lab4-phone.sh "$phone:/tmp/wifi-lab4-phone.sh" || exit 1
echo "== Running it as root (sudo password for ankit on the phone); takes about 40 s ..."
timeout --foreground 150 ssh -t "$phone" 'sudo sh /tmp/wifi-lab4-phone.sh > /tmp/wifi-lab4.txt 2>&1; sudo chmod a+r /tmp/wifi-lab4.txt; echo "written: $(wc -l < /tmp/wifi-lab4.txt) lines"'
scp "$phone:/tmp/wifi-lab4.txt" "$out" && echo "== Saved: $out"
