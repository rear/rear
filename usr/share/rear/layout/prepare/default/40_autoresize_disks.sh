# Try to automatically resize disks

if [ -z "$MIGRATION_MODE" ] ; then
    return 0
fi

# If a disk has one or multiple raid or lvm partitions, these could be resized
# to accomodate larger/smaller disks.
# This does not resize volumes on top of the affected partitions.

cp $LAYOUT_FILE $LAYOUT_FILE.tmp
backup_file $LAYOUT_FILE

while read type device size junk ; do
    sysfsname=$(get_sysfs_name $device)

    if [ -d /sys/block/$sysfsname ] ; then
        newsize=$(get_disk_size $sysfsname)

        if [ "$newsize" -eq "$size" ] ; then
            continue
        fi

        let oldsize=$size

        let difference=$newsize-$oldsize # can be negative!
        Log "Total resize of ${difference}B"

        Log "Searching for resizeable partitions on disk $device ($newsize)B"

        # Find partitions that could be resized
        partitions=()
        resizeable_size=0
        while read type part size start name flags name junk; do
            if [ "${flags/lvm/j}" != "${flags}" ] || [ "${flags/raid/j}" != "$flags" ] ; then
                partitions=( "${partitions[@]}" "$name|${size%B}" )
                let resizeable_size=$resizeable_size+${size%B}
                Log "Will resize partition $name."
            fi
        done < <(grep "^part $device" $LAYOUT_FILE)

        if [ ${#partitions[@]} -eq 0 ] ; then
            Log "No resizeable partitions found."
            continue
        fi

        if [ $resizeable_size -eq 0 ] || [ $resizeable_size -lt $difference ] ; then
            LogPrint "No space to automatically resize partitions on disk $device."
            continue
        fi

        # evenly distribute the size changes
        for data in "${partitions[@]}" ; do
            name=${data%|*}
            current_size=${data#*|}

            delta=$(echo "$current_size $resizeable_size $difference" | awk '{ printf "%d", ($1/$2)*$3; }')
            let new_size=current_size+delta

            nr=$(echo "$name" | sed -r 's/.+([0-9])$/\1/')
            sed -r -i "s|^(part $device) ${current_size}(.+)$nr$|\1 ${new_size}\2$nr|" $LAYOUT_FILE.tmp
            Log "Resized partition $name from ${current_size}B to ${new_size}B."
        done
    fi
done < <(grep "^disk " $LAYOUT_FILE)

mv $LAYOUT_FILE.tmp $LAYOUT_FILE
