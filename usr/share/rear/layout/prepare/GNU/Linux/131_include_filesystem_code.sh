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

    # If available try to use wipefs as a generic way to cleanup disk partitions
    # and try to use dd as generic fallback to erase at least dos partition tables
    # before creating a filesystem on a disk partition,
    # see https://github.com/rear/rear/issues/540
    # and https://github.com/rear/rear/issues/649#issuecomment-148725865
    # and https://github.com/rear/rear/issues/1327
    # and https://github.com/rear/rear/issues/799
    # TODO: Enhancements welcome from whoever likes to maintain them ;-)
    local cleanup_command="" cleanup_info_message=""
    if has_binary wipefs ; then
        # First try wipefs that supports '--force' in order to also erase the partition table on a block device.
        # If that fails and regardless why it fails (i.e. play dumb), try a more conservative approach with 'wipefs --all'.
        # If that also fails and regardless why it fails (play dumb), let dd erase the first 512 bytes as generic fallback.
        # At https://github.com/rear/rear/wiki/Coding-Style see "Try to care about possible errors"
        # and "Maintain backward compatibility" and "Dirty hacks welcome".
        # Because the cleanup_command is added to the LAYOUT_CODE script (i.e. diskrestore.sh)
        # and the LAYOUT_CODE script is run with 'set -e' have a final 'true' in order to
        # not let "rear recover" abort only because cleanup of disk partitions failed:
        cleanup_command="wipefs --all --force $device || wipefs --all $device || dd if=/dev/zero of=$device bs=512 count=1 || true"
        cleanup_info_message="Using wipefs to cleanup '$device' before creating filesystem."
    else
        # As generic fallback use plain dd to erase dos partition tables
        # on systems that do not have wipefs which should at least avoid
        # issues like https://github.com/rear/rear/issues/1327 on all systems.
        # Because the cleanup_command is added to the LAYOUT_CODE script (i.e. diskrestore.sh)
        # and the LAYOUT_CODE script is run with 'set -e' have a final 'true' in order to
        # not let "rear recover" abort only because cleanup of disk partitions failed:
        cleanup_command="dd if=/dev/zero of=$device bs=512 count=1 || true"
        cleanup_info_message="Using dd to cleanup the first 512 bytes on '$device' before creating filesystem."
    fi

    # Tell what will be done:
    local create_filesystem_info_message="Creating filesystem of type '$fstype' with mount point '$mountpoint' on '$device'."
    Debug "$create_filesystem_info_message"
    echo "LogPrint '$create_filesystem_info_message'" >> "$LAYOUT_CODE"
    Debug "$cleanup_info_message"
    echo "# $cleanup_info_message" >> "$LAYOUT_CODE"

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
            # Cleanup disk partition:
            echo "$cleanup_command" >> "$LAYOUT_CODE"
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
                  echo "if ! mkfs -t ${fstype}${blocksize}${fragmentsize}${bytes_per_inode} -U $uuid -F $device >&2 ; then"
                  echo "    mkfs -t ${fstype}${blocksize}${fragmentsize}${bytes_per_inode} -F $device >&2"
                  echo "    $tunefs -U $uuid $device >&2"
                  echo "fi"
                ) >> "$LAYOUT_CODE"
            else
                echo "mkfs -t ${fstype}${blocksize}${fragmentsize}${bytes_per_inode} -F $device >&2" >> "$LAYOUT_CODE"
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
            Log "Begin generating code to create XFS on $device ..."
            # Cleanup disk partition:
            echo "$cleanup_command" >> "$LAYOUT_CODE"

            # Load xfs options from configuration files saved during
            # 'rear mkbackup/mkrescue' by xfs_info.
            # xfs info is called in 230_filesystem_layout.sh (layout/prepare)
            # xfs_opts will be used as additional parameter for mkfs.xfs and
            # ensures that xfs filesystem will be created exactly as original
            # unless the user has explicitly specified XFS filesystem options:
            local xfs_opts
            local xfs_device_basename="$( basename $device )"
            local xfs_info_filename="$LAYOUT_XFS_OPT_DIR/$xfs_device_basename.xfs"
            # Only uppercase letters and digits are used to ensure mkfs_xfs_options_variable_name is a valid bash variable name
            # even in case of complicated device nodes e.g. things like /dev/mapper/SIBM_2810XIV_78033E7012F-part3 
            # cf. current_orig_device_basename_alnum_uppercase in layout/prepare/default/300_map_disks.sh
            local xfs_device_basename_alnum_uppercase="$( echo $xfs_device_basename | tr -d -c '[:alnum:]' | tr '[:lower:]' '[:upper:]' )"
            # cf. predefined_input_variable_name in the function UserInput in lib/_input-output-functions.sh
            local mkfs_xfs_options_variable_name="MKFS_XFS_OPTIONS_$xfs_device_basename_alnum_uppercase"
            # Set which options to use for mkfs.xfs:
            if test "${!mkfs_xfs_options_variable_name:-}" ; then
                # When the user has specified device specific options for mkfs.xfs e.g. in MKFS_XFS_OPTIONS_SDA2 use that:
                if test -s $xfs_info_filename ; then
                    LogPrint "Overriding $xfs_device_basename mkfs.xfs options in $xfs_info_filename with those in $mkfs_xfs_options_variable_name"
                else
                    Log "Using $xfs_device_basename mkfs.xfs options in $mkfs_xfs_options_variable_name"
                fi
                xfs_opts="${!mkfs_xfs_options_variable_name:-}"
            else
                if test "$MKFS_XFS_OPTIONS" ; then
                    # When the user has specified global options for mkfs.xfs in MKFS_XFS_OPTIONS use that:
                    if test -s $xfs_info_filename ; then
                        LogPrint "Overriding $xfs_device_basename mkfs.xfs options in $xfs_info_filename with those in MKFS_XFS_OPTIONS"
                    else
                        Log "Using $xfs_device_basename mkfs.xfs options in MKFS_XFS_OPTIONS"
                    fi
                    xfs_opts="$MKFS_XFS_OPTIONS"
                else
                    # When the user has not specified any options for mkfs.xfs
                    # recreate the XFS filesystem on that particular device as it originally was
                    # cf. https://github.com/rear/rear/issues/1998#issuecomment-445149675
                    # The function xfs_parse in lib/filesystems-functions.sh falls back to mkfs.xfs defaults
                    # (i.e. xfs_parse outputs nothing) when there is no $xfs_info_filename file where the
                    # XFS filesystem options of that particular device on the original system were saved:
                    Log "Parsing $xfs_device_basename mkfs.xfs options from $xfs_info_filename"
                    xfs_opts="$( xfs_parse $xfs_info_filename )"
                fi
            fi
            # In case of fallback to mkfs.xfs defaults xfs_opts is empty:
            contains_visible_char "$xfs_opts" && Log "Using $xfs_device_basename mkfs.xfs options: $xfs_opts" || LogPrint "Using $xfs_device_basename mkfs.xfs defaults"
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
                echo "mkfs.xfs -f $xfs_opts $device >&2" >> "$LAYOUT_CODE"
            fi

            # Set the label:
            if [ -n "$label" ] ; then
                echo "xfs_admin -L $label $device >&2" >> "$LAYOUT_CODE"
            fi
            Log "End of generating code to create XFS on $device"
            ;;
        (reiserfs)
            # Cleanup disk partition:
            echo "$cleanup_command" >> "$LAYOUT_CODE"
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
            # Cleanup disk partition provided the disk partition is not already mounted:
            echo "mount | grep -q $device || $cleanup_command" >> "$LAYOUT_CODE"

            # Actually create the filesystem provided the disk partition is not already mounted.
            (   echo "# if $device is already mounted, skip"
                echo "# force overwriting existing btrfs when the disk was already used before"
                echo "if ! mount | grep -q $device >&2 ; then"
            ) >> "$LAYOUT_CODE"

            if [ -n "$uuid" ] ; then
                # Latest version of btrfs provides -U option to specify UUID druring the filesystem creation.
                # User -f [force] to force overwriting an existing btrfs on that disk partition
                # when the disk was already used before, see https://bugzilla.novell.com/show_bug.cgi?id=878870
                (   echo "  # Try to create btrfs with UUID"
                    echo "  if ! mkfs -t $fstype -U $uuid -f $device >&2 ; then"
                    # Problem with old btrfs version is that UUID cannot be set during mkfs! So, we must map it and
                    # change later the /etc/fstab, /boot/grub/menu.lst, etc.
                    echo "      mkfs -t $fstype -f $device >&2"
                    echo "      new_uuid=\$( btrfs filesystem show $device 2>/dev/null | grep -o 'uuid: .*' | cut -d ':' -f 2 | tr -d '[:space:]' )"
                    echo "      if [ $uuid != \$new_uuid ] ; then"
                    echo "          # The following grep command intentionally also"
                    echo "          # fails when there is not yet a FS_UUID_MAP file"
                    echo "          # and then the FS_UUID_MAP file will be created:"
                    echo "          if ! grep -q $uuid \"$FS_UUID_MAP\" ; then"
                    echo "              echo \"$uuid \$new_uuid $device\" >> $FS_UUID_MAP"
                    echo "          else"
                    echo "              # Required when we restart rear recover (via menu) - UUID changed again."
                    echo "              old_uuid=\$(grep ${uuid} $FS_UUID_MAP | tail -1 | awk '{print \$2}')"
                    echo "              SED_SCRIPT=\";/${uuid}/s/\${old_uuid}/\${new_uuid}/g\""
                    echo "              sed -i \"\$SED_SCRIPT\" \"$FS_UUID_MAP\""
                    echo "          fi"
                    echo "      fi # end of [ $uuid != $new_uuid ]"
                    echo "  fi"
                ) >> "$LAYOUT_CODE"
            else
                # UUID is not provided. Create FS without UUID
                # Latest version of btrfs provides -U option to specify UUID druring the filesystem creation.
                echo "  mkfs -t $fstype -f $device" >> "$LAYOUT_CODE"
            fi

            # Set the label:
            if [ -n "$label" ] ; then
                echo "  btrfs filesystem label $device $label >&2" >> "$LAYOUT_CODE"
            fi

            echo "fi" >> "$LAYOUT_CODE"
            ;;
        (vfat)
            # Cleanup disk partition:
            echo "$cleanup_command" >> "$LAYOUT_CODE"
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
            # Cleanup disk partition:
            echo "$cleanup_command" >> "$LAYOUT_CODE"
            # Actually create the filesystem:
            echo "mkfs -t $fstype $device >&2" >> "$LAYOUT_CODE"
            ;;
    esac

    # Call the mount_fs function with argument $1 (device):
    mount_fs ${1}

    Log "End create_fs( $@ )"
}
