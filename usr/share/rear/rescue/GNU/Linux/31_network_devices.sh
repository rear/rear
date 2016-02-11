# 31_network_devices.sh
#
# record network device configuration for Relax-and-Recover
#
#    Relax-and-Recover is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.

#    Relax-and-Recover is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with Relax-and-Recover; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
# Notes:
# - Thanks to Markus Brylski for fixing some bugs with bonding !
# - Thanks to Gerhard Weick for coming up with a way to disable bonding if needed

# BUG: Supports Ethernet only (so far)

# where to build networking configuration
netscript=$ROOTFS_DIR/etc/scripts/system-setup.d/60-network-devices.sh

### Skip netscript if noip is configured on the command line
cat <<EOT >> $netscript
if [[ -e /proc/cmdline ]] ; then
    if grep -q 'noip' /proc/cmdline ; then
        return
    fi
fi
EOT

# add a line at the top of netscript to skip if dhclient will be used
cat - <<EOT > $netscript
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

# collect list of all physical network interface cards
# take all interfaces in /sys/class/net and subtract /sys/devices/virtual/net, bonding_masters
physical_network_interfaces=""
# e.g. on SLES12 with KVM/QEMU 'ls /sys/devices/virtual/net' may result "br0 lo virbr1 virbr1-nic vnet0"
virtual_network_interfaces=$( ls /sys/devices/virtual/net )
# e.g. on SLES12 with KVM/QEMU 'ls /sys/class/net' may result "br0 eth0 lo virbr1 virbr1-nic vnet0"
network_interfaces=$( ls /sys/class/net )
# so that in this example using network_interfaces and subtracting virtual_network_interfaces
# results "eth0" as the only physical network interface.
# Note that when network_interfaces or virtual_network_interfaces is empty
# then no commands are executed in the for-loops and the return status is 0
# which is the right behaviour here (i.e. no additional "if empty" test needed) and
# because network interface names do not allow spaces they can be just used in for-loops:
for network_interface in $network_interfaces ; do
    # See https://github.com/rear/rear/issues/758 why regular expression
    # cannot be used here (because it does not work on all bash 3.x versions).
    # Additionally one cannot use simple substring search because assume
    # virtual_network_interfaces is "lo virt-eth0" and network_interfaces is "eth0 lo virt-eth0"
    # then simple substring search would find "etho" as substring in "lo virt-eth0"
    # so that to be on the safe side a dumb traditional for-loop approach is used
    # (unitl someone implements a better solution that works on all bash 3.x versions):
    for virtual_network_interface in $virtual_network_interfaces ; do
        test "$network_interface" = "$virtual_network_interface" && network_interface=""
    done
    # bonding_masters is also no physical network interface:
    test "$network_interface" = "bonding_masters" && network_interface=""
    # Now network_interface is non-epmtry only for physical network interfaces:
    test "$network_interface" && physical_network_interfaces+=" $network_interface"
done

# go over the physical network interfaces and record information
# and, BTW, network interface names luckily do not allow spaces :-)
for physical_network_interface in $physical_network_interfaces ; do
    sysfspath=/sys/class/net/$physical_network_interface
    # get mac address
    mac="$( cat $sysfspath/address )"
    BugIfError "Could not read a MAC address from '$sysfspath/address'!"

    # skip fake interfaces without MAC address
    test "$mac" == "00:00:00:00:00:00" && continue

    # TODO: skip bonding (and other dependent) devices from recording their MAC address in /etc/mac-addresses
    # because such devices mirror the MAC address of (usually the first) real NIC.
    # I lack experience with bonding setups to write this blindly, so please contribute better code
    #
    # keep mac address information for rescue system
    echo "$physical_network_interface $mac">>$ROOTFS_DIR/etc/mac-addresses

    # take information only from UP devices, we don't care about non-working devices.
    ip link show dev $physical_network_interface | grep -q UP || continue

    # link is up
    # determine the driver to load, relevant only for non-udev environments
    if [[ -z "$driver" && -e "$sysfspath/device/driver" ]]; then
        # this should work for virtio_net, xennet and vmxnet on recent kernels
        driver=$(basename $(readlink $sysfspath/device/driver))
    if test "$driver" -a "$driver" = vif ; then
        # xennet driver announces itself as vif :-(
        driver=xennet
    fi
    elif [[ -z "$driver" && -e "$sysfspath/driver" ]]; then
        # this should work for virtio_net, xennet and vmxnet on older kernels (2.6.18)
        driver=$(basename $(readlink $sysfspath/driver))
    elif [[ -z "$driver" ]] && has_binary ethtool; then
        driver=$(ethtool -i $physical_network_interface 2>&8 | grep driver: | cut -d: -f2)
    fi
    if [[ "$driver" ]]; then
        if ! grep -q $driver /proc/modules; then
            LogPrint "WARNING: Driver $driver currently not loaded ?"
        fi
        echo "$driver" >>$ROOTFS_DIR/etc/modules
    else
        LogPrint "WARNING:   Could not determine network driver for '$physical_network_interface'. Please make
WARNING:   sure that it loads automatically (e.g. via udev) or add
WARNING:   it to MODULES_LOAD in $CONFIG_DIR/{local,site}.conf!"
    fi
    mkdir -p $v $TMP_DIR/mappings >&2
    test -f $CONFIG_DIR/mappings/ip_addresses && read_and_strip_file $CONFIG_DIR/mappings/ip_addresses > $TMP_DIR/mappings/ip_addresses

    if test -s $TMP_DIR/mappings/ip_addresses ; then

        while read network_device ip_address junk ; do
            Log "New IP-address will be $network_device $ip_address"
            echo "ip addr add $ip_address dev $network_device" >>$netscript
            echo "ip link set dev $network_device up" >>$netscript
        done < $TMP_DIR/mappings/ip_addresses
    else

        for addr in $(ip a show dev $physical_network_interface scope global | grep "inet.*\ " | tr -s " " | cut -d " " -f 3) ; do
            echo "ip addr add $addr dev $physical_network_interface" >>$netscript
        done
        echo "ip link set dev $physical_network_interface up" >>$netscript
    fi

    # record interface MTU
    if test -e "$sysfspath/mtu" ; then
        mtu="$(cat $sysfspath/mtu)"
        PrintIfError "Could not read a MTU address from '$sysfspath/mtu'!"
        [[ "$mtu" ]] && echo "ip link set dev $physical_network_interface mtu $mtu" >>$netscript
    fi
done



# extract configuration of a given VLAN interface
vlan_setup() {
	local IFACE=$1

	# check if we already dealt with this interface as a dependency
	[[ $VLANS_SET_UP =~ (^|[[:space:]])$IFACE($|[[:space:]]) ]] && return

	local PARENT=$(grep "^${IFACE}" /proc/net/vlan/config | awk '{print $5}')
	
	# if VLNA is built on top of a bonding, set that up first
	if [[ ${BONDS[@]} =~ (^|[[:space:]])$PARENT($|[[:space:]]) ]]
	then
		bond_setup $PARENT
	fi

	local VLAN_ID=$(grep "^${IFACE}" /proc/net/vlan/config | awk '{print $3}')

	echo ip link add link $PARENT name $IFACE type vlan id $VLAN_ID >>$netscript

	for ADDR in $(ip ad show dev $IFACE scope global | grep "inet.*\ " | tr -s " " | cut -d " " -f 3) ; do
		echo "ip addr add $ADDR dev $IFACE" >>$netscript
	done
	echo "ip link set dev $IFACE up" >>$netscript
	
	VLANS_SET_UP+=" ${IFACE}"
}

# extract configuration of a given bonding interface
bond_setup() {
	local IFACE=$1

	# check if we already dealt with this interface as a dependency
	[[ $BONDS_SET_UP =~ (^|[[:space:]])$IFACE($|[[:space:]]) ]] && return
	
	# get list of members
	local MEMBERS=$(cat /sys/class/net/${IFACE}/bonding/slaves)
		
	# if a member of the bonding group is a VLAN, set that up first
	for MEMBER in $MEMBERS
	do
		if [[ ${VLANS[@]} =~ (^|[[:space:]])$MEMBER($|[[:space:]]) ]]
		then
			vlan_setup $MEMBER
		else
			echo member $MEMBER not a vlan
		fi
	done

	
	# we first need to "up" the bonding interface, then add the slaves (ifenslave complains
	# about missing IP adresses, can be ignored), and then add the IP addresses
	echo "ip link set dev $IFACE up" >>$netscript

	# enslave slave interfaces which we read from the sysfs status file
	if command -v ifenslave >/dev/null 2>&1
	then
		# we can use ifenslave(8) and do it all at once
		echo ifenslave $IFACE $MEMBERS >>$netscript
	else
		# no ifenslave(8) found, hopefully ip(8) can do it
		for MEMBER in $MEMBERS
		do
			echo ip link set $MEMBER master $IFACE >>$netscript
		done
	fi
	
	echo "sleep 5" >>$netscript
		
	for ADDR in $(ip ad show dev $IFACE scope global | grep "inet.*\ " | tr -s " " | cut -d " " -f 3) ; do
		echo "ip addr add $ADDR dev $IFACE " >>$netscript
	done
	
	BONDS_SET_UP+=" ${IFACE}"
}


# load required modules for bonding and collect list of all up bonding interfaces
BONDS=()
if test -d /proc/net/bonding ; then
	
	for BOND in `ls /proc/net/bonding`
	do
		if ip link show dev $BOND | grep -q UP
		then
			BONDS+=($BOND)
		fi
	done
	
	# default bonding mode 1 (active backup)
    BONDING_MODE=1
    grep -q "Bonding Mode: IEEE 802.3ad" /proc/net/bonding/${BONDS[0]} && BONDING_MODE=4
    # load bonding with the correct amount of bonding devices
    echo "modprobe bonding max_bonds=${#BONDS[@]} miimon=100 mode=$BONDING_MODE use_carrier=0"  >>$netscript
    MODULES=( "${MODULES[@]}" 'bonding' )
fi

# load required modules for VLAN and collect list of all up VLAN interfaces
VLANS=()
if test -d /proc/net/vlan ; then
	if [[ -f /proc/net/vlan/config ]]; then
        # config file contains a line like "vlan163        | 163  | bond1" describing the vlan
        cp /proc/net/vlan/config $VAR_DIR/recovery/vlan.config   # save a copy to our recovery area
        # we might need it if we ever want to implement VLAN Migration
	fi
	
	echo "modprobe 8021q" >>$netscript
	echo "sleep 5" >>$netscript
	
	for VLAN in `ls /proc/net/vlan | grep -v config`
	do
		if ip link show dev $VLAN | grep -q UP
		then
			VLANS+=($VLAN)
		fi
	done
fi

# set up all VLANS
for VLAN in ${VLANS[@]}
do
	vlan_setup $VLAN
done

# set up BONDS
if ! test "$SIMPLIFY_BONDING" ; then
    for BOND in ${BONDS[@]} ; do
        bond_setup $BOND
    done
else
    # The way to simplify the bonding is to copy the IP addresses from the bonding device to the
    # *first* slave device
    #
    # FIXME: Translate the following comment into globally comprehensible language (i.e. English!)
    # Anpassung HZD: Hat ein System bei einer SLES10 Installation zwei Bonding-Devices
    # gibt es Probleme beim Boot mit der Rear-Iso-Datei. Der Befehl modprobe -o name ...
    # funkioniert nicht. Dadurch wird nur das erste bonding-Device koniguriert.
    # Die Konfiguration des zweiten Devices schlaegt fehl und dieses laesst sich auch nicht manuell
    # nachinstallieren. Daher wurde diese script so angepasst, dass die Rear-Iso-Datei kein Bonding
    # konfiguriert, sondern die jeweiligen IP-Adressen einer Netzwerkkarte des Bondingdevices
    # zuordnet. Dadurch musste aber auch das script 35_routing.sh angepasst werden.
    #
    # go over bondX and record information
    c=0
    while : ; do
        bonding_device=bond$c
        if test -r /proc/net/bonding/$bonding_device ; then
            if ip link show dev $bonding_device | grep -q UP ; then
                # link is up
                ifslaves=($(cat /proc/net/bonding/$bonding_device | grep "Slave Interface:" | cut -d : -f 2))
                for addr in $(ip a show dev $bonding_device scope global | grep "inet.*\ " | tr -s " " | cut -d " " -f 3) ; do
                    # ise ifslaves[0] instead of bond$c to copy IP address from bonding device
                    # to the first enslaved device
                    echo "ip addr add $addr dev ${ifslaves[0]}" >>$netscript
                done
                echo "ip link set dev ${ifslaves[0]} up" >>$netscript
            fi
        else
            break # while loop
        fi
        let c++
    done
    # fake BONDS_SET_UP, so that no recursive call tries to bring one up the not-simplified way
    BONDS_SET_UP=${BONDS[@]}
fi

