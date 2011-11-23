# Save the partition layout

### Parted can output machine parseable information
FEATURE_PARTED_MACHINEREADABLE=
### Parted used to have slightly different naming
FEATURE_PARTED_OLDNAMING=

parted_version=$(get_version parted -v)
[[ "$parted_version" ]]
BugIfError "Function get_version could not detect parted version."

if version_newer "$parted_version" 1.8.2 ; then
    FEATURE_PARTED_MACHINEREADABLE=y
fi
if ! version_newer "$parted_version" 1.6.23 ; then
    FEATURE_PARTED_OLDNAMING=y
fi

# Extract partitioning information of device $1 (full device path)
# format : part <partition size(bytes)> <partition start(bytes)> <partition type|name> <flags> /dev/<partition>
extract_partitions() {
    declare device=$1

    declare sysfs_name=$(get_sysfs_name $device)
    declare block_size=$(get_block_size $device)

    ### collect basic information
    : > $TMP_DIR/partitions

    declare path partition_name partition_prefix start_block
    declare partition_nr size start
    for path in /sys/block/$sysfs_name/$sysfs_name* ; do
        partition_name=${path##*/}

        [[ $partition_name =~ ([0-9]+)$ ]]
        partition_nr=${BASH_REMATCH[1]}

        partition_prefix=${partition_name%$partition_nr}

        size=$(get_disk_size $sysfs_name/$partition_name)
        start_block=$(< $path/start)
        if [[ -z "$start_block" ]] ; then
            BugError "Could not determine start of partition $partition_name, please file a bug."
        fi
        start=$(( $start_block*$block_size ))

        echo "$partition_nr $size $start">> $TMP_DIR/partitions
    done

    if [[ ! -s $TMP_DIR/partitions ]] ; then
        Debug "No partitions found on $device."
        return
    fi

    ### Cache parted data
    declare disk_label
    if [[ $FEATURE_PARTED_MACHINEREADABLE ]] ; then
        parted -m -s $device print > $TMP_DIR/parted
        disk_label=$(grep ^/ $TMP_DIR/parted | cut -d ":" -f "6")
    else
        parted -s $device print > $TMP_DIR/parted
        disk_label=$(grep -E "Partition Table|Disk label" $TMP_DIR/parted | cut -d ":" -f "2" | tr -d " ")
    fi

    cp $TMP_DIR/partitions $TMP_DIR/partitions-data

    declare type

    ### determine partition type for msdos partition tables
    if [[ "$disk_label" = "msdos" ]] ; then
        declare -i has_logical
        while read partition_nr size start junk ; do
            if (( $partition_nr > 4 )) ; then
                ### logical
                has_logical=1
                sed -i /^$partition_nr\ /s/$/\ logical/ $TMP_DIR/partitions
            else
                ### set to primary until flags are known
                declare type="primary"
                sed -i /^$partition_nr\ /s/$/\ primary/ $TMP_DIR/partitions
            fi
        done < $TMP_DIR/partitions-data
    fi

    ### find partition name for gpt disks.
    if [[ "$disk_label" = "gpt" ]] ; then
        if [[ "$FEATURE_PARTED_MACHINEREADABLE" ]] ; then
            while read partition_nr size start junk ; do
                type=$(grep "^$partition_nr:" $TMP_DIR/parted | cut -d ":" -f "6")
                if [[ -z "$type" ]] ; then
                    type="rear-noname"
                fi
                sed -i /^$partition_nr\ /s/$/\ $type/ $TMP_DIR/partitions
            done < $TMP_DIR/partitions-data
        else
            declare line line_length number numberfield
            init_columns "$(grep "Flags" $TMP_DIR/parted)"
            while read line ; do
                # read throws away leading spaces
                line_length=${line%% *}
                if (( "$line_length" < 10 )) ; then
                    line=" $line"
                fi

                if [[ "$FEATURE_PARTED_OLDNAMING" ]] ; then
                    numberfield="minor"
                else
                    numberfield="number"
                fi

                number=$(get_columns "$line" "$numberfield" | tr -d " " | tr -d ";")
                type=$(get_columns "$line" "name" | tr -d " " | tr -d ";")

                if [[ -z "$type" ]] ; then
                    type="rear-noname"
                fi

                sed -i /^$number\ /s/$/\ $type/ $TMP_DIR/partitions
            done < <(grep -E '^[ ]*[0-9]' $TMP_DIR/parted)
        fi
    fi

    ### find the flags given by parted.
    declare flags
    if [[ "$FEATURE_PARTED_MACHINEREADABLE" ]] ; then
        while read partition_nr size start junk ; do
            flags=$(grep "^$partition_nr:" $TMP_DIR/parted | cut -d ":" -f "7" | tr -d " " | tr -d ";")
            if [[ -z "$flags" ]] ; then
                flags="none"
            fi
            sed -i /^$partition_nr\ /s/$/\ $flags/ $TMP_DIR/partitions
        done < $TMP_DIR/partitions-data
    else
        declare line line_length number numberfield
        init_columns "$(grep "Flags" $TMP_DIR/parted)"
        while read line ; do
            # read throws away leading spaces
            line_length=${line%% *}
            if (( "$line_length" < 10 )) ; then
                line=" $line"
            fi

            if [[ "$FEATURE_PARTED_OLDNAMING" ]] ; then
                numberfield="minor"
            else
                numberfield="number"
            fi

            number=$(get_columns "$line" "$numberfield" | tr -d " " | tr -d ";")
            flags=$(get_columns "$line" "flags" | tr -d " " | tr -d ";")

            if [[ -z "$flags" ]] ; then
                flags="none"
            fi

            sed -i /^$number\ /s/$/\ $flags/ $TMP_DIR/partitions
        done < <(grep -E '^[ ]*[0-9]' $TMP_DIR/parted)
    fi

    ### Find an extended partition if there is one
    if [[ "$disk_label" = "msdos" ]] && [[ "$has_logical" ]] ; then
        cp $TMP_DIR/partitions $TMP_DIR/partitions-data
        while read partition_nr size start type flags junk ; do
            (( $partition_nr > 4 )) && continue

            if has_binary sfdisk ; then
                declare partition_id=$(sfdisk -c $device $partition_nr)
                if [[ "$partition_id" = "f" ]] || [[ "$partition_id" = "5" ]] ; then
                    sed -i /^$partition_nr\ /s/\ primary\ /\ extended\ / $TMP_DIR/partitions
                fi
            else
                if [[ "${flags/lba/}" != "$flags" ]] ; then
                    sed -i /^$partition_nr\ /s/\ primary\ /\ extended\ / $TMP_DIR/partitions
                fi
            fi
        done < $TMP_DIR/partitions-data
    fi

    ### Write to layout file
    while read partition_nr size start type flags junk ; do
        echo "part $device $size $start $type $flags ${device%/*}/${partition_prefix/\!//}$partition_nr"
    done < $TMP_DIR/partitions
}


Log "Saving disk partitions."

(
    # Disk sizes
    # format: disk <disk> <sectors> <partition label type>
    for disk in /sys/block/* ; do
        if [[ ${disk#/sys/block/} = @(hd*|sd*|cciss*|vd*) ]] ; then
            devname=$(get_device_name $disk)
            devsize=$(get_disk_size ${disk#/sys/block/})

            disktype=$(parted -s /dev/$devname print | grep -E "Partition Table|Disk label" | cut -d ":" -f "2" | tr -d " ")

            echo "disk /dev/$devname $devsize $disktype"

            extract_partitions "/dev/$devname"
        fi
    done

) >> $DISKLAYOUT_FILE
