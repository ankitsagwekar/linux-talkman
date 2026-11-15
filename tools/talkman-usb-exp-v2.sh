#!/bin/sh
# USB bring-up measurements, round 2 (runs once per boot).
# Boot with the cable plugged into a PC and WATCH THE SCREEN: it asks you to
# unplug and re-plug the cable. Results: /var/log/talkman-usb-exp.txt
out=/var/log/talkman-usb-exp.txt
RP=/usr/local/bin/regpoke
UDC=/sys/class/udc/f9200000.usb
PSY=/sys/class/power_supply/qcom-smbchg-usb
HS=0xf92f8810; PARAM=0xf92f8814; CHGCTL=0xf92f8818; CHGOUT=0xf92f881c
ALTEN=0xf92f8820; IRQSTAT=0xf92f8824; COMMON=0xf92f88ec

log() { echo "$*" >> "$out"; sync; }
say() { i=0; while [ $i -lt 3 ]; do echo "<1>==== USB TEST: $* ====" > /dev/kmsg; i=$((i+1)); done; log "SCREEN: $*"; }
rv() { $RP r "$1" 2>&1; }
state() {
	echo "  t=$(cut -d' ' -f1 /proc/uptime) udc=$(cat $UDC/state 2>&1) vbus_present=$(cat $PSY/present 2>&1) HSCTRL=$(rv $HS) COMMON=$(rv $COMMON) DSTS=$(rv 0xf920c70c) DCTL=$(rv 0xf920c704) IRQSTAT=$(rv $IRQSTAT) link=$(cat /sys/kernel/debug/usb/f9200000.usb/link_state 2>&1)" >> "$out"
}
# Read the PHY's own line-state / charger comparators in each detection mode
probe() {
	log "-- probe: $1"
	state
	for ctl in 0x0 0x2 0x30 0x34 0x10; do
		$RP w $CHGCTL $ctl > /dev/null 2>&1
		sleep 1
		a=$(rv $CHGOUT); sleep 1; b=$(rv $CHGOUT)
		echo "  CHGCTL=$ctl -> CHGOUT=$a then $b" >> "$out"
	done
	$RP w $CHGCTL 0x0 > /dev/null 2>&1
	sync
}
pullup_off() {
	echo disconnect > $UDC/soft_connect 2>>"$out"
	$RP c $HS 0x00002000 >> "$out" 2>&1   # VBUSVLDEXT0 off
	sleep 1
}
pullup_on() {
	$RP s $HS 0x10102000 >> "$out" 2>&1
	echo connect > $UDC/soft_connect 2>>"$out"
	sleep 2
}
wait_vbus() { # $1 = wanted value, up to 40 s
	i=0
	while [ $i -lt 40 ]; do
		[ "$(cat $PSY/present 2>/dev/null)" = "$1" ] && return 0
		sleep 1; i=$((i+1))
	done
	return 1
}

log ""
log "===== USB measurements v2, kernel $(uname -v) ====="
[ -x $RP ] || { log "regpoke missing"; exit 1; }

log "-- environment"
{
	echo "typec: data=$(cat /sys/class/typec/port0/data_role 2>&1) power=$(cat /sys/class/typec/port0/power_role 2>&1) orient=$(cat /sys/class/typec/port0/orientation 2>&1)"
	for c in div_clk1 div_clk2 div_clk3 ln_bb_clk; do
		d=/sys/kernel/debug/clk/$c
		[ -d $d ] && echo "clk $c: enable=$(cat $d/clk_enable_count) prepare=$(cat $d/clk_prepare_count) rate=$(cat $d/clk_rate)"
	done
	for p in /sys/kernel/debug/pinctrl/*; do
		case "$p" in *pmic*|*gpio@c000*|*spmi*) echo "pinctrl $p"; grep -E 'gpio(4|5|8|9|10|17|18)\)' $p/pinconf-pins 2>/dev/null;; esac
	done
	grep -iE 'pm8994|pmi8994|gpio-(4|5|8|9|10|17) ' /sys/kernel/debug/gpio 2>/dev/null | head -40
} >> "$out" 2>&1
sync

# Phase A: cable in, as booted (pull-up on)
probe "A: cable IN, pull-up ON"
# Phase B: cable in, pull-up off
pullup_off
probe "B: cable IN, pull-up OFF"
pullup_on

# Phase C: Windows' own PHY tuning value from the Lumia ACPI tables
log "-- C: PARAMETER_OVERRIDE_X = 0x00D191A7 (Windows value)"
$RP w $PARAM 0x00d191a7 >> "$out" 2>&1
echo disconnect > $UDC/soft_connect; sleep 1; echo connect > $UDC/soft_connect
sleep 5; state
if [ "$(cat $UDC/state)" != "not attached" ]; then
	log "*** SUCCESS with Windows tuning value: udc=$(cat $UDC/state)"
	say "USB WORKS NOW - leave the cable in"
	exit 0
fi

# Phase D/E: cable out
say "UNPLUG THE USB CABLE NOW"
if wait_vbus 0; then log "cable unplugged (VBUS gone)"; else log "VBUS never went away (40 s)"; fi
sleep 2
probe "D: cable OUT, pull-up ON"
pullup_off
probe "E: cable OUT, pull-up OFF"
pullup_on

say "PLUG THE USB CABLE BACK IN"
if wait_vbus 1; then log "cable plugged back (VBUS present)"; else log "VBUS never came back (40 s)"; fi
sleep 5
log "-- F: after re-plug"
state
{
	echo "typec: data=$(cat /sys/class/typec/port0/data_role 2>&1) power=$(cat /sys/class/typec/port0/power_role 2>&1) orient=$(cat /sys/class/typec/port0/orientation 2>&1)"
	dmesg | grep -iE 'uc120|typec|smbchg|dwc3|gadget' | tail -30
} >> "$out" 2>&1
say "TEST FINISHED - thank you"
log "===== finished ====="
