# Save the partition layout
### This works on a per device basis.
### The main function is extract_partitions
### Temporary caching of data in $TMP_DIR/partitions
### Temporary caching of parted data in $TMP_DIR/parted

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
    declare block_size=$(get_block_size $sysfs_name)

    ### check if we can find any partitions
    declare -a sysfs_paths=(/sys/block/$sysfs_name/$sysfs_name*)

    declare path sysfs_path
    if [[ ${#sysfs_paths[@]} -eq 0 ]] ; then
        ### try to find partitions like /dev/mapper/datalun1p1
        if [[ ${device/mapper//} != ${device} ]] ; then
            for path in ${device}p* ${device}-part*  ${device}_part*; do
                sysfs_path=$(get_sysfs_name $path)
                if [[ "$sysfs_path" ]] && [[ -e "/sys/block/$sysfs_path" ]] ; then
                    sysfs_paths=( "${sysfs_paths[@]}" "/sys/block/$sysfs_path" )
                fi
            done
        fi
    fi

    ### collect basic information
    : > $TMP_DIR/partitions

    declare partition_name partition_prefix start_block
    declare partition_nr size start
    for path in "${sysfs_paths[@]}" ; do
        ### path can be: /sys/block/sda/sda1 --> /dev/sda1
        ###              /sys/block/dm-4 --> /dev/mapper/mpathbp1
        partition_name=$(get_device_name ${path##*/})
        ### strip prefixes
        partition_name=${partition_name#/dev/}
        partition_name=${partition_name#mapper/}

        partition_nr=$(get_partition_number "$partition_name")

        partition_prefix=${partition_name%$partition_nr}

        size=$(get_disk_size ${path#/sys/block/})
        if [[ -r $path/start ]] ; then
            start_block=$(< $path/start)
            start=$(( $start_block*$block_size ))
        else
            Log "Could not determine start of partition $partition_name."
            start="unknown"
        fi

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
                type=$(echo "$type" | sed -e 's/ /0x20/g') # replace spaces with 0x20 in name field
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

                type=$(echo "$type" | sed -e 's/ /0x20/g')
                sed -i /^$number\ /s/$/\ $type/ $TMP_DIR/partitions
            done < <(grep -E '^[ ]*[0-9]' $TMP_DIR/parted)
        fi
    fi

    ### find the flags given by parted.
    declare flags flaglist
    if [[ "$FEATURE_PARTED_MACHINEREADABLE" ]] ; then
        while read partition_nr size start junk ; do
            flaglist=$(grep "^$partition_nr:" $TMP_DIR/parted | cut -d ":" -f "7" | tr -d "," | tr -d ";")

            ### only report flags parted can actually recreate
            flags=""
            for flag in $flaglist ; do
                if [[ "$flag" = @(boot|root|swap|hidden|raid|lvm|lba|palo|legacy_boot|bios_grub) ]] ; then
                    flags="$flags$flag,"
                fi
            done

            if [[ -z "$flags" ]] ; then
                flags="none"
            fi
            sed -i /^$partition_nr\ /s/$/\ ${flags%,}/ $TMP_DIR/partitions
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
            flaglist=$(get_columns "$line" "flags" | tr -d "," | tr -d ";")

            ### only report flags parted can actually recreate
            flags=""
            for flag in $flaglist ; do
                if [[ "$flag" = @(boot|root|swap|hidden|raid|lvm|lba|palo|legacy_boot|bios_grub) ]] ; then
                    flags="$flags$flag,"
                fi
            done

            if [[ -z "$flags" ]] ; then
                flags="none"
            fi

            sed -i /^$number\ /s/$/\ ${flags%,}/ $TMP_DIR/partitions
        done < <(grep -E '^[ ]*[0-9]' $TMP_DIR/parted)
    fi

    ### Find an extended partition if there is one
    if [[ "$disk_label" = "msdos" ]] && [[ "$has_logical" ]] ; then
        cp $TMP_DIR/partitions $TMP_DIR/partitions-data
        while read partition_nr size start type flags junk ; do
            (( $partition_nr > 4 )) && continue

            if has_binary sfdisk ; then
                declare partition_id=$(sfdisk -c $device $partition_nr 2>&8)
                ### extended partitions are either DOS_EXT, EXT_LBA or LINUX_EXT
                if [[ "$partition_id" = @(5|f|85) ]]; then
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
        ### determine the name of the partition using the number
        ### device=/dev/cciss/c0d0 ; partition_prefix=cciss/c0d0p
        ### device=/dev/md127 ; partition_prefix=md127p
        ### device=/dev/sda ; partition_prefix=sda
        ### device=/dev/mapper/mpathbp1 ; partition_prefix=mpathbp
        partition_name="${device%/*}/${partition_prefix#*/}$partition_nr"
        echo "part $device $size $start $type $flags $(get_device_name $partition_name)"
    done < $TMP_DIR/partitions
}


Log "Saving disk partitions."
(
    # Disk sizes
    # format: disk <disk> <sectors> <partition label type>
    for disk in /sys/block/* ; do
        if [[ ${disk#/sys/block/} = @(hd*|sd*|cciss*|vd*|xvd*) ]] ; then
            devname=$(get_device_name $disk)
            devsize=$(get_disk_size ${disk#/sys/block/})
            disktype=$(parted -s $devname print | grep -E "Partition Table|Disk label" | cut -d ":" -f "2" | tr -d " ")

            diskserialnumber="0"
            if which smartctl >/dev/null 2>&1 ; then
                diskserialnumber=$(LANG=C smartctl -a $devname | grep -i "Serial Number" | cut -d ':' -f 2 | tr -d ' ' 2>/dev/null)
                if [[ $diskserialnumber = "" ]] ; then
                    diskserialnumber="0"
                fi
            fi

            disklocation="0"
            if which lsscsi >/dev/null 2>&1 ; then
                lsscsi -t | grep disk  | grep $devname | grep -q " fc:"
                if [ ! $? -eq 0 ] ; then
                    disklocation=$(lsscsi -t | grep disk  | grep $devname | cut -d " " -f 1 2>/dev/null)
                fi
            fi

            echo "disk $devname $devsize $disktype $diskserialnumber $disklocation"
            extract_partitions "$devname"
        fi
    done
) >> $DISKLAYOUT_FILE
