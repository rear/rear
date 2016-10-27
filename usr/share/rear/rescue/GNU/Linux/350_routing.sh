# 350_routing.sh
#
# record routing configuration for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

mkdir -p $v $TMP_DIR/mappings >&2
read_and_strip_file $CONFIG_DIR/mappings/routes > $TMP_DIR/mappings/routes

# where to build networking configuration
netscript=$ROOTFS_DIR/etc/scripts/system-setup.d/62-routing.sh

# add a line at the top of netscript to skip if dhclient will be used
cat - <<EOT > $netscript
# if USE_DHCLIENT=y then skip 62-routing.sh as we are using DHCP instead
[[ ! -z "\$USE_DHCLIENT" && -z "\$USE_STATIC_NETWORKING" ]] && return
# if GATEWAY is defined as boot option gw=1.2.3.4 then use that one
[[ ! -z "\$GATEWAY" ]] && return
EOT

### Skip netscript if noip is configured on the command line
cat <<EOT >> $netscript
if [[ -e /proc/cmdline ]] ; then
    if grep -q 'noip' /proc/cmdline ; then
        return
    fi
fi
EOT

# route mapping is available
if test -s $TMP_DIR/mappings/routes ; then
	while read destination gateway device junk ; do
		echo "ip route add $destination via $gateway dev $device" >>$netscript
	done < $TMP_DIR/mappings/routes
else # use original routes

	COPY_AS_IS=( "${COPY_AS_IS[@]}" /etc/iproute2 ) # for policy routing

	# find out routing rules
	RULES=()
	c=0
	while read ; do
		RULES[c]="$REPLY"
		let c++
	done < <(
		ip rule list | \
		cut -d : -f 2- | \
		grep -Ev "from all lookup (local|main|default)"
		)
	for rule in "${RULES[@]}" ; do
		echo "ip rule add $rule" >>$netscript
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
			if test "$SIMPLIFY_BONDING" -a -r /proc/net/bonding/$device ; then
				# if this is a bond we need to simplify then we substitute the route through the bond
				# by a route to the *first* bonded slave
				ifslaves=($(cat /proc/net/bonding/$device | grep "Slave Interface:" | cut -d : -f 2))
				Log "X${ifslaves[@]}X"
				echo "ip route add $destination $via $gateway $dev ${ifslaves[0]} table $table" >>$netscript
			# be sure that it is not a teaming-interface
			elif ! ethtool -i $device | grep -w "driver:" | grep -qw team ; then
				echo "ip route add $destination $via $gateway $dev $device table $table" >>$netscript
			fi
		done
		ip -6 route list table $table |\
			grep -Ev 'unreachable|::/96|fe80::' | grep via |\
			while read destination via gateway dev device junk;
		do
			if test "$SIMPLIFY_BONDING" -a -r /proc/net/bonding/$device ; then
				ifslaves=($(cat /proc/net/bonding/$device | grep "Slave Interface:" | cut -d : -f 2))
				Log "X${ifslaves[@]}X"
				echo "ip route add $destination $via $gateway $dev ${ifslaves[0]} table $table" >>$netscript
			# be sure that it is not a teaming-interface
			elif ! ethtool -i $device | grep -w "driver:" | grep -qw team ; then
				echo "ip route add $destination $via $gateway $dev $device table $table" >>$netscript
			fi
		done
	done
fi
