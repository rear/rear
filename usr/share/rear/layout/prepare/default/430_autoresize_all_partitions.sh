#
# layout/prepare/default/430_autoresize_all_partitions.sh
#
# Try to automatically resize all active partitions on all active disks
# (except boot and swap partitions via some special hardcoded rules)
# if the disk size had changed (i.e. only in migration mode).
# This does not resize volumes on top of the affected partitions.
#
# When AUTORESIZE_PARTITIONS is false, no partition is resized.
#
# When AUTORESIZE_PARTITIONS is neither true nor false (the default behaviour)
# only the last active partition on each active disk gets resized
# by the separated 420_autoresize_last_partitions.sh script.
#
# To automatically resize all active partitions on all active disks
# AUTORESIZE_PARTITIONS must be explicity set to true.
#
# A true or false value must be the first one in the AUTORESIZE_PARTITIONS array.

# Skip if not in migration mode:
is_true "$MIGRATION_MODE" || return 0

# Skip if resizing all partitions is not explicity wanted:
is_true "$AUTORESIZE_PARTITIONS" || return 0

cp "$LAYOUT_FILE" "$LAYOUT_FILE.tmp"
save_original_file "$LAYOUT_FILE"

while read type device size junk ; do
    sysfsname=$(get_sysfs_name $device)

    if [[ -d "/sys/block/$sysfsname" ]] ; then
        newsize=$(get_disk_size "$sysfsname")

        if (( "$newsize" == "$size" )) ; then
            continue
        fi

        oldsize="$size"
        difference=$( mathlib_calculate "$newsize - $oldsize" ) # can be negative!
        Log "Total resize of ${difference}B"

        Log "Searching for resizeable partitions on disk $device (${newsize}B)"

        # Find partitions that could be resized.
        partitions=()
        resizeable_space=0
        available_space="$newsize"
        while read type part size start name flags name junk; do
            if [ -n "$(grep "^fs $name /boot\|^swap $name " "$LAYOUT_FILE")" ]; then
                    available_space=$( mathlib_calculate "$available_space - ${size%B}" )
                    Log "Will not resize partition $name."
            else
                    partitions=( "${partitions[@]}" "$name|${size%B}" )
                    resizeable_space=$( mathlib_calculate "$resizeable_space + ${size%B}" )

                    Log "Will resize partition $name."
            fi
        done < <(grep "^part $device" "$LAYOUT_FILE" )

        if (( ${#partitions[@]} == 0 )) ; then
            Log "No resizeable partitions found."
            continue
        fi

        if (( available_space < 0 )) ; then
            LogPrint "No space to automatically resize partitions on disk $device."
            LogPrint "Please do this manually."
            continue
        fi

        # evenly distribute the size changes
        ### example:
        ### resize     to      3145728000
        ###          from    160041885696
        ### partitions:
        ###  1 :                 209682432 (boot -> skipped)
        ###  2 :              128639303680
        ###  3 :               30040653824
        ###
        ### space used by resizeable partitions
        ###  128639303680 + 30040653824 = 158679957504
        ### available for resize on disk
        ###   3145728000 - 209682432 = 2936045568
        ### divide available space evenly
        ### 2' : 128639303680 * 2936045568 / 158679957504 = 2380205183
        ### 3' :  30040653824 * 2936045568 / 158679957504 =  555840384
        ###                                                 2936045567
        for data in "${partitions[@]}" ; do
            name=${data%|*}
            partition_size=${data#*|}

            new_size=$( mathlib_calculate "( $partition_size / $resizeable_space ) * $available_space" )

            (( new_size > 0 ))
            BugIfError "Partition $name resized to a negative number."

            nr=$(echo "$name" | sed -r 's/.+([0-9])$/\1/')
            sed -r -i "s|^(part $device) ${partition_size}(.+)$nr$|\1 ${new_size}\2$nr|" $LAYOUT_FILE.tmp
            Log "Resized partition $name from ${partition_size}B to ${new_size}B."
        done
    fi
done < <(grep "^disk " "$LAYOUT_FILE")

mv "$LAYOUT_FILE.tmp" "$LAYOUT_FILE"
