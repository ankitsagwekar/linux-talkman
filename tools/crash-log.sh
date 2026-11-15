#!/bin/sh
# Fetch the kernel messages that survived the last freeze or reset (ramoops,
# r40+) from the phone into ~/talkman/logs. systemd moves them from
# /sys/fs/pstore to /var/lib/systemd/pstore at boot, so look in both.
# Asks for the phone's sudo password.
#   sh ~/talkman/tools/crash-log.sh
phone=ankit@172.16.42.1
out="$HOME/talkman/logs/crash-$(date +%m%d-%H%M%S).txt"
cat > /tmp/crash-log-phone.sh <<'PHONE'
#!/bin/sh
echo "== /sys/fs/pstore"; ls -la /sys/fs/pstore
echo "== /var/lib/systemd/pstore"; ls -laR /var/lib/systemd/pstore 2>&1 | tail -15
echo "== systemd-pstore: $(systemctl is-enabled systemd-pstore 2>&1), last run:"; journalctl -b -u systemd-pstore --no-pager -o cat 2>/dev/null | tail -3
n=$(find /var/lib/systemd/pstore -type f 2>/dev/null | sort | tail -3)
for f in /sys/fs/pstore/* $n; do
	[ -f "$f" ] || continue
	echo; echo "===== $f (last 60 lines)"; tail -60 "$f"
done
PHONE
scp /tmp/crash-log-phone.sh "$phone:/tmp/" || exit 1
ssh -t "$phone" 'sudo sh /tmp/crash-log-phone.sh > /tmp/crash-log.txt 2>&1; echo "lines: $(wc -l < /tmp/crash-log.txt)"'
scp "$phone:/tmp/crash-log.txt" "$out" && echo "== Saved: $out" && head -40 "$out" | cut -c1-170
