# Remember the mappings if any for disk-by-id

# be careful udevinfo is old, now we have udevadm
# udevinfo -r -q name -n /dev/disk/by-id/scsi-360060e8015268c000001268c000065c0-part4
# udevadm info --query=name --name /dev/disk/by-id/dm-name-vg_fedora-lv_root
UdevQueryName=""
type -p udevinfo >/dev/null && UdevQueryName="udevinfo -r -q name -n"
type -p udevadm >/dev/null && UdevQueryName="udevadm info --query=name --name"

# udevinfo is deprecated by udevadm (SLES 10 still uses udevinfo)
UdevSymlinkName=""
type -p udevinfo >/dev/null && UdevSymlinkName="udevinfo -r / -q symlink -n"
type -p udevadm >/dev/null &&  UdevSymlinkName="udevadm info --root --query=symlink --name"

( test -z "$UdevQueryName" || test -z "$UdevSymlinkName" ) && {
	LogPrint "Could not find udevinfo nor udevadm (skip 260_rename_diskbyid.sh)"
	return
	}

ls /dev/disk/by-id | while read ID;
do
	# create diskbyid_mappings file:
	# we need to keep absolute PATH for device in order to be able to easily use 320_apply_mappings.sh
	# and apply disk mapping during migration.
	#
	# example:	scsi-360060e8015268c000001268c000065c0-part4 /dev/sda4
	#			wwn-0x600507680c82004cf8000000000000d8 /dev/mapper/maptha
	ID_NEW=$($UdevQueryName /dev/disk/by-id/$ID)
	if [[ $ID_NEW =~ ^dm- ]]; then
		# If dm- device is a multipath, get its /dev/mapper/name instead of /dev/dm-X
		# as /dev/dm-X are not persistent across reboot and not used in disk mapping file.
		SYMLINKS=$($UdevSymlinkName /dev/$ID_NEW)
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
