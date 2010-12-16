# Save the Software RAID layout

if [ -e /proc/mdstat ] &&  grep -q blocks /proc/mdstat ; then
    LogPrint "Saving Software RAID configuration."
    (
        while read array device level ndevices metadata uuid junk ; do
            if [ "$array" != "ARRAY" ] ; then
                continue
            fi
        
            device=$(basename $device)
            ndevices=$(echo "$ndevices" | cut -d "=" -f 2)
            uuid=$(echo "$uuid" | cut -d "=" -f 2)
        
            read jname junk jstate level devices < <(grep $device /proc/mdstat)
            devices=$(echo "$devices" | sed 's/\[[[:digit:]]\]//g')
        
            echo "raid $device $level $ndevices $uuid $devices"
        done < <(mdadm --detail --scan --config=partitions)
    ) >> $DISKLAYOUT_FILE
fi
