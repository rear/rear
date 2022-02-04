#!/bin/bash
# system-status.sh
# give s summary information about important system infos
(
# variable is assigned in:
# usr/share/rear/lib/_input-output-functions.sh
# shaellcheck disable=SC2034
LF="$(echo)"
export LF
echo "---------------------------------------------------------------"
echo "System Status Overview for $(hostname -f)"
echo "I am $(uname -a)"
echo "---- Loaded modules:"
lsmod
echo "---- NIC configuration:"
for k in $(ip l |grep \< | cut -d : -f 2) ; do
	echo "NIC $k:"
	ethtool -i $k 2>&1
	ethtool $k 2>&1
done
if test "$(brctl show | wc -l)" -gt 1 ; then
	echo "---- Bridge configuration:"
	brctl show
	for k in $(brctl show | grep '\.' | tr -s "\t " " " | cut -d " " -f 1) ; do
		echo "-- Bridge $k STP status:"
		brctl showstp $k
		echo "-- Bridge $k MAC addresses:"
		brctl showmacs $k
	done
fi
#sleep 1 # to let syslog send the data
echo "---- IP configuration:"
ip addr list
echo "---- IP routing:"
ip route list
echo "---- IPTABLES status:"
iptables -L -v -n
iptables -L -v -n -t nat
if type -p ebtables >/dev/null ; then
	echo "---- EBTABLES status:"
	ebtables -L -v -n
fi
if type -p arptables >/dev/null ; then
	echo "---- ARPTABLES status:"
	arptables -L -v -n
fi
sleep 1 # to let syslog send the data
echo "--------------------------------------------------------------"
echo "---- Running processes:"
ps ax -F
echo "---- Memory:"
free
echo "---- Network connections:"
netstat -atupn
if test -r /var/run/*ntpd.pid ; then
	echo "---- NTP information:"
	ntpq -c peers 127.0.0.1
fi
echo "---------------------------------------------------------------"
) | expand
