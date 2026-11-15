#!/bin/sh
# Install ~/talkman/update/grub-efiesp.cfg as the GRUB config the phone really
# boots from (EFIESP:/EFI/boot/grub.cfg). Keeps the current one as
# grub.cfg.orig, touches no other file on that partition, and also updates the
# copy in /boot. Asks for the phone's sudo password.
#   sh ~/talkman/tools/install-grub-cfg.sh [config-file]
cfg="${1:-$HOME/talkman/update/grub-efiesp.cfg}"
phone=ankit@172.16.42.1
[ -f "$cfg" ] || { echo "missing $cfg" >&2; exit 1; }
cat > /tmp/install-grub-phone.sh <<'PHONE'
#!/bin/sh
set -e
m=/tmp/esprw; mkdir -p $m
d=/dev/disk/by-partlabel/EFIESP
[ -b $d ] || { echo "no EFIESP partition"; exit 1; }
mount $d $m
t=$m/EFI/boot/grub.cfg
[ -f $t ] || { echo "no $t: not touching anything"; umount $m; exit 1; }
[ -f $t.orig ] || cp $t $t.orig
cp /tmp/grub-new.cfg $t
sync
cmp /tmp/grub-new.cfg $t && echo "EFIESP grub.cfg updated ($(grep -c menuentry $t) entries); backup: grub.cfg.orig"
ls -la $m/EFI/boot/
umount $m
cp /tmp/grub-new.cfg /boot/grub.cfg; sync
ls /boot/vmlinuz.prev /boot/msm8992-msft-lumia-octagon-talkman.dtb.prev >/dev/null && echo "fallback kernel files present in /boot"
PHONE
scp "$cfg" "$phone:/tmp/grub-new.cfg" && scp /tmp/install-grub-phone.sh "$phone:/tmp/" || exit 1
ssh -t "$phone" 'sudo sh /tmp/install-grub-phone.sh'
