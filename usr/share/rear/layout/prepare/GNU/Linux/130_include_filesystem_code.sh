# Code to recreate filesystems.

function create_fs () {
    Log "Begin create_fs( $@ )"

    local fs device mountpoint fstype uuid label options
    device=${1#fs:}
    read fs device mountpoint fstype uuid label options < <( grep "^fs.* $device " "$LAYOUT_FILE" )
    label=${label#label=}
    uuid=${uuid#uuid=}

    # Wait until udev had created the disk partition device node before creating a filesystem there:
    (   echo "# Wait until udev had created '$device' before creating a filesystem there:"
        echo "my_udevsettle"
    ) >> "$LAYOUT_CODE"

    # If available use wipefs as a generic way to cleanup disk partitions
    # before creating a filesystem on a disk partition,
    # see https://github.com/rear/rear/issues/540
    # and https://github.com/rear/rear/issues/649#issuecomment-148725865
    local has_wipefs="" wipefs_command="" wipefs_info_message=""
    if has_binary wipefs ; then
        has_wipefs="yes"
        wipefs_command="wipefs -a $device"
        wipefs_info_message="Using wipefs to cleanup '$device' before creating filesystem."
        Debug "$wipefs_info_message"
        echo "# $wipefs_info_message" >> "$LAYOUT_CODE"
    fi

    # Tell what will be done:
    local create_filesystem_info_message="Creating filesystem of type '$fstype' with mount point '$mountpoint' on '$device'."
    Debug "$create_filesystem_info_message"
    echo "LogPrint '$create_filesystem_info_message'" >> "$LAYOUT_CODE"

    # Actually do it:
    case "$fstype" in
        (ext*)
            # File system parameters:
            local blocksize="" reserved_blocks="" max_mounts="" check_interval="" default_mount_options=""
            local fragmentsize="" bytes_per_inode=""
            local option name value
            for option in $options ; do
                name=${option%=*}
                value=${option#*=}
                case "$name" in
                    (blocksize)
                        blocksize=" -b $value"
                        ;;
                    (fragmentsize)
                        fragmentsize=" -f $value"
                        ;;
                    (bytes_per_inode)
                        bytes_per_inode=" -i $value"
                        ;;
                    (reserved_blocks)
                        ### reserved_blocks can be a number or a percentage.
                        if [[ ${value%\%} == ${value} ]] ; then
                            reserved_blocks=" -r $value"
                        else
                            reserved_blocks=" -m ${value%\%}"
                        fi
                        ;;
                    (max_mounts)
                        max_mounts=" -c $value"
                        ;;
                    (check_interval)
                        check_interval=" -i $value"
                        ;;
                    (default_mount_options)
                        default_mount_options=" -o $value"
                        ;;
                esac
            done
            # If available use wipefs to cleanup disk partition:
            test "$has_wipefs" && echo "$wipefs_command" >> "$LAYOUT_CODE"
            # Use the right program to adjust tunable filesystem parameters on ext2/ext3/ext4 filesystems:
            local tunefs="tune2fs"
            # On RHEL 5, tune2fs does not work on ext4.
            if [ "$fstype" = "ext4" ] && has_binary tune4fs ; then
                tunefs="tune4fs"
            fi
            # Actually create the filesystem with initially correct UUID
            # (addresses Fedora/systemd problem, see issue 851)
            # "mkfs -U" works at least since SLE11 but it may fail on older systems
            # e.g. on RHEL 5 mkfs does not support '-U' so that when "mkfs -U" fails
            # we assume it failed because of missing support for '-U' and
            # then we fall back to the old way before issue 851
            # i.e. using "mkfs" without '-U' plus "tunefs -U":
            if [ -n "$uuid" ] ; then
                ( echo "# Try 'mkfs -U' to create the filesystem with initially correct UUID"
                  echo "# but if that fails assume it failed because of missing support for '-U'"
                  echo "# (e.g. in RHEL 5 it fails, see https://github.com/rear/rear/issues/890)"
                  echo "# then fall back to using mkfs without '-U' plus 'tune2fs/tune4fs -U'"
                  echo "if ! mkfs -t ${fstype}${blocksize}${fragmentsize}${bytes_per_inode} -U $uuid $device >&2 ; then"
                  echo "    mkfs -t ${fstype}${blocksize}${fragmentsize}${bytes_per_inode} $device >&2"
                  echo "    $tunefs -U $uuid $device >&2"
                  echo "fi"
                ) >> "$LAYOUT_CODE"
            else
                echo "mkfs -t ${fstype}${blocksize}${fragmentsize}${bytes_per_inode} $device >&2" >> "$LAYOUT_CODE"
            fi
            # Adjust tunable filesystem parameters on ext2/ext3/ext4 filesystems:
            # Set the label:
            if [ -n "$label" ] ; then
                echo "$tunefs -L $label $device >&2" >> "$LAYOUT_CODE"
            fi
            # Set the other tunable filesystem parameters:
            tune2fsopts="${reserved_blocks}${max_mounts}${check_interval}${default_mount_options}"
            if [ -n "$tune2fsopts" ] ; then
                echo "$tunefs $tune2fsopts $device >&2" >> "$LAYOUT_CODE"
            fi
            ;;
        (xfs)
            # If available use wipefs to cleanup disk partition:
            test "$has_wipefs" && echo "$wipefs_command" >> "$LAYOUT_CODE"

            # Load xfs options from configuration files saved during
            # 'rear mkbackup/mkrescue' by xfs_info.
            # xfs info is called in 230_filesystem_layout.sh (layout/prepare)
            # xfs_opts will be used as additional parameter for mkfs.xfs and
            # ensures that xfs filesystem will be created exactly as original.
            local xfs_opts
            xfs_opts=$(xfs_parse $LAYOUT_XFS_OPT_DIR/$(basename ${device}.xfs))

            # Decide if mkfs.xfs or xfs_admin will set uuid.
            # Uuid set by xfs_admin will set incompatible flag on systems with
            # enabled CRC. This might cause ReaR failure during grub installation.
            # See: https://github.com/rear/rear/issues/1065
            if [ -n "$uuid" ]; then
                ( echo "if ! mkfs.xfs -f -m uuid=$uuid $xfs_opts $device >&2; then"
                  echo "    mkfs.xfs -f $xfs_opts $device >&2"
                  echo "    xfs_admin -U $uuid $device >&2"
                  # xfs_admin -U might cause dirty structure and problems with
                  # mounting.
                  # xfs_repair will fix this.
                  echo "    xfs_repair $device"
                  echo "fi"
                ) >> "$LAYOUT_CODE"
            else
                # Actually create the filesystem
                echo "mkfs.xfs -f $xfs_opts $device >&2" >> "$LAYOUT_CODE"
            fi

            # Set the label:
            if [ -n "$label" ] ; then
                echo "xfs_admin -L $label $device >&2" >> "$LAYOUT_CODE"
            fi
            ;;
        (reiserfs)
            # If available use wipefs to cleanup disk partition:
            test "$has_wipefs" && echo "$wipefs_command" >> "$LAYOUT_CODE"
            # Actually create the filesystem:
            echo "mkfs -t $fstype -q $device" >> "$LAYOUT_CODE"
            # Set the label:
            if [ -n "$label" ] ; then
                echo "reiserfstune --label $label $device >&2" >> "$LAYOUT_CODE"
            fi
            # Set the UUID:
            if [ -n "$uuid" ] ; then
                echo "reiserfstune --uuid $uuid $device >&2" >> "$LAYOUT_CODE"
            fi
            ;;
        (btrfs)
            # If available use wipefs to cleanup disk partition:
            test "$has_wipefs" && echo "mount | grep -q $device || $wipefs_command" >> "$LAYOUT_CODE"
            # Actually create the filesystem provided the disk partition is not already mounted.
            # User -f [force] to force overwriting an existing btrfs on that disk partition
            # when the disk was already used before, see https://bugzilla.novell.com/show_bug.cgi?id=878870
            (   echo "# if $device is already mounted, skip"
                echo "# force overwriting existing btrfs when the disk was already used before"
                echo "mount | grep -q $device || mkfs -t $fstype -f $device"
            ) >> "$LAYOUT_CODE"
            # Set the label:
            if [ -n "$label" ] ; then
                echo "mount | grep -q $device || btrfs filesystem label $device $label >&2" >> "$LAYOUT_CODE"
            fi
            # Set the UUID:
            if [ -n "$uuid" ] ; then
                # Problem with btrfs is that UUID cannot be set during mkfs! So, we must map it and
                # change later the /etc/fstab, /boot/grub/menu.lst, etc.
                cat >> "$LAYOUT_CODE" <<EOF
new_uuid=\$( btrfs filesystem show $device 2>/dev/null | grep -o 'uuid: .*' | cut -d ':' -f 2 | tr -d '[:space:]' )
if [ "$uuid" != "\$new_uuid" ] ; then
    # The following grep command intentionally also
    # fails when there is not yet a FS_UUID_MAP file
    # and then the FS_UUID_MAP file will be created:
    if ! grep -q "${uuid}" "$FS_UUID_MAP" ; then
        echo "$uuid \$new_uuid $device" >> $FS_UUID_MAP
    else
        # Required when we restart rear recover (via menu) - UUID changed again.
        old_uuid=\$(grep ${uuid} $FS_UUID_MAP | tail -1 | awk '{print \$2}')
        SED_SCRIPT=";/${uuid}/s/\${old_uuid}/\${new_uuid}/g"
        sed -i "\$SED_SCRIPT" "$FS_UUID_MAP"
    fi
fi # end of [ "$uuid" != "\$new_uuid" ]
EOF
            fi
            ;;
        (vfat)
            # If available use wipefs to cleanup disk partition:
            test "$has_wipefs" && echo "$wipefs_command" >> "$LAYOUT_CODE"
            # Actually create the filesystem with or without label:
            if [ -n "$label" ] ; then
                # we substituted all " " with "\\b" in savelayout (\\b becomes \b by reading label)
                echo "$label" | grep -q '\b'
                if [ $? -eq 0 ] ; then
                    label2="$(echo $label | sed -e 's/\\b/ /g')" # replace \b with a " "
                    label="$label2"
                fi
                echo "mkfs.vfat -n \"$label\" $device" >> "$LAYOUT_CODE"
            else
                echo "mkfs.vfat $device" >> "$LAYOUT_CODE"
            fi
            # Set the UUID:
            if [ -n "$uuid" ]; then
                # The UUID label of vfat is changed by recreating the fs, we must swap it.
                cat >> "$LAYOUT_CODE" <<EOF
new_uuid=\$(blkid_uuid_of_device $device)
if [ "$uuid" != "\$new_uuid" ] ; then
    echo "$uuid \$new_uuid $device" >> "$FS_UUID_MAP"
fi
EOF
            fi
            ;;
        (*)
            # If available use wipefs to cleanup disk partition:
            test "$has_wipefs" && echo "$wipefs_command" >> "$LAYOUT_CODE"
            # Actually create the filesystem:
            echo "mkfs -t $fstype $device >&2" >> "$LAYOUT_CODE"
            ;;
    esac

    # Call the mount_fs function with argument $1 (device):
    mount_fs ${1}

    Log "End create_fs( $@ )"
}

