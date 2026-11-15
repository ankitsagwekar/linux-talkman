#!/bin/sh
# Test: open an inbound (endpoint -> RAM) address-translation window on the
# DesignWare PCIe0 root complex by hand, then retry the ath10k probe.
#   sh ~/talkman/tools/wifi-lab3.sh
# The window maps bus addresses 0x0 - 0xffffffff 1:1 onto the CPU address
# space (viewport iATU, inbound region 0, memory type, address match).
set -u

phone=ankit@172.16.42.1
logdir="$HOME/talkman/logs"
mkdir -p "$logdir"
out="$logdir/wifi-lab3-$(date +%Y%m%d-%H%M%S).txt"

cat > /tmp/wifi-lab3-phone.sh <<'EOF'
#!/bin/sh
RP=/usr/local/bin/regpoke
BD=0000:01:00.0
DBI=0xff000000
P=/sys/module/ath10k_pci/parameters
r() { printf '%s=%s ' "$1" "$($RP r "$2" 2>&1)"; }
w() { $RP w "$1" "$2" >/dev/null 2>&1; }
at() { printf '0x%x' $((DBI + $1)); }

echo "===== $(date) kernel $(uname -v)"
[ -d /sys/bus/pci/devices/$BD ] || { echo "endpoint $BD not present: bring PCIe up and rescan first"; exit 1; }
echo "--- DesignWare core"
r VERSION $(at 0x8f8); r VERSION_TYPE $(at 0x8fc); r PORT_LINK_CTRL $(at 0x710); r MISC_CTRL1 $(at 0x8bc); echo
echo "--- iATU viewport: inbound regions 0..2 BEFORE"
for i in 0 1 2; do
	w $(at 0x900) $(printf '0x%x' $((0x80000000 | i)))
	r VIEWPORT $(at 0x900); r CTRL1 $(at 0x904); r CTRL2 $(at 0x908); r LBASE $(at 0x90c); r LIMIT $(at 0x914); r LTARGET $(at 0x918); echo
done
echo "--- iATU viewport: outbound regions 0..2 (for reference)"
for i in 0 1 2; do
	w $(at 0x900) $i
	r VIEWPORT $(at 0x900); r CTRL1 $(at 0x904); r CTRL2 $(at 0x908); r LBASE $(at 0x90c); r LIMIT $(at 0x914); r LTARGET $(at 0x918); echo
done

echo "--- programming inbound region 0: bus 0x0..0xffffffff -> CPU 0x0 (address match, MEM)"
w $(at 0x900) 0x80000000
w $(at 0x90c) 0x00000000   # lower base address (bus)
w $(at 0x910) 0x00000000   # upper base address
w $(at 0x914) 0xffffffff   # limit
w $(at 0x918) 0x00000000   # lower target address (CPU)
w $(at 0x91c) 0x00000000   # upper target address
w $(at 0x904) 0x00000000   # CTRL1: type = memory
w $(at 0x908) 0x80000000   # CTRL2: region enable, address match mode
w $(at 0x900) 0x80000000
r VIEWPORT $(at 0x900); r CTRL1 $(at 0x904); r CTRL2 $(at 0x908); r LBASE $(at 0x90c); r LIMIT $(at 0x914); r LTARGET $(at 0x918); echo

echo "--- clear PCIe errors, retry ath10k"
w 0xff000104 0xffffffff; w 0xff000110 0xffffffff
echo 0 > $P/reset_mode; echo 0 > $P/irq_mode
echo "WIFI-LAB3 start" > /dev/kmsg
echo $BD > /sys/bus/pci/drivers/ath10k_pci/unbind 2>/dev/null
sleep 1
echo $BD > /sys/bus/pci/drivers/ath10k_pci/bind 2>/dev/null
sleep 8
echo "--- dmesg"
dmesg | sed -n '/WIFI-LAB3 start/,$p' | tail -n +2 | head -40
echo "--- result"
ls /sys/class/ieee80211/ 2>&1; ls /sys/class/net
r AER_UE 0xff000104; r HDRLOG0 0xff00011c; r HDRLOG2 0xff000124; echo
echo "===== done"
EOF

echo "== Copying the script to the phone ..."
scp /tmp/wifi-lab3-phone.sh "$phone:/tmp/wifi-lab3-phone.sh" || exit 1
echo "== Running it as root (sudo password for ankit on the phone) ..."
timeout --foreground 120 ssh -t "$phone" 'sudo sh /tmp/wifi-lab3-phone.sh > /tmp/wifi-lab3.txt 2>&1; sudo chmod a+r /tmp/wifi-lab3.txt; echo "written: $(wc -l < /tmp/wifi-lab3.txt) lines"'
scp "$phone:/tmp/wifi-lab3.txt" "$out" && echo "== Saved: $out"
