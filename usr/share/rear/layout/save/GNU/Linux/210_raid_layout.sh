# Save the Software RAID layout

if [ -e /proc/mdstat ] &&  grep -q blocks /proc/mdstat ; then
    Log "Saving Software RAID configuration."
    (
        ( echo "List of Software Raid devices (mdadm --detail --scan --config=partitions):"; mdadm --detail --scan --config=partitions; echo ) | sed -e 's/^/# /'
        while read array device junk ; do
            if [ "$array" != "ARRAY" ] ; then
                continue
            fi

            ### Get the actual device node
            if [[ -h $device ]] ; then
                name=${device##*/}
                device=$(readlink -f $device)
            fi

            # We use the detailed mdadm output quite a lot
            tmpfile="$TMP_DIR/mdraid.$name"
            mdadm --misc --detail $device > $tmpfile
            ( echo "mdadm --misc --detail $device" ; cat $tmpfile ) | sed -e 's/^/# /'

            # Gather information
            metadata=$( grep "Version" $tmpfile | tr -d " " | cut -d ":" -f "2")
            level=$( grep "Raid Level" $tmpfile | tr -d " " | cut -d ":" -f "2")
            uuid=$( grep "UUID" $tmpfile | tr -d " " | cut -d "(" -f "1" | cut -d ":" -f "2-")
            layout=$( grep "Layout" $tmpfile | tr -d " " | cut -d ":" -f "2")
            chunksize=$( grep "Chunk Size" $tmpfile | tr -d " " | cut -d ":" -f "2" | sed -r 's/^([0-9]+).+/\1/')
            container=$( grep "Container" $tmpfile | tr -d " " | cut -d ":" -f "2" | cut -d "," -f "1")

            array_size=$( grep "Array Size" $tmpfile | tr -d " " | cut -d ":" -f "2" | cut -d "(" -f "1")
            used_dev_size=$( grep "Used Dev Size" $tmpfile | tr -d " " | cut -d ":" -f "2" | cut -d "(" -f "1")

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

            totaldevices=$( grep "Total Devices" $tmpfile | tr -d " " | cut -d ":" -f "2")
            ndevices=$( grep "Raid Devices" $tmpfile | tr -d " " | cut -d ":" -f "2")
            if [[ "$ndevices" ]] ; then
                let sparedevices=$totaldevices-$ndevices
            else
                let sparedevices=0
            fi

            devices=""
            let size=0
            if [[ "$container" ]] ; then
                devices=" devices=$(readlink -f $container)"
                if [[ "$used_dev_size" ]] ; then
                    let size=$used_dev_size
                elif [[ "$array_size" ]] ; then
                    let size=$array_size/$ndevices
                fi
            else
                # Find all devices
                # use the output of mdadm, but skip the array itself
                # sysfs has the information in RHEL 5+, but RHEL 4 lacks it.
                for disk in $( grep -o -E "/dev/[^m].*$" $tmpfile | tr "\n" " ") ; do
                    disk=$( get_device_name $disk )
                    if [ -z "$devices" ] ; then
                        devices=" devices=$disk"
                    else
                        devices="$devices,$disk"
                    fi
                done
            fi

            if [ "$size" -gt 0 ] ; then
                size=" size=$size"
            else
                size=""
            fi

            # prepare for output
            if [[ "$metadata" ]] ; then
                metadata=" metadata=$metadata"
            else
                metadata=""
            fi
            level=" level=$level"
            if [[ "$ndevices" ]] && [ $ndevices -gt 0 ] ; then
                ndevices=" raid-devices=$ndevices"
            elif [[ "$totaldevices" ]] ; then
                ndevices=" raid-devices=$totaldevices"
            else
                ndevices=""
            fi
            uuid=" uuid=$uuid"

            if [ "$sparedevices" -gt 0 ] ; then
                sparedevices=" spare-devices=$sparedevices"
            else
                sparedevices=""
            fi

            # mdadm can print '-unknown-' for a RAID layout
            # which got recently (2019-12-02) added to RAID0 (it existed before for RAID5 and RAID6 and RAID10) see
            # https://git.kernel.org/pub/scm/utils/mdadm/mdadm.git/commit/Detail.c?id=329dfc28debb58ffe7bd1967cea00fc583139aca
            # so we treat '-unknown-' same as an empty value to avoid that layout/prepare/GNU/Linux/120_include_raid_code.sh
            # will create a 'mdadm' command in diskrestore.sh like "mdadm ... --layout=-unknown- ..." which would fail
            # during "rear recover" with something like "mdadm: layout -unknown- not understood for raid0"
            # see https://github.com/rear/rear/issues/2616
            if test "$layout" -a '-unknown-' != "$layout" ; then
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

            echo "raid ${device}${metadata}${level}${ndevices}${uuid}${name}${sparedevices}${layout}${chunksize}${devices}${size}"

            extract_partitions "$device"
        done < <(mdadm --detail --scan --config=partitions)
    ) >> $DISKLAYOUT_FILE

    # mdadm is required in the recovery system if disklayout.conf contains at least one 'raid' entry
    # see the create_raid function in layout/prepare/GNU/Linux/120_include_raid_code.sh
    # what program calls are written to diskrestore.sh
    # cf. https://github.com/rear/rear/issues/1963
    grep -q '^raid ' $DISKLAYOUT_FILE && REQUIRED_PROGS+=( mdadm ) || true
    grep -q '^raid ' $DISKLAYOUT_FILE && PROGS+=( mdmon ) || true

fi

