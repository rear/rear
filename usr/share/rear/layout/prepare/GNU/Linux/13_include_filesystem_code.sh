# Code to recreate filesystems.

create_fs() {
    local fs device mp fstype uuid label options
    ## mp: mount point
    read fs device mp fstype uuid label options < <(grep "^fs.* ${1#fs:} " "$LAYOUT_FILE")

    label=${label#label=}
    uuid=${uuid#uuid=}


    case "$fstype" in
        ext*)
            # File system parameters.
            local blocksize="" reserved_blocks="" max_mounts="" check_interval="" default_mount_options=""

            local option name value
            for option in $options ; do
                name=${option%=*}
                value=${option#*=}
                case "$name" in
                    blocksize)
                        blocksize=" -b $value"
                        ;;
                    bytes_per_inode)
                        bytes_per_inode=" -i $value"
                        ;;
                    reserved_blocks)
                        ### reserved_blocks can be a number or a percentage.
                        if [[ ${value%\%} == ${value} ]] ; then
                            reserved_blocks=" -r $value"
                        else
                            reserved_blocks=" -m ${value%\%}"
                        fi
                        ;;
                    max_mounts)
                        max_mounts=" -c $value"
                        ;;
                    check_interval)
                        check_interval=" -i $value"
                        ;;
                    default_mount_options)
                        default_mount_options=" -o $value"
                        ;;
                esac
            done
cat >> "$LAYOUT_CODE" <<EOF
LogPrint "Creating $fstype-filesystem $mp on $device"
mkfs -t ${fstype}${blocksize}${fragmentsize}${bytes_per_inode} $device >&2
EOF

            local tunefs="tune2fs"
            # On RHEL 5, tune2fs does not work on ext4.
            if [ "$fstype" = "ext4" ] && has_binary tune4fs; then
                tunefs="tune4fs"
            fi

            if [ -n "$label" ] ; then
                echo "$tunefs -L $label $device >&2" >> "$LAYOUT_CODE"
            fi
            if [ -n "$uuid" ] ; then
                echo "$tunefs -U $uuid $device >&2" >> "$LAYOUT_CODE"
            fi

            tune2fsopts="${reserved_blocks}${max_mounts}${check_interval}${default_mount_options}"
            if [ -n "$tune2fsopts" ] ; then
                echo "$tunefs $tune2fsopts $device >&2" >> "$LAYOUT_CODE"
            fi
            ;;
        xfs)
cat >> "$LAYOUT_CODE" <<EOF
LogPrint "Creating $fstype-filesystem $mp on $device"
mkfs.xfs -f $device
EOF
            if [ -n "$label" ] ; then
                echo "xfs_admin -L $label $device >&2" >> "$LAYOUT_CODE"
            fi
            if [ -n "$uuid" ] ; then
                echo "xfs_admin -U $uuid $device >&2" >> "$LAYOUT_CODE"
            fi
            ;;
        reiserfs)
cat >> "$LAYOUT_CODE" <<EOF
LogPrint "Creating $fstype-filesystem $mp on $device"
mkfs -t $fstype -q $device
EOF
            if [ -n "$label" ] ; then
                echo "reiserfstune --label $label $device >&2" >> "$LAYOUT_CODE"
            fi
            if [ -n "$uuid" ] ; then
                echo "reiserfstune --uuid $uuid $device >&2" >> "$LAYOUT_CODE"
            fi
            ;;
        btrfs)
cat >> "$LAYOUT_CODE" <<EOF
LogPrint "Creating $fstype-filesystem $mp on $device"
# if $device is already mounted, skip
# see https://bugzilla.novell.com/show_bug.cgi?id=878870 (adding -f [force] option to mkfs for btrfs)
mount | grep -q $device || mkfs -t $fstype -f $device
EOF
            if [ -n "$label" ] ; then
                echo "mount | grep -q $device || btrfs filesystem label $device $label >&2" >> "$LAYOUT_CODE"
            fi
            if [ -n "$uuid" ] ; then
                # Problem with btrfs is that UUID cannot be set during mkfs! So, we must map it and
                # change later the /etc/fstab, /boot/grub/menu.lst, etc.
                cat >> "$LAYOUT_CODE" <<-EOF
                new_uuid=\$(btrfs filesystem show $device 2>/dev/null | grep -i uuid: | cut -d: -f3 | sed -e 's/^ //')
                if [ "$uuid" != "\$new_uuid" ] ; then
                    if [ ! -f "$FS_UUID_MAP" ]; then
                        echo "$uuid \$new_uuid $device" > "$FS_UUID_MAP"
                    else
                        grep -q "${uuid}" "$FS_UUID_MAP"
                        if [[ \$? -eq 0 ]]; then
                            # Required when we restart rear recover (via menu) - UUID changed again.
                            old_uuid=\$(grep ${uuid} $FS_UUID_MAP | tail -1 | awk '{print \$2}')
                            SED_SCRIPT=";/${uuid}/s/\${old_uuid}/\${new_uuid}/g"
                            sed -i "\$SED_SCRIPT" "$FS_UUID_MAP"
                        else
                            echo "$uuid \$new_uuid $device" >> $FS_UUID_MAP
                        fi
                    fi
                fi # end of [ "$uuid" != "\$new_uuid" ]
EOF
            fi
            ;;
        vfat)
cat >> "$LAYOUT_CODE" <<EOF
LogPrint "Creating $fstype-filesystem $mp on $device"
mkfs.vfat $device
EOF
            if [ -n "$label" ] ; then
                echo "dosfslabel $device $label >&2" >> "$LAYOUT_CODE"
            fi
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
        *)
cat >> "$LAYOUT_CODE" <<EOF
LogPrint "Creating filesystem ($fstype) $mp on $device"
mkfs -t $fstype $device >&2
EOF
            ;;
    esac

    # Extract mount options.
    local option mountopts
    for option in $options ; do
        name=${option%%=*}     # options can contain more '=' signs
        value=${option#*=}

        case $name in
            options)
                ### Do not mount nodev, as chrooting later on would fail.
                mountopts=${value//nodev/dev}
                ;;
        esac
    done

    if [ -n "$mountopts" ] ; then
        mountopts=" -o $mountopts"
    fi

    echo "LogPrint \"Mounting filesystem $mp\"" >> "$LAYOUT_CODE"

    case $fstype in
        btrfs)
            # check the $value for subvols (other then root)
            subvol=$(echo $value |  awk -F, '/subvol=/  { print $NF}') # empty or something like 'subvol=root'
            if [ -z "$subvol" ]; then
                echo "mkdir -p /mnt/local$mp" >> "$LAYOUT_CODE"
                echo "mount$mountopts $device /mnt/local$mp" >> "$LAYOUT_CODE"
            elif [ "$subvol" = "subvol=root" ]; then
                (
		echo "# btrfs subvolume 'root' is a special case"
		echo "# before we can create subvolumes we must mount a btrfs device on /mnt"
		echo "mount | grep btrfs | grep -q '/mnt' || mount $device /mnt"
		echo "# create the root btrfs subvolume"
		echo "btrfs subvolume create /mnt/root"
                echo "mkdir -p /mnt/local$mp"
                echo "# umount subvol 0 as it will be remounted as /mnt/local"
                echo "umount /mnt"
                echo "mount$mountopts $device /mnt/local$mp"
                ) >> "$LAYOUT_CODE"
            else
                (
		echo "# btrfs subvolume creates sub-directory itself"
                echo "btrfs subvolume create /mnt/local$mp"
                # just mounting it with subvol=xxx will probably fail with an cryptic error:
                # mount: mount(2) failed: No such file or directory
                # we need to mount it with its subvol-id - not a joke
                # even its not yet mounted we can view it - see http://www.funtoo.org/BTRFS_Fun
                echo "btrfs_id=\$(btrfs subvolume list /mnt/local$mp | tail -1 | awk '{print \$2}')"
                echo "mountopts=\" -o subvolid=\${btrfs_id}\""
                echo "mount\$mountopts $device /mnt/local$mp"
                ) >> "$LAYOUT_CODE"
            fi
            ;;
        *)
            (
            echo "mkdir -p /mnt/local$mp"
            echo "mount$mountopts $device /mnt/local$mp"
            ) >> "$LAYOUT_CODE"
            ;;
    esac

}
