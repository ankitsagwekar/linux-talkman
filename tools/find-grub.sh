#!/bin/sh
# Find which GRUB config the phone really boots from, and switch the 3-minute
# screen blank on for the current boot. Asks for the phone's sudo password.
phone=ankit@172.16.42.1
cat > /tmp/find-grub-phone.sh <<'PHONE'
#!/bin/sh
printf '\033[9;3]' > /dev/tty1
echo "blank timer now: $(cat /sys/module/kernel/parameters/consoleblank) s"
echo "running cmdline: $(cat /proc/cmdline)"
echo "== config files on /boot"
find /boot \( -iname '*.cfg' -o -iname '*.conf' \) | while read f; do
	echo "$f  ($(grep -c menuentry "$f") menu entries, consoleblank: $(grep -c consoleblank "$f"), keep_bootcon: $(grep -c keep_bootcon "$f"))"
done
echo "== GRUB / EFI binaries"
find /boot -iname '*.efi' -exec ls -la {} \;
echo "== other mounted or EFI partitions"
lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL,MOUNTPOINT 2>/dev/null | grep -iE "vfat|efi|boot|NAME" | head -12
PHONE
scp /tmp/find-grub-phone.sh "$phone:/tmp/" || exit 1
ssh -t "$phone" 'sudo sh /tmp/find-grub-phone.sh'
