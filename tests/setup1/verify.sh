#!/bin/bash

CASE=$1
if [ -z "$CASE" ]; then
	echo "Need a test case directory as argument!" >&2
	exit 2
fi

echo
echo "CASE $CASE"
echo

DEVICES="$( ls /sys/class/net/ | egrep -wv "(bonding_masters|eth0|lo)" )"

# Cleanup of network interfaces
for dev in $DEVICES; do
	ip addr flush dev $dev
	ip link set dev $dev down
	ip link del $dev
done 2>/dev/null

for file in 60-network-devices.sh 62-routing.sh; do
	bash $CASE/$file
done

sleep 3

tmpfile_ipa=$( mktemp /tmp/REARXXX )
tmpfile_ipr=$( mktemp /tmp/REARXXX )

DEVICES="$( ls /sys/class/net/ | egrep -wv "(bonding_masters|eth0|lo)" )"

for dev in $DEVICES; do
	ip addr show dev $dev
done 2>/dev/null | egrep -w "(mtu|inet)" | sed "s/^[0-9]*: //" > $tmpfile_ipa

for dev in $DEVICES; do
	ip r show dev $dev
done 2>/dev/null | sort > $tmpfile_ipr

echo
echo "Verifying 'ip a' output"
echo
rc=0
if ! diff -u <(sort $CASE/ip_a.expected) <(sort $tmpfile_ipa); then
	rc=1
else
	/bin/rm $tmpfile_ipa
	echo "ip a OK"
fi

echo
echo "Verifying 'ip r' output"
echo
if ! diff -u <(sort $CASE/ip_r.expected) <(sort $tmpfile_ipr); then
	rc=1
else
	/bin/rm $tmpfile_ipr
	echo "ip r OK"
fi

# Cleanup of network interfaces
for dev in $DEVICES; do
	ip addr flush dev $dev
	ip link set dev $dev down
	ip link del $dev
done 2>/dev/null

exit $rc
