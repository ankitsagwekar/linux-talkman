# postmarketOS on Microsoft Lumia 950 (microsoft-talkman)

Install guide for the postmarketOS **v26.06** (stable) port in this folder.

- Device: Microsoft Lumia 950 (`microsoft-talkman`, Snapdragon 808 / MSM8992)
- Kernel: `linux-postmarketos-qcom-msm8994` 6.16-r46 (mainline + USB, Wi-Fi,
  battery, idle states, thermistors, screen blank, RPM fix, plus parked CPU
  scaling and an untested Venus driver; patches 0002-0032). Device package
  `device-microsoft-talkman` r8. Frozen known-good r39 copy in `stable/r39/`.
- Status: **frozen 2026-11-15.** Everything below "Works" is tested on the phone.
- User: `ankit`, hostname: `lumia950`, UI: console
- Boot chain: Windows Boot Manager -> BootShim -> Lumia UEFI -> GRUB -> Linux
  (the image's systemd-boot does not start on this 2020 UEFI; GRUB lives on
  EFIESP, config in `update/grub-efiesp.cfg`, see "Boot menu (GRUB)")

> Make the full backup in Part 3 before changing anything on the phone.

---

## What works / what doesn't

| Feature | Status |
|---|---|
| Boot, display (UEFI framebuffer), touchscreen, volume keys, hall sensor | Works |
| USB networking to a PC + SSH (172.16.42.1) | Works |
| Wi-Fi (QCA6174), joins saved networks by itself ~65 s after boot | Works |
| Bluetooth (hci0) | Radio off by default (driver must stay loaded: Wi-Fi needs it); `tools/bluetooth-off.sh on` turns it on |
| CPU frequency scaling (A53 600-960 MHz, A57 384-768 MHz) | **Parked**: in the kernel but not loaded at boot (A57 freezes under load), see below |
| Venus video decoder/encoder (H.264, MPEG-2/4, VC-1, VP8) | Experimental, **untested**, not loaded at boot, see below |
| USB host via USB-C OTG (Ethernet, flash drive, HDD) | Experimental (new UC120 driver) |
| Charging (SMBCHG) | Works on a wall charger (~1.2 A); a PC USB port cannot cover the idle draw, so the battery drains slowly there |
| Battery percentage, voltage, current, temperature (`/sys/class/power_supply/battery`) | Works |
| CPU idle states (PSCI) | Works |
| Screen blanks after 3 minutes without a key press (black, AMOLED pixels off); volume up wakes it | Works (r42+) |
| Board temperature sensors (`/sys/class/thermal`): CPU throttling at 65 °C, shutdown at 115 °C | Works (r40+; node names fixed in r46) |
| Camera keys | Removed (the focus key reads as held and blocked screen blanking) |
| Power button, native display, GPU, audio, camera, mobile data | Not working |

> A weak or empty battery makes the phone restart at random points during
> boot (no error on screen). Charge it from a wall charger with the phone off,
> or replace the battery.

---

## Part 0 - What you need

- Lumia 950 with an **unlocked bootloader**, battery above 50 %
- A **Windows PC** (Part 1 only)
- A **Linux PC** (Parts 2 and 3), about 35 GB free for the backup
- A good USB-C **data** cable
- The two images from the Linux PC:
  - `microsoft-talkman-boot.img` (512 MB)
  - `microsoft-talkman-root.img` (about 844 MB)

  On the build PC they are in
  `~/.local/var/pmbootstrap/chroot_native/home/pmos/rootfs/`
  (symlinked in `/tmp/postmarketOS-export/`, which is cleared on reboot).

---

## Part 1 - Install the Lumia UEFI (Windows PC)

1. Install **WPinternals**: <https://github.com/ReneLergner/WPinternals/releases>
   Connect the phone and confirm it reports the bootloader as unlocked.

2. Download:
   - `MSM8992.UEFI.Lumia.950.zip` from
     <https://github.com/WOA-Project/Lumia950XLPkg/releases/tag/2.24b>
     (use the **MSM8992 / Lumia 950** file, not the 950 XL one).
     You only need `MSM8992 UEFI (Lumia 950)\ELF\UEFI.elf`.
   - `BootShim.efi` from
     <https://github.com/imbushuo/boot-shim/releases/tag/elf-aa64-loader-pre1>
     (the **aa64** release, not `elf-loader-pre*`).

3. In WPinternals choose **Switch mode -> Mass Storage**.
   The phone's partitions appear as drives. Find **EFIESP** (this guide uses `E:`).
   If it has no letter: `diskpart` -> `list volume` -> `select volume N` -> `assign letter=E`.

4. **Back up** `E:\EFI\Microsoft\Boot\BCD` somewhere safe.

5. Copy the files:
   - `UEFI.elf` -> `E:\UEFI.elf`
   - `BootShim.efi` -> `E:\EFI\Boot\BootShim.efi`

6. Open **Command Prompt as Administrator** and create the boot entry:

   ```bat
   bcdedit /store E:\EFI\Microsoft\Boot\BCD /create /d "UEFI" /application BOOTAPP
   ```

   It prints a GUID like `{xxxxxxxx-xxxx-...}`. Use it in place of `{GUID}`:

   ```bat
   bcdedit /store E:\EFI\Microsoft\Boot\BCD /set {GUID} path \EFI\Boot\BootShim.efi
   bcdedit /store E:\EFI\Microsoft\Boot\BCD /set {GUID} device partition=E:
   bcdedit /store E:\EFI\Microsoft\Boot\BCD /set {GUID} testsigning on
   bcdedit /store E:\EFI\Microsoft\Boot\BCD /set {GUID} nointegritychecks on
   bcdedit /store E:\EFI\Microsoft\Boot\BCD /displayorder {GUID} /addlast
   bcdedit /store E:\EFI\Microsoft\Boot\BCD /set {bootmgr} displaybootmenu on
   bcdedit /store E:\EFI\Microsoft\Boot\BCD /set {bootmgr} timeout 10
   ```

7. **Leave the phone in mass-storage mode** and move the cable to the Linux PC.
   The mode should survive the move. If the phone drops out of it, switch it
   on again in WPinternals.

---

## Part 2 - Build the images (Linux PC, optional)

Skip this if you already have the two `.img` files.

```bash
sudo apt install git
```

```bash
git clone --depth 1 --branch 3.12.1 https://gitlab.nura.eco/nura/pmbootstrap.git ~/.local/src/pmbootstrap-3.12.1 && mkdir -p ~/.local/bin && ln -sf ~/.local/src/pmbootstrap-3.12.1/pmbootstrap.py ~/.local/bin/pmbootstrap
```

```bash
git clone -b v26.06 https://gitlab.postmarketos.org/postmarketOS/pmaports.git ~/.local/var/pmbootstrap/cache_git/pmaports
```

Copy this port in (run from the folder that contains this README):

```bash
cp -r device-microsoft-talkman ~/.local/var/pmbootstrap/cache_git/pmaports/device/testing/ && git -C ~/.local/var/pmbootstrap/cache_git/pmaports apply "$PWD/linux-postmarketos-qcom-msm8994/v26.06-talkman.patch"
```

Configure (choose channel **v26.06**, vendor **microsoft**, device **talkman**,
user **ankit**, UI **console**):

```bash
pmbootstrap init
```

```bash
pmbootstrap config sudo_timer True
```

Build (stay at the terminal: it asks for sudo and the `ankit` password):

```bash
pmbootstrap checksum linux-postmarketos-qcom-msm8994 device-microsoft-talkman && pmbootstrap install --split
```

If the install fails right after building the kernel with
`losetup: unrecognized option: json`, just run it again:

```bash
pmbootstrap shutdown && pmbootstrap install --split && pmbootstrap export
```

Notes:
- postmarketOS was renamed **Nura**. `gitlab.postmarketos.org` redirecting to
  `gitlab.nura.eco` is expected.
- The images end up in `/tmp/postmarketOS-export/`.

---

## Part 3 - Install to internal storage (Linux PC, phone in mass-storage mode)

**Warning:** never use `pmbootstrap install --disk` on this phone. It wipes
EFIESP, DPP (IMEI/calibration) and the modem partitions and bricks the phone.
These steps only replace the **Data** partition. **Windows Phone will stop
working** (restore it from the backup if needed).

1. **Find the phone's disk** (about 29 GB, partitions named EFIESP, MainOS, Data, DPP).
   Below it is `/dev/sdX`. **Double-check it**: the wrong disk gets wiped.

   ```bash
   lsblk -o NAME,SIZE,PARTLABEL,FSTYPE
   ```

2. **Full backup** (about 32 GB). This is your only way back:

   ```bash
   sudo dd if=/dev/sdX of=~/lumia950-emmc-backup.img bs=4M status=progress conv=fsync
   ```

3. **Find the Data partition number** (`N`). Touch nothing else, especially DPP:

   ```bash
   sudo sgdisk -p /dev/sdX
   ```

4. **Replace Data with two partitions.** `N` = Data's number,
   `M` = a number no other partition uses:

   ```bash
   sudo sgdisk -d N -n N:0:+512M -t N:ef00 -c N:pmOS_boot -n M:0:0 -t M:8300 -c M:pmOS_root /dev/sdX
   ```

   ```bash
   sudo partprobe /dev/sdX
   ```

5. **Write the images and grow the root filesystem:**

   ```bash
   sudo dd if=microsoft-talkman-boot.img of=/dev/sdXN bs=4M status=progress conv=fsync
   ```

   ```bash
   sudo dd if=microsoft-talkman-root.img of=/dev/sdXM bs=4M status=progress conv=fsync
   ```

   ```bash
   sudo e2fsck -f /dev/sdXM && sudo resize2fs /dev/sdXM
   ```

6. Hold the **power** button until the phone vibrates to restart it.

To update later, repeat only step 5 with new images (the partitions stay).

---

## Part 4 - First boot

1. In the Windows boot menu pick **UEFI** (volume keys to move, power to select).
   The UEFI starts GRUB from EFIESP (`EFI/boot/bootaa64.efi`), which starts
   postmarketOS. The pmbootstrap image's systemd-boot does not start on this
   UEFI: install GRUB on EFIESP and copy `update/grub-efiesp.cfg` to
   `EFIESP:/EFI/boot/grub.cfg`.
2. Log in on the console as `ankit`.
3. **SSH over USB**: plug the phone into the Linux PC:

   ```bash
   ssh ankit@172.16.42.1
   ```

### Internet over the USB cable (works without Wi-Fi)

On the **PC** (replace `enxXXXX` with the USB interface that has
`172.16.42.2`, and `wlan0` with the PC's internet interface):

```bash
ip -br addr | grep 172.16.42
```

```bash
sudo sysctl -w net.ipv4.ip_forward=1
```

```bash
sudo iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE && sudo iptables -A FORWARD -i enxXXXX -j ACCEPT && sudo iptables -A FORWARD -o enxXXXX -m state --state RELATED,ESTABLISHED -j ACCEPT
```

On the **phone**:

```bash
sudo ip route add default via 172.16.42.2 && echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf
```

### Boot menu (GRUB)

GRUB boots from the phone's `EFIESP` partition and reads
`EFIESP:/EFI/boot/grub.cfg` (not `/boot/grub.cfg`). It has two entries:
the current kernel and "previous kernel (fallback)", which boots the kernel
`ota-update.sh` kept from before the last update. To change the kernel
command line, edit `update/grub-efiesp.cfg` and run
`sh ~/talkman/tools/install-grub-cfg.sh` (it keeps `grub.cfg.orig`).
`sh ~/talkman/tools/screen-blank.sh N` sets the blank time to N minutes.

### Updating the kernel over SSH (no mass-storage mode)

Build the kernel package on the PC and copy it to `ota/`, then:

```bash
sh ~/talkman/tools/ota-update.sh
```

It replaces `vmlinuz` and the device tree and keeps the working kernel as
`vmlinuz.prev` (GRUB entry "previous kernel (fallback)" when the GRUB config
has one). Reboot with `ssh -t ankit@172.16.42.1 'sudo reboot'`. If the phone no
longer boots, put it in mass-storage mode and run
`sh ~/talkman/tools/recover-kernel.sh` on the Linux PC.

### Wi-Fi

`talkman-wifi.service` powers the Wi-Fi chip at boot; `wlan0` appears about a
minute after boot. Add a network once (type the password at the prompt):

```bash
ssh -t ankit@172.16.42.1 'sudo nmcli dev wifi connect YOUR-SSID --ask'
```

### Bluetooth

A udev rule (`90-talkman-bluetooth-off.rules`) soft-blocks the Bluetooth radio
at boot. The `hci_uart` driver stays loaded because Wi-Fi does not come up
without it. Turn the radio on or off with `sh ~/talkman/tools/bluetooth-off.sh on`
(or `off`).

### CPU frequency scaling (parked)

The kernel has the CPU clock driver (`clk-cpu-8994`, modules) and the OPP tables
(A53 600-960 MHz, A57 384-768 MHz), and the device package installs
`talkman-cpufreq.service`, but the service is **not enabled**: the phone still
freezes when the A57 cluster switches clocks under load. The CPUs run at the
clocks the UEFI left. What is known:

- A57 mux writes must happen with the other CPUs stopped (`stop_machine`), and
  the PLLs the firmware left "on" have to be parked at probe (patch 0019).
- The A57 "ACC" registers are secure-only on the Lumia (SCM write returns
  -EOPNOTSUPP, a direct write hangs), so the A57 cannot go above 768 MHz.
- A settle delay per step (`clk_cpu_8994.settle_us`, default 10000) made loading
  survive, but not sustained load.

To test it again (the modules are installed with
`sh ~/talkman/tools/install-cpufreq.sh`; `tools/cpufreq-test.sh` and
`tools/cpufreq-stress.sh` drive it by hand):

```bash
ssh -t ankit@172.16.42.1 'sudo systemctl enable --now talkman-cpufreq'
```

If the phone dies while the modules load, the next boot skips them and leaves
`/var/lib/talkman-cpufreq.loading`; delete that file to try again.

### Venus video codec (experimental, untested)

Patches 0031-0032 add the MSM8974-style Venus IOMMU and MSM8994/MSM8992
support to the `venus` driver (HFI 1xx, firmware loaded into `venus_mem`). The
target is headless transcoding (for example Jellyfin with V4L2 M2M). The modules
are blocked from auto-loading (`talkman-venus.conf`) until they have been tested.

The firmware is proprietary and is not in this folder's history. It comes from
the phone's own Windows partition (`MainOS:\Windows\System32\qcvss8994.mbn`,
VIDEO.VE.1.10, no HEVC/VP9). With the phone in mass-storage mode:

```bash
sh ~/talkman/tools/get-venus-fw.sh
```

Then, with the phone booted, install the firmware and modules and try it:

```bash
sh ~/talkman/tools/install-venus.sh
```

```bash
sh ~/talkman/tools/venus-test.sh
```

Run `install-venus.sh` after the r46 kernel is installed, so it copies the r46
modules.

### Testing USB host mode (experimental)

1. Unplug from the PC.
2. Connect a **USB-C OTG adapter** with a USB Ethernet dongle or a flash drive.
   Try this before the HD-500 dock.
3. Check what happened (over SSH, or on the phone's console):

   ```bash
   dmesg | grep -iE 'uc120|smbchg|role|xhci|r8152|ax88179'
   ```

   ```bash
   cat /sys/class/typec/port0/data_role /sys/class/usb_role/*/role
   ```

   ```bash
   ip link
   ```

---

## Troubleshooting

- **Hangs with no messages:** the GRUB config already leaves out `quiet` and
  adds `earlycon=efifb ignore_loglevel`. After a crash, `sh ~/talkman/tools/crash-log.sh`
  reads the kernel log that ramoops saved (it often stops partway through boot).
- **New kernel does not boot:** pick "previous kernel (fallback)" in the GRUB
  menu, or run `sh ~/talkman/tools/recover-kernel.sh` with the phone in
  mass-storage mode.
- **Black screen right after the kernel starts:** add `efi=novamap` to the
  `linux` line in `update/grub-efiesp.cfg` and run `tools/install-grub-cfg.sh`.
- **Phone gets hot or charges oddly:** the new charger driver may be at fault.
  Block it with `echo "blacklist qcom_smbchg" | sudo tee /etc/modprobe.d/no-smbchg.conf`
  and reboot (this also disables USB host power).
- **UEFI entry won't start / signature error:** the unlock is incomplete. In
  WPinternals, check that "Unlock bootloader" was done, not just "Root access".

### Restore Windows Phone

Put the phone in mass-storage mode (WPinternals) and write the backup back:

```bash
sudo dd if=~/lumia950-emmc-backup.img of=/dev/sdX bs=4M status=progress conv=fsync
```

---

## Files in this folder

| Path | Contents |
|---|---|
| `device-microsoft-talkman/` | Device package r8 (deviceinfo, kernel command line, initramfs modules, Wi-Fi and USB-debug services, parked CPU-scaling service, Bluetooth-off rule, Venus module block) |
| `linux-postmarketos-qcom-msm8994/v26.06-talkman.patch` | All pmaports changes (device package + kernel r46); apply to pmaports v26.06 |
| `linux-postmarketos-qcom-msm8994/patches/` | The kernel patches on their own (0002-0032) |
| `linux-postmarketos-qcom-msm8994/patches-dropped/` | Superseded patches, kept for reference |
| `update/grub-efiesp.cfg` | The GRUB config installed on EFIESP (two entries, `consoleblank=180`) |
| `stable/r39/` | Frozen known-good kernel r39: patches, device package, notes (`NOTES.md`) |
| `next/patches/` | Carry-over patch for EpicLPer's 7.2-based octagon tree (built, not tested) |
| `tools/` | Install and update: `ota-update.sh`, `recover-kernel.sh`, `install-grub-cfg.sh`, `install-modules.sh`, `install-wifi-service.sh`, `install-cpufreq.sh`, `install-venus.sh`, `get-venus-fw.sh`, `make-image.sh`, `usb-internet.sh`, `add-wifi.sh`. Settings: `screen-blank.sh`, `bluetooth-off.sh`. Diagnostics: `crash-log.sh`, `blank-diag.sh`, `cpufreq-test.sh`, `cpufreq-stress.sh`, `venus-test.sh`, `rpm-watch`, and the older `pcie-*`, `wifi-*`, `talkman-usb-exp*`, `regpoke.c` |

Not in git (see `.gitignore`): built packages and images (`ota/`, `update/`
binaries, `stable/*/image/`, `*.apk`), the 7.2 source tarball, logs, and
`firmware/` (proprietary Qualcomm firmware from the phone).

## Credits

- Mainline Lumia 950 device tree: Konrad Dybcio, Gustave Monce
- Lumia UEFI: WOA-Project (Lumia950XLPkg); BootShim: imbushuo
- UC120 USB-C driver and SMBCHG backport base: Android4Lumia950/linux
  (sonic011gamer); SMBCHG original: Yassine Oudjana, Alejandro Tafalla
- CPU clock driver, PMI8994 fuel gauge, PSCI idle states, thermistors and the
  MSM8974-style Venus IOMMU: EpicLPer's Lumia 950/950 XL kernel work
