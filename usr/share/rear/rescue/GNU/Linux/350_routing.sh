# 350_routing.sh
#
# record routing configuration for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# Where to build network routing configuration.
# When booting the rescue/recovery system
# /etc/scripts/system-setup.d/62-routing.sh
# is run to setup the network routing:
network_routing_setup_script=$ROOTFS_DIR/etc/scripts/system-setup.d/62-routing.sh

# Initialize network_routing_setup_script:
echo "# Network routing setup:" >$network_routing_setup_script

# Skip network_routing_setup_script if the kernel command line contains the 'noip' parameter
# (a kernel command line parameter has precedence over other things):
cat - <<EOT >>$network_routing_setup_script
# Skip network routing setup if the kernel command line parameter 'noip' is specified:
grep -q '\<noip\>' /proc/cmdline && return
EOT

# If IP address plus a default gateway were specified at recovery system boot time
# via kernel command line parameters like ip=192.168.100.2 gw=192.168.100.1
# skip network_routing_setup_script because then a default gateway was already set up
# in the before running /etc/scripts/system-setup.d/60-network-devices.sh script:
cat - <<EOT >>$network_routing_setup_script
# If kernel command line parameters like ip=192.168.100.2 plus gw=192.168.100.1
# were specified skip the rest because a default gateway is already set up:
[[ "\$IPADDR" ]] && [[ "\$GATEWAY" ]] && return
EOT

# Skip network_routing_setup_script if dhclient will be used
cat - <<EOT >>$network_routing_setup_script
# If USE_DHCLIENT=y then skip the rest as DHCP also does the routing setup as needed:
[[ ! -z "\$USE_DHCLIENT" && -z "\$USE_STATIC_NETWORKING" ]] && return
EOT

# make route mapping available
mkdir -p $v $TMP_DIR/mappings >&2
read_and_strip_file $CONFIG_DIR/mappings/routes > $TMP_DIR/mappings/routes

# route mapping is available
if test -s $TMP_DIR/mappings/routes ; then
    while read destination gateway device junk ; do
        echo "ip route add $destination via $gateway dev $device" >>$network_routing_setup_script
    done < $TMP_DIR/mappings/routes
else # use original routes

    COPY_AS_IS=( "${COPY_AS_IS[@]}" /etc/iproute2 ) # for policy routing

    # find out routing rules
    rules=()
    c=0
    while read ; do
        rules[c]="$REPLY"
        let c++
    done < <(
        ip rule list | \
        cut -d : -f 2- | \
        grep -Ev "from all lookup (local|main|default)"
        )
    for rule in "${rules[@]}" ; do
        echo "ip rule add $rule" >>$network_routing_setup_script
    done

    # for each table, list routes
    # main is the default table, some distros don't mention it in rt_tables,
    # so I add it for them and strip doubles with uniq
    for table in $( { echo "254     main" ; cat /etc/iproute2/rt_tables ; } |\
            grep -E '^[0-9]+' |\
            tr -s " \t" " " |\
            cut -d " " -f 2 | sort -u | grep -Ev '(local|default|unspec)' ) ;
    do
        ip route list table $table |\
            grep -Ev 'scope (link|host)' |\
            while read destination via gateway dev device junk;
        do
            device=$( get_mapped_network_interface $device )
            echo "ip route add $destination $via $gateway $dev $device table $table" >>$network_routing_setup_script
        done
        ip -6 route list table $table |\
            grep -Ev 'unreachable|::/96|fe80::' | grep via |\
            while read destination via gateway dev device junk;
        do
            device=$( get_mapped_network_interface $device )
            echo "ip route add $destination $via $gateway $dev $device table $table" >>$network_routing_setup_script
        done
    done
fi

