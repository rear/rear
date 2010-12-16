# Save Filesystem layout

LogPrint "Saving Filesystem layout."

(
    # Filesystems
    # format: fs <device> <mountpoint> <filesystem> [uuid=<uuid>] [label=<label>]
    while read line ; do
        if [ "${line#/}" = "$line" ] ; then
            continue
        fi
        
        device=$(echo $line | cut -d " " -f 1)
        mountpoint=$(echo $line | cut -d " " -f 3)
        fstype=$(echo $line | cut -d " " -f 5)
        
        echo -n "fs $device $mountpoint $fstype "
        case "$fstype" in 
            ext*)
                uuid=$(tune2fs -l $device | grep UUID | cut -d ":" -f 2 | tr -d " ")
                label=$(e2label $device)
                echo -n "uuid=$uuid label=$label "
                ;;
            xfs)
                uuid=$(xfs_admin -u $device | cut -d'=' -f 2 | tr -d " ")
                label=$(xfs_admin -l $device | cut -d'"' -f 2)
                echo -n "uuid=$uuid label=$label "
                ;;
        esac
        
        # TODO: filesystem attributes
        
        echo
    done < <(mount)
) >> $DISKLAYOUT_FILE
