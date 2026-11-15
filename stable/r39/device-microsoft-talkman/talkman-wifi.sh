#!/bin/sh
# Bring up the QCA6174 Wi-Fi chip on PCIe0 (MSM8992). The kernel keeps the
# MSM8994 PCIe driver off until asked; the chip takes 10-45 s to train its link
# after being powered, so poll and rescan until it shows up.
P=/sys/module/pcie_qcom/parameters/msm8994_enable
RC=fc520000.pcie
EP=/sys/bus/pci/devices/0000:01:00.0

[ -w "$P" ] || exit 0
# ath10k asks for optional calibration files that do not exist; without a
# firmware helper the kernel waits the default 60 s for each one.
[ -w /sys/class/firmware/timeout ] && echo 1 > /sys/class/firmware/timeout
echo 1 > "$P"
[ -e /sys/bus/platform/drivers/qcom-pcie/$RC ] || \
	echo "$RC" > /sys/bus/platform/drivers/qcom-pcie/bind
i=0
while [ ! -e "$EP" ] && [ $i -lt 40 ]; do
	echo 1 > /sys/bus/pci/rescan
	sleep 3
	i=$((i + 1))
done
[ -e "$EP" ] && echo "Wi-Fi chip found" || echo "Wi-Fi chip did not appear"
