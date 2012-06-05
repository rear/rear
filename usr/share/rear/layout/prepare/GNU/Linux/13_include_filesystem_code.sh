# Code to recreate filesystems.

create_fs() {
    local fs device mp fstype uuid label options
    read fs device mp fstype uuid label options < <(grep "^fs.* ${1#fs:} " $LAYOUT_FILE)

    label=${label#label=}
    uuid=${uuid#uuid=}

    case $fstype in
        ext*)
            # File system parameters.
            local blocksize="" reserved_blocks="" max_mounts="" check_interval=""

            local option name value
            for option in $options ; do
                name=${option%=*}
                value=${option#*=}

                case $name in
                    blocksize)
                        blocksize=" -b $value"
                        ;;
                    bytes_per_inode)
                        bytes_per_inode=" -i $value"
                        ;;
                    reserved_blocks)
                        ### reserved_blocks can be a number or a percentage
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
                esac
            done
cat >> $LAYOUT_CODE <<EOF
LogPrint "Creating $fstype-filesystem $mp on $device"
mkfs -t ${fstype}${blocksize}${fragmentsize}${bytes_per_inode} $device >&2
EOF

            local tunefs="tune2fs"
            # on RHEL 5, tune2fs does not work on ext4
            if [ "$fstype" = "ext4" ] && has_binary tune4fs; then
                tunefs="tune4fs"
            fi

            if [ -n "$label" ] ; then
                echo "$tunefs -L $label $device >&2" >> $LAYOUT_CODE
            fi
            if [ -n "$uuid" ] ; then
                echo "$tunefs -U $uuid $device >&2" >> $LAYOUT_CODE
            fi

            tune2fsopts="${reserved_blocks}${max_mounts}${check_interval}"
            if [ -n "$tune2fsopts" ] ; then
                echo "$tunefs $tune2fsopts $device >&2" >> $LAYOUT_CODE
            fi
            ;;
        xfs)
cat >> $LAYOUT_CODE <<EOF
LogPrint "Creating $fstype-filesystem $mp on $device"
mkfs -t $fstype $device
EOF
            if [ -n "$label" ] ; then
                echo "xfs_admin -L $label $device >&2" >> $LAYOUT_CODE
            fi
            if [ -n "$uuid" ] ; then
                echo "xfs_admin -U $uuid $device >&2" >> $LAYOUT_CODE
            fi
            ;;
        reiserfs)
cat >> $LAYOUT_CODE <<EOF
LogPrint "Creating $fstype-filesystem $mp on $device"
mkfs -t $fstype -q $device
EOF
            if [ -n "$label" ] ; then
                echo "reiserfstune --label $label $device >&2" >> $LAYOUT_CODE
            fi
            if [ -n "$uuid" ] ; then
                echo "reiserfstune --uuid $uuid $device >&2" >> $LAYOUT_CODE
            fi
            ;;
        btrfs)
cat >> $LAYOUT_CODE <<EOF
LogPrint "Creating $fstype-filesystem $mp on $device"
mkfs -t $fstype $device
EOF
            if [ -n "$label" ] ; then
                echo "btrfs filesystem label $device $label >&2" >> $LAYOUT_CODE
            fi
            if [ -n "$uuid" ] ; then
                # Problem with btrfs is that uuid cannot be set during mkfs! So, we must map it and
                # change later the /etc/fstab, /boot/grub/menu.lst, etc
                cat >> $LAYOUT_CODE <<EOF
                new_uuid=\$(btrfs filesystem show $device | grep -i uuid | cut -d: -f3 | sed -e 's/^ //')
                if [ "$uuid" != "\$new_uuid" ] ; then
                    echo "$uuid \$new_uuid $device" >> $FS_UUID_MAP
                fi
EOF
            fi
            ;;
        vfat)
cat >> $LAYOUT_CODE <<EOF
LogPrint "Creating $fstype-filesystem $mp on $device"
mkfs.vfat $device
EOF
            if [ -n "$label" ] ; then
                echo "dosfslabel $device $label >&2" >> $LAYOUT_CODE
            fi
            ;;
        *)
cat >> $LAYOUT_CODE <<EOF
LogPrint "Creating filesystem ($fstype) $mp on $device"
mkfs -t $fstype $device >&2
EOF
            ;;
    esac

    # Extract mount options
    local option mountopts
    for option in $options ; do
        name=${option%=*}
        value=${option#*=}

        case $name in
            options)
                mountopts=$value
                ;;
        esac
    done

    if [ -n "$mountopts" ] ; then
        mountopts=" -o $mountopts"
    fi

cat >> $LAYOUT_CODE <<EOF
LogPrint "Mounting filesystem $mp"
mkdir -p /mnt/local$mp
mount$mountopts $device /mnt/local$mp
EOF
}
