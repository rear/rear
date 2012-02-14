#
# create filesystems
#
# every vol_id file in recovery/dev represents a filesystem

LogPrint "Creating file systems"
while read file ; do
	# file looks like dev/md/0/fs_vol_id
	device="/${file%%/fs_vol_id}" # /dev/md/0

	[ -s $VAR_DIR/recovery/$file ]
	StopIfError "Description file '$VAR_DIR/recovery/$file' is empty."

	# initialize variables
	ID_FS_USAGE=""
	ID_FS_TYPE=""
	ID_FS_VERSION=""
	ID_FS_UUID=""
	ID_FS_LABEL=""
	ID_FS_LABEL_SAFE=""
	# source information from vol_id file
	. $VAR_DIR/recovery/$file
	# This should set stuff like this:
	# ID_FS_USAGE=filesystem
	# ID_FS_TYPE=reiserfs
	# ID_FS_VERSION=3.6
	# ID_FS_UUID=59954040-479f-4232-8fb7-6f3e7db0f1dc
	# ID_FS_LABEL=hdd2
	# ID_FS_LABEL_SAFE=hdd2

	# build file system creation command
	# NOTE: We use an array to better preserve quotes in the arguments
	CMD=()
	CMD2=() # in case another command has to be run
	CMD3=() # in case yet another command has to be run
	case $ID_FS_TYPE in
		reiserfs)
			CMD=(mkreiserfs -f -f)
			test "$ID_FS_UUID" && CMD=( "${CMD[@]}" -u "$ID_FS_UUID" )
			test "$ID_FS_LABEL" && CMD=( "${CMD[@]}" -l "'$ID_FS_LABEL'" )
			CMD=( "${CMD[@]}" "$device" )
			;;
        # The following rule works for ext2, ext3, ext4 and probably also for ext4dev
        # we use mkfs.extXXX with the same extension as the filesystem had, so that
        # for ext2 we use mkfs.ext2 and for ext4dev we use mkfs.ext4dev
        # This works well since all these filesystems are created by the same mkfs binary
        # from the e2fsprogs package which looks at the mkfs. extension to determine the
        # filesystem type requested.
		ext*)
			CMD=(mkfs.$ID_FS_TYPE -F )
			test "$ID_FS_UUID" && CMD2=( tune2fs -U "$ID_FS_UUID" "$device")
			test "$ID_FS_LABEL" && CMD=( "${CMD[@]}" -L "$ID_FS_LABEL" )
			test -r $VAR_DIR/recovery$device/fs_parameters && . $VAR_DIR/recovery$device/fs_parameters
			test "$FS_RESERVED_BLOCKS" && test "$FS_MAX_MOUNTS" && test "$FS_CHECK_INTERVAL" && \
				CMD3=( tune2fs -r "$FS_RESERVED_BLOCKS" -c "$FS_MAX_MOUNTS" -i "$FS_CHECK_INTERVAL" "$device" )
			CMD=( "${CMD[@]}" "$device" )
			;;
		xfs)
			CMD=(mkfs.xfs -f)
			test "$ID_FS_UUID" && CMD2=( xfs_admin -U "$ID_FS_UUID" "$device")
			test "$ID_FS_LABEL" && CMD=( "${CMD[@]}" -L "'$ID_FS_LABEL'" )
			CMD=( "${CMD[@]}" "$device" )
			;;
		jfs)
			CMD=(mkfs.jfs -q)
			test "$ID_FS_UUID" && CMD2=( jfs_tune -U "$ID_FS_UUID" "$device")
			test "$ID_FS_LABEL" && CMD=( "${CMD[@]}" -L "'$ID_FS_LABEL'" )
			CMD=( "${CMD[@]}" "$device" )
			;;
		vfat)
			# vfat is used for EFI file system only (IA64)
			# changed mkfs.vfat cmd -- according to the man-page mkfs.vfat should autodetect the needed size
			CMD=(mkfs.vfat)
			VOLUME_ID="`echo $ID_FS_UUID | sed -e 's/-//'`"
			test "$ID_FS_UUID" && CMD=( "${CMD[@]}" -i "$VOLUME_ID" )
			test "$ID_FS_LABEL" && CMD=( "${CMD[@]}" -n "'$ID_FS_LABEL'" )
			CMD=( "${CMD[@]}" "$device" )
			;;
		*)
			Error "File system '$ID_FS_TYPE' is not supported. You should file a bug."
			;;
	esac

	# check that command has enough words
	[ "${#CMD[@]}" -ge 3 ]
	StopIfError "Invalid filesystem creation command: '${CMD[@]}'"

	# check that command exists
	[ -x "$(get_path $CMD)" ]
	StopIfError "Filesystem creation command '$CMD' not found !"

        # check if device is already there (some devices need time after partitioning)
        if ! test -b "$device"
        then echo "'$device' not ready, waiting up to 30 seconds for it to appear"
             for i in 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9
             do ProgressStep
                sleep 1
                if test -b "$device"
                then break
                fi
             done
        fi

	# run command
	eval "${CMD[@]}" >&8
	StopIfError "Could not create filesystem ($ID_FS_TYPE) on '$device'"

	# should we run another command (CMD2) ?
	if test "${#CMD2[@]}" -ge 2 ; then

		# check that CMD2 exists
		[ -x "$( get_path $CMD2)" ]
		StopIfError "Filesystem manipulation command '$CMD2' not found !"

		# run CMD2
		eval "${CMD2[@]}" >&8
		StopIfError "Could not '$CMD2' filesystem ($ID_FS_TYPE) on '$device'"

	fi

	# should we run another command (CMD3) ?
	if test "${#CMD3[@]}" -ge 2 ; then

		# check that CMD3 exists
		[ test -x "$( get_path $CMD3)" ]
		StopIfError "Filesystem manipulation command '$CMD3' not found !"

		# run CMD3
		eval "${CMD3[@]}" >&8
		StopIfError "Could not '$CMD3' filesystem ($ID_FS_TYPE) on '$device'"

	fi
done < <(
	cd $VAR_DIR/recovery
	find . -name fs_vol_id -printf "%P\n"
	)
