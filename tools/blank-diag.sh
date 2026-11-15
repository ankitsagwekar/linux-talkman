#!/bin/sh
# Find out why the console blank timer never fires: show which input devices
# count as keyboards, the console mode, and any input events for 30 s.
# Do not touch the phone while it runs. Asks for the phone's sudo password.
#   sh ~/talkman/tools/blank-diag.sh
phone=ankit@172.16.42.1
cat > /tmp/blank-diag-phone.py <<'PY'
import fcntl, struct, os, select, time, glob
f = os.open("/dev/tty1", os.O_RDWR)
m = fcntl.ioctl(f, 0x4B3B, struct.pack("I", 0))
print("tty1 mode:", "TEXT" if struct.unpack("I", m)[0] == 0 else "GRAPHICS")
fds = {os.open(p, os.O_RDONLY | os.O_NONBLOCK): p for p in sorted(glob.glob("/dev/input/event*"))}
t0 = time.time(); n = {}
print("recording input events for 30 s, do not touch the phone ...", flush=True)
while time.time() - t0 < 30:
    r, _, _ = select.select(list(fds), [], [], 1)
    for d in r:
        try:
            data = os.read(d, 24 * 64)
        except OSError:
            continue
        for i in range(0, len(data), 24):
            _, _, ty, co, va = struct.unpack("qqHHi", data[i:i + 24])
            if ty:
                n[fds[d]] = n.get(fds[d], 0) + 1
                if n[fds[d]] <= 5:
                    print(round(time.time() - t0, 1), fds[d], "type", ty, "code", co, "value", va, flush=True)
print("events in 30 s:", n or "none")
PY
scp /tmp/blank-diag-phone.py "$phone:/tmp/" || exit 1
ssh -t "$phone" 'grep -E "^N:|^H:" /proc/bus/input/devices; sudo python3 /tmp/blank-diag-phone.py'
