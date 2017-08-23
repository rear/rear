# Remember the mappings if any for disk-by-id

ls /dev/disk/by-id | while read ID;
do
	# create diskbyid_mappings file:
	# we need to keep absolute PATH for device in order to be able to easily use apply_mappings() function.
	# and apply disk mapping during migration.
	#
	# example:	scsi-360060e8015268c000001268c000065c0-part4 /dev/sda4
	#			wwn-0x600507680c82004cf8000000000000d8 /dev/mapper/maptha

	# get real device name from a symlink defined by udev
	# UdevQueryName() defined in lib/layout-function.sh
	ID_NEW=$(UdevQueryName /dev/disk/by-id/$ID)
	if [[ $ID_NEW =~ ^dm- ]]; then
		# If dm- device is a multipath, get its /dev/mapper/name instead of /dev/dm-X
		# as /dev/dm-X are not persistent across reboot and not used in disk mapping file.

		# get symlinks defined by udev from a device
    	# UdevSymlinkName() defined in lib/layout-function.sh
		SYMLINKS=$(UdevSymlinkName /dev/$ID_NEW)
	    set -- $SYMLINKS
	    while [ $# -gt 0 ]; do
	     	if [[ $1 =~ /dev/mapper/ ]]; then
	        	ID_NEW=${1#/dev/}
	        	break
	      else
	        	shift
	      fi
	    done
	fi
	echo $ID /dev/$ID_NEW
done >$VAR_DIR/recovery/diskbyid_mappings

[[ -f $VAR_DIR/recovery/diskbyid_mappings ]] &&  Log "Saved diskbyid_mappings"
