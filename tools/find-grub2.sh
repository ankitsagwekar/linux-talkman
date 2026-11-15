#!/bin/sh
# Look (read-only) at the small EFI partitions for the GRUB the phone really
# boots, and print its config. Changes nothing. Asks for the sudo password.
phone=ankit@172.16.42.1
cat > /tmp/find-grub2-phone.sh <<'PHONE'
#!/bin/sh
m=/tmp/espro; mkdir -p $m
for pl in EFIESP PLAT MMOS; do
	d=/dev/disk/by-partlabel/$pl
	[ -b $d ] || continue
	mount -o ro $d $m 2>/dev/null || { echo "== $pl: cannot mount"; continue; }
	echo "== $pl ($(df -h $m | tail -1 | awk '{print $3" used of "$2}'))"
	find $m \( -iname '*grub*' -o -iname '*.cfg' -o -iname '*shim*' -o -iname 'boot*.efi' \) -exec ls -la {} \; 2>/dev/null | sed "s#$m#$pl:#" | head -20
	for f in $(find $m -iname 'grub.cfg' 2>/dev/null); do
		echo "---- $pl:${f#$m} ----"; cat "$f"; echo "---- end ----"
	done
	umount $m
done
PHONE
scp /tmp/find-grub2-phone.sh "$phone:/tmp/" || exit 1
ssh -t "$phone" 'sudo sh /tmp/find-grub2-phone.sh'
