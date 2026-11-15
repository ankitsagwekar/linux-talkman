#!/bin/sh
# One-shot USB bring-up experiments for the Lumia 950 (runs once per boot).
# Keep the phone plugged into a PC. Results: /var/log/talkman-usb-exp.txt
out=/var/log/talkman-usb-exp.txt
stagef=/var/lib/talkman-usb-exp.stage
RP=/usr/local/bin/regpoke
UDC=/sys/class/udc/f9200000.usb
HS=0xf92f8810      # QSCRATCH HS_PHY_CTRL
COMMON=0xf92f88ec  # QSCRATCH HS_PHY_CTRL_COMMON

log() { echo "$*" >> "$out"; sync; }
r() { printf '%s=%s ' "$1" "$($RP r "$2" 2>&1)"; }
dump() {
	{
		echo "[$1] t=$(cut -d' ' -f1 /proc/uptime) udc=$(cat $UDC/state 2>&1)"
		r GENCFG 0xf92f8808; r HSCTRL $HS; r PARAM 0xf92f8814; r CHGDET 0xf92f8818
		r CHGOUT 0xf92f881c; r ALTEN 0xf92f8820; r IRQSTAT 0xf92f8824
		r SSCTRL 0xf92f8830; r COMMON $COMMON; echo
		r GCTL 0xf920c110; r GSTS 0xf920c118; r GUSB2PHYCFG 0xf920c200
		r DCFG 0xf920c700; r DCTL 0xf920c704; r DSTS 0xf920c70c; echo
		r SLEEPCBCR 0xfc4004ac; r PHYBCR 0xfc4004b0; r AHB2PHY 0xfc401a84
		r MOCKUTMI 0xfc4003d0; r MASTER 0xfc4003c8; echo
	} >> "$out" 2>&1
	sync
}
reconnect() {
	echo disconnect > $UDC/soft_connect 2>>"$out"
	sleep 1
	echo connect > $UDC/soft_connect 2>>"$out"
}
check() {
	i=0
	while [ $i -lt 6 ]; do
		s=$(cat $UDC/state 2>/dev/null)
		if [ -n "$s" ] && [ "$s" != "not attached" ]; then
			log "*** SUCCESS after step $1: udc=$s"
			dump "success-$1"
			rm -f "$stagef"; sync
			exit 0
		fi
		sleep 1; i=$((i + 1))
	done
	log "    no change after step $1"
}
# Skip the step a previous boot died in (and later ones) to avoid a loop.
badf=/var/lib/talkman-usb-exp.bad
mkdir -p /var/lib
if [ -f "$stagef" ]; then
	cat "$stagef" > "$badf"   # the previous boot never finished that step
	rm -f "$stagef"; sync
fi
died=99
[ -f "$badf" ] && died=$(cat "$badf")
step() {
	if [ "$1" -ge "$died" ]; then
		log "--- step $1 skipped (an earlier boot died at step $died)"
		return 1
	fi
	echo "$1" > "$stagef"; sync
	log "--- step $1: $2"
	return 0
}

mkdir -p /var/lib
log ""
log "===== USB experiments, kernel $(uname -r) $(uname -v) ====="
[ -x $RP ] || { log "regpoke missing"; exit 1; }
dump initial

step 1 "soft reconnect only" && { reconnect; check 1; }

step 2 "clear QSCRATCH charger detection + alt interrupts" && {
	$RP w 0xf92f8818 0 >> "$out" 2>&1
	$RP c 0xf92f8820 0x1fff >> "$out" 2>&1
	$RP w 0xf92f8824 0x1fff >> "$out" 2>&1
	reconnect; check 2; }

step 3 "force VBUS-valid / D+ pull-up override bits" && {
	$RP s $COMMON 0x00001000 >> "$out" 2>&1   # VBUSVLDEXTSEL0
	$RP s $HS 0x10102000 >> "$out" 2>&1       # SW_SESSVLD_SEL|UTMI_OTG_VBUS_VALID|VBUSVLDEXT0
	$RP s 0xf92f8830 0x01000000 >> "$out" 2>&1 # LANE0_PWR_PRESENT
	reconnect; check 3; }

step 4 "force PHY out of suspend (SUSPEND_N_SEL|SUSPEND_N)" && {
	$RP s $HS 0x00c00000 >> "$out" 2>&1
	reconnect; check 4; }

step 5 "release all HV/ID/DP/DM clamps" && {
	$RP s $HS 0x01020380 >> "$out" 2>&1
	reconnect; check 5; }

step 6 "enable gcc_usb2_hs_phy_sleep_clk" && {
	$RP s 0xfc4004ac 0x1 >> "$out" 2>&1
	sleep 1; dump after-6; reconnect; check 6; }

step 7 "PHY power-on reset via GCC USB2_HS_PHY_ONLY_BCR" && {
	echo disconnect > $UDC/soft_connect 2>>"$out"
	$RP s 0xfc4004b0 0x1 >> "$out" 2>&1
	sleep 1
	$RP c 0xfc4004b0 0x1 >> "$out" 2>&1
	sleep 1
	echo connect > $UDC/soft_connect 2>>"$out"
	dump after-7; check 7; }

step 8 "re-probe dwc3 core, re-attach gadget" && {
	echo f9200000.usb > /sys/bus/platform/drivers/dwc3/unbind 2>>"$out"
	sleep 1
	echo f9200000.usb > /sys/bus/platform/drivers/dwc3/bind 2>>"$out"
	sleep 2
	for g in /sys/kernel/config/usb_gadget/*; do
		[ -d "$g" ] && echo f9200000.usb > "$g/UDC" 2>>"$out"
	done
	$RP s $HS 0x10102000 >> "$out" 2>&1
	sleep 1; dump after-8; check 8; }

step 9 "alternative ref-clock select (FSEL default, no PLLBTUNE)" && {
	$RP c $COMMON 0x0000c000 >> "$out" 2>&1
	$RP s $COMMON 0x00000030 >> "$out" 2>&1
	sleep 1; reconnect; check 9; dump after-9; }

log "===== finished, no step attached the UDC ====="
dmesg | grep -iE 'dwc3|udc|gadget|usb' | tail -40 >> "$out" 2>&1
rm -f "$stagef"; sync
