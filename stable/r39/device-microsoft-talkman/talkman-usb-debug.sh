#!/bin/sh
# Dump USB/USB-C state to /var/log so it can be read over mass storage.
out=/var/log/talkman-usb-debug.txt
{
	echo "=== $(date) uptime: $(cut -d' ' -f1 /proc/uptime)s ==="
	uname -a
	mountpoint -q /sys/kernel/debug || mount -t debugfs none /sys/kernel/debug
	echo "--- lsmod"; lsmod
	echo "--- devices_deferred"; cat /sys/kernel/debug/devices_deferred 2>&1
	echo "--- spi devices"
	for d in /sys/bus/spi/devices/*; do
		[ -e "$d" ] || continue
		echo "$d modalias=$(cat $d/modalias 2>/dev/null) driver=$(readlink $d/driver 2>/dev/null)"
	done
	echo "--- udc"
	for u in /sys/class/udc/*; do
		[ -e "$u" ] || continue
		echo "$u state=$(cat $u/state 2>/dev/null) speed=$(cat $u/current_speed 2>/dev/null) function=$(cat $u/function 2>/dev/null)"
	done
	echo "--- gadget UDC: $(cat /sys/kernel/config/usb_gadget/*/UDC 2>&1)"
	echo "--- usb_role"; for r in /sys/class/usb_role/*; do [ -e "$r" ] && echo "$r $(cat $r/role)"; done
	echo "--- typec"; ls -la /sys/class/typec/ 2>&1; for p in /sys/class/typec/port*; do [ -e "$p" ] && echo "$p data=$(cat $p/data_role) power=$(cat $p/power_role) orient=$(cat $p/orientation 2>/dev/null)"; done
	echo "--- power_supply"; for s in /sys/class/power_supply/*; do echo "$s online=$(cat $s/online 2>/dev/null) present=$(cat $s/present 2>/dev/null) type=$(cat $s/usb_type 2>/dev/null)"; done
	echo "--- ip"; ip addr 2>&1
	echo "--- modprobe -v uc120"; modprobe -v uc120 2>&1
	echo "--- dmesg (usb/typec/spi)"; dmesg | grep -iE 'uc120|typec|spi|dwc3|udc|gadget|usb|smbchg|phy|role|vbus' | tail -150
	echo "--- pci"; ls -l /sys/bus/pci/devices/ 2>&1; for d in /sys/bus/pci/devices/*; do [ -e "$d" ] && echo "$d vendor=$(cat $d/vendor) device=$(cat $d/device) driver=$(readlink $d/driver)"; done
	echo "--- wifi"; ls /sys/class/ieee80211/ 2>&1; nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device 2>&1; nmcli -t -f SSID,SIGNAL dev wifi list 2>&1 | head -20
	echo "--- dmesg (pcie/wifi/bt)"; dmesg | grep -iE 'pcie|pci |ath10k|qca|wlan|firmware|bluetooth|hci0' | tail -120
	echo "--- regulator_summary"; cat /sys/kernel/debug/regulator/regulator_summary 2>&1 | head -220
	echo
} >> "$out" 2>&1

# Run the one-shot USB experiments once per boot, if installed
if [ -x /usr/libexec/talkman-usb-exp.sh ] && [ ! -e /run/talkman-usb-exp-ran ]; then
	touch /run/talkman-usb-exp-ran
	/usr/libexec/talkman-usb-exp.sh
fi
