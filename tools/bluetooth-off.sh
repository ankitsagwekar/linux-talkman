#!/bin/sh
# Turn Bluetooth off on the phone but keep Wi-Fi working: the Bluetooth radio
# is soft-blocked and its service disabled, while the hci_uart driver stays
# loaded (the Wi-Fi chip does not start without it).
#   sh ~/talkman/tools/bluetooth-off.sh        off
#   sh ~/talkman/tools/bluetooth-off.sh on     back on
# Asks for the phone's sudo password.
mode="${1:-off}"
phone=ankit@172.16.42.1
cat > /tmp/bluetooth-phone.sh <<PHONE
#!/bin/sh
if [ "$mode" = on ]; then v=0; else v=1; fi
# only present when BlueZ is installed
if systemctl cat bluetooth.service >/dev/null 2>&1; then
	if [ \$v = 0 ]; then systemctl enable --now bluetooth.service; else systemctl disable --now bluetooth.service; fi
fi
for r in /sys/class/rfkill/rfkill*; do
	[ "\$(cat \$r/type)" = bluetooth ] && echo \$v > \$r/soft
done
# keep the setting across reboots even if systemd-rfkill is not in use
if [ \$v = 1 ]; then
	mkdir -p /etc/udev/rules.d
	cat > /etc/udev/rules.d/90-talkman-bluetooth-off.rules <<'RULE'
SUBSYSTEM=="rfkill", ATTR{type}=="bluetooth", ACTION=="add", ATTR{soft}="1"
RULE
else rm -f /etc/udev/rules.d/90-talkman-bluetooth-off.rules; fi
sleep 2
for r in /sys/class/rfkill/rfkill*; do echo "\$(cat \$r/name) (\$(cat \$r/type)): soft-blocked=\$(cat \$r/soft)"; done
echo "boot rule: \$(ls /etc/udev/rules.d/90-talkman-bluetooth-off.rules 2>/dev/null || echo none)"
echo "hci_uart loaded: \$(lsmod | grep -c '^hci_uart')"
nmcli -t -f DEVICE,STATE,CONNECTION dev | grep wlan0
PHONE
scp /tmp/bluetooth-phone.sh "$phone:/tmp/" || exit 1
ssh -t "$phone" 'sudo sh /tmp/bluetooth-phone.sh'
