#!/bin/sh
# Write a NetworkManager Wi-Fi profile onto the phone's pmOS_root partition.
# Run on the PC with the phone in mass-storage mode:
#   sudo sh ~/talkman/tools/add-wifi.sh "Your SSID"
# The password is asked for interactively and is only written to the phone.
set -eu

ssid="${1:-}"
if [ -z "$ssid" ]; then
	echo "usage: sudo sh $0 \"SSID\"" >&2
	exit 1
fi

dev=/dev/disk/by-partlabel/pmOS_root
if ! [ -b "$dev" ]; then
	echo "pmOS_root not found: put the phone in mass-storage mode first" >&2
	exit 1
fi

printf 'Wi-Fi password for "%s": ' "$ssid"
stty -echo 2>/dev/null || true
read -r psk
stty echo 2>/dev/null || true
echo

mnt=$(mktemp -d)
mount -t ext4 "$dev" "$mnt"
trap 'umount "$mnt"; rmdir "$mnt"' EXIT

dir="$mnt/etc/NetworkManager/system-connections"
mkdir -p "$dir"
f="$dir/lumia-wifi.nmconnection"
umask 077
cat > "$f" <<EOF
[connection]
id=lumia-wifi
type=wifi
autoconnect=true

[wifi]
mode=infrastructure
ssid=$ssid

[wifi-security]
key-mgmt=wpa-psk
psk=$psk

[ipv4]
method=auto

[ipv6]
method=auto
EOF
chown 0:0 "$f"
chmod 600 "$f"
echo "Wrote $f (mode 600). The phone will join \"$ssid\" when Wi-Fi comes up."
