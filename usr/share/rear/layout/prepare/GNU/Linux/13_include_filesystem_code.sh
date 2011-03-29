# Code to recreate filesystems.

create_fs() {
    read fs device mp fstype uuid label options < $1

    label=${label#label=}
    uuid=${uuid#uuid=}

    case $fstype in
        ext*)
            # File system parameters.
            blocksize=""
            reserved_blocks=""
            max_mounts=""
            check_interval=""
            
            for option in $options ; do
                name=${option%=*}
                value=${option#*=}
                
                case $name in
                    blocksize)
                        blocksize=" -b $value"
                        ;;
                    reserved_blocks)
                        reserved_blocks=" -r $value"
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
mkfs -t ${fstype}${blocksize}${fragmentsize} $device 1>&2
EOF
            if [ -n "$label" ] ; then
                echo "tune2fs -L $label $device 1>&2" >> $LAYOUT_CODE
            fi
            if [ -n "$uuid" ] ; then
                echo "tune2fs -U $uuid $device 1>&2" >> $LAYOUT_CODE
            fi
            
            tune2fsopts="${reserved_blocks}${max_mounts}${check_interval}"
            if [ -n "$tune2fsopts" ] ; then
                echo "tune2fs $tune2fsopts $device 1>&2" >> $LAYOUT_CODE
            fi
            ;;
        xfs)
cat >> $LAYOUT_CODE <<EOF
LogPrint "Creating $fstype-filesystem $mp on $device"
mkfs -t $fstype $device
EOF
            if [ -n "$label" ] ; then
                echo "xfs_admin -L $label $device 1>&2" >> $LAYOUT_CODE
            fi
            if [ -n "$uuid" ] ; then
                echo "xfs_admin -U $uuid $device 1>&2" >> $LAYOUT_CODE
            fi
            ;;
        reiserfs)
cat >> $LAYOUT_CODE <<EOF
LogPrint "Creating $fstype-filesystem $mp on $device"
mkfs -t $fstype -q $device
EOF
            if [ -n "$label" ] ; then
                echo "reiserfstune --label $label $device 1>&2" >> $LAYOUT_CODE
            fi
            if [ -n "$uuid" ] ; then
                echo "reiserfstune -uuid $uuid $device 1>&2" >> $LAYOUT_CODE
            fi
            ;;
        *)
cat >> $LAYOUT_CODE <<EOF
LogPrint "Creating filesystem ($fstype) $mp on $device"
mkfs -t $fstype $device 1>&2
EOF
            ;;
    esac

cat >> $LAYOUT_CODE <<EOF
LogPrint "Mounting filesystem $mp"
mkdir -p /mnt/local$mp
mount $device /mnt/local$mp
EOF
}
