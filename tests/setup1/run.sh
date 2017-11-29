#!/bin/bash

echo
echo "$0"
echo

REAR_DIR="/path/to/rear/sources"

RESULT_DIR="/root/$(basename $0 .sh)_results"
mkdir -p $RESULT_DIR

function DebugPrint () {
	echo "DebugPrint: $*" | tee -a $RESULT_DIR/stderr >&2
}

function LogPrint () {
	echo "LogPrint: $*" | tee -a $RESULT_DIR/stderr >&2
}

function LogPrintError () {
	echo "LogPrintError: $*" | tee -a $RESULT_DIR/stderr >&2
}

function BugError () {
	echo "BUGERROR: $*" | tee -a $RESULT_DIR/stderr >&2
}

function read_and_strip_file () {
	grep -v "^#" $1 2>/dev/null || true
}

TMP_DIR=/root/tmp

rm -fr $TMP_DIR

# Add to sed -e below to test 'has_lower_links=0' (RHEL6)
#    -e 's#$has_lower_links#0#' \

# Add to sed -e below to test 'readlink' taking only 1 filename (RHEL6)
#    -e 's#readlink /foo /bar#! readlink /foo /bar#' \

# Add to sed -e below to have code using 'brctl' instead of 'ip link' (RHEL6)
#    -e 's#^iplink_has_bridge_rc=#iplink_has_bridge_rc=1#' \
sed -e "s#^network_devices_setup_script=.*#network_devices_setup_script=/tmp/60-network-devices.sh#" \
    $REAR_DIR/usr/share/rear/rescue/GNU/Linux/310_network_devices.sh > /tmp/310_network_devices.sh
sed "s#^netscript=.*#netscript=/tmp/62-routing.sh#" $REAR_DIR/usr/share/rear/rescue/GNU/Linux/350_routing.sh > /tmp/350_routing.sh

. /tmp/310_network_devices.sh
. /tmp/350_routing.sh

for f in /tmp/60-network-devices.sh /tmp/62-routing.sh; do
	grep -v "dev eth0" $f > $RESULT_DIR/$(basename $f)
done
