# Save Filesystem layout

LogPrint "Saving Filesystem layout."

(
    # Filesystems
    # format: fs <device> <mountpoint> <filesystem> [uuid=<uuid>] [label=<label>] [<attributes>]
    while read line ; do
        if [ "${line#/}" = "$line" ] ; then
            continue
        fi
        
        device=$(echo $line | cut -d " " -f 1)
        mountpoint=$(echo $line | cut -d " " -f 3)
        fstype=$(echo $line | cut -d " " -f 5)
        
        if [ ! -b "$device" ] ; then
            Log "$device is not a block device, skipping."
            continue
        fi
        
        echo -n "fs $device $mountpoint $fstype "
        case "$fstype" in 
            ext*)
                uuid=$(tune2fs -l $device | grep UUID | cut -d ":" -f 2 | tr -d " ")
                label=$(e2label $device)
                
                # options: blocks, fragments, max_mount, check_interval, reserved blocks
                blocksize=$(tune2fs -l $device | grep "Block size" | tr -d " " | cut -d ":" -f "2")
                max_mounts=$(tune2fs -l $device | grep "Maximum mount count" | tr -d " " | cut -d ":" -f "2")
                check_interval=$(tune2fs -l $device | grep "Check interval" | cut -d "(" -f 1 | tr -d " " | cut -d ":" -f "2")
                reserved_blocks=$(tune2fs -l $device | grep "Reserved block count" | tr -d " " | cut -d ":" -f "2")
                
                # translate check_interval from seconds to days
                let check_interval=$check_interval/86400
                
                echo -n "uuid=$uuid label=$label"
                echo -n " blocksize=$blocksize reserved_blocks=$reserved_blocks"
                echo -n " max_mounts=$max_mounts check_interval=${check_interval}d"
                ;;
            xfs)
                uuid=$(xfs_admin -u $device | cut -d'=' -f 2 | tr -d " ")
                label=$(xfs_admin -l $device | cut -d'"' -f 2)
                echo -n "uuid=$uuid label=$label "
                ;;
            reiserfs)
                uuid=$(reiserfstune $device | grep "UUID" | cut -d":" -f "2" | tr -d " ")
                label=$(reiserfstune $device | grep "LABEL" | cut -d":" -f "2" | tr -d " ")
                echo -n "uuid=$uuid label=$label"
                ;;
        esac
        
        echo
    done < <(mount)
) >> $DISKLAYOUT_FILE
