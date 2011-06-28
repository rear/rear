# Save the partition layout

Log "Saving disk partitions."

(
    # Disk sizes
    # format: disk <disk> <sectors> <partition label type>
    devices=()
    for disk in /sys/block/* ; do
        case $(basename $disk) in
            hd*|sd*|cciss*|vd*)
                devname=$(get_device_name $disk)
                devsize=$(get_disk_size ${disk#/sys/block/})
                
                disktype=$(parted -s /dev/$devname print | grep -E "Partition Table|Disk label" | cut -d ":" -f "2" | tr -d " ")
                
                echo "disk /dev/$devname $devsize $disktype"
                
                devices=( "${devices[@]}" "$devname" )
                ;;
        esac
    done

    # This uses parted. Old versions of parted produce different output than newer versions.
    parted_version=$(get_version parted -v)
    [ "$parted_version" ]
    BugIfError "Function get_version could not detect parted version."
    
    if ! version_newer "$parted_version" 1.6.23 ; then
        oldparted="yes"
        Log "Old version of parted detected."
    fi

    # Partitions
    # Partitions are read from sysfs. Extra information is collected using parted
    # format : part <partition size(bytes)> <partition type|name> <flags> /dev/<partition>
    for device in "${devices[@]}" ; do
        if [ -e /dev/$device ] ; then
            
            sysfsname=$(get_sysfs_name $device)
            blocksize=$(get_block_size $sysfsname)
            
            # Check for old version of parted.
            # Parted on RHEL 4 outputs differently 
            # - header names: minor instead of number,
            # - no support for units (we use sysfs for sizes)
            if [ -z "$oldparted" ] ; then
                numberfield="number"
            else
                numberfield="minor"
            fi
            
            parted -s /dev/$device print > $TMP_DIR/parted
            disktype=$(grep -E "Partition Table|Disk label" $TMP_DIR/parted | cut -d ":" -f "2" | tr -d " ")

            # Difference between gpt and msdos: type|name
            case $disktype in
                msdos)
                    typefield="type"
                    ;;
                gpt)
                    typefield="name"
                    ;;
                *)
                    Log "Unsupported disk label $disktype on $device."
                    continue
            esac
            
            init_columns "$(grep "Flags" $TMP_DIR/parted)"
            while read line ; do
                # read throws away leading spaces
                number=${line%% *}
                if [ "$number" -lt 10 ] ; then
                    line=" $line"
                fi
                
                pnumber=$(get_columns "$line" "$numberfield" | tr -d " " | tr -d ";")
                ptype=$(get_columns "$line" "$typefield" | tr -d " " | tr -d ";")
                pflags=$(get_columns "$line" "flags" | tr -d "," |tr -d ";")
                
                case $device in
                    *cciss*)
                        pname="p${pnumber}"
                        ;;
                    *)
                        pname="${pnumber}"
                        ;;
                esac
                
                psize=$(get_disk_size "$sysfsname/$sysfsname$pname")
                
                pstart=$( < /sys/block/$sysfsname/${sysfsname}${pname}/start)
                if [ -z "$pstart" ] ; then
                    BugError "Could not determine start of partition ${sysfsname}${pname}, please file a bug."
                fi
                let pstart=$pstart\*$blocksize
                
                flags=""
                for flag in $pflags ; do
                    case $flag in
                        boot|root|swap|hidden|raid|lvm|lba|palo)
                            flags="$flags$flag,"
                            ;;
                    esac
                done
                if [ -z "$flags" ] ; then
                    flags="none"
                fi
                
                echo "part /dev/$device $psize $pstart $ptype ${flags%,} /dev/${device}${pname}"
            done < <(grep -E '^[ ]*[0-9]' $TMP_DIR/parted)

        fi
    done

) >> $DISKLAYOUT_FILE
