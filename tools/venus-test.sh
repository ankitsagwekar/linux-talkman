#!/bin/sh
# Load the Venus video codec by hand with the kernel log streamed to this PC,
# then list the video devices it created. If the phone freezes, force a
# reboot and run tools/crash-log.sh. Asks for the phone's sudo password.
#   sh ~/talkman/tools/venus-test.sh
phone=ankit@172.16.42.1
log="$HOME/talkman/logs/venus-$(date +%m%d-%H%M%S).log"
ssh -o ServerAliveInterval=2 -o ServerAliveCountMax=3 "$phone" 'dmesg -w' > "$log" 2>&1 &
streamer=$!
sleep 2
timeout --foreground 90 ssh -t "$phone" 'sudo sh -c "echo VENUS-TEST > /dev/kmsg; modprobe -i venus_core && sleep 3 && modprobe -i venus_dec && modprobe -i venus_enc; sleep 3; echo; ls -la /dev/video* 2>&1; for v in /sys/class/video4linux/*; do echo \"\$v: \$(cat \$v/name)\"; done; lsmod | grep -E \"venus|v4l2|videobuf\""'
rc=$?
sleep 2; kill $streamer 2>/dev/null
echo "== ssh exit code: $rc (124/255: the phone probably froze)"
sed -n '/VENUS-TEST/,$p' "$log" | grep -iE "venus|iommu|qcom_iommu|scm|pas|firmware|mdt|video|error|fail|Oops|Internal" | head -40
echo "Full log: $log"
