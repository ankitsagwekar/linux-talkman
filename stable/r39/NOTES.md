# Frozen build: kernel 6.16-r39 (2026-11-15)

Known-good snapshot for the Lumia 950. Reinstall the kernel with:

    sh ~/talkman/tools/ota-update.sh ~/talkman/stable/r39/linux-postmarketos-qcom-msm8994-6.16-r39.apk
    sh ~/talkman/tools/install-modules.sh drivers/power/supply/qcom-pmi8994-fg.ko   # only if /lib/modules lacks it

Working in this build: boot, UEFI framebuffer, touch, keys, USB networking,
Wi-Fi (talkman-wifi.service), battery percentage and signed current (fuel
gauge), wall charging (~1.2 A), CPU idle states (PSCI).

Not in effect: CPU frequency scaling (modules installed, guard file
/var/lib/talkman-cpufreq.loading keeps them off after a crash).

Known limits: drains ~150 mA on a PC USB port (500 mA is less than the idle
draw); no native display, GPU, audio, camera, modem, power button.

Contents: kernel package, all kernel patches (0002-0027), the full pmaports
diff (v26.06-talkman.patch) and the device package.

## Full images (image/)

Built with `pmbootstrap install --split` and `tools/make-image.sh` on 2026-11-15:

- `microsoft-talkman-root.img`: root filesystem (label pmOS_root, fstab by label,
  Wi-Fi/CPU services enabled). Write it to the phone's pmOS_root partition.
- `vmlinuz`, `initramfs`, `msm8992-msft-lumia-octagon-talkman.dtb`, `grub.cfg`:
  copy onto the existing pmOS_boot partition (keeps GRUB).
- `microsoft-talkman-boot.img`: pmbootstrap's own boot partition image
  (systemd-boot; does not start on this UEFI, kept for reference).
- `SHA256SUMS`: checksums of the above.

Install as in README Part 3, using these files instead of `update/`. The Wi-Fi
password is not in the image: add the network after first boot (README, Wi-Fi).
