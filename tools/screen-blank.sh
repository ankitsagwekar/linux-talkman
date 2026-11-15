#!/bin/sh
# Blank the phone's console screen after N minutes without key presses
# (default 3). On the AMOLED panel a blank screen has its pixels off (r40+).
# Applies it now and makes it permanent in the real GRUB config
# (EFIESP:/EFI/boot/grub.cfg, through install-grub-cfg.sh).
#   sh ~/talkman/tools/screen-blank.sh [minutes]      0 = never blank
# A volume or camera key press wakes the screen. Asks for the sudo password twice.
min="${1:-3}"
phone=ankit@172.16.42.1
cfg="$HOME/talkman/update/grub-efiesp.cfg"
sed -i "s/ consoleblank=[0-9]*//g; s/ console=tty0/ console=tty0 consoleblank=$((min * 60))/" "$cfg"
sh "$HOME/talkman/tools/install-grub-cfg.sh" "$cfg" || exit 1
ssh -t "$phone" "sudo sh -c 'printf \"\\033[9;${min}]\" > /dev/tty1'; echo \"blank timer now: \$(cat /sys/module/kernel/parameters/consoleblank) s\""
