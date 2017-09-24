# Save Filesystem layout
Log "Begin saving filesystem layout"
# If available wipefs is used in the recovery system by 130_include_filesystem_code.sh
# as a generic way to cleanup disk partitions before creating a filesystem on a disk partition,
# see https://github.com/rear/rear/issues/540
# and https://github.com/rear/rear/issues/649#issuecomment-148725865
# Therefore if wipefs exists here in the original system it is added to REQUIRED_PROGS
# so that it will become also available in the recovery system (cf. 260_crypt_layout.sh):
has_binary wipefs && REQUIRED_PROGS=( "${REQUIRED_PROGS[@]}" wipefs ) || true
# Comma separated list of filesystems that is used for "mount/findmnt -t <list,of,filesystems>" below:
supported_filesystems="ext2,ext3,ext4,vfat,xfs,reiserfs,btrfs"
# Read filesystem information from the system by default using the traditional mount command
# limited to only the supported filesystems which results output lines of the form
#   device mountpoint filesystem (list,of,options)
# for example
#   /dev/sda2 / btrfs (rw,relatime,space_cache)
#   /dev/sda2 /.snapshots btrfs (rw,relatime,space_cache)
#   /dev/sda2 /var/tmp btrfs (rw,relatime,space_cache)
read_filesystems_command="mount -t $supported_filesystems | cut -d ' ' -f 1,3,5,6"
# If the findmnt command is available use it instead of the traditional mount command
# because (since SLE12) "man 8 mount" reads:
#   The listing mode is maintained for backward compatibility only.
#   For more robust and customizable output use findmnt(8), especially in your scripts.
# It is limited to only the supported filesystems which results output lines of the form
#   device mountpoint filesystem list,of,options
# for example
#   /dev/sda2 / btrfs rw,relatime,space_cache
#   /dev/sda2 /.snapshots btrfs rw,relatime,space_cache
#   /dev/sda2 /var/tmp btrfs rw,relatime,space_cache
# The only difference is that the traditional mount command output has the list of options in parenthesis.
findmnt_command="$( type -P findmnt )"
if test -x "$findmnt_command" ; then
    # Use the (deprecated) "findmnt -m" to avoid issues
    # as in https://github.com/rear/rear/issues/882
    # FIXME: Replace using the deprecated '-m' option with a future proof solution.
    read_filesystems_command="$findmnt_command -mnrv -o SOURCE,TARGET,FSTYPE,OPTIONS -t $supported_filesystems"
    Log "Saving filesystem layout (using the findmnt command)."
else
    Log "Saving filesystem layout (using the traditional mount command)."
fi
# Remove duplicate lines for the same device:
#   -t ' ' space is the field delimiter
#   -k 1,1 the sort key starts and ends at field 1 (i.e. device is the only sort key)
#   -u     unique regarding the sort key (i.e. remove duplicate lines regarding the sort key)
# so that in the above example the resulting output using the traditional mount command is
#   /dev/sda2 / btrfs (rw,relatime,space_cache)
# and the resulting output using using the findmnt command is
#   /dev/sda2 / btrfs rw,relatime,space_cache
# The sorting relies on that mount and findmnt output the first mounted thing first
# so that in particular what is mounted at '/' is output before other stuff.
read_filesystems_command="$read_filesystems_command | sort -t ' ' -k 1,1 -u"
# Begin writing output to DISKLAYOUT_FILE:
(
    echo "# Filesystems (only $supported_filesystems are supported)."
    echo "# Format: fs <device> <mountpoint> <fstype> [uuid=<uuid>] [label=<label>] [<attributes>]"
    # Read the output of the read_filesystems_command:
    while read device mountpoint fstype options junk ; do
        # Empty device or mountpoint or fstype may may indicate an error. In this case be verbose and inform the user:
        if test -z "$device" -o -z "$mountpoint" -o -z "$fstype" ; then
            LogPrint "Empty device='$device' or mountpoint='$mountpoint' or fstype='$fstype', skipping saving filesystem layout for it."
            continue
        fi
        # FIXME: I (jsmeix@suse.de) have no idea what the reason for the following is.
        # If someone knows the reason replace this comment with a description of the the actual root cause.
        if [ "${device#/}" = "$device" ] ; then
            Log "\${device#/} = '${device#/}' = \$device, skipping."
            continue
        fi
        # Skip saving filesystem layout for non-block devices:
        if [ ! -b "$device" ] ; then
            Log "$device is not a block device, skipping."
            continue
        fi
        # Skip saving filesystem layout for CD/DVD type devices:
        if [ "$fstype" = "iso9660" ] ; then
            Log "$device is CD/DVD type device [fstype=$fstype], skipping."
            continue
        fi
        # Replace a symbolic link /dev/disk/by-uuid/a1b2c3 -> ../../sdXn
        # by the fully canonicalized target of the link e.g. /dev/sdXn
        if [[ $device == /dev/disk/by-uuid* ]]; then
            # Canonicalize by following every symlink in every component of /dev/disk/by-uuid... and all components must exist:
            ndevice=$(readlink -e $device)
            Log "Mapping $device to $ndevice"
            device=$ndevice
        fi
        # FIXME: is the above condition still needed if the following is in place?
        # get_device_name and get_device_name_mapping below should canonicalize obscured udev names

        # Work with the persistent dev name:
        # Address the fact than dm-XX may be different disk in the recovery environment.
        # See https://github.com/rear/rear/pull/695
        device=$( get_device_mapping $device )
        device=$( get_device_name $device )

        # Output generic filesystem layout values:
        echo -n "fs $device $mountpoint $fstype"
        # Output filesystem specific layout values:
        case "$fstype" in
            # Use leading parenthesis for the cases to have pairs of matching parenthesis in the script:
            (ext*)
                tunefs="tune2fs"
                # on RHEL 5 tune2fs does not work on ext4, needs tune4fs
                if [ "$fstype" = "ext4" ] ; then
                    if ! tune2fs -l $device >/dev/null; then
                        tunefs="tune4fs"
                    fi
                fi
                uuid=$( $tunefs -l $device | tr -d '[:blank:]' | grep -i 'UUID:' | cut -d ':' -f 2 )
                echo -n " uuid=$uuid"
                label=$( e2label $device )
                echo -n " label=$label"
                # options: blocks, fragments, max_mount, check_interval, reserved blocks, bytes_per_inode
                blocksize=$( $tunefs -l $device | tr -d '[:blank:]' | grep -i 'Blocksize:[0-9]*' | cut -d ':' -f 2 )
                echo -n " blocksize=$blocksize"
                # we agreed to comment fragmentsize due mkfs.ext* option -f not existing (man page says it is) - issue #558
                #fragmentsize=$( $tunefs -l $device | tr -d '[:blank:]' | grep -oi 'Fragmentsize:[0-9]*' | cut -d ':' -f 2 )
                #echo -n " fragmentsize=$fragmentsize"
                nr_blocks=$( $tunefs -l $device | tr -d '[:blank:]' | grep -iv reserved | grep -i 'Blockcount:[0-9]*' | cut -d ':' -f 2 )
                reserved_blocks=$( $tunefs -l $device | tr -d '[:blank:]' | grep -i 'Reservedblockcount:[0-9]*' | cut -d ':' -f 2 )
                reserved_percentage=$(( reserved_blocks * 100 / nr_blocks ))
                StopIfError "Divide by zero detected"
                echo -n " reserved_blocks=$reserved_percentage%"
                max_mounts=$( $tunefs -l $device | tr -d '[:blank:]' | grep -i 'Maximummountcount:[0-9]*' | cut -d ':' -f 2 )
                echo -n " max_mounts=$max_mounts"
                check_interval=$( $tunefs -l $device | tr -d '[:blank:]' | grep -i 'Checkinterval:[0-9]*' | cut -d ':' -f 2 | cut -d '(' -f1 )
                check_interval=$( is_numeric $check_interval )  # if non-numeric 0 is returned
                # translate check_interval from seconds to days
                let check_interval=$check_interval/86400
                echo -n " check_interval=${check_interval}d"
                nr_inodes=$( $tunefs -l $device | tr -d '[:blank:]' | grep -i 'Inodecount:[0-9]*' | cut -d ':' -f 2 )
                let "bytes_per_inode=$nr_blocks*$blocksize/$nr_inodes"
                StopIfError "Divide by zero detected"
                echo -n " bytes_per_inode=$bytes_per_inode"
                default_mount_options=$( tune2fs -l $device | grep -i "Default mount options:" | cut -d ':' -f 2 | awk '{$1=$1};1' | tr ' ' ',' | grep -v none )
                if [[ -n $default_mount_options ]]; then
                    echo -n " default_mount_options=$default_mount_options"
                fi
                ;;
            (vfat)
                label=$(blkid_label_of_device $device)
                uuid=$(blkid_uuid_of_device $device)
                echo -n " uuid=$uuid label=$label"
                ;;
            (xfs)
                uuid=$(xfs_admin -u $device | cut -d'=' -f 2 | tr -d " ")
                label=$(xfs_admin -l $device | cut -d'"' -f 2)
                echo -n " uuid=$uuid label=$label "
                xfs_info $device > $LAYOUT_XFS_OPT_DIR/$(basename ${device}.xfs)
                StopIfError "Failed to save XFS options of $device"
                ;;
            (reiserfs)
                uuid=$(debugreiserfs $device | grep "UUID" | cut -d":" -f "2" | tr -d " ")
                label=$(debugreiserfs $device | grep "LABEL" | cut -d":" -f "2" | tr -d " ")
                echo -n " uuid=$uuid label=$label"
                ;;
            (btrfs)
                # Remember devices and mountpoints of the btrfs filesystems for the btrfs subvolume layout stuff below:
                btrfs_devices_and_mountpoints="$btrfs_devices_and_mountpoints $device,$mountpoint"
                uuid=$( btrfs filesystem show $device | grep -o 'uuid: .*' | cut -d ':' -f 2 | tr -d '[:space:]' )
                label=$( btrfs filesystem show $device | grep -o 'Label: [^ ]*' | cut -d ':' -f 2 | tr -d '[:space:]' )
                test "none" = "$label" && label=
                echo -n " uuid=$uuid label=$label"
                ;;
        esac
        # Remove parenthesis (from the traditional mount command output) from the list of options:
        options=${options#(}
        options=${options%)}

        #clip out the "seclabel" option to avoid problems. See issue no.545
        options=${options//seclabel,/}

        echo -n " options=$options"
        # Finish the current filesystem layout line with a newline character:
        echo
    done < <( eval $read_filesystems_command )

    # Btrfs subvolume layout if a btrfs filesystem exists:
    if test -n "$btrfs_devices_and_mountpoints" ; then
        ########################################
        # Btrfs subvolumes (regardless if mounted or not):
        for btrfs_device_and_mountpoint in $btrfs_devices_and_mountpoints ; do
            # Assume $btrfs_device_and_mountpoint is "/dev/sdX99,/my/mount,point" then split
            # at the first comma because device nodes (e.g. /dev/sdX99) do not contain a comma
            # but a mount point directory name may contain a comma (e.g. /my/mount,point).
            # If a mount point directory name contains space or tab characters it will break here
            # because space tab and newline are standard bash internal field separators ($IFS)
            # so that admins who use such characters for their files or directories get hereby
            # an exercise in using fail-safe names and/or how to enhance standard bash scripts:
            btrfs_device=${btrfs_device_and_mountpoint%%,*}
            btrfs_mountpoint=${btrfs_device_and_mountpoint#*,}
            ####################################
            # Btrfs default subvolume:
            echo "# Btrfs default subvolume for $btrfs_device at $btrfs_mountpoint"
            echo "# Format: btrfsdefaultsubvol <device> <mountpoint> <btrfs_subvolume_ID> <btrfs_subvolume_path>"
            # The command:           btrfs subvolume get-default /
            # results on SLES 12:    ID 257 gen 6733 top level 5 path @
            # and on openSUSE 13.2:  ID 5 (FS_TREE)
            # and on Fedora 21:      ID 5 (FS_TREE)
            btrfs_default_subvolume_ID=$( btrfs subvolume get-default $btrfs_mountpoint | tr -s '[:blank:]' ' ' | cut -d ' ' -f 2 )
            btrfs_default_subvolume_path=$( btrfs subvolume get-default $btrfs_mountpoint | tr -s '[:blank:]' ' ' | cut -d ' ' -f 9 )
            # If there is no field 9 the default subvolume path is the filesystem root (called "top-level subvolume" or "FS_TREE" by btrfs).
            # Denote the btrfs filesystem root by '/' (the only character that is really forbidden in directory names).
            # Do not denote the filesystem root by 'FS_TREE' or by any word that is a valid directory name or btrfs subvolume name
            # because an admin can create a btrfs subvolume with name 'FS_TREE' via: btrfs subvolume create FS_TREE
            test -z "$btrfs_default_subvolume_path" && btrfs_default_subvolume_path="/"
            # Empty btrfs_default_subvolume_ID may may indicate an error. In this case be verbose and inform the user:
            if test -z "$btrfs_default_subvolume_ID" ; then
                LogPrint "Empty btrfs_default_subvolume_ID, no btrfs default subvolume stored for $btrfs_device at $btrfs_mountpoint"
            else
                echo "btrfsdefaultsubvol $btrfs_device $btrfs_mountpoint $btrfs_default_subvolume_ID $btrfs_default_subvolume_path"
            fi
            ####################################
            # Btrfs snapshot subvolumes:
            # In case of errors "btrfs subvolume list" results output on stderr but none on stdout
            # so that the following test intentionally also fails in case of errors:
            if test $( btrfs subvolume list -as $btrfs_mountpoint | wc -l ) -gt 0 ; then
                snapshot_subvolume_list=$( btrfs subvolume list -as $btrfs_mountpoint | tr -s '[:blank:]' ' ' | cut -d ' ' -f 2,14 | sed -e 's/<FS_TREE>\///' )
                prefix=$( echo "#btrfssnapshotsubvol $btrfs_device $btrfs_mountpoint" | sed -e 's/\//\\\//g' )
                echo "# Btrfs snapshot subvolumes for $btrfs_device at $btrfs_mountpoint"
                echo "# Btrfs snapshot subvolumes are listed here only as documentation."
                echo "# There is no recovery of btrfs snapshot subvolumes."
                echo "# Format: btrfssnapshotsubvol <device> <mountpoint> <btrfs_subvolume_ID> <btrfs_subvolume_path>"
                echo "$snapshot_subvolume_list" | sed -e "s/^/$prefix /"
            fi
            ####################################
            # Btrfs normal subvolumes:
            # Btrfs normal subvolumes are btrfs subvolumes that are no snapshot subvolumes.
            # In case of errors "btrfs subvolume list" results output on stderr but none on stdout
            # so that the following test intentionally also fails in case of errors:
            if test $( btrfs subvolume list -a $btrfs_mountpoint | wc -l ) -gt 0 ; then
                subvolume_list=$( btrfs subvolume list -a $btrfs_mountpoint | tr -s '[:blank:]' ' ' | cut -d ' ' -f 2,9 | sed -e 's/<FS_TREE>\///' )
                prefix=$( echo "btrfsnormalsubvol $btrfs_device $btrfs_mountpoint" | sed -e 's/\//\\\//g' )
                # Get the IDs of the snapshot subvolumes as pattern for "egrep -v" e.g. like
                #   egrep -v '^279 |^280 |^281 |^282 |^285 |^286 |^289 |^290 '
                # to exclude snapshot subvolume lines to get only the normal subvolumes.
                # btrfs subvolume IDs are only unique for one same btrfs filesystem
                # which is the case here because the btrfs_device_and_mountpoint is fixed herein
                # and on one btrfs_device (e.g. /dev/sda2) there is only one btrfs filesystem.
                # The following " sed | tr | sed " pipe is ugly ( simplification is left as an exercise for the reader ;-)
                snapshot_subvolumes_pattern=$( btrfs subvolume list -as $btrfs_mountpoint | tr -s '[:blank:]' ' ' | cut -d ' ' -f 2 | sed -e 's/^/^/' -e 's/$/ |/' | tr -d '\n' | sed -e 's/|$//' )
                # SLES 12 SP1 and SP2 normal subvolumes that belong to snapper are excluded from being recreated:
                # Snapper's base subvolume '/@/.snapshots' is excluded because during "rear recover"
                # that one will be created by "snapper/installation-helper --step 1" which fails if it already exists
                # (see the code in layout/prepare/GNU/Linux/130_include_mount_subvolumes_code.sh).
                # Furthermore any normal btrfs subvolume under snapper's base subvolume '/@/.snapshots' is wrong
                # (see https://github.com/rear/rear/issues/944#issuecomment-238239926
                # and https://github.com/rear/rear/issues/963).
                # Because any btrfs subvolume under '@/.snapshots/' lets "snapper/installation-helper --step 1" fail
                # any btrfs subvolume under '@/.snapshots/' is excluded here from being recreated
                # to not let "rear recover" fail because of such kind of wrong btrfs subvolumes:
                snapper_base_subvolume="@/.snapshots"
                # Exclude usual snapshot subvolumes and subvolumes that belong to snapper.
                # When SLES12 SP1 (or later) is setup to use btrfs without snapshots
                # $snapshot_subvolumes_pattern variable will be empty. This special case
                # must be handled properly when setting up $subvolumes_exclude_pattern
                # otherwise ReaR would not recreate the btrfs subvolumes during recovery
                # because an empty pattern in the below egrep -v '|...' command would
                # exclude all lines (see https://github.com/rear/rear/pull/1435):
                if test -z "$snapshot_subvolumes_pattern" ; then
                    subvolumes_exclude_pattern="$snapper_base_subvolume"
                else
                    subvolumes_exclude_pattern="$snapshot_subvolumes_pattern|$snapper_base_subvolume"
                fi
                # Output header:
                echo "# Btrfs normal subvolumes for $btrfs_device at $btrfs_mountpoint"
                echo "# Format: btrfsnormalsubvol <device> <mountpoint> <btrfs_subvolume_ID> <btrfs_subvolume_path>"
                # List subvolumes that belong to snapper as comments (deactivated) if such subvolumes exist.
                # Have them before the other btrfs normal subvolumes because a single comment block looks less confusing
                # and matches better to the directly before listed (deactivated) snapshot subvolumes comments:
                if btrfs subvolume list -a $btrfs_mountpoint | grep -q "$snapper_base_subvolume" ; then
                    echo "# Btrfs subvolumes that belong to snapper are listed here only as documentation."
                    echo "# Snapper's base subvolume '/@/.snapshots' is deactivated here because during 'rear recover'"
                    echo "# it is created by 'snapper/installation-helper --step 1' (which fails if it already exists)."
                    echo "# Furthermore any normal btrfs subvolume under snapper's base subvolume would be wrong."
                    echo "# See https://github.com/rear/rear/issues/944#issuecomment-238239926"
                    echo "# and https://github.com/rear/rear/issues/963#issuecomment-240061392"
                    echo "# how to create a btrfs subvolume in compliance with the SLES12 default brtfs structure."
                    echo "# In short: Normal btrfs subvolumes on SLES12 must be created directly below '/@/'"
                    echo "# e.g. '/@/var/lib/mystuff' (which requires that the btrfs root subvolume is mounted)"
                    echo "# and then the subvolume is mounted at '/var/lib/mystuff' to be accessible from '/'"
                    echo "# plus usually an entry in /etc/fstab to get it mounted automatically when booting."
                    echo "# Because any '@/.snapshots' subvolume would let 'snapper/installation-helper --step 1' fail"
                    echo "# such subvolumes are deactivated here to not let 'rear recover' fail:"
                    if test -z "$snapshot_subvolumes_pattern" ; then
                        # With an empty snapshot_subvolumes_pattern egrep -v '' would exclude all lines:
                        echo "$subvolume_list" | grep "$snapper_base_subvolume" | sed -e "s/^/#$prefix /"
                    else
                        echo "$subvolume_list" | egrep -v "$snapshot_subvolumes_pattern" | grep "$snapper_base_subvolume" | sed -e "s/^/#$prefix /"
                    fi
                fi
                # Output btrfs normal subvolumes:
                if test -z "$subvolumes_exclude_pattern" ; then
                    # With an empty subvolumes_exclude_pattern egrep -v '' would exclude all lines:
                    echo "$subvolume_list" | sed -e "s/^/$prefix /"
                else
                    echo "$subvolume_list" | egrep -v "$subvolumes_exclude_pattern" | sed -e "s/^/$prefix /"
                fi
            fi
        done
        ########################################
        # Mounted btrfs subvolumes:
        # On older systems like SLE11 findmnt does not know about FSROOT
        # see https://github.com/rear/rear/issues/883
        # therefore use by default the traditional mount command
        read_mounted_btrfs_subvolumes_command="mount -t btrfs | cut -d ' ' -f 1,3,6"
        # and use findmnd only if "findmnd -o FSROOT" works:
        # Use the (deprecated) "findmnt -m" to avoid issues
        # as in https://github.com/rear/rear/issues/882
        # FIXME: Replace using the deprecated '-m' option with a future proof solution.

        if test -x "$findmnt_command" && $findmnt_command -mnrv -o FSROOT -t btrfs &>/dev/null ; then
            read_mounted_btrfs_subvolumes_command="$findmnt_command -mnrv -o SOURCE,TARGET,OPTIONS,FSROOT -t btrfs"
            findmnt_FSROOT_works="yes"
        fi
        while read device subvolume_mountpoint mount_options btrfs_subvolume_path junk ; do
            # Work with the persistent dev name:
            # Address the fact than dm-XX may be different disk in the recovery environment.
            # See https://github.com/rear/rear/pull/695
            device=$( get_device_mapping $device )
            device=$( get_device_name $device )
            # Output btrfsmountedsubvol entries:
            if test -n "$device" -a -n "$subvolume_mountpoint" ; then
                if test -z "$btrfsmountedsubvol_entry_exists" ; then
                    # Output header only once:
                    btrfsmountedsubvol_entry_exists="yes"
                    echo "# All mounted btrfs subvolumes (including mounted btrfs default subvolumes and mounted btrfs snapshot subvolumes)."
                    if test "$findmnt_FSROOT_works" ; then
                        echo "# Determined by the findmnt command that shows the mounted btrfs_subvolume_path."
                        echo "# Format: btrfsmountedsubvol <device> <subvolume_mountpoint> <mount_options> <btrfs_subvolume_path>"
                    else
                        echo "# Determined by the traditional mount command that cannot show the mounted btrfs_subvolume_path."
                        echo "# The mounted btrfs_subvolume_path is read from /etc/fstab if it can be found there."
                        echo "# Without btrfs_subvolume_path the btrfs subvolume cannot be mounted during system recovery."
                        echo "# Format: btrfsmountedsubvol <device> <subvolume_mountpoint> <mount_options> [<btrfs_subvolume_path>]"
                    fi
                fi
                # Remove parenthesis (from the traditional mount command output) from the list of mount options:
                mount_options=${mount_options#(}
                mount_options=${mount_options%)}
                if test -z "$btrfs_subvolume_path" ; then
                    # When btrfs_subvolume_path is empty (in particular when the traditional mount command is used)
                    # try to find the mountpoint in /etc/fstab and try to read the subvol=... option value if exists
                    # (using subvolid=... can fail because the subvolume ID can be different during system recovery).
                    # Because both "mount ... -o subvol=/path/to/subvolume" and "mount ... -o subvol=path/to/subvolume" work
                    # the subvolume path can be specified with or without leading '/':
                    btrfs_subvolume_path=$( egrep "[[:space:]]$subvolume_mountpoint[[:space:]]+btrfs[[:space:]]" /etc/fstab \
                                            | egrep -v '^[[:space:]]*#' \
                                            | grep -o 'subvol=[^ ]*' | cut -s -d '=' -f 2 )
                fi
                # Remove leading '/' from btrfs_subvolume_path (except it is only '/') to have same syntax for all entries and
                # without leading '/' is more clear that it is not an absolute path in the currently mounted tree of filesystems
                # instead the subvolume path is relative to the toplevel/root subvolume of the particular btrfs filesystem
                # (i.e. a subvolume path is an absolute path in the particular btrfs filesystem)
                # see https://btrfs.wiki.kernel.org/index.php/Mount_options
                test "/" != "$btrfs_subvolume_path" && btrfs_subvolume_path=${btrfs_subvolume_path#/}

                # Finally, test whether the btrfs subvolume listed as mounted actually exists. A running docker
                # daemon apparently can convince the system to list a non-existing btrfs volume as mounted.
                # See https://github.com/rear/rear/issues/1496
                if btrfs_subvolume_exists "$subvolume_mountpoint" "$btrfs_subvolume_path"; then
                    echo "btrfsmountedsubvol $device $subvolume_mountpoint $mount_options $btrfs_subvolume_path"
                else
                    LogPrintError "Ignoring non-existing btrfs subvolume listed as mounted: $subvolume_mountpoint"
                    echo "# Ignoring non-existing btrfs subvolume listed as mounted:"
                    echo "#btrfsmountedsubvol $device $subvolume_mountpoint $mount_options $btrfs_subvolume_path"
                fi
            fi
        done < <( eval $read_mounted_btrfs_subvolumes_command )
        ########################################
        # No copy on write attributes of mounted btrfs subvolumes:
        echo "# Mounted btrfs subvolumes that have the 'no copy on write' attribute set."
        echo "# Format: btrfsnocopyonwrite <btrfs_subvolume_path>"
        lsattr_command="$( type -P lsattr )"
        # On older systems like SLE11 findmnt does not know about FSROOT (see above)
        # therefore test if findmnt_FSROOT_works was set above:
        # Use the (deprecated) "findmnt -m" to avoid issues
        # as in https://github.com/rear/rear/issues/882
        # FIXME: Replace using the deprecated '-m' option with a future proof solution.
        if test -x "$lsattr_command" -a -x "$findmnt_command" -a "$findmnt_FSROOT_works" ; then
            for subvolume_mountpoint in $( $findmnt_command -mnrv -o TARGET -t btrfs ) ; do
                # The 'no copy on write' attribute is shown as 'C' in the lsattr output (see "man chattr"):
                if $lsattr_command -d $subvolume_mountpoint | cut -d ' ' -f 1 | grep -q 'C' ; then
                    btrfs_subvolume_path=$( $findmnt_command -mnrv -o FSROOT $subvolume_mountpoint )
                    # Remove leading '/' from btrfs_subvolume_path (except it is only '/') to have same syntax for all entries and
                    # without leading '/' is more clear that it is not an absolute path in the currently mounted tree of filesystems
                    # instead the subvolume path is relative to the toplevel/root subvolume of the particular btrfs filesystem
                    # (i.e. a subvolume path is an absolute path in the particular btrfs filesystem)
                    # see https://btrfs.wiki.kernel.org/index.php/Mount_options
                    test "/" != "$btrfs_subvolume_path" && btrfs_subvolume_path=${btrfs_subvolume_path#/}
                    if test -n "btrfs_subvolume_path" ; then
			# Add the following binaries to the rescue image in order to be able to change required attrs uppon recovery.
                        for p in chattr lsattr
                        do
                            if ! IsInArray "$p" "${PROGS[@]}"; then
                                PROGS=( ${PROGS[@]} "$p" )
                            fi
                        done
                        echo "btrfsnocopyonwrite $btrfs_subvolume_path"
                    else
                        echo "# $subvolume_mountpoint has the 'no copy on write' attribute set but $findmnt_command does not show its btrfs subvolume path"
                    fi
                fi
            done
        else
            echo "# Attributes cannot be determined because no executable 'lsattr' and/or 'findmnt' command(s) found that supports 'FSROOT'."
        fi
    fi

) >> $DISKLAYOUT_FILE
# End writing output to DISKLAYOUT_FILE.
Log "End saving filesystem layout"
