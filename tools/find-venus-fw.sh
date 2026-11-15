#!/bin/sh
# Look (read-only) on the phone's Windows partitions for the Venus video
# firmware the Lumia's secure world accepts. Changes nothing.
# Asks for the phone's sudo password.
#   sh ~/talkman/tools/find-venus-fw.sh
phone=ankit@172.16.42.1
cat > /tmp/find-venus-phone.sh <<'PHONE'
#!/bin/sh
m=/tmp/fwro; mkdir -p $m
echo "filesystems: $(grep -oE 'ntfs3?|vfat|exfat' /proc/filesystems | sort -u | tr '\n' ' ')"
lsblk -o NAME,SIZE,FSTYPE,PARTLABEL 2>/dev/null | grep -iE "ntfs|MainOS|Data|EFIESP|PLAT|DPP|NAME" | head -12
for pl in MainOS Data PLAT DPP EFIESP; do
	d=/dev/disk/by-partlabel/$pl; [ -b $d ] || continue
	fs=$(blkid -o value -s TYPE $d 2>/dev/null)
	case "$fs" in ntfs) t="ntfs3 ntfs";; vfat) t=vfat;; *) t="$fs";; esac
	ok=""
	for ty in $t; do mount -t $ty -o ro $d $m 2>/dev/null && { ok=$ty; break; }; done
	[ -n "$ok" ] || { echo "== $pl ($fs): cannot mount"; continue; }
	echo "== $pl ($fs as $ok)"
	find $m -iname '*vss*' -o -iname '*venus*' -o -iname 'qcvss*' -o -iname '*vidc*' 2>/dev/null | grep -iE '\.(mbn|mdt|b[0-9]+|bin)$|vss|venus' | head -20 | while read f; do ls -la "$f"; done
	umount $m
done
PHONE
scp /tmp/find-venus-phone.sh "$phone:/tmp/" || exit 1
ssh -t "$phone" 'sudo sh /tmp/find-venus-phone.sh'
