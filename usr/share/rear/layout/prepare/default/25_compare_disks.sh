# Compare disks from the original system to this system

LogPrint "Comparing disks."

MIGRATION_MODE=${MIGRATION_MODE-""}

while read disk dev size junk ; do
    if [ "${dev#cciss}" != "$dev" ] ; then
        dev=${dev/\//!}
    fi
    
    Log "Looking for $dev..."
    
    if [ -e "/sys/block/$dev" ] ; then
        Log "Device $dev exists."
        newsize=$(cat /sys/block/$dev/size)
        
        if [ "$newsize" -eq "$size" ] ; then
            Log "Size of device $dev matches."
        else
            LogPrint "Device $dev has size $newsize, $size expected"
            MIGRATION_MODE="true"
        fi
    fi
done < <(grep "^disk" $LAYOUT_FILE)

if [ -n "$MIGRATION_MODE" ] ; then
    LogPrint "Switching to manual disk layout configuration."
else
    LogPrint "Disk configuration is identical, proceeding with restore."
fi
