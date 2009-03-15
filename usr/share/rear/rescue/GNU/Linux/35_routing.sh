# #35_routing.sh
#
# record routing configuration for Relax & Recover
#
#    Relax & Recover is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.

#    Relax & Recover is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with Relax & Recover; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
#


# where to build networking configuration
netscript=$ROOTFS_DIR/etc/network.sh

COPY_AS_IS=( "${COPY_AS_IS[@]}" /etc/iproute2 ) # for policy routing

# find out routing rules
RULES=() 
c=0
while read ; do 
	RULES[c]="$REPLY" 
	let c++
done < <( 
	ip rule list |\
	cut -d : -f 2- |\
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
		while read destination via gateway dev device ;
	do
		if test "$SIMPLIFY_BONDING" -a -r /proc/net/bonding/$device ; then
			# if this is a bond we need to simplify then we substitute the route through the bond
			# by a route to the *first* bonded slave
			ifslaves=($(cat /proc/net/bonding/$device | grep "Slave Interface:" | cut -d : -f 2))
			Log "X${ifslaves[@]}X"
			echo "ip route add $destination $via $gateway $dev ${ifslaves[0]} table $table" >>$netscript
		else
			echo "ip route add $destination $via $gateway $dev $device table $table" >>$netscript
		fi
	done
done

