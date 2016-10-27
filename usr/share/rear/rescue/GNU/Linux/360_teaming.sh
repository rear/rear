# 360_teaming.sh
#
# record teaming information (network and routing) for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# BUG: Supports Ethernet only (so far)

# where to build networking configuration
netscript=$ROOTFS_DIR/etc/scripts/system-setup.d/63-teaming.sh

### Skip netscript if noip is configured on the command line
cat <<EOT >> ${netscript}
if [[ -e /proc/cmdline ]] ; then
    if grep -q 'noip' /proc/cmdline ; then
        return
    fi
fi
EOT

# add a line at the top of netscript to skip if dhclient will be used
cat - <<EOT > ${netscript}
# if USE_DHCLIENT=y then use DHCP instead and skip 60-network-devices.sh
[[ ! -z "\$USE_DHCLIENT" && -z "\$USE_STATIC_NETWORKING" ]] && return
# if IPADDR=1.2.3.4 has been defined at boot time via ip=1.2.3.4 then configure
if [[ "\$IPADDR" ]] && [[ "\$NETMASK" ]] ; then
    device=\${NETDEV:-eth0}
    ip link set dev "\$device" up
    ip addr add "\$IPADDR"/"\$NETMASK" dev "\$device"
    if [[ "\$GATEWAY" ]] ; then
        ip route add default via "\$GATEWAY"
    fi
    return
fi
EOT

# store virtual devices, because teaming interfaces are declared as virtual
VIRTUAL_DEVICES=$(ls /sys/devices/virtual/net)

TEAMINGS=()

# check if virtual interface is a teaming interface
for VIRT_DEV in ${VIRTUAL_DEVICES}
do
    if ethtool -i ${VIRT_DEV} | grep -w "driver:" | grep -qw team
    then
        TEAMINGS+=($VIRT_DEV)
    fi

done

for TEAM in "${TEAMINGS[@]}"
do
    # catch all ip-addresses for the teaming interface
    ADDR=()
    for x in $(ip ad show dev ${TEAM} scope global | grep "inet.*\ " | tr -s " " | cut -d " " -f 3)
    do
        ADDR+=($x)
    done

    # create netscript only when the interface has at least one configured ip
    # to simplify we attach the configured ip-addresses to the first teaming-member
    if [[ ${ADDR[*]} ]]
    then
        # find out one member interface. Greping for "active port:" will not work for all possible teaming configs (e.g. roundrobin, loadbalance, ...)
        FIRST_PORT=$(teamdctl ${TEAM} state | grep -A1 -w ports: | tail -1  | sed 's/[[:blank:]]*//g')

        for TEAM_IP in ${ADDR[@]}
        do
            echo "ip addr add ${TEAM_IP} dev ${FIRST_PORT}" >>${netscript}
        done

        echo "ip link set dev ${FIRST_PORT} up" >>${netscript}

        PORT_MTU="$(cat /sys/class/net/${FIRST_PORT}/mtu)"
        echo "ip link set dev ${FIRST_PORT} mtu ${PORT_MTU}" >>${netscript}
    fi

    # catch the routing for the teaming interface as we disabled it in 350_routing.sh
    for table in $( { echo "254     main" ; cat /etc/iproute2/rt_tables ; } |\
            grep -E '^[0-9]+' |\
                tr -s " \t" " " |\
                cut -d " " -f 2 | sort -u | grep -Ev '(local|default|unspec)' ) ;
        do
            ip route list table $table |\
                grep -Ev 'scope (link|host)' |\
                while read destination via gateway dev device junk;
                do
            if [[ "${device}" == "${TEAM}" ]]
            then
                echo "ip route add ${destination} ${via} ${gateway} ${dev} ${FIRST_PORT} table ${table}" >>${netscript}
            fi
        done
    done
done
