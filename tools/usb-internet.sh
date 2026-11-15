#!/bin/sh
# Share this PC's internet with the phone over the USB network.
#   sh ~/talkman/tools/usb-internet.sh up     # enable (default)
#   sh ~/talkman/tools/usb-internet.sh down   # remove the PC rules again
# Needs: sudo on this PC, and (for "up") sudo on the phone. Nothing is made
# permanent: it is gone after a reboot of either side.
set -eu

action="${1:-up}"
phone=ankit@172.16.42.1
phone_ip=172.16.42.1
pc_ip=172.16.42.2
subnet=172.16.42.0/24

usb=$(ip -o -4 addr show | awk -v ip="$pc_ip/" 'index($4, ip) == 1 {print $2; exit}')
wan=$(ip -o -4 route show default | awk '{print $5; exit}')
[ -n "$usb" ] || { echo "USB interface (with $pc_ip) not found: is the phone connected?" >&2; exit 1; }
[ -n "$wan" ] || { echo "no default route on this PC: no internet to share" >&2; exit 1; }
echo "USB interface: $usb   internet interface: $wan"

case "$action" in
up)
	echo "== PC: enabling forwarding + NAT (sudo password for this PC)"
	sudo sh -eu -c "
		sysctl -qw net.ipv4.ip_forward=1
		iptables -t nat -C POSTROUTING -s $subnet -o $wan -j MASQUERADE 2>/dev/null ||
			iptables -t nat -A POSTROUTING -s $subnet -o $wan -j MASQUERADE
		iptables -C FORWARD -i $usb -o $wan -j ACCEPT 2>/dev/null ||
			iptables -I FORWARD 1 -i $usb -o $wan -j ACCEPT
		iptables -C FORWARD -i $wan -o $usb -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null ||
			iptables -I FORWARD 1 -i $wan -o $usb -m state --state RELATED,ESTABLISHED -j ACCEPT
	"
	now=$(date +%s)
	echo "== Phone: default route, DNS and clock (sudo password for ankit on the phone)"
	ssh -t "$phone" "
		set -e
		sudo ip route replace default via $pc_ip dev usb0
		# systemd-resolved is not running here, so /etc/resolv.conf points at
		# a stub nobody answers: use a plain file (original kept for \"down\")
		if [ ! -e /root/resolv.conf.orig ]; then
			sudo cp -P /etc/resolv.conf /root/resolv.conf.orig
		fi
		sudo rm -f /etc/resolv.conf
		printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' | sudo tee /etc/resolv.conf >/dev/null
		sudo date -s @$now
		sudo systemctl restart systemd-timesyncd 2>/dev/null || true
		echo; echo 'route:'; ip route
		echo; echo 'ping 1.1.1.1:'; ping -c2 -W3 1.1.1.1
		echo; echo 'DNS lookup:'; ping -c1 -W5 mirror.postmarketos.org || ping -c1 -W5 dl-cdn.alpinelinux.org || true
		echo; date
	"
	echo
	echo "== Done. The phone should now have internet."
	;;
down)
	echo "== PC: removing NAT rules (sudo password for this PC)"
	sudo sh -c "
		iptables -t nat -D POSTROUTING -s $subnet -o $wan -j MASQUERADE 2>/dev/null || true
		iptables -D FORWARD -i $usb -o $wan -j ACCEPT 2>/dev/null || true
		iptables -D FORWARD -i $wan -o $usb -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
		sysctl -qw net.ipv4.ip_forward=0
	"
	ssh -t "$phone" 'sudo ip route del default via 172.16.42.2 dev usb0 2>/dev/null
		if [ -e /root/resolv.conf.orig ]; then sudo rm -f /etc/resolv.conf; sudo cp -P /root/resolv.conf.orig /etc/resolv.conf; fi
		true' || true
	echo "== Removed."
	;;
*)
	echo "usage: $0 up|down" >&2
	exit 1
	;;
esac
