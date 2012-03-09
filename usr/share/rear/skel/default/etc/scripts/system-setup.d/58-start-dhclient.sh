# start dhclient daemon script
#
# check if we have USE_DHCLIENT=y, if not then we run 60/62 scripts
[[ -z "$USE_DHCLIENT"  ]] && return

echo "Attempting to start the DHCP client daemon"

. /usr/share/rear/lib/network-functions.sh

# Need to find the devices and their HWADDR (avoid local and virtual devices)
for dev in `get_device_by_hwaddr` ; do
        case $dev in
		(lo|pan*|sit*|tun*|tap*|vboxnet*|vmnet*|virt*|vif*) continue ;; # skip all kind of internal devices
        esac
        HWADDR=`get_hwaddr $dev`

	if [ -n "$HWADDR" ]; then
		HWADDR=$(echo $HWADDR | awk '{ print toupper($0) }')
	fi
	[ -z "$DEVICE" -a -n "$HWADDR" ] && DEVICE=$(get_device_by_hwaddr $HWADDR)
	[ -z "$DEVICETYPE" ] && DEVICETYPE=$(echo ${DEVICE} | sed "s/[0-9]*$//")
	[ -z "$REALDEVICE" -a -n "$PARENTDEVICE" ] && REALDEVICE=$PARENTDEVICE
	[ -z "$REALDEVICE" ] && REALDEVICE=${DEVICE%%:*}
	if [ "${DEVICE}" != "${REALDEVICE}" ]; then
		ISALIAS=yes
	else
		ISALIAS=no
	fi

	# IPv4 DHCP clients
	case $DHCLIENT_BIN in
		(dhclient)
			dhclient -lf /var/lib/dhclient/dhclient.leases.${DEVICE} -pf /var/run/dhclient.pid -cf /etc/dhclient.conf ${DEVICE}
		;;
		(dhcpcd)
			dhcpcd -c /bin/dhcpcd.sh ${DEVICE}
		;;
	esac

	# IPv6 DHCP clients
	case $DHCLIENT6_BIN in
		(dhclient6)
			dhclient6 -lf /var/lib/dhclient/dhclient.leases.${DEVICE} -pf /var/run/dhclient.pid -cf /etc/dhclient.conf ${DEVICE}
		;;
		(dhcp6c)
			dhcp6c  ${DEVICE}
		;;
	esac
done
