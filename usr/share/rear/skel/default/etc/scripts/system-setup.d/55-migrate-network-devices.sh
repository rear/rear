#
# update 60-network-devices.sh and 62-routing.sh system-setup script if needed (inet renamed, migration)
#
# migrate network device configuration found in /etc/udev/rules.d/*persistent*{net|names}*.rules to match
# different hardware from the source system. We assume that udev or static module loading was used to load the
# appropriate drivers and do not do anything about driver loading
#
# adjusts the udev rule and triggers udev
#

# get the rule files (though it should be only one)
RULE_FILES=( /etc/udev/rules.d/*persistent*{names,net}.rules )
ORIG_MACS_FILE=/etc/mac-addresses
MAC_MAPPING_FILE=/etc/rear/mappings/mac
MANUAL_MAC_MAPPING=
network_setup_scripts=( "/etc/scripts/system-setup.d/60-network-devices.sh" "/etc/scripts/system-setup.d/62-routing.sh" )

# first check the existence of the original network devices
MIGRATE_MACS=() # this array collects the MAC addresses that we need to migrate
ORIGINAL_MACS=() # this array collects the original MAC addresses
ORIGINAL_DEVICES=() # this array collect the original device names
while read orig_dev orig_mac ; do
	ORIGINAL_MACS=( "${ORIGINAL_MACS[@]}" "$orig_mac" )
	ORIGINAL_DEVICES=( "${ORIGINAL_DEVICES[@]}" "$orig_dev")
	if ip link show | grep -q "$orig_mac" ; then
		: noop
	else
		#TODO: Check if we really need to store DEVNAMES here.
		MIGRATE_MACS=( "${MIGRATE_MACS[@]}" "$orig_mac" )
		MIGRATE_DEVNAMES=( "${MIGRATE_DEVNAMES[@]}" "$orig_dev" )
	fi
done < $ORIG_MACS_FILE

test ${#MIGRATE_MACS[@]} -eq 0 && test ${#MIGRATE_DEVNAMES[@]} -eq 0 && return 0 # skip this process if all MACs and DEVs are accounted for

# find the MAC addresses that are now available
# this is an array with values of the form "$dev $mac $driver"
# which is similar to /etc/mac-addresses but with the driver information added
NEW_DEVICES=()
for dev_dir in /sys/class/net/* ; do
	dev="${dev_dir##*/}" # basename $dev_dir
	case $dev in
		(lo|pan*|sit*|tun*|tap*|vboxnet*|vmnet*) continue ;; # skip all kind of internal devices
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
			new_dev=${vars[0]}
			new_mac=${vars[1]} # vars = "dev mac driver ..."
			# remember the old_mac->new_mac mapping for later use
			mkdir -p /etc/rear/mappings
			echo "$old_mac $new_mac $old_dev" >>$MAC_MAPPING_FILE
		fi
	done
fi

# Initialize reload_udev variable to false
local reload_udev=false

if test -s $MAC_MAPPING_FILE ; then
	# valid mac mapping available
	while read old_mac new_mac old_dev; do
		# replace old mac address with new one directly in network_setup_scripts
		sed -i -e "s#$old_mac#$new_mac#gI" "${network_setup_scripts[@]}"

		# Migrate udev persistent-net rules files (if any)
		if test $RULE_FILES ; then
			if grep -q "$old_mac" "${RULE_FILES[@]}" ; then
				# remove the "wrong" line with the new mac address and
				# replace the old mac address with the new mac address
				sed -i -e "/$new_mac/d" -e "s#$old_mac#$new_mac#gI" "${RULE_FILES[@]}"
				reload_udev=true
			else
				if grep -q "$old_dev" "${RULE_FILES[@]}" ; then
					new_dev=$( get_device_by_hwaddr "$new_mac" )
					# remove the "wrong" line with the new mac address and
					# rename the new device name with the old one
					sed -i -e "/$old_dev/d" -e "s#$new_dev#$old_dev#gI" "${RULE_FILES[@]}"
					reload_udev=true
				fi
			fi
		fi
	done < <( read_and_strip_file "$MAC_MAPPING_FILE" )
fi

# reload udev if we have MAC mappings
if is_true $reload_udev ; then
	echo -n "Reloading udev ... "
	my_udevtrigger
	sleep 1
	my_udevsettle

    if [[ $(ps --no-headers -C systemd) ]]; then
        # This might be not mandatory.
        # It will release orphaned (old) device names in systemd
        # Maybe it can be done by some less invazive command, but I didn't found it yet
        systemctl daemon-reload
    fi

	echo "done."
fi

# done. A later script in finalize/* will also go over the MAC mappings file and
# apply them to the files in the recovered system
