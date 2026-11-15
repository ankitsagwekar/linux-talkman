#!/bin/sh
# Install the Venus video codec pieces on the phone: the Lumia firmware
# (qcvss8994.mbn), the Venus and supporting media modules from the newest
# kernel package, and a block so they never load automatically at boot.
# Asks for the phone's sudo password.
#   sh ~/talkman/tools/install-venus.sh
set -eu
phone=ankit@172.16.42.1
pkg=$(ls -t "$HOME"/talkman/ota/linux-postmarketos-qcom-msm8994-*.apk | head -1)
fw="$HOME/talkman/firmware/qcvss8994.mbn"
[ -f "$fw" ] || { echo "missing $fw (run tools/get-venus-fw.sh)" >&2; exit 1; }
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
tar -xzf "$pkg" -C "$work" lib/modules 2>/dev/null
K=lib/modules/6.16.0/kernel
mods=$(cd "$work/$K" && find drivers/media/platform/qcom/venus drivers/media/v4l2-core drivers/media/common/videobuf2 drivers/media/mc drivers/soc/qcom -name '*.ko' 2>/dev/null | grep -E 'venus|v4l2|videobuf2|videodev|mc\.ko|mdt_loader' | sort)
echo "== From $(basename "$pkg"):"; echo "$mods" | sed 's/^/   /'
mkdir -p "$work/send"
for m in $mods; do mkdir -p "$work/send/$(dirname "$m")"; cp "$work/$K/$m" "$work/send/$m"; done
cp "$fw" "$work/send/qcvss8994.mbn"
printf 'install venus_core /bin/false\ninstall venus_dec /bin/false\ninstall venus_enc /bin/false\n' > "$work/send/talkman-venus.conf"
( cd "$work/send" && tar -czf ../venus.tgz . )
scp "$work/venus.tgz" "$phone:/tmp/venus.tgz"
ssh -t "$phone" 'set -e
sudo rm -rf /tmp/venus-inst; mkdir -p /tmp/venus-inst; tar -xzf /tmp/venus.tgz -C /tmp/venus-inst
cd /tmp/venus-inst
for m in $(find drivers -name "*.ko"); do sudo install -Dm644 $m /lib/modules/6.16.0/kernel/$m; done
sudo install -Dm644 qcvss8994.mbn /lib/firmware/qcom/msm8994/microsoft/qcvss8994.mbn
sudo install -Dm644 talkman-venus.conf /etc/modprobe.d/talkman-venus.conf
sudo depmod -a 6.16.0
ls -la /lib/firmware/qcom/msm8994/microsoft/
echo "installed (Venus stays off at boot; load it with tools/venus-test.sh)"'
