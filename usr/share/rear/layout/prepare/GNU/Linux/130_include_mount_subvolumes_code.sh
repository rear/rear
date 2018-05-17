
# Code for btrfs subvolume handling.
# 130_include_mount_subvolumes_code.sh contains the function btrfs_subvolumes_setup for all btrfs subvolume handling.
# Btrfs filesystems with subvolumes need a special handling.
# All btrfs subvolume handling happens in the btrfs_subvolumes_setup function in 130_include_mount_subvolumes_code.sh
# For a plain btrfs filesystem without subvolumes the btrfs_subvolumes_setup function does nothing.

btrfs_subvolumes_setup() {
    Log "Begin btrfs_subvolumes_setup( $@ )"
    # Local variables are visible only in this btrfs_subvolumes_setup function and its children:
    local dummy junk keyword info_message
    local device mountpoint mountopts target_system_mountpoint
    local subvolume_path subvolume_directory_path subvolume_mountpoint subvolume_mount_options
    local snapshot_subvolumes_devices_and_paths snapshot_subvolume_device_and_path snapshot_subvolume_device snapshot_subvolume_path
    local default_subvolume_path
    # Assign function arguments to meaningful variable names:
    # This function is called in 130_include_mount_filesystem_code.sh as follows:
    #   btrfs_subvolumes_setup $device $mountpoint $mountopts
    # where $device is the device node where the filesystem was already created by 130_include_filesystem_code.sh
    # (usually a harddisk partition like e.g. /dev/sda1):
    device=$1
    mountpoint=$2
    # mountopts are of the form "-o foo,bar,baz" (see 130_include_mount_filesystem_code.sh)
    # which means $3 is '-o' and 'foo,bar,baz' is $4:
    mountopts="$3 $4"
    # Empty device or mountpoint may indicate an error. In this case be verbose and inform the user:
    if test -z "$device" -o -z "$mountpoint" ; then
        LogPrint "Empty device='$device' or mountpoint='$mountpoint' may indicate an error, skipping btrfs_subvolumes_setup( $@ )."
        Log "Return 0 from btrfs_subvolumes_setup( $@ )"
        return 0
    fi
    ###########################################
    # SLES 12 SP1 (and later) special btrfs subvolumes setup detection:
    SLES12SP1_btrfs_detection_string="@/.snapshots/"
    if grep -q "^btrfsdefaultsubvol $device $mountpoint [0-9]* $SLES12SP1_btrfs_detection_string" "$LAYOUT_FILE" ; then
        info_message="Doing SLES12-SP1 (and later) btrfs subvolumes setup because the default subvolume path contains '$SLES12SP1_btrfs_detection_string'"
        LogPrint $info_message
        echo "# $info_message" >> "$LAYOUT_CODE"
        # For SLES 12 SP1 a btrfsdefaultsubvol entry in disklayout.conf looks like
        #   btrfsdefaultsubvol /dev/sda2 / 259 @/.snapshots/1/snapshot
        # where "@/.snapshots/" should be fixed but "1/snapshot" may vary.
        # This requires special setup because the btrfs default subvolume on SLES 12 SP1
        # is not a normal btrfs subvolume (as it was on SLES 12 (without SP1))
        # but on SLES 12 SP1 it is a snapper controlled btrfs snapshot subvolume, see
        # https://github.com/rear/rear/issues/556
        # https://fate.suse.com/318701 (SUSE internal feature request)
        # https://bugzilla.suse.com/show_bug.cgi?id=946006 (SUSE internal issue)
        SLES12SP1_btrfs_subvolumes_setup="yes"
        # Because that very special btrfs default subvolume on SLES 12 SP1
        # has to be controlled by snapper it must be set up by snapper
        # which means that snapper is needed in the ReaR recovery system.
        # For this special setup during installation a special SUSE tool
        # /usr/lib/snapper/installation-helper is used:
        SLES12SP1_installation_helper_executable="/usr/lib/snapper/installation-helper"
        # What "snapper/installation-helper --step 1" basically does is
        # creating a snapshot of the first root filesystem
        # where the first root filesystem must have the btrfs subvolume '@' mounted at '/'
        # which means the btrfs subvolume '@' must be the initial btrfs default subvolume:
        SLES12SP1_initial_default_subvolume_path="@"
    fi
    ###########################################
    # Btrfs snapshot subvolumes handling:
    # Remember all btrfs snapshot subvolumes to exclude them when mounting all btrfs normal subvolumes below.
    # The btrfs snapshot subvolumes entries that are created by 230_filesystem_layout.sh
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
    # is also listed as a normal subvolume so that also the subvolume that is later used as default subvolume is hereby created
    # provided the btrfs default subvolume is not a btrfs snapshot subvolume as in SLES 12 SP1 - but not in SLES 12 (without SP1):
    while read dummy dummy dummy dummy subvolume_path junk ; do
        # Empty subvolume_path may indicate an error. In this case be verbose and inform the user:
        if test -z "$subvolume_path" ; then
            LogPrint "btrfsnormalsubvol entry with empty subvolume_path for $device at $mountpoint may indicate an error, skipping subvolume setup for it."
            continue
        fi
        # In case of SLES 12 SP1 (and later) special btrfs subvolumes setup skip setup of '@/.snapshots' normal btrfs subvolumes:
        if test -n "$SLES12SP1_btrfs_subvolumes_setup" ; then
            # In case of SLES 12 SP1 (and later) special btrfs subvolumes setup
            # skip setup of the normal btrfs subvolume '@/.snapshots' because
            # that one will be created by "snapper/installation-helper --step 1"
            # which fails if it already exists.
            if test "$subvolume_path" = "@/.snapshots" ; then
                info_message="No 'btrfs subvolume create' for '$subvolume_path' because it will be created by 'snapper/installation-helper --step 1' (which fails if that already exists)."
                LogPrint $info_message
                echo "# $info_message" >> "$LAYOUT_CODE"
                continue
            fi
            # Any normal btrfs subvolume under snapper's base subvolume is wrong
            # (see https://github.com/rear/rear/issues/944#issuecomment-238239926
            # and https://github.com/rear/rear/issues/963
            # and layout/save/GNU/Linux/230_filesystem_layout.sh).
            # Because any btrfs subvolume under '@/.snapshots/' lets "snapper/installation-helper --step 1" fail
            # any btrfs subvolume under '@/.snapshots/' is excluded here from being recreated
            # to not let "rear recover" fail because of such kind of wrong btrfs subvolumes
            # and inform the user about that via 'LogPrint':
            if [[ "$subvolume_path" == "@/.snapshots/"* ]] ; then
                info_message="Skipping subvolume setup for '$subvolume_path' because any btrfs subvolume under '.snapshots' would let 'snapper/installation-helper --step 1' fail."
                LogPrint $info_message
                echo "# $info_message" >> "$LAYOUT_CODE"
                continue
            fi
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
        target_system_mountpoint=$TARGET_FS_ROOT$mountpoint
        info_message="Creating normal btrfs subvolume $subvolume_path on $device at $mountpoint"
        Log $info_message
        (
        echo "# $info_message"
        if test -n "$subvolume_directory_path" ; then
            # Test in the recovery system if the directory path already exists to avoid that
            # useless 'mkdir -p' commands are run which look confusing in the "rear recover" log
            # regardless that 'mkdir -p' does nothing when its argument already exists:
            echo "if ! test -d $target_system_mountpoint/$subvolume_directory_path ; then"
            echo "    mkdir -p $target_system_mountpoint/$subvolume_directory_path"
            echo "fi"
        fi
        echo "btrfs subvolume create $target_system_mountpoint/$subvolume_path"
        ) >> "$LAYOUT_CODE"
        # Btrfs subvolumes 'no copy on write' attribute setup:
        if grep -q "^btrfsnocopyonwrite $subvolume_path\$" "$LAYOUT_FILE" ; then
            info_message="Setting 'no copy on write' attribute for subvolume $subvolume_path"
            Log $info_message
            (
            echo "# $info_message"
            echo "chattr +C $target_system_mountpoint/$subvolume_path"
            ) >> "$LAYOUT_CODE"
        fi
    done < <( grep "^btrfsnormalsubvol $device $mountpoint " "$LAYOUT_FILE" )
    ###########################################
    # Btrfs default subvolume setup:
    # No outer 'while read ...' loop because there is exactly one default subvolume for one btrfs filesystem
    # on one specific device (usually a harddisk partition like e.g. /dev/sda1):
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
        # When in the original system the btrfs filesystem had a special different default subvolume
        # (i.e. when the btrfs default subvolume is not the toplevel/root subvolume), then
        # that different subvolume needs to be set to be the default subvolume:
        target_system_mountpoint=$TARGET_FS_ROOT$mountpoint
        Log "Setting $subvolume_path as btrfs default subvolume for $device at $mountpoint"
        if test -n "$SLES12SP1_btrfs_subvolumes_setup" ; then
            (
            echo "# Begin btrfs default subvolume setup on $device at $mountpoint"
            echo "# Doing special SLES 12 SP1 btrfs default snapper snapshot subvolume setup"
            echo "# because the default subvolume path '$subvolume_path' contains '@/.snapshots/'"
            echo "# Making the $SLES12SP1_initial_default_subvolume_path subvolume the initial default subvolume"
            echo "# Get the ID of the $initial_default_subvolume_path subvolume"
            echo "subvolumeID=\$( btrfs subvolume list -a $target_system_mountpoint | sed -e 's/<FS_TREE>\///' | grep ' $SLES12SP1_initial_default_subvolume_path\$' | tr -s '[:blank:]' ' ' | cut -d ' ' -f 2 )"
            echo "# Set the $SLES12SP1_initial_default_subvolume_path subvolume as initial default subvolume using its subvolume ID"
            echo "btrfs subvolume set-default \$subvolumeID $target_system_mountpoint"
            echo "# Begin step 1 of special SLES 12 SP1 btrfs default snapper snapshot subvolume setup"
            echo "umount $target_system_mountpoint"
            echo "# Configuring snapper for root filesystem - step 1:"
            echo "# - temporarily mounting device"
            echo "# - copying/modifying config-file"
            echo "# - creating filesystem config"
            echo "# - creating snapshot of first root filesystem"
            echo "# - setting default subvolume"
            echo "if test -x $SLES12SP1_installation_helper_executable"
            echo "then LogPrint 'Running snapper/installation-helper'"
            echo "     $SLES12SP1_installation_helper_executable --step 1 --device $device --description 'first root filesystem'"
            echo "else LogPrint '$SLES12SP1_installation_helper_executable not executable may indicate an error with btrfs default subvolume setup for $subvolume_path on $device'"
            echo "fi"
            echo "mount -t btrfs -o subvolid=0 $mountopts $device $target_system_mountpoint"
            echo "# End step 1 of special SLES 12 SP1 btrfs default snapper snapshot subvolume setup"
            ) >> "$LAYOUT_CODE"
        else
            (
            echo "# Begin btrfs default subvolume setup on $device at $mountpoint"
            echo "# Making the $subvolume_path subvolume the default subvolume"
            echo "# Get the ID of the $subvolume_path subvolume"
            echo "subvolumeID=\$( btrfs subvolume list -a $target_system_mountpoint | sed -e 's/<FS_TREE>\///' | grep ' $subvolume_path\$' | tr -s '[:blank:]' ' ' | cut -d ' ' -f 2 )"
            echo "# Set the $subvolume_path subvolume as default subvolume using its subvolume ID"
            echo "btrfs subvolume set-default \$subvolumeID $target_system_mountpoint"
            ) >> "$LAYOUT_CODE"
        fi
        # When the btrfs filesystem has a special default subvolume (one that is not the toplevel/root subvolume)
        # then a reasonable assumption is that this one was mounted in the original system and not something else.
        # FIXME: It is possible that the admin has actually mounted something else in his original system
        # which would result a wrong recovery because currently such an awkward setup is not supported.
        # Under the above assumption the btrfs filesystem needs to be umonted and mounted again so that
        # the special default subvolume gets mounted in the recovery system at $TARGET_FS_ROOT$mountpoint.
        Log "Remounting the btrfs default subvolume $subvolume_path for $device at $mountpoint"
        (
        echo "# Remounting the $subvolume_path default subvolume at $target_system_mountpoint"
        echo "umount $target_system_mountpoint"
        echo "mount -t btrfs $mountopts $device $target_system_mountpoint"
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
        # btrfs mount options like subvolid=259 or subvol=/@/.snapshots/1/snapshot
        # from the old system cannot work here or are not needed here for recovery
        # because for new created btrfs subvolumes their subvolid is likely different
        # and the subvol=... value is already explicitly available via subvolume_path
        # so that those mount options are removed here:
        # First add a comma at the end so that it is easier to remove a mount option at the end:
        subvolume_mount_options=${subvolume_mount_options/%/,}
        # Remove all subvolid= and subvol= mount options (the extglob shell option is enabled in rear):
        subvolume_mount_options=${subvolume_mount_options//subvolid=*([^,]),/}
        subvolume_mount_options=${subvolume_mount_options//subvol=*([^,]),/}
        # Remove all commas at the end:
        subvolume_mount_options=${subvolume_mount_options/%,/}
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
        target_system_mountpoint=$TARGET_FS_ROOT$subvolume_mountpoint
        # Remounting is needed when at the '/' mountpoint not the btrfs default subvolume is mounted:
        # On Fedora 21 what is mounted at the root of the filesystem tree (i.e. at the '/' mountpoint)
        # is not the btrfs default subvolume (the default subvolume is the toplevel/root subvolume).
        # On Fedora 21 there is a btrfs subvolume "root" which is mounted at the '/' mountpoint.
        # I (jsmeix@suse.de) am not a btrfs expert but from my point of view it looks like
        # a misconfiguration (a.k.a. bug) in Fedora 21 how they set up btrfs. I think Fedora
        # should specify as btrfs default subvolume what is mounted by default at the '/' mountpoint.
        # On the other hand I noticed an openSUSE user who presented arguments that
        # the btrfs default subvolume setting only belongs to the user and
        # should not be used by the system to specify what is mounted by default,
        # see what Chris Murphy wrote on the "Default btrfs subvolume after a rollback"
        # and "systemd, btrfs, /var/lib/machines" mail threads on opensuse-factory@opensuse.org
        # http://lists.opensuse.org/opensuse-factory/2015-07/msg00517.html
        # http://lists.opensuse.org/opensuse-factory/2015-07/msg00591.html
        # and his GitHub snapper issue and openSUSE feature request
        # "snapper improperly usurps control of the default subvolume from the user"
        # https://github.com/openSUSE/snapper/issues/178
        # https://features.opensuse.org/319292
        # Regardless who or what is right or wrong here I like to have ReaR working fail-safe
        # because an admin could manually create any kind of awkward btrfs setup.
        # Therefore remounting is needed when the subvolume_mountpoint is '/'
        # but the subvolume_path is neither '/' nor the default subvolume.
        # Examples: disklayout.conf contains
        # on openSUSE 13.2 at '/' the default subvolume which is the root subvolume (ID 5 '/') is mounted:
        #   btrfsdefaultsubvol /dev/sda2 / 5 /
        #   btrfsmountedsubvol /dev/sda2 / rw,relatime,space_cache /
        # on SLES 12 at '/' the default subvolume '@' is mounted:
        #   btrfsdefaultsubvol /dev/sda2 / 257 @
        #   btrfsmountedsubvol /dev/sda2 / rw,relatime,space_cache @
        # on SLES 12 SP1 at '/' the default subvolume '@/.snapshots/1/snapshot' is mounted:
        #   btrfsdefaultsubvol /dev/sda2 / 259 @/.snapshots/1/snapshot
        #   #btrfssnapshotsubvol /dev/sda2 / 259 @/.snapshots/1/snapshot
        #   btrfsnormalsubvol /dev/sda2 / 258 @/.snapshots
        #   btrfsmountedsubvol /dev/sda2 / rw,relatime,space_cache,subvolid=259,subvol=/@/.snapshots/1/snapshot @/.snapshots/1/snapshot
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
            echo "# Begin remounting btrfs subvolume $subvolume_path at $target_system_mountpoint"
            echo "# On $device btrfs subvolume $subvolume_path is currently not mounted at $target_system_mountpoint, needs remounting:"
            echo "# Get the ID of the $subvolume_path subvolume because it must be mounted with subvolid=ID"
            echo "# (using subvol=NAME may not work as long as it is falsely mounted so that subvolume names may not match)"
            echo "subvolumeID=\$( btrfs subvolume list -a $target_system_mountpoint | sed -e 's/<FS_TREE>\///' | grep ' $subvolume_path\$' | tr -s '[:blank:]' ' ' | cut -d ' ' -f 2 )"
            echo "if test -n \"\$subvolumeID\" ; then"
            echo "    # No remounting when subvolumeID is empty because then umount would work but mount would fail"
            echo "    # Remounting the $subvolume_path subvolume at $target_system_mountpoint"
            echo "    umount $target_system_mountpoint"
            echo "    mount -t btrfs -o $subvolume_mount_options -o subvolid=\$subvolumeID $device $target_system_mountpoint"
            echo "else"
            echo "    # Empty subvolumeID may indicate an error. Therefore be verbose and inform the user:"
            echo "    LogPrint 'Empty subvolumeID for $subvolume_path on $device may indicate an error, skipping remounting it to $subvolume_mountpoint'"
            echo "fi"
            echo "# End remounting btrfs subvolume $subvolume_path at $target_system_mountpoint"
            ) >> "$LAYOUT_CODE"
            # Handling of the '/' mountpoint is done hereby:
            continue
        fi
        # Do not mount when something is already mounted at the mountpoint.
        # In particular do not mount again the already mounted btrfs default subvolume or toplevel/root subvolume at the same mountpoint.
        # One same subvolume can be mounted at several mountpoints but one mountpoint cannot be used several times.
        Log "Mounting btrfs normal subvolume $subvolume_path on $device at $subvolume_mountpoint (if not something is already mounted there)."
        (
        echo "# Mounting btrfs normal subvolume $subvolume_path on $device at $target_system_mountpoint (if not something is already mounted there):"
        # If target_system_mountpoint has a trailing '/' it must be cut, otherwise it is not found as an already mounted mountpoint.
        # In particular a subvolume_mountpoint '/' leads to a trailing '/' in target_system_mountpoint (e.g. '/mnt/local/')
        # and at least the recovery filesystem root $TARGET_FS_ROOT (by default '/mnt/local') is already mounted in any case here:
        echo "if ! mount -t btrfs | tr -s '[:blank:]' ' ' | grep -q ' on ${target_system_mountpoint%/} ' ; then"
        # Test in the recovery system if the target_system_mountpoint directory already exists to avoid that
        # useless 'mkdir -p' commands are run which look confusing in the "rear recover" log
        # regardless that 'mkdir -p' does nothing when its argument already exists:
        echo "    if ! test -d $target_system_mountpoint ; then"
        echo "        mkdir -p $target_system_mountpoint"
        echo "    fi"
        echo "    mount -t btrfs -o $subvolume_mount_options -o subvol=$subvolume_path $device $target_system_mountpoint"
        echo "fi"
        ) >> "$LAYOUT_CODE"
    done < <( grep "^btrfsmountedsubvol $device " "$LAYOUT_FILE" )
    ###########################################
    # Return successfully:
    Log "End btrfs_subvolumes_setup( $@ )"
    true
}

