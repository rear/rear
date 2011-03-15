# Try to automatically resize disks

if [ -z "$MIGRATION_MODE" ] ; then
    return 0
fi

# If a disk has one or multiple raid or lvm partitions, these could be resized
# to accomodate larger/smaller disks.
# This does not resize volumes on top of the affected partitions.

cp $LAYOUT_FILE $LAYOUT_FILE.tmp
backup_file $LAYOUT_FILE

while read type disk size junk ; do
    device="/dev/$disk"
    sysfsname=${disk/\//\!}
    
    if [ -d /sys/block/$sysfsname ] ; then
        newsize=$(cat /sys/block/$sysfsname/size) # sectors
        
        if [ "$newsize" -eq "$size" ] ; then
            continue
        fi
        
        # Get the sector size
        if [ -e /sys/block/$sysfsname/queue/logical_block_size ] ; then
            sectorsize=$(cat /sys/block/$sysfsname/queue/logical_block_size)
        else
            sectorsize=512
        fi
        
        let newsize=$newsize\*$sectorsize
        let oldsize=$size\*512 # FIXME: should have old size in bytes instead...
        
        Log "Searching for resizeable partitions on disk $device ($newsize)B"
        
        # Find partitions that could be resized
        partitions=()
        while read type part size name flags name junk; do
            if [ "${flags/lvm/j}" != "${flags}" ] || [ "${flags/raid/j}" != "$flags" ] ; then
                partitions=( "${partitions[@]}" "$name|${size%B}" )
                Log "Will resize partition $name."
            fi
        done < <(grep "^part $disk" $LAYOUT_FILE)
        
        if [ ${#partitions[@]} -eq 0 ] ; then
            Log "No resizeable partitions found."
            continue
        fi
        
        # evenly distribute the size changes
        let difference=$newsize-$oldsize
        let delta=$difference/${#partitions[@]} # can be negative!
        Log "Total resize of ${difference}B (${delta}x${#partitions[@]})"
        
        for data in "${partitions[@]}" ; do
            name=${data%|*}
            current_size=${data#*|}
            
            nr=$(echo "$name" | sed -r 's/.+([0-9])$/\1/')
            
            let new_size=$current_size+$delta
            sed -r -i "s/^(part $disk) ${current_size}B(.+)$nr$/\1 ${new_size}B\2$nr/" $LAYOUT_FILE.tmp
            Log "Resized partition $name from ${current_size}B to ${new_size}B."
        done
    fi
done < <(grep "^disk " $LAYOUT_FILE)

mv $LAYOUT_FILE.tmp $LAYOUT_FILE
