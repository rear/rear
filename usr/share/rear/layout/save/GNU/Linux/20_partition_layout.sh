# Save the partition layout

LogPrint "Saving disk partitions."

(
    # Disk sizes
    # format: disk <disk> <sectors>
    devices=()
    for disk in /sys/block/* ; do
        case $(basename $disk) in
            hd*|sd*|cciss*)
                if [ "$(cat $disk/removable)" = "1" ] ; then
                    continue
                fi
                
                # fix cciss
                devname=$(basename $disk | tr '!' '/')
                devsize=$(cat $disk/size)
                echo "disk $devname $devsize"
                
                devices=( "${devices[@]}" "$devname" )
                ;;
        esac
    done

    # Partitions
    # format : part <partition size(sectors)> <partition id> 
    for device in "${devices[@]}" ; do
        if [ -e /dev/$device ] ; then
            while read line ; do
                if [ -z "$(echo $line | grep start)" ] ; then
                    continue
                fi
                
                psize=$(echo $line | cut -d "," -f 2 | cut -d "=" -f 2 | tr -d " ")
                pid=$(echo $line | cut -d "," -f 3 | cut -d "=" -f 2 | tr -d " ")
                
                echo "part $device $psize $pid"
            done < <(sfdisk -uS -d /dev/$device)
        fi
    done

) >> $DISKLAYOUT_FILE
