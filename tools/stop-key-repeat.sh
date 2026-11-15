#!/bin/sh
# Switch off key auto-repeat on gpio-keys (volume/camera) until the next
# boot, so the stuck camera-focus key stops resetting the screen-blank timer.
# Then sets the blank timer to 1 minute for a quick check.
# Asks for the phone's sudo password.
#   sh ~/talkman/tools/stop-key-repeat.sh
phone=ankit@172.16.42.1
cat > /tmp/stop-key-repeat.py <<'PY'
import fcntl, struct, os, glob
EVIOCSREP = 0x40084503  # _IOW('E', 0x03, unsigned int[2])
done = False
for p in sorted(glob.glob("/sys/class/input/event*/device/name")):
    if open(p).read().strip() == "gpio-keys":
        dev = "/dev/input/" + p.split("/")[4]
        fd = os.open(dev, os.O_RDWR)
        fcntl.ioctl(fd, EVIOCSREP, struct.pack("II", 0, 0))  # delay 0, period 0: no repeat
        os.close(fd)
        print("auto-repeat off on", dev)
        done = True
if not done:
    print("gpio-keys not found")
t = os.open("/dev/tty1", os.O_WRONLY)
os.write(t, b"\033[9;1]")
print("blank timer set to 1 minute: leave the phone untouched")
PY
scp /tmp/stop-key-repeat.py "$phone:/tmp/" || exit 1
ssh -t "$phone" 'sudo python3 /tmp/stop-key-repeat.py'
