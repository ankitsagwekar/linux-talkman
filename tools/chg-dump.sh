#!/bin/sh
# Dump the PMI8994 charger (SMBCHG) registers and battery state from the phone
# into ~/talkman/logs. Asks for the phone's sudo password.
#   sh ~/talkman/tools/chg-dump.sh
phone=ankit@172.16.42.1
out="$HOME/talkman/logs/chg-dump-$(date +%H%M%S).txt"
cat > /tmp/chg-dump-phone.sh <<'PHONE'
#!/bin/sh
B=/sys/class/power_supply/battery; U=/sys/class/power_supply/qcom-smbchg-usb
echo "cap=$(cat $B/capacity) V=$(cat $B/voltage_now) I=$(cat $B/current_now) temp=$(cat $B/temp) status=$(cat $B/status)"
grep -E "STATUS|TYPE|ONLINE|CURRENT|HEALTH" $U/uevent
echo "pmic temp: $(cat /sys/class/thermal/thermal_zone*/temp | tr '\n' ' ')"
ls /sys/kernel/debug/regmap/
for d in /sys/kernel/debug/regmap/*; do
	[ -r $d/registers ] || continue
	grep -qE "^13f2: " $d/registers 2>/dev/null || continue
	echo "== $d"
	grep -E "^1(00|01|0f|20|21|24|2f|30|31|34|3f|60|61)[0-9a-f]: " $d/registers
done
dmesg | grep -iE "smbchg|pmi8994-fg" | tail -15
PHONE
scp /tmp/chg-dump-phone.sh "$phone:/tmp/" || exit 1
echo "== Reading charger state (sudo password for ankit on the phone) ..."
timeout --foreground 90 ssh -t "$phone" 'sudo sh /tmp/chg-dump-phone.sh > /tmp/chg-dump.txt 2>&1; sudo chmod a+r /tmp/chg-dump.txt; echo "lines: $(wc -l < /tmp/chg-dump.txt)"'
scp "$phone:/tmp/chg-dump.txt" "$out" && echo "== Saved: $out"
