
# Code for btrfs subvolume handling.
# 13_include_mount_subvolumes_code.sh contains the function btrfs_subvolumes_setup for all btrfs subvolume handling.
# Btrfs filesystems with subvolumes need a special handling.
# All btrfs subvolume handling happens in the btrfs_subvolumes_setup function in 13_include_mount_subvolumes_code.sh
# For a plain btrfs filesystem without subvolumes the btrfs_subvolumes_setup function does nothing.

btrfs_subvolumes_setup() {
    Log "Begin btrfs_subvolumes_setup( $@ )"
    # Local variables are visible only in this btrfs_subvolumes_setup function and its children:
    local dummy junk keyword info_message
    local device mountpoint mountopts recovery_system_root recovery_system_mountpoint
    local subvolume_path subvolume_directory_path subvolume_mountpoint subvolume_mount_options
    local snapshot_subvolumes_devices_and_paths snapshot_subvolume_device_and_path snapshot_subvolume_device snapshot_subvolume_path
    local default_subvolume_path
    # Assign function arguments to meaningful variable names:
    # This function is called in 13_include_mount_filesystem_code.sh as follows:
    #   btrfs_subvolumes_setup $device $mp $mountopts
    # where $device is the device node where the filesystem was already created by 13_include_filesystem_code.sh
    # (usually a harddisk partition like e.g. /dev/sda1):
    device=$1
    mountpoint=$2
    # mountopts are of the form "-o foo,bar,baz" (see 13_include_mount_filesystem_code.sh)
    # which means $3 is '-o' and 'foo,bar,baz' is $4:
    mountopts="$3 $4"
    # Empty device or mountpoint may indicate an error. In this case be verbose and inform the user:
    if test -z "$device" -o -z "$mountpoint" ; then
        LogPrint "Empty device='$device' or mountpoint='$mountpoint' may indicate an error, skipping btrfs_subvolumes_setup( $@ )."
        Log "Return 0 from btrfs_subvolumes_setup( $@ )"
        return 0
    fi
    # FIXME: The following avoids to have '/mnt/local' hardcoded at many places in the code only here.
    # The root of the filesysten tree of the to-be-recovered-system in the recovery system should be in a global variable:
    recovery_system_root=/mnt/local
    ###########################################
    # Btrfs snapshot subvolumes handling:
    # Remember all btrfs snapshot subvolumes to exclude them when mounting all btrfs normal subvolumes below.
    # The btrfs snapshot subvolumes entries that are created by 23_filesystem_layout.sh
    # are deactivated (as '#btrfssnapshotsubvol ...') in the LAYOUT_FILE (disklayout.conf).
    # When there are active btrfs snapshot subvolumes entries, the user has manually
    # activated them (as 'btrfssnapshotsubvol ...') in the LAYOUT_FILE (disklayout.conf).
    # Because any btrfssnapshotsubvol entries are needed to exclude all btrfs snapshot subvolumes
    # 'grep "btrfssnapshotsubvol ..." ... | sed ...' is used.
    while read keyword dummy dummy dummy subvolume_path junk ; do
        if test -z "$subvolume_path" ; then
           continue
        fi
        # When there is a non-empty subvolume_path, btrfs snapshot subvolume handling is needed:
        Log "Handling snapshot subvolume $subvolume_path for $device at $mountpoint"
        # Remember btrfs snapshot subvolumes to exclude them when mounting all btrfs normal subvolumes below:
        snapshot_subvolumes_devices_and_paths="$snapshot_subvolumes_devices_and_paths $device,$subvolume_path"
        # Be verbose if there are active btrfs snapshot subvolumes entries (snapshot subvolumes cannot be recreated).
        # In this case inform the user that nothing can be done for activated snapshot subvolumes entries:
        if test "btrfssnapshotsubvol" = "$keyword" ; then
            info_message="It is not possible to recreate btrfs snapshot subvolumes, skipping $subvolume_path on $device at $mountpoint"
            LogPrint $info_message
            echo "# $info_message" >> "$LAYOUT_CODE"
         fi
    done < <( grep "btrfssnapshotsubvol $device $mountpoint " "$LAYOUT_FILE" | sed -e 's/.*#.*btrfssnapshotsubvol/#btrfssnapshotsubvol/' )
    ###########################################
    # Btrfs normal subvolumes setup:
    # Create the normal btrfs subvolumes before the btrfs default subvolume setup
    # because currently the whole btrfs filesystem (i.e. its top-level/root subvolume) is mounted at the mountpoint
    # so that currently normal btrfs subvolumes can be created using the subvolume path relative to the btrfs toplevel/root subvolume
    # and that subvolume path relative to the btrfs toplevel/root subvolume is stored in the LAYOUT_FILE.
    # In contrast after the btrfs default subvolume setup only the btrfs filesystem default subvolume is mounted at the mountpoint and
    # then it would be no longer possible to create btrfs subvolumes with the subvolume path that is stored in the LAYOUT_FILE.
    # In particular a special btrfs default subvolume (i.e. when the btrfs default subvolume is not the toplevel/root subvolume)
    # is also listed as a normal subvolume so that also the subvolume that is later used as default subvolume is hereby created.
    while read dummy dummy dummy dummy subvolume_path junk ; do
        # Empty subvolume_path may indicate an error. In this case be verbose and inform the user:
        if test -z "$subvolume_path" ; then
            LogPrint "btrfsnormalsubvol entry with empty subvolume_path for $device at $mountpoint may indicate an error, skipping subvolume setup for it."
            continue
        fi
        # When there is a non-empty subvolume_path, btrfs normal subvolume setup is needed:
        Log "Setup normal subvolume $subvolume_path for $device at $mountpoint"
        # E.g. for 'btrfs subvolume create /foo/bar/subvol' the directory path /foo/bar/ must already exist
        # but 'subvol' must not exist because 'btrfs subvolume create' creates the subvolume 'subvol' itself.
        # When 'subvol' already exists (e.g. as normal directory), it fails with ERROR: '/foo/bar/subvol' exists.
        subvolume_directory_path=${subvolume_path%/*}
        if test "$subvolume_directory_path" = "$subvolume_path" ; then
            # When subvolume_path is only plain 'mysubvol' then also subvolume_directory_path becomes 'mysubvol'
            # but 'mysubvol' must not be made as a normal directory by 'mkdir' below:
            subvolume_directory_path=""
        fi
        recovery_system_mountpoint=$recovery_system_root$mountpoint
        info_message="Creating normal btrfs subvolume $subvolume_path on $device at $mountpoint"
        Log $info_message
        (
        echo "# $info_message"
        if test -n "$subvolume_directory_path" ; then
            # Test in the recovery system if the directory path already exists to avoid that
            # useless 'mkdir -p' commands are run which look confusing in the "rear recover" log
            # regardless that 'mkdir -p' does nothing when its argument already exists:
            echo "if ! test -d $recovery_system_mountpoint/$subvolume_directory_path ; then"
            echo "    mkdir -p $recovery_system_mountpoint/$subvolume_directory_path"
            echo "fi"
        fi
        echo "btrfs subvolume create $recovery_system_mountpoint/$subvolume_path"
        ) >> "$LAYOUT_CODE"
    done < <( grep "^btrfsnormalsubvol $device $mountpoint " "$LAYOUT_FILE" )
    ###########################################
    # Btrfs default subvolume setup:
    # There is exactly one default subvolume for one btrfs filesystem on one specific device (usually a harddisk partition like e.g. /dev/sda1):
    read dummy dummy dummy dummy subvolume_path junk < <( grep "^btrfsdefaultsubvol $device $mountpoint " "$LAYOUT_FILE" )
    # Artificial 'for' clause that is run only once to be able to 'continue' in the same syntactical way as in the 'while' loops
    # (because the 'for' loop is run only once 'continue' is the same as 'break'):
    for dummy in "once" ; do
        # Empty subvolume_path may indicate an error. In this case be verbose and inform the user:
        if test -z "$subvolume_path" ; then
            LogPrint "btrfsdefaultsubvol entry with empty subvolume_path for $device at $mountpoint may indicate an error, skipping default subvolume setup for it."
            continue
        fi
        # When there is a non-empty subvolume_path, btrfs default subvolume setup is needed:
        Log "Setup default subvolume $subvolume_path for $device at $mountpoint"
        # Remember the btrfs default subvolume on that specific device which is needed when mounting all btrfs normal subvolumes below
        # (also needed when the default subvolume path is "/" to avoid that it gets remounted when mounting normal subvolumes below):
        default_subvolume_path="$subvolume_path"
        # When subvolume_path is "/", the default for the btrfs default subvolume is used
        # (i.e. the btrfs default subvolume is the toplevel/root subvolume):
        if test "/" = "$subvolume_path" ; then
            info_message="No special btrfs default subvolume is used on $device at $mountpoint, no default subvolume setup needed"
            Log $info_message
            echo "# $info_message" >> "$LAYOUT_CODE"
            continue
        fi
        # When in the original system the btrfs filesystem had a special different default subvolume,
        # that different subvolume needs to be set to be the default subvolume:
        recovery_system_mountpoint=$recovery_system_root$mountpoint
        Log "Setting $subvolume_path as btrfs default subvolume for $device at $mountpoint"
        (
        echo "# Begin btrfs default subvolume setup on $device at $mountpoint"
        echo "# Making the $subvolume_path subvolume the default subvolume"
        echo "# Get the ID of the $subvolume_path subvolume"
        echo "subvolumeID=\$( btrfs subvolume list -a $recovery_system_mountpoint | sed -e 's/<FS_TREE>\///' | grep ' $subvolume_path\$' | tr -s '[:blank:]' ' ' | cut -d ' ' -f 2 )"
        echo "# Set the $subvolume_path subvolume as default subvolume using its subvolume ID"
        echo "btrfs subvolume set-default \$subvolumeID $recovery_system_mountpoint"
        ) >> "$LAYOUT_CODE"
        # When the btrfs filesystem has a special default subvolume (one that is not the toplevel/root subvolume)
        # then a reasonable assumption is that this one was mounted in the original system and not something else.
        # FIXME: It is possible that the admin has actually mounted something else in his original system
        # which would result a wrong recovery because currently such an awkward setup is not supported.
        # Under the above assumption the btrfs filesystem needs to be umonted and mounted again so that
        # the special default subvolume gets mounted in the recovery system at /mnt/local$mountpoint.
        Log "Remounting the btrfs default subvolume $subvolume_path for $device at $mountpoint"
        (
        echo "# Remounting the $subvolume_path default subvolume at $recovery_system_mountpoint"
        echo "umount $recovery_system_mountpoint"
        echo "mount -t btrfs $mountopts $device $recovery_system_mountpoint"
        echo "# End btrfs default subvolume setup on $device at $mountpoint"
        ) >> "$LAYOUT_CODE"
    done
    ###########################################
    # Mounting all btrfs normal subvolumes:
    # After the btrfs default subvolume setup now the btrfs default subvolume is mounted and then it is possible
    # to mount the other btrfs normal subvolumes at their mountpoints in the tree of the mounted filesystems:
    while read dummy dummy subvolume_mountpoint subvolume_mount_options subvolume_path junk ; do
        # Empty subvolume_mountpoint or subvolume_mount_options or subvolume_path may indicate an error.
        # E.g. missing subvolume mount options result that the subvolume path is read into subvolume_mount_options and subvolume_path becomes empty.
        # Therefore be verbose and inform the user:
        if test -z "$subvolume_mountpoint" -o -z "$subvolume_mount_options" -o -z "$subvolume_path" ; then
            LogPrint "btrfsmountedsubvol entry for $device where subvolume_mountpoint='$subvolume_mountpoint' or subvolume_mount_options='$subvolume_mount_options' or subvolume_path='$subvolume_path' is empty may indicate an error, skipping mounting it."
            continue
        fi
        # When there are non-empty values, mounting normal subvolume is needed:
        Log "Mounting normal subvolume $subvolume_path at $subvolume_mountpoint for $device"
        # Do not mount btrfs snapshot subvolumes:
        for snapshot_subvolume_device_and_path in $snapshot_subvolumes_devices_and_paths ; do
            # Assume $snapshot_subvolume_device_and_path is "/dev/sdX99,my/subvolume,path" then split
            # at the first comma because device nodes (e.g. /dev/sdX99) do not contain a comma
            # but a subvolume path may contain a comma (e.g. my/subvolume,path).
            # If a subvolume path contains space or tab characters it will break here
            # because space tab and newline are standard bash internal field separators ($IFS)
            # so that admins who use such characters for their subvolume paths get hereby
            # an exercise in using fail-safe names and/or how to enhance standard bash scripts:
            snapshot_subvolume_device=${snapshot_subvolume_device_and_path%%,*}
            snapshot_subvolume_path=${snapshot_subvolume_device_and_path#*,}
            if test "$device" = "$snapshot_subvolume_device" -a "$subvolume_path" = "$snapshot_subvolume_path" ; then
                info_message="It is not possible to recreate btrfs snapshot subvolumes, skipping mounting $subvolume_path on $device at $subvolume_mountpoint"
                Log $info_message
                echo "# $info_message" >> "$LAYOUT_CODE"
                # If one snapshot_subvolume_device_and_path matches,
                # continue with the next btrfsmountedsubvol line from the LAYOUT_FILE
                # (i.e. continue with the while loop which is the 2th enclosing loop):
                continue 2
            fi
        done
        recovery_system_mountpoint=$recovery_system_root$subvolume_mountpoint
        # Remounting is needed when at the '/' mountpoint not the btrfs default subvolume is mounted:
        # On Fedora 21 what is mounted at the root of the filesystem tree (i.e. at the '/' mountpoint)
        # is not the btrfs default subvolume (the default subvolume is the toplevel/root subvolume).
        # On Fedora 21 there is a btrfs subvolume "root" which is mounted at the '/' mountpoint.
        # I (jsmeix@suse.de) am not a btrfs expert but from my point of view it looks like
        # a misconfiguration (a.k.a. bug) in Fedora 21 how they set up btrfs. I think Fedora
        # should specify as btrfs default subvolume what is mounted at the '/' mountpoint.
        # Regardless if it is really a misconfiguration or not I like to have rear working fail-safe
        # because an admin could manually create such an awkward btrfs setup.
        # Therefore remounting is needed when the subvolume_mountpoint is '/'
        # but the subvolume_path is neither '/' nor the default subvolume.
        # Examples: disklayout.conf contains
        # on openSUSE 13.2 at '/' the default subvolume which is the root subvolume (ID 5 '/') is mounted:
        #   btrfsdefaultsubvol /dev/sda2 / 5 /
        #   btrfsmountedsubvol /dev/sda2 / rw,relatime,space_cache /
        # on SLES 12 at '/' the default subvolume '@' is mounted:
        #   btrfsdefaultsubvol /dev/sda2 / 257 @
        #   btrfsmountedsubvol /dev/sda2 / rw,relatime,space_cache @
        # on Fedora 21 at '/' not the default subvolume which is the root subvolume (ID 5 '/') but the subvolume 'root' is mounted:
        #   btrfsdefaultsubvol /dev/sda3 / 5 /
        #   btrfsmountedsubvol /dev/sda3 / rw,relatime,seclabel,space_cache root
        # FIXME: Currently only for the mountpoint '/' there is this special handling.
        # In general the subvolume_mountpoint could be anything.
        # For example for a second disk /dev/sdb1 the disklayout.conf file could contain those entries:
        #   btrfsdefaultsubvol /dev/sdb1 /data 5 /
        #   btrfsmountedsubvol /dev/sdb1 /data rw,relatime,seclabel,space_cache datasubvol
        # This would mean for /dev/sdb1 what is mounted at its mountpoint /data
        # is not its btrfs default subvolume but the btrfs subvolume "datasubvol".
        # Currently such a setup is not supported for mountpoints other than '/'.
        if test '/' = "$subvolume_mountpoint" ; then
            # No remounting needed when the subvolume_path is the default_subvolume_path for this device
            # because then the default subvolume is already mounted by the "Btrfs default subvolume setup" above:
            if test "$subvolume_path" = "$default_subvolume_path" ; then
               Log "On $device btrfs default subvolume $default_subvolume_path already mounted at $subvolume_mountpoint, no remounting needed"
               continue
            fi
            # Remounting is needed when the subvolume_path is not the default_subvolume_path for this device:
            Log "On $device btrfs subvolume $subvolume_path currently not mounted at $subvolume_mountpoint, needs remounting"
            (
            echo "# Begin remounting btrfs subvolume $subvolume_path at $recovery_system_mountpoint"
            echo "# On $device btrfs subvolume $subvolume_path is currently not mounted at $recovery_system_mountpoint, needs remounting:"
            echo "# Get the ID of the $subvolume_path subvolume because it must be mounted with subvolid=ID"
            echo "# (using subvol=NAME may not work as long as it is falsely mounted so that subvolume names may not match)"
            echo "subvolumeID=\$( btrfs subvolume list -a $recovery_system_mountpoint | sed -e 's/<FS_TREE>\///' | grep ' $subvolume_path\$' | tr -s '[:blank:]' ' ' | cut -d ' ' -f 2 )"
            echo "if test -n \"\$subvolumeID\" ; then"
            echo "    # No remounting when subvolumeID is empty because then umount would work but mount would fail"
            echo "    # Remounting the $subvolume_path subvolume at $recovery_system_mountpoint"
            echo "    umount $recovery_system_mountpoint"
            echo "    mount -t btrfs -o $subvolume_mount_options -o subvolid=\$subvolumeID $device $recovery_system_mountpoint"
            echo "else"
            echo "    # Empty subvolumeID may indicate an error. Therefore be verbose and inform the user:"
            echo "    LogPrint 'Empty subvolumeID for $subvolume_path on $device may indicate an error, skipping remounting it to $subvolume_mountpoint'"
            echo "fi"
            echo "# End remounting btrfs subvolume $subvolume_path at $recovery_system_mountpoint"
            ) >> "$LAYOUT_CODE"
            # Handling of the '/' mountpoint is done hereby:
            continue
        fi
        # Do not mount when something is already mounted at the mountpoint.
        # In particular do not mount again the already mounted btrfs default subvolume or toplevel/root subvolume at the same mountpoint.
        # One same subvolume can be mounted at several mountpoints but one mountpoint cannot be used several times.
        Log "Mounting btrfs normal subvolume $subvolume_path on $device at $subvolume_mountpoint (if not something is already mounted there)."
        (
        echo "# Mounting btrfs normal subvolume $subvolume_path on $device at $recovery_system_mountpoint (if not something is already mounted there):"
        # If recovery_system_mountpoint has a trailing '/' it must be cut, otherwise it is not found as an already mounted mountpoint.
        # In particular a subvolume_mountpoint '/' leads to a trailing '/' in recovery_system_mountpoint (e.g. '/mnt/local/')
        # and at least the recovery filesystem root '/mnt/local/' is already mounted in any case here:
        echo "if ! mount -t btrfs | tr -s '[:blank:]' ' ' | grep -q ' on ${recovery_system_mountpoint%/} ' ; then"
        # Test in the recovery system if the recovery_system_mountpoint directory already exists to avoid that
        # useless 'mkdir -p' commands are run which look confusing in the "rear recover" log
        # regardless that 'mkdir -p' does nothing when its argument already exists:
        echo "    if ! test -d $recovery_system_mountpoint ; then"
        echo "        mkdir -p $recovery_system_mountpoint"
        echo "    fi"
        echo "    mount -t btrfs -o $subvolume_mount_options -o subvol=$subvolume_path $device $recovery_system_mountpoint"
        echo "fi"
        ) >> "$LAYOUT_CODE"
    done < <( grep "^btrfsmountedsubvol $device " "$LAYOUT_FILE" )
    ###########################################
    # Return successfully:
    Log "End btrfs_subvolumes_setup( $@ )"
    true
}

