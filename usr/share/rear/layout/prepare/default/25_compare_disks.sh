# Compare disks from the original system to this system

LogPrint "Comparing disks."

MIGRATION_MODE=${MIGRATION_MODE-""}

while read disk dev size junk serialnumber location  ; do
    dev=$( get_sysfs_name $dev )

    Log "Looking for $dev..."

    if [ -e "/sys/block/$dev" ] ; then
        Log "Device $dev exists."
        newsize=$(get_disk_size $dev)

        if [ "$newsize" -eq "$size" ] ; then
            Log "Size of device $dev matches."
        else
            LogPrint "Device $dev has size $newsize, $size expected"
            MIGRATION_MODE="true"
        fi

        if which smartctl >/dev/null 2>&1 ; then
            diskserialnumber=$(LANG=C smartctl -a /dev/$dev | grep -i "Serial Number" | cut -d ':' -f 2 | tr -d ' ' 2>/dev/null)
            if [[ $diskserialnumber = "" ]] ; then
                diskserialnumber="0"
            fi
            if [[ "$diskserialnumber" = "$serialnumber" ]] ; then
                Log "Serial number of device $dev matches."
            else
                LogPrint "Device $dev has serialnumber <$diskserialnumber>, <$serialnumber> expected"
                MIGRATION_MODE="true"
            fi
        fi
        # Only reliable if it's a internal disk
        if which lsscsi >/dev/null 2>&1 ; then
            disklocation="0"
            lsscsi -t | grep disk  | grep $dev | grep -q " fc:"
            if [ ! $? -eq 0 ] ; then
                disklocation=$(lsscsi -t | grep disk  | grep $dev | cut -d " " -f 1 2>/dev/null)
            fi
            if [[ "$disklocation" = "$location" ]] ; then
                Log "Location of device $dev matches."
            else
                LogPrint "Device $dev has not the same internal location."
                MIGRATION_MODE="true"
            fi
        fi
    else
        LogPrint "Device $dev does not exist."
        MIGRATION_MODE="true"
    fi
done < <(grep "^disk" $LAYOUT_FILE)

if [ -n "$MIGRATION_MODE" ] ; then
    LogPrint "Switching to manual disk layout configuration."
else
    LogPrint "Disk configuration is identical, proceeding with restore."
fi
