#!/bin/sh
# Capture the hardware state of the Wi-Fi PCIe link on the phone (run it
# right after pcie-test.sh failed to train a link) and copy it to this PC.
#   sh ~/talkman/tools/pcie-diag.sh
# Asks for the phone's sudo password once.
set -u

phone=ankit@172.16.42.1
logdir="$HOME/talkman/logs"
mkdir -p "$logdir"
out="$logdir/pcie-diag-$(date +%Y%m%d-%H%M%S).txt"

cat > /tmp/pcie-diag-phone.sh <<'EOF'
#!/bin/sh
RP=/usr/local/bin/regpoke
r() { printf '%s=%s ' "$1" "$($RP r "$2" 2>&1)"; }
echo "===== $(date) kernel $(uname -v)"
echo "--- PHY (0xfc526000): PCS_STATUS bit6 clear = ready"
r PCS_STATUS 0xfc526728; r START 0xfc526608; r SWRESET 0xfc526600; r PWRDN 0xfc526604; r EPREFCLK 0xfc526648; echo
echo "--- PARF (0xfc520000)"
r SYS_CTRL 0xfc520000; r PM_CTRL 0xfc520020; r PHY_CTRL 0xfc520040; r PHY_REFCLK 0xfc52004c; r CFG_BITS 0xfc520050; echo
r DBI_BASE 0xfc520168; r LTSSM 0xfc5201b0; r DEVTYPE 0xfc521000; echo
echo "--- DBI / ELBI"
r PORT_DEBUG0_LTSSM 0xff000728; r PORT_DEBUG1 0xff00072c; r LNKCAP 0xff00007c; r LNKCTL_STA 0xff000080; r ELBI_SYS_STTS 0xff000f28; echo
echo "--- GCC: PCIe0 BCR/CBCRs, USB/others untouched"
r PCIE0_BCR 0xfc401ac0; r SLV_AXI 0xfc401ac8; r MSTR_AXI 0xfc401acc; r CFG_AHB 0xfc401ad0; r AUX 0xfc401ad4; r PIPE 0xfc401ad8; r PHY_BCR 0xfc401b18; echo
echo
echo "--- gpio (debugfs)"; cat /sys/kernel/debug/gpio 2>&1
echo
echo "--- tlmm pin config for 35,36,37,112,113"
for d in /sys/kernel/debug/pinctrl/*tlmm* /sys/kernel/debug/pinctrl/*pinctrl@fd510000*; do [ -f "$d/pinconf-pins" ] && grep -E 'gpio(35|36|37|112|113)\)' "$d/pinconf-pins"; done 2>&1 | head
echo
echo "--- regulators (full)"; cat /sys/kernel/debug/regulator/regulator_summary 2>&1
echo
echo "--- clocks"; grep -iE 'ln_bb|div_clk|pcie|sleep|xo|rpm|bb_clk' /sys/kernel/debug/clk/clk_summary 2>&1 | head -60
echo
echo "--- dmesg tail"; dmesg | tail -60
EOF

echo "== Copying diagnostics script to the phone ..."
scp /tmp/pcie-diag-phone.sh "$phone:/tmp/pcie-diag-phone.sh" || exit 1

echo "== Running it as root (sudo password for ankit on the phone) ..."
timeout --foreground 90 ssh -t "$phone" 'sudo sh /tmp/pcie-diag-phone.sh > /tmp/pcie-diag.txt 2>&1; sudo chmod a+r /tmp/pcie-diag.txt; echo "diag written: $(wc -l < /tmp/pcie-diag.txt) lines"'
scp "$phone:/tmp/pcie-diag.txt" "$out" && echo "== Saved: $out"
