#
#
# migrate network device configuration found in /etc/udev/rules.d/*persistent*{net|names}*.rules to match
# different hardware from the source system. We assume that udev or static module loading was used to load the
# appropriate drivers and do not do anything about driver loading
#
# adjusts the udev rule and triggers udev
#
# NOTE: We don't do anything on systems that do not manage the persistent network names
# through udev rules

# get the rule files (though it should be only one)
RULE_FILES=( /etc/udev/rules.d/*persistent*{names,net}.rules )
ORIG_MACS_FILE=/etc/mac-addresses
MAC_MAPPING_FILE=/etc/rear/mappings/mac
MANUAL_MAC_MAPPING=

test "$RULE_FILES" || return 0 # skip this process if we don't have any udev rule files


# first check the existence of the original network devices
MIGRATE_MACS=() # this array collects the MAC addresses that we need to migrate
ORIGINAL_MACS=() # this array collects the original MAC addresses
ORIGINAL_DEVICES=() # this array collect the original device names
while read orig_dev orig_mac ; do
	ORIGINAL_MACS=( "${ORIGINAL_MACS[@]}" "$orig_mac" )
	ORIGINAL_DEVICES=( "${ORIGINAL_DEVICES[@]}" "$orig_dev")
	if ip link show | grep -q $orig_mac ; then
		: noop
	else
		MIGRATE_MACS=( ${MIGRATE_MACS[@]} $orig_mac )
		if ! grep -q $orig_mac "${RULE_FILES[@]}" ; then
			echo "
WARNING ! The original network interface $orig_dev $orig_mac is not available
and I could not find $orig_mac in the udev
rules (${RULE_FILES[@]}).

If your system uses persistent network names, it does not configure them with
udev and you will have to adjust it yourself. If your system does not use
persistent network names, then everything might or might not work, YMMV.
"
			return 0 # skip the remaining script
		fi
	fi
done < $ORIG_MACS_FILE

test ${#MIGRATE_MACS[@]} -eq 0 && return 0 # skip this process if all MACs are accounted for

# find the MAC addresses that are now available
# this is an array with values of the form "$dev $mac $driver"
# which is similar to /etc/mac-addresses but with the driver information added
NEW_DEVICES=()
for dev_dir in /sys/class/net/* ; do
	dev="${dev_dir##*/}" # basename $dev_dir
	case $dev in
		lo|pan*|sit*|tun*|tap*|vboxnet*|vmnet*) continue ;; # skip all kind of internal devices
	esac
	test -s $dev_dir/address || continue # skip unless have MAC address
	read mac junk <$dev_dir/address # read first word from address file
	test "$mac" = "00:00:00:00:00:00" && continue # skip devices without MAC address
	# get the driver(s), I care only about the first one, udev prints a list of DRIVER[S]=="module" lines
	driver=( $( my_udevinfo -a -p /sys/class/net/$dev | sed -ne '/DRIVER.*=".\+"/s/.*"\(.*\)".*/\1/p') )
	# the array contains a list of drivers, but I care only about the first one

	NEW_DEVICES=( "${NEW_DEVICES[@]}" "$dev $mac $driver" )
done

TOTAL_MACS=${#MIGRATE_MACS[@]}

# check the existence of a valid mapping file. The file is valid, if at least one "old" mac is mapped
# to an existing new one.
read_and_strip_file $MAC_MAPPING_FILE && while read orig_dev orig_mac ; do
	read_and_strip_file $MAC_MAPPING_FILE | grep -q "$orig_mac" && MANUAL_MAC_MAPPING=true
done < $ORIG_MACS_FILE

if ! test $MANUAL_MAC_MAPPING ; then
	# loop over all the original macs and ask the user to specify a new one
	# even though maybe some MACs stayed we want to offer the user the option to
	# reassign all MAC addresses. That is why we loop over all the original MACs and
	# not only over the MACs that require reassignment
	for ((c=0 ; c < ${#ORIGINAL_MACS[@]} ; c++ )) ; do
		old_dev=${ORIGINAL_DEVICES[$c]}
		old_mac=${ORIGINAL_MACS[$c]}
		PS3="
	Choose the network device to use: "
		echo -e "\nThe original network device $old_dev $old_mac is not available.\nPlease select another device:\n"
		select choice in  "${NEW_DEVICES[@]}" "Skip replacing the network device" ; do
			n=( $REPLY )
			let n-- # because bash arrays count from 0
			if test $n -eq "${#NEW_DEVICES[@]}" ; then
				choice="cancel"
				break; # from the select
			elif test $n -ge 0 -a $n -lt "${#NEW_DEVICES[@]}" ; then
				NEW_DEVICES=( "${NEW_DEVICES[@]/$choice/}" )
				break; # from the select
			else
				: invalid choice
			fi
		done
		if test "$choice" == "cancel" ; then
			echo "Skipping $old_mac, please remember to fix your network setup!"
			continue # with next line from /etc/mac-addresses
		else
			vars=( $choice ) # word splitting
			new_mac=${vars[1]} # vars = "dev mac driver ..."
			# remember the old_mac->new_mac mapping for later use
			mkdir -p /etc/rear/mappings
			echo "$old_mac $new_mac $old_dev" >>$MAC_MAPPING_FILE
			# remove the "wrong" line with the new mac address and
			# replace the old mac address with the new mac address
			sed -i -e "/$new_mac/d" -e "s#$old_mac#$new_mac#g" "${RULE_FILES[@]}"
		fi

	done
else # valid mac mapping available
	while read old_mac new_mac old_dev ; do
		sed -i -e "/$new_mac/d" -e "s#$old_mac#$new_mac#g" "${RULE_FILES[@]}"
	done < <( read_and_strip_file $MAC_MAPPING_FILE )
fi

# reload udev if we have MAC mappings
if test -s /etc/rear/mappings/mac ; then
	echo -n "Reloading udev ... "
	my_udevtrigger
	sleep 1
	my_udevsettle
	echo "done."
fi

# done. A later script in finalize/* will also go over the MAC mappings file and
# apply them to the files in the recovered system
