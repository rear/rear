# remove existing disk-by-id mappings 
#
# We call sed once for each substituation
# it would be better to build one sed script and use this later 
# (like verify/GNU/Linux/21_migrate_recovery_configuration.sh 
#   and finalize/GNU/Linux/15_migrate_disk_devices.sh)
#
# OLD_ID_FILE contains entries like these (last 2 lines are multipath targets)
# cciss-3600508b100104c3953573830524b0004 /dev/cciss/c0d0
# cciss-3600508b100104c3953573830524b0004-part1 /dev/cciss/c0d0p1
# cciss-3600508b100104c3953573830524b0004-part2 /dev/cciss/c0d0p2
# cciss-3600508b100104c3953573830524b0004-part3 /dev/cciss/c0d0p3
# cciss-3600508b100104c3953573830524b0004-part5 /dev/cciss/c0d0p5
# scsi-1HITACHI_770122800061 /dev/dm-1
# scsi-1HITACHI_770122800062 /dev/dm-0
#
# Those devices have already been adjusted in 
# verify/GNU/Linux/21_migrate_recovery_configuration.sh

FILES="/etc/fstab /boot/grub/menu.lst /boot/grub2/grub.cfg /boot/grub/device.map /boot/efi/*/*/grub.cfg /etc/lvm/lvm.conf"

OLD_ID_FILE=${VAR_DIR}/recovery/diskbyid_mappings
NEW_ID_FILE=$TMP_DIR/diskbyid_mappings

[ ! -s "$OLD_ID_FILE" ] && return 0
[ -z "$FILES" ] && return 0

# udevinfo is deprecated by udevadm (SLES 10 still uses udevinfo)
UdevSymlinkName=""
type -p udevinfo >/dev/null && UdevSymlinkName="udevinfo -r / -q symlink -n"
type -p udevadm >/dev/null &&  UdevSymlinkName="udevadm info --root --query=symlink --name"
[[ -z "$UdevSymlinkName" ]] && {
	LogPrint "Could not find udevinfo nor udevadm (skip 16_remove_diskbyid.sh)"
	return
	}

# replace the device names with the real devices

while read ID DEV_NAME; do
  ID_NEW=""
  if [[ $DEV_NAME =~ /dev/dm ]]; then
    # probably a multipath device
    # we cannot migrate device mapper targets
    # we delete DEV_NAME to make sure it won't get used
    DEV_NAME=""
  else
    SYMLINKS=$($UdevSymlinkName $DEV_NAME)
    set -- $SYMLINKS
    while [ $# -gt 0 ]; do
      if [[ $1 =~ /dev/disk/by-id ]]; then
        # bingo, we found what we are looking for
        ID_NEW=${1#/dev/disk/by-id/}
        break
      else
        shift
      fi
    done
  fi
  echo $ID $DEV_NAME $ID_NEW
done < $OLD_ID_FILE > $NEW_ID_FILE

for file in $FILES; do
	realfile=/mnt/local/$file
	[ ! -f $realfile ] && continue	# if file is not there continue with next one
	# keep backup
	cp $realfile ${realfile}.rearbak
        sed -i -e 's/$/ /g' $realfile
	# we should consider creating a sed script within a string
	# and then call sed once (as done other times)
	while read ID DEV_NAME ID_NEW; do
		if [ -n "$ID_NEW" ]; then 
			# great, we found a new device
			ID_FULL=/dev/disk/by-id/$ID
			ID_NEW_FULL=/dev/disk/by-id/$ID_NEW
			sed -i "s#$ID_FULL\([^-a-zA-Z0-9]\)#$ID_NEW_FULL\1#g" \
				$realfile
			#                 ^^^^^^^^^^^^^^^ 
			# This is to make sure we get the full ID (and not
			# a substring) because we ask sed for a char other then
			# those contained in IDs. Unfortunately this won't work
			# with IDs at line end (luckily we don't have then 
			# right now
		else
			# lets try with the DEV_NAME as fallback
			[ -z "$DEV_NAME" ] && continue 
			# not even DEV_NAME exists, we can't do anything
			ID_FULL=/dev/disk/by-id/$ID
			sed -i "s#$ID_FULL\([^-a-zA-Z0-9]\)#$DEV_NAME\1#g" \
				$realfile
		fi
	done < $NEW_ID_FILE
done

unset ID DEV_NAME ID_NEW SYMLINKS ID_FULL ID_NEW_FULL
