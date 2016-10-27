# Save the Software RAID layout

if [ -e /proc/mdstat ] &&  grep -q blocks /proc/mdstat ; then
    Log "Saving Software RAID configuration."
    (
        while read array device junk ; do
            if [ "$array" != "ARRAY" ] ; then
                continue
            fi

            ### Get the actual device node
            if [[ -h $device ]] ; then
                name=${device##*/}
                device=$(readlink -f $device)
            fi

            # We use the detailed mdadm output quite alot
            mdadm --misc --detail $device > $TMP_DIR/mdraid

            # Gather information
            metadata=$( grep "Version" $TMP_DIR/mdraid | tr -d " " | cut -d ":" -f "2")
            level=$( grep "Raid Level" $TMP_DIR/mdraid | tr -d " " | cut -d ":" -f "2")
            uuid=$( grep "UUID" $TMP_DIR/mdraid | tr -d " " | cut -d "(" -f "1" | cut -d ":" -f "2-")
            layout=$( grep "Layout" $TMP_DIR/mdraid | tr -d " " | cut -d ":" -f "2")
            chunksize=$( grep "Chunk Size" $TMP_DIR/mdraid | tr -d " " | cut -d ":" -f "2" | sed -r 's/^([0-9]+).+/\1/')

            # fix up layout for RAID10:
            # > near=2,far=1 -> n2
            if [ "$level" = "raid10" ] ; then
                OIFS=$IFS
                IFS=","
                for param in "$layout" ; do
                    copies=${layout%=*}
                    number=${layout#*=}
                    if [ "$number" -gt 1 ] ; then
                        layout="${copies:0:1}$number"
                    fi
                done
                IFS=$OIFS
            fi

            ndevices=$( grep "Raid Devices" $TMP_DIR/mdraid | tr -d " " | cut -d ":" -f "2")
            totaldevices=$( grep "Total Devices" $TMP_DIR/mdraid | tr -d " " | cut -d ":" -f "2")
            let sparedevices=$totaldevices-$ndevices

            # Find all devices
            # use the output of mdadm, but skip the array itself
            # sysfs has the information in RHEL 5+, but RHEL 4 lacks it.
            devices=""
            for disk in $( grep -o -E "/dev/[^m].*$" $TMP_DIR/mdraid | tr "\n" " ") ; do
                disk=$( get_device_name $disk )
                if [ -z "$devices" ] ; then
                    devices=" devices=$disk"
                else
                    devices="$devices,$disk"
                fi
            done

            # prepare for output
            metadata=" metadata=$metadata"
            level=" level=$level"
            ndevices=" raid-devices=$ndevices"
            uuid=" uuid=$uuid"

            if [ "$sparedevices" -gt 0 ] ; then
                sparedevices=" spare-devices=$sparedevices"
            else
                sparedevices=""
            fi

            if [ -n "$layout" ] ; then
                layout=" layout=$layout"
            else
                layout=""
            fi

            if [ -n "$chunksize" ] ; then
                chunksize=" chunk=$chunksize"
            else
                chunksize=""
            fi

            if [[ "$name" ]] ; then
                name=" name=$name"
            else
                name=""
            fi

            echo "raid ${device}${metadata}${level}${ndevices}${uuid}${name}${sparedevices}${layout}${chunksize}${devices}"

            extract_partitions "$device"
        done < <(mdadm --detail --scan --config=partitions)
    ) >> $DISKLAYOUT_FILE
fi
