#
# Create missing directories.
# For background information and reasoning see
# https://github.com/rear/rear/issues/1455#issuecomment-324904017
# that reads:
#   Typical backup software assumes that the restore always happens
#   on top of a system that was installed the traditional way,
#   so that for the backup software it is safe to assume that
#   those directories are present. From the perspective
#   of the backup software there is therefore no need
#   to include such directories in a full backup.
#   Bottom line is, it is the duty of ReaR to make sure
#   that these special directories really do exist.
#
pushd $TARGET_FS_ROOT 1>/dev/null

local tmp_directories="tmp var/tmp"
# First of all some generic directories that are created in any case:
for directory in mnt proc run sys dev/pts dev/shm $tmp_directories ; do
    test -d "$directory" || mkdir $v -p $directory 1>&2
done
# Set permissions for 'tmp' directories (cf. issue #1455):
for tmp_dir in $tmp_directories ; do
    chmod $v 1777 $tmp_dir 1>&2
done

# Recreate mountpoints with permissions from the mountpoint_permissions file:
local mountpoint_permissions_file="$VAR_DIR/recovery/mountpoint_permissions"
if test -f "$mountpoint_permissions_file" ; then
    LogPrint "Creating mountpoints (with permissions) from $mountpoint_permissions_file"
    while read directory mode userid groupid junk ; do
        test -d "$directory" || mkdir $v -p $directory 1>&2
        chmod $v $mode $directory 1>&2
        chown $v $userid:$groupid $directory 1>&2
    done < <( grep -v '^#' "$mountpoint_permissions_file" )
fi

# Finally recreate possibly user-specified DIRECTORIES_TO_CREATE and
# also add MOUNTPOINTS_TO_RESTORE for backward compatibility (see issue #1455):
test "$MOUNTPOINTS_TO_RESTORE" && DIRECTORIES_TO_CREATE="$DIRECTORIES_TO_CREATE $MOUNTPOINTS_TO_RESTORE"
if test "$DIRECTORIES_TO_CREATE" ; then
    LogPrint "Creating directories from DIRECTORIES_TO_CREATE"
    for directory in $DIRECTORIES_TO_CREATE ; do
        test -d "$directory" || mkdir $v -p $directory 1>&2
    done
fi

popd 1>/dev/null

