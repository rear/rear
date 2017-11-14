#!/bin/bash

REAR_DIR="/path/to/rear/sources"

RESULT_DIR="/root/$(basename $0 .sh)_results"
mkdir -p $RESULT_DIR

function DebugPrint () {
	echo "DebugPrint: $*" | tee $RESULT_DIR/stderr >&2
}

function LogPrint () {
	echo "LogPrint: $*" | tee $RESULT_DIR/stderr >&2
}

function LogPrintError () {
	echo "LogPrintError: $*" | tee $RESULT_DIR/stderr >&2
}

function BugError () {
	echo "BUGERROR: $*" | tee $RESULT_DIR/stderr >&2
}

function read_and_strip_file () {
	grep -v "^#" $1 2>/dev/null || true
}

TMP_DIR=/root/tmp

rm -fr $TMP_DIR

sed "s#^network_devices_setup_script=.*#network_devices_setup_script=/tmp/60-network-devices.sh#" $REAR_DIR/usr/share/rear/rescue/GNU/Linux/310_network_devices.sh > /tmp/310_network_devices.sh
sed "s#^netscript=.*#netscript=/tmp/62-routing.sh#" $REAR_DIR/usr/share/rear/rescue/GNU/Linux/350_routing.sh > /tmp/350_routing.sh

. /tmp/310_network_devices.sh
. /tmp/350_routing.sh

for f in /tmp/60-network-devices.sh /tmp/62-routing.sh; do
	grep -v "dev eth0" $f > $RESULT_DIR/$(basename $f)
done
