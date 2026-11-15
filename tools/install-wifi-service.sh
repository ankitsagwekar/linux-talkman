#!/bin/sh
# Install the boot-time Wi-Fi service on the phone (no rebuild needed).
#   sh ~/talkman/tools/install-wifi-service.sh
set -e
phone=ankit@172.16.42.1
d="$HOME/talkman/device-microsoft-talkman"
scp "$d/talkman-wifi.sh" "$d/talkman-wifi.service" "$phone:/tmp/"
ssh -t "$phone" 'sudo install -Dm755 /tmp/talkman-wifi.sh /usr/libexec/talkman-wifi.sh &&
 sudo install -Dm644 /tmp/talkman-wifi.service /etc/systemd/system/talkman-wifi.service &&
 echo 1 | sudo tee /sys/class/firmware/timeout >/dev/null && sudo systemctl daemon-reload && sudo systemctl enable talkman-wifi.service &&
 echo "installed; reboot to test"'
