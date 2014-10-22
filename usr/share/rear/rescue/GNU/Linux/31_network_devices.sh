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

# go over the network devices and record information
# and, BTW, interfacenames luckily do not allow spaces :-)
for sysfspath in /sys/class/net/* ; do
    dev=${sysfspath##*/}
    # skip well-known non-physical interfaces
    # FIXME: This guess is name-based and will fail horribly on renamed interfaces like I like to use them :-(
    case $dev in
        (bonding_masters|lo|pan*|sit*|tun*|tap*|vboxnet*|vmnet*) continue ;; # skip all kind of internal devices
                (vlan*) MODULES=( "${MODULES[@]}" '8021q' 'garp' )
    esac

    # get mac address
    mac="$(cat $sysfspath/address)"
    BugIfError "Could not read a MAC address from '$sysfspath/address'!"

    # skip fake interfaces without MAC address
    test "$mac" == "00:00:00:00:00:00" && continue

    # TODO: skip bonding (and other dependent) devices from recording their MAC address in /etc/mac-addresses
    # because such devices mirror the MAC address of (usually the first) real NIC.
    # I lack experience with bonding setups to write this blindly, so please contribute better code
    #
    # keep mac address information for rescue system
    echo "$dev $mac">>$ROOTFS_DIR/etc/mac-addresses

    # take information only from UP devices, we don't care about non-working devices.
    case $dev in
        (bond*|vlan*) continue  # we have a seperate section for bonding and vlan
            ;;
        (*) ip link show dev $dev | grep -q UP || continue
            ;;
    esac

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
        driver=$(ethtool -i $dev 2>&8 | grep driver: | cut -d: -f2)
    fi
    if [[ "$driver" ]]; then
        if ! grep -q $driver /proc/modules; then
            LogPrint "WARNING: Driver $driver currently not loaded ?"
        fi
        echo "$driver" >>$ROOTFS_DIR/etc/modules
    else
        LogPrint "WARNING:   Could not determine network driver for '$dev'. Please make
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

        for addr in $(ip a show dev $dev scope global | grep "inet.*\ " | tr -s " " | cut -d " " -f 3) ; do
            echo "ip addr add $addr dev $dev" >>$netscript
        done
        echo "ip link set dev $dev up" >>$netscript
    fi

    # record interface MTU
    if test -e "$sysfspath/mtu" ; then
        mtu="$(cat $sysfspath/mtu)"
        PrintIfError "Could not read a MTU address from '$sysfspath/mtu'!"
        [[ "$mtu" ]] && echo "ip link set dev $dev mtu $mtu" >>$netscript
    fi
done # for dev in /sys/class/net/*

# the following is only used for bonding setups
if test -d /proc/net/bonding ; then

    if ! test "$SIMPLIFY_BONDING" ; then
        # go over bondX and record information
        # Note: Some users reported that this works only for the first bonding device
        # in this case one should disable bonding by setting SIMPLIFY_BONDING
        #

        # get list of bonding devices
        BONDS=( $(ls /proc/net/bonding) )
        
        # default bonding mode 1 (active backup)
        BONDING_MODE=1
        grep -q "Bonding Mode: IEEE 802.3ad" /proc/net/bonding/${BONDS[0]} && BONDING_MODE=4

        # load bonding with the correct amount of bonding devices
        echo "modprobe bonding max_bonds=${#BONDS[@]} miimon=100 mode=$BONDING_MODE use_carrier=0"  >>$netscript
        MODULES=( "${MODULES[@]}" 'bonding' )

        # configure bonding devices
        for dev in "${BONDS[@]}" ; do
            if ip link show dev $dev | grep -q UP ; then
                # link is up, copy interface setup
                #
                # we first need to "up" the bonding interface, then add the slaves (ifenslave complains
                # about missing IP adresses, can be ignores), and then add the IP addresses
                echo "ip link set dev $dev up" >>$netscript
                # enslave slave interfaces which we read from the /proc status file
                ifslaves=($(cat /proc/net/bonding/$dev | grep "Slave Interface:" | cut -d : -f 2))
                #
                # NOTE: [*] is used here on purpose !
                echo "ifenslave $dev ${ifslaves[*]}" >>$netscript
                echo "sleep 5" >>$netscript
                for addr in $(ip a show dev $dev scope global | grep "inet.*\ " | tr -s " " | cut -d " " -f 3) ; do
                    echo "ip addr add $addr dev $dev" >>$netscript
                done
            fi
        done

    else
        # The way to simplify the bonding is to copy the IP addresses from the bonding device to the
        # *first* slave device

        # Anpassung HZD: Hat ein System bei einer SLES10 Installation zwei Bonding-Devices
        # gibt es Probleme beim Boot mit der Rear-Iso-Datei. Der Befehl modprobe -o name ...
        # funkioniert nicht. Dadurch wird nur das erste bonding-Device koniguriert.
        # Die Konfiguration des zweiten Devices schlägt fehl und dieses lässt sich auch nicht manuell
        # nachinstallieren. Daher wurde diese script so angepasst, dass die Rear-Iso-Datei kein Bonding
        # konfiguriert, sondern die jeweiligen IP-Adressen einer Netzwerkkarte des Bondingdevices
        # zuordnet. Dadurch musste aber auch das script 35_routing.sh angepasst werden.

        # go over bondX and record information
        c=0
        while : ; do
            dev=bond$c
            if test -r /proc/net/bonding/$dev ; then
                if ip link show dev $dev | grep -q UP ; then
                # link is up
                    ifslaves=($(cat /proc/net/bonding/$dev | grep "Slave Interface:" | cut -d : -f 2))
                    for addr in $(ip a show dev $dev scope global | grep "inet.*\ " | tr -s " " | cut -d " " -f 3) ; do
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

    fi

fi # if bonding

# VLAN section
if test -d /proc/net/vlan ; then
    # copy the vlan config file to VAR_DIR/recovery/
    if [[ -f /proc/net/vlan/config ]]; then
        # config file contains a line like "vlan163        | 163  | bond1" describing the vlan
        cp /proc/net/vlan/config $VAR_DIR/recovery/vlan.config   # save a copy to our recovery area
        # we might need it if we ever want to implement VLAN Migration
        echo "modprobe 8021q" >>$netscript
        echo "sleep 5" >>$netscript
        VLANS=( $(ls /proc/net/vlan/* | grep -v config) )
        for vlan in ${VLANS[*]##*/}
        do
            if ip link show dev $vlan | grep -q UP ; then
            # link is up; skip if the vlan is down
                VLAN_ID=$( grep "^${vlan}" /proc/net/vlan/config | awk '{print $3}' )
                dev=$( grep "^${vlan}" /proc/net/vlan/config | awk '{print $5}' )
                echo "ip link add link $dev name $vlan type vlan id $VLAN_ID" >>$netscript
                for addr in $(ip a show dev $vlan scope global | grep "inet.*\ " | tr -s " " | cut -d " " -f 3) ; do
                    echo "ip addr add $addr dev $vlan" >>$netscript
                done
                echo "ip link set dev $vlan up" >>$netscript
            fi
        done
    fi
fi # if vlan

