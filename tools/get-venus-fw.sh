#!/bin/sh
# Copy the Lumia's Venus video firmware (Windows\System32\qcvss8994.mbn on
# MainOS) to ~/talkman/firmware for inspection. MainOS is mounted read-only.
# Asks for the phone's sudo password.
#   sh ~/talkman/tools/get-venus-fw.sh
phone=ankit@172.16.42.1
mkdir -p "$HOME/talkman/firmware"
ssh -t "$phone" 'sudo sh -c "m=/tmp/fwro; mkdir -p \$m; mount -t ntfs3 -o ro /dev/disk/by-partlabel/MainOS \$m && cp \$m/Windows/System32/qcvss8994.mbn /tmp/qcvss8994.mbn; umount \$m; chmod a+r /tmp/qcvss8994.mbn; ls -la /tmp/qcvss8994.mbn"'
scp "$phone:/tmp/qcvss8994.mbn" "$HOME/talkman/firmware/" && sha256sum "$HOME/talkman/firmware/qcvss8994.mbn"
