#
# 900_create_missing_directories.sh
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

# The directories_permissions_owner_group file was created by 400_save_mountpoint_details.sh
# to save permissions, owner, and group of mountpoint directories:
local directories_permissions_owner_group_file="$VAR_DIR/recovery/directories_permissions_owner_group"

# Append other directories to the directories_permissions_owner_group file
# as defined in the DIRECTORIES_TO_CREATE array.
# This way settings from the DIRECTORIES_TO_CREATE array overwrite already existing ones
# because the last entry in the directories_permissions_owner_group file is the one
# that makes the final permissions, owner, and group settings.
# For the 'test' one must have all array members as a single word i.e. "${name[*]}"
# because it should succeed when there is any non-empty array member, not necessarily the first one:
if test "${DIRECTORIES_TO_CREATE[*]}" ; then
    for directory_permissions_owner_group in "${DIRECTORIES_TO_CREATE[@]}" ; do
        echo "$directory_permissions_owner_group" >>"$directories_permissions_owner_group_file"
    done
fi

pushd $TARGET_FS_ROOT 1>&2
# Recreate directories from the directories_permissions_owner_group file:
if test -f "$directories_permissions_owner_group_file" ; then
    LogPrint "Recreating directories (with permissions) from $directories_permissions_owner_group_file"
    local directory mode owner group junk
    while read directory mode owner group junk ; do
        # Normal directories are strored in lines like (e.g. on a SLES12 system):
        # /tmp 1777 root root
        # /usr 755 root root
        # Symbolic links are strored in lines like (e.g. on a SLES12 system)
        # note the difference between absolute and relative symbolic link target:
        # /var/lock -> /run/lock
        # /var/mail -> spool/mail
        # Accordingly when mode is '->' it is a symbolic link:
        if test '->' = "$mode" ; then
            local symlink_name="$directory"
            local symlink_target="$owner"
            LogPrint "Recreating symbolic link '$symlink_name -> $symlink_target' is not yet supported"
        else
            # Strip leading slash from directory because we need a relative directory inside TARGET_FS_ROOT:
            directory="${directory#/}"
            test -d "$directory" || mkdir $v -p $directory 1>&2
            chmod $v $mode $directory 1>&2
            chown $v $owner:$group $directory 1>&2
        fi
    done < <( grep -v '^#' "$directories_permissions_owner_group_file" )
fi
popd 1>&2

