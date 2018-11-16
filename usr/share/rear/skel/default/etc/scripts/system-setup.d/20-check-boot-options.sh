# purpose of 20-check-boot-options.sh is to find out if at boot time
# we entered special boot options, such as:
# dhcp to force DHCLIENT to be started instead of the network scripts
# ip=10.10.10.10 was defined to force an IPADDR of our choice instead
# of the original IP address of the source system (useful for cloning purposes)
# nm=255.255.255.0 to set the netmask (may be skipped)

read -r </proc/cmdline
echo $REPLY | grep -q dhcp && USE_DHCLIENT=y
echo $REPLY | grep -q "ip="
if [ $? -eq 0 ]; then
	IPADDR=${REPLY#*ip=}
	IPADDR=${IPADDR%% *}
	echo "IP address will be overruled by kernel option ip=$IPADDR"
fi
echo $REPLY | grep -q "nm="
if [ $? -eq 0 ]; then
	NETMASK=${REPLY#*nm=}
	NETMASK=${NETMASK%% *}
fi
echo $REPLY | grep -q "gw="
if [ $? -eq 0 ]; then
	GATEWAY=${REPLY#*gw=}
	GATEWAY=${GATEWAY%% *}
fi
echo $REPLY | grep -q "netdev="
if [ $? -eq 0 ]; then
    NETDEV=${REPLY#*netdev=}
    NETDEV=${NETDEV%% *}
fi
