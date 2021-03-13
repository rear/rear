# start dhclient daemon script
#
# Skip execution if USE_DHCLIENT is empty or set to 'false'.
! is_true $USE_DHCLIENT && return

# When USE_STATIC_NETWORKING is set to a 'true' value
# (by default USE_STATIC_NETWORKING is empty)
# no networking setup via DHCP must happen because
# USE_STATIC_NETWORKING overrules USE_DHCLIENT (see default.conf):
is_true $USE_STATIC_NETWORKING && return

# if 'noip' is gicen on boot prompt then skip dhcp start-up
if [[ -e /proc/cmdline ]] ; then
    if grep -q 'noip' /proc/cmdline ; then
        return
    fi
fi

echo "Attempting to start the DHCP client daemon"

# To be sure that network is properly initialized (get_device_by_hwaddr sees network interfaces)
sleep 5

# Source the network related functions:
source /etc/scripts/dhcp-setup-functions.sh

# Need to find the devices and their HWADDR (avoid local and virtual devices)
for DEVICE in `get_device_by_hwaddr` ; do
        case $DEVICE in
		(lo|pan*|sit*|tun*|tap*|vboxnet*|vmnet*|virt*|vif*) continue ;; # skip all kind of internal devices
        esac
        HWADDR=`get_hwaddr $DEVICE`

	if [ -n "$HWADDR" ]; then
		HWADDR=$(echo $HWADDR | awk '{ print toupper($0) }')
	    DEVICE=$(get_device_by_hwaddr $HWADDR)
	fi
	[ -z "$DEVICETYPE" ] && DEVICETYPE=$(echo ${DEVICE} | sed "s/[0-9]*$//")
	[ -z "$REALDEVICE" -a -n "$PARENTDEVICE" ] && REALDEVICE=$PARENTDEVICE
	[ -z "$REALDEVICE" ] && REALDEVICE=${DEVICE%%:*}
	if [ "${DEVICE}" != "${REALDEVICE}" ]; then
		ISALIAS=yes
	else
		ISALIAS=no
	fi

	case "$DHCLIENT_BIN" in
		(dhclient*)
			"$DHCLIENT_BIN" -lf /var/lib/dhclient/dhclient.leases.${DEVICE} -pf /var/run/dhclient.${DEVICE}.pid -cf /etc/dhclient.conf ${DEVICE}
		    ;;
		(dhcpcd*)
			"$DHCLIENT_BIN" ${DEVICE}
		    ;;
		(*)
		    echo "Could not start DHCP client as DHCLIENT_BIN specifies an unsupported binary '$DHCLIENT_BIN'"
		    ;;
	esac
done
