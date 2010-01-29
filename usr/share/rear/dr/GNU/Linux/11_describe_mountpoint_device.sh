# create mountpoint_device table
# this table gives the disk device for each mountpoint
# This is only to normalize mount by label or uuid

# truncate output file
echo -n "" >$VAR_DIR/recovery/mountpoint_device


while read -a entry ; do
	# exclude mountpoints here
	if IsInArray "$entry" "${EXCLUDE_MOUNTPOINTS[@]}" ; then
		Log "Skipping excluded mountpoint '$entry' (${entry[@]:1})"
		continue
	fi
	# exclude MD devices here, too
	if IsInArray "${entry[1]}" "${EXCLUDE_MD[@]}" ; then
		Log "Skipping mountpoint '$entry' on excluded MD device '${entry[1]}' (${entry[@]:2})"
		continue
	fi
	# fail on all lines that have only 3 or less entries
	# NOTE: the entries are not expected to have BLANKS in them !!!
	if test "${#entry[@]}" -ne 4 ; then
	       Error "The filesystem '$entry' is not mounted. I cannot determine
the corresponding device. Please either mount or exclude it."
	fi

	# write out entry to output file
	echo "${entry[@]}" >>$VAR_DIR/recovery/mountpoint_device
done < <(
	join -a 2 -j 2 <(
				mount | \
				cut -d " " -f 1,3 | \
				sort -k 2 -t " "
			) <(
				grep -v -E '(noauto|nfs)' /etc/fstab | \
				grep -E '(reiserfs|xfs|ext|jfs|vfat)' | \
				grep -v '^#' | tr -s ' \t' ' ' | \
				cut -s -d ' ' -f 1,2,3 | \
				sort -k 2
			)
	)	

# a last check to be sure
test -s $VAR_DIR/recovery/mountpoint_device || Error "$VAR_DIR/recovery/mountpoint_device is missing"


# NOTE: this list might be faulty, e.g. if a device that is in the fstab is NOT mounted, then 
#       there are only 3 entries and not 4.
#
# a typical list might look like this:

# / /dev/sda2 /dev/sda2 reiserfs
# /media/hdd2 /dev/hdd2 LABEL=hdd2 reiserfs
# /media/md1 /dev/md1 UUID=64eeafc7-824c-4f7d-b19c-14f65c7aef98 ext3
# /media/sdb3 /dev/sdb4 LABEL=sdb3 ext3
# /media/sdc3 /dev/sdc4 LABEL=sdc3 ext3
# /media/vg1-lv1 /dev/mapper/vg1-lv1 /dev/vg1/lv1 ext3
# /media/vg2-lv1 /dev/mapper/vg2-lv1 /dev/vg2/lv1 ext3
# /media/vg3-lv1 /dev/mapper/vg3-lv1 /dev/vg3/lv1 ext3
