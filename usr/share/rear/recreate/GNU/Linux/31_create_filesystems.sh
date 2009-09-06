#
# create filesystems
#
# every vol_id file in recovery/dev represents a filesystem

ProgressStart "Creating file systems"
while read file ; do
	# file looks like dev/md/0/vol_id
	device="/${file%%/fs_vol_id}" # /dev/md/0
	
	test -s $VAR_DIR/recovery/$file
	ProgressStopIfError $? "Description file '$VAR_DIR/recovery/$file' is empty."
	ProgressStep
	
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
	case $ID_FS_TYPE in
		reiserfs)
			CMD=(mkreiserfs -f -f)
			test "$ID_FS_UUID" && CMD=( "${CMD[@]}" -u "$ID_FS_UUID" )
			test "$ID_FS_LABEL" && CMD=( "${CMD[@]}" -l "$ID_FS_LABEL" )
			CMD=( "${CMD[@]}" "$device" )
			;;
        # The following rule works for ext2, ext3, ext4 and probably also for ext4dev
        # we use mkfs.extXXX with the same extension as the filesystem had, so that
        # for ext2 we use mkfs.ext2 and for ext4dev we use mkfs.ext4dev
        # This works well since all these filesystems are created by the same mkfs binary
        # from the e2fsprogs package which looks at the mkfs. extension to determine the
        # filesystem type requested.
		ext*)
			CMD=(mkfs.ext2 -F )
			test "$ID_FS_UUID" && CMD2=( tune2fs -U "$ID_FS_UUID" "$device")
			test "$ID_FS_LABEL" && CMD=( "${CMD[@]}" -L "$ID_FS_LABEL" )
			CMD=( "${CMD[@]}" "$device" )
			;;
		xfs)
			CMD=(mkfs.xfs -f)
			test "$ID_FS_UUID" && CMD2=( xfs_admin -U "$ID_FS_UUID" "$device")
			test "$ID_FS_LABEL" && CMD=( "${CMD[@]}" -L "$ID_FS_LABEL" )
			CMD=( "${CMD[@]}" "$device" )
			;;
		jfs)
			CMD=(mkfs.jfs -q)
			test "$ID_FS_UUID" && CMD2=( jfs_tune -U "$ID_FS_UUID" "$device")
			test "$ID_FS_LABEL" && CMD=( "${CMD[@]}" -L "$ID_FS_LABEL" )
			CMD=( "${CMD[@]}" "$device" )
			;;
		vfat)
			# vfat is used for EFI file system only (IA64)
			CMD=(mkfs.vfat -F 16 )
			VOLUME_ID="`echo $ID_FS_UUID | sed -e 's/-//'`"
			test "$ID_FS_UUID" && CMD=( "${CMD[@]}" -i "$VOLUME_ID" )
			test "$ID_FS_LABEL" && CMD=( "${CMD[@]}" -n "$ID_FS_LABEL" )
			CMD=( "${CMD[@]}" "$device" )
			;;
		*)
			ProgressStopIfError 1 "File system '$ID_FS_TYPE' is not supported. You should file a bug."
			;;
	esac
	ProgressStep

	# check that command has enough words
	test "${#CMD[@]}" -ge 3
	ProgressStopIfError $? "Invalid filesystem creation command: '${CMD[@]}'"
	ProgressStep
	
	# check that command exists
	test -x "$(type -p $CMD)"
	ProgressStopIfError $? "Filesystem creation command '$CMD' not found !"
	ProgressStep

	# run command
	eval "${CMD[@]}" 1>&8
	ProgressStopIfError $? "Could not create filesystem ($ID_FS_TYPE) on '$device'"
	
	# should we run another command (CMD2) ?
	if test "${#CMD2[@]}" -ge 2 ; then

		# check that CMD2 exists
		test -x "$( type -p $CMD2)"
		ProgressStopIfError $? "Filesystem manipulation command '$CMD2' not found !"
		
		# run CMD2
		eval "${CMD2[@]}" 1>&8
		ProgressStopIfError $? "Could not '$CMD2' filesystem ($ID_FS_TYPE) on '$device'"

	fi

done < <(
	cd $VAR_DIR/recovery
	find . -name fs_vol_id -printf "%P\n" 
	)

ProgressStop
