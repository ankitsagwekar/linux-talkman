#!/bin/sh
# USB bring-up experiment v3: route the primary USB port to the DWC3 controller.
# Downstream dwc3-msm.c writes 1 to the TCSR register at 0xfd4ab000 ("Enable
# USB3 on the primary USB port"). Mainline never does. Results: /var/log/talkman-usb-exp.txt
out=/var/log/talkman-usb-exp.txt
RP=/usr/local/bin/regpoke
UDC=/sys/class/udc/f9200000.usb
TCSR=0xfd4ab000

log() { echo "$*" >> "$out"; sync; }
state() { log "  udc=$(cat $UDC/state 2>&1) vbus=$(cat /sys/class/power_supply/qcom-smbchg-usb/present 2>&1) DSTS=$($RP r 0xf920c70c 2>&1) HSCTRL=$($RP r 0xf92f8810 2>&1) TCSR=$($RP r $TCSR 2>&1)"; }
reconnect() {
	echo disconnect > $UDC/soft_connect 2>>"$out"; sleep 1
	echo connect > $UDC/soft_connect 2>>"$out"
}
try() { # $1 = TCSR value to write
	log "--- TCSR $TCSR <- $1"
	$RP w $TCSR "$1" >> "$out" 2>&1
	reconnect
	i=0
	while [ $i -lt 12 ]; do
		s=$(cat $UDC/state 2>/dev/null)
		if [ -n "$s" ] && [ "$s" != "not attached" ]; then
			log "*** SUCCESS: udc=$s with TCSR=$1"
			state
			echo "<1>==== USB WORKS NOW (TCSR=$1) ====" > /dev/kmsg
			exit 0
		fi
		sleep 1; i=$((i + 1))
	done
	log "    no change"
	state
}

log ""
log "===== USB experiment v3 (TCSR port select), kernel $(uname -v) ====="
[ -x $RP ] || { log "regpoke missing"; exit 1; }
log "-- initial"; state
try 0x1
try 0x0
try 0x3
log "===== finished: no value attached the UDC ====="
echo 0x1 > /dev/null
$RP w $TCSR 0x1 >> "$out" 2>&1
