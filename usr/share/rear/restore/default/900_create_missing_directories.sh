#
# 900_create_missing_directories.sh
#
# Create still missing directories and symbolic links
# after the backup was restored.
#

# The directories_permissions_owner_group file was created by prep/default/400_save_directories.sh
# to save permissions, owner, group or symbolic link name and target of basic directories:
local directories_permissions_owner_group_file="$VAR_DIR/recovery/directories_permissions_owner_group"

# Append other directories or symlinks in the DIRECTORY_ENTRIES_TO_RECOVER array
# to the directories_permissions_owner_group file.
# For the 'test' one must have all array members as a single word i.e. "${name[*]}"
# because it should succeed when there is any non-empty array member, not necessarily the first one:
if test "${DIRECTORY_ENTRIES_TO_RECOVER[*]}" ; then
    for directory_permissions_owner_group in "${DIRECTORY_ENTRIES_TO_RECOVER[@]}" ; do
        test "$directory_permissions_owner_group" || continue
        # Using no double quotes for the variable in the echo command
        # condenses multiple spaces into one and strips leading and trailing spaces:
        echo $directory_permissions_owner_group >>"$directories_permissions_owner_group_file"
    done
fi

pushd $TARGET_FS_ROOT 1>&2
# Recreate directories from the directories_permissions_owner_group file:
if test -f "$directories_permissions_owner_group_file" ; then
    LogPrint "Recreating directories (with permissions) from $directories_permissions_owner_group_file"
    local directory mode owner group junk
    while read directory mode owner group junk ; do
        # At least the directory name must exist:
        test $directory || continue
        # Strip leading slash from directory because we need a relative directory inside TARGET_FS_ROOT:
        directory=${directory#/}
        # Normal directories are strored in lines like (e.g. on a SLES12 system):
        # /tmp 1777 root root
        # /usr 755 root root
        # Symbolic links are strored in lines like (e.g. on a SLES12 system)
        # note the difference between absolute and relative symbolic link target:
        # /var/lock -> /run/lock
        # /var/mail -> spool/mail
        # Accordingly when mode is '->' it is a symbolic link:
        if test '->' = "$mode" ; then
            local symlink_name=$directory
            local symlink_target=$owner
            # Create only symlinks if the symbolic link name does not yet exist (regardless in what form)
            # so that things that have been already restored from the backup do not get changed here:
            test -e $symlink_name || test -L $symlink_name && continue
            # The symbolic link target may not exist so that dangling symlinks can be created
            # (it is not ReaR's job to prevent the user from creating dangling symlinks)
            # because a symbolic link target directory may be created later by this script
            # depending on the ordering in the directories_permissions_owner_group file:
            ln $v -s $symlink_target $symlink_name 1>&2 || LogPrintError "Failed to create symlink $symlink_name -> $symlink_target"
        else
            # Create only directories if nothing with that name already exists (regardless in what form)
            # so that things that have been already restored from the backup do not get changed here:
            test -e $directory || test -L $directory && continue
            mkdir $v -p $directory 1>&2 || LogPrintError "Failed to create directory $directory"
            # mode, owner, and group are optional with this syntax: [ mode [ owner [ group ] ] ]
            # (e.g. to specify owner also mode must be specified).
            # When no mode is specified the default 'rwxr-xr-x root root' gets used as fallback:
            if test $mode ; then
                chmod $v $mode $directory 1>&2 || LogPrintError "Failed to 'chmod $mode $directory'"
                # owner and group are optional with this syntax: [ owner [ group ] ]
                # When no owner is specified the default 'root root' gets used as fallback:
                if test $owner ; then
                    # When owner is specified but no group then group is set same as the owner
                    # (this way e.g. 'lp lp' can be abbreviated to only 'lp'):
                    test $group || group=$owner
                    # In the ReaR recovery system there exist only a few users
                    # ("cut -d ':' -f1 /etc/passwd" shows only root, sshd, daemon, rpc, and nobody)
                    # so that 'chroot' into the recreated system is needed to 'chown' to other users.
                    # Use a login shell in between so that one has in the chrooted environment
                    # all the advantages of a "normal working shell" which means one can write
                    # the commands inside 'chroot' as one would type them in a normal working shell.
                    # In particular one can call programs (like 'chown') by their basename without path
                    # cf. https://github.com/rear/rear/issues/862#issuecomment-274068914
                    if ! chroot $TARGET_FS_ROOT /bin/bash --login -c "chown $v $owner:$group $directory" 1>&2 ; then
                        LogPrintError "Failed to 'chown $owner:$group $directory' "
                    fi
                fi
            fi
        fi
    done < <( grep -v '^#' "$directories_permissions_owner_group_file" )
fi
popd 1>&2

