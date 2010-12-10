# start dhclient daemon script
#
## check if we have the executable, if not then we run 60/62 scripts
[ ! -x /bin/dhclient ] && return

echo "Start dhclient daemon..."

. /usr/share/rear/lib/network-functions.sh

# Need the find the devices and their HWADDR (take the last in row)
for dev in `get_device_by_hwaddr` ; do
        case $dev in
                lo|pan*|sit*|tun*|tap*|vboxnet*|vmnet*|virt*) continue ;; # skip all kind of internal devices
        esac
        HWADDR=`get_hwaddr $dev`
done

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

dhclient -lf /var/lib/dhclient/dhclient.leases -pf /var/run/dhclient -cf /etc/dhclient.conf -v ${DEVICE}
