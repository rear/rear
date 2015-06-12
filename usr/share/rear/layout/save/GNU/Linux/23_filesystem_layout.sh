# Save Filesystem layout
Log "Begin saving filesystem layout"
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
    read_filesystems_command="$findmnt_command -nrv -o SOURCE,TARGET,FSTYPE,OPTIONS -t $supported_filesystems"
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
        # Output generic filesystem layout values:
        echo -n "fs $device $mountpoint $fstype"
        # Output filesystem specific layout values:
        case "$fstype" in
            # Use leading parenthesis for the cases to have pairs of matching parenthesis in the script:
            (ext*)
                tunefs="tune2fs"
                # on RHEL 5 tune2fs does not work on ext4, needs tune4fs
                if [ "$fstype" = "ext4" ] ; then
                    if ! tune2fs -l $device >&8; then
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
                # Make sure we don't get any other output from dosfslabel (errors go to stdout :-/)
                label=$(dosfslabel $device | tail -1 | sed -e 's/ /\\\\b/g')  # replace all " " with "\\b"
                uuid=$(blkid_uuid_of_device $device)
                echo -n " uuid=$uuid label=$label"
                ;;
            (xfs)
                uuid=$(xfs_admin -u $device | cut -d'=' -f 2 | tr -d " ")
                label=$(xfs_admin -l $device | cut -d'"' -f 2)
                echo -n " uuid=$uuid label=$label "
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
                echo "# Btrfs snapshot subvolumes for $btrfs_device at $btrfs_mountpoint"
                echo "# Btrfs snapshot subvolumes are listed here only as documentation."
                echo "# There is no recovery of btrfs snapshot subvolumes."
                echo "# Format: btrfssnapshotsubvol <device> <mountpoint> <btrfs_subvolume_ID> <btrfs_subvolume_path>"
                prefix=$( echo "#btrfssnapshotsubvol $btrfs_device $btrfs_mountpoint" | sed -e 's/\//\\\//g' )
                btrfs subvolume list -as $btrfs_mountpoint | tr -s '[:blank:]' ' ' | cut -d ' ' -f 2,14 | sed -e 's/<FS_TREE>\///' | sed -e "s/^/$prefix /"
            fi
            ####################################
            # Btrfs normal subvolumes:
            # Btrfs normal subvolumes are btrfs subvolumes that are no snapshot subvolumes.
            # In case of errors "btrfs subvolume list" results output on stderr but none on stdout
            # so that the following test intentionally also fails in case of errors:
            if test $( btrfs subvolume list -a $btrfs_mountpoint | wc -l ) -gt 0 ; then
                # Get the IDs of the snapshot subvolumes as pattern for "egrep -v" e.g. like
                #   egrep -v '^279 |^280 |^281 |^282 |^285 |^286 |^289 |^290 '
                # to exclude snapshot subvolume lines to get only the normal subvolumes.
                # btrfs subvolume IDs are only unique for one same btrfs filesystem
                # which is the case here because the btrfs_device_and_mountpoint is fixed herein
                # and on one btrfs_device (e.g. /dev/sda2) there is only one btrfs filesystem.
                # The following " sed | tr | sed " pipe is ugly ( simplification is left as an exercise for the reader ;-)
                pattern=$( btrfs subvolume list -as $btrfs_mountpoint | tr -s '[:blank:]' ' ' | cut -d ' ' -f 2 | sed -e 's/^/^/' -e 's/$/ |/' | tr -d '\n' | sed -e 's/|$//' )
                echo "# Btrfs normal subvolumes for $btrfs_device at $btrfs_mountpoint"
                echo "# Format: btrfsnormalsubvol <device> <mountpoint> <btrfs_subvolume_ID> <btrfs_subvolume_path>"
                prefix=$( echo "btrfsnormalsubvol $btrfs_device $btrfs_mountpoint" | sed -e 's/\//\\\//g' )
                # With an empty pattern egrep -v '' excludes all lines:
                if test -z "$pattern" ; then
                    btrfs subvolume list -a $btrfs_mountpoint | tr -s '[:blank:]' ' ' | cut -d ' ' -f 2,9 | sed -e 's/<FS_TREE>\///' | sed -e "s/^/$prefix /"
                else
                    btrfs subvolume list -a $btrfs_mountpoint | tr -s '[:blank:]' ' ' | cut -d ' ' -f 2,9 | sed -e 's/<FS_TREE>\///' | egrep -v "$pattern" | sed -e "s/^/$prefix /"
                fi
            fi
        done
        ########################################
        # Mounted btrfs subvolumes:
        if test -x "$findmnt_command" ; then
            read_mounted_btrfs_subvolumes_command="$findmnt_command -nrv -o SOURCE,TARGET,OPTIONS,FSROOT -t btrfs"
        else
            read_mounted_btrfs_subvolumes_command="mount -t btrfs | cut -d ' ' -f 1,3,6"
        fi
        while read device subvolume_mountpoint mount_options btrfs_subvolume_path junk ; do
            if test -n "$device" -a -n "$subvolume_mountpoint" ; then
                if test -z "$btrfsmountedsubvol_entry_exists" ; then
                    # Output header only once:
                    btrfsmountedsubvol_entry_exists="yes"
                    echo "# All mounted btrfs subvolumes (including mounted btrfs default subvolumes and mounted btrfs snapshot subvolumes)."
                    if test -x "$findmnt_command" ; then
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
                    btrfs_subvolume_path=$( grep " $subvolume_mountpoint btrfs " /etc/fstab | grep -o 'subvol=[^ ]*' | cut -s -d '=' -f 2 )
                fi
                # Remove leading '/' from btrfs_subvolume_path (except it is only '/') to have same syntax for all entries and
                # without leading '/' is more clear that it is not an absolute path in the currently mounted tree of filesystems
                # instead the subvolume path is relative to the toplevel/root subvolume of the particular btrfs filesystem
                # (i.e. a subvolume path is an absolute path in the particular btrfs filesystem)
                # see https://btrfs.wiki.kernel.org/index.php/Mount_options
                test "/" != "$btrfs_subvolume_path" && btrfs_subvolume_path=${btrfs_subvolume_path#/}
                echo "btrfsmountedsubvol $device $subvolume_mountpoint $mount_options $btrfs_subvolume_path"
            fi
        done < <( eval $read_mounted_btrfs_subvolumes_command )
    fi

) >> $DISKLAYOUT_FILE
# End writing output to DISKLAYOUT_FILE.
Log "End saving filesystem layout"

