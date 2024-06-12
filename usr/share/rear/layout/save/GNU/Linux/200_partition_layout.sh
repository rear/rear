# Save the partition layout
# This works on a per device basis.
# The main function is extract_partitions
# Temporary caching of data in $TMP_DIR/partitions
# Temporary caching of parted data in $TMP_DIR/parted

# Parted can output machine parseable information
FEATURE_PARTED_MACHINEREADABLE=
# Parted used to have slightly different naming
FEATURE_PARTED_OLDNAMING=

parted_version=$( get_version parted -v )
test "$parted_version" || BugError "Function get_version could not detect parted version."

# Function version_newer v1 v2 returns 0 when v1 is greater or equal than v2:
# Use FEATURE_PARTED_MACHINEREADABLE if parted version is 1.8.2 or newer:
version_newer "$parted_version" 1.8.2 && FEATURE_PARTED_MACHINEREADABLE=y
# Use FEATURE_PARTED_OLDNAMING if parted version is older than 1.6.23:
version_newer "$parted_version" 1.6.23 || FEATURE_PARTED_OLDNAMING=y

# Extract partitioning information of device $1 (full device path)
# format : part <partition size(bytes)> <partition start(bytes)> <partition type|name> <flags> /dev/<partition>
extract_partitions() {
    declare device=$1

    declare sysfs_name=$(get_sysfs_name $device)

    ### check if we can find any partitions
    declare -a sysfs_paths_unfiltered=(/sys/block/$sysfs_name/$sysfs_name*)

    ### initialize array
    declare -a sysfs_paths=()

    ### Silently skip invalid partitions on eMMC devices
    ### of type *rpmb or *boot[0-9] like /dev/mmcblk0rpmb or /dev/mmcblk0boot0
    ### because sysfs for (some?) eMMC disks recognises partitions,
    ### which are no usual partitions, but special areas on the eMMC.
    ### When trying to get the partition layout for such disks, ReaR would exit with an error.
    ### Therefore we ignore these special partitions, see also
    ### https://github.com/rear/rear/issues/2087
    for possible_sysfs_partition in "${sysfs_paths_unfiltered[@]}"; do
	if [[ ! ( $possible_sysfs_partition = *'/mmcblk'+([0-9])'rpmb' || $possible_sysfs_partition = *'/mmcblk'+([0-9])'boot'+([0-9]) ) ]] ; then
	    sysfs_paths+=($possible_sysfs_partition)
        fi    
    done

    declare path sysfs_path
    if [[ ${#sysfs_paths[@]} -eq 0 ]] ; then
        if [[ $device = *'/mapper/'* ]]; then
            ### As /sys/block/dm-X/holders directory contains partition name or LVM logical volume name in dm-X format,
            ### we have to filter and keep only partition type device.
            if [ -d /sys/block/$sysfs_name/holders ]; then
                # for each dm devices in holders directory, only add partitions to sysfs_path array.
                # One way is to check if the dm uuid starts with "part"
                # example: cat /sys/block/dm-2/holders/dm-7/dm/uuid => part3-mpath-3600507680c82004cf8000000000000d8
                for potential_partition in /sys/block/$sysfs_name/holders/*; do
                    uuid=$( cat $potential_partition/dm/uuid )
                    if [[ $uuid = part* ]]; then
                        # store all the $device partition in sysfs_paths array
                        sysfs_paths+=( "$potential_partition" )
                    fi
                done
            else
                ### if the holders directory does not exisits 
                ### failback to partition name guessing method.
                ### try to find partitions like /dev/mapper/datalun1p1
                for path in ${device}p[0-9]* ${device}[0-9]* ${device}-part* ${device}_part*; do
                    sysfs_path=$(get_sysfs_name $path)
                    if [[ "$sysfs_path" ]] && [[ -e "/sys/block/$sysfs_path" ]] ; then
                        sysfs_paths+=( "/sys/block/$sysfs_path" )
                    fi
                done
            fi
        fi
    fi

    ### collect basic information
    : > $TMP_DIR/partitions_unsorted

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
        start=$(get_partition_start ${path#/sys/block/})

        echo "$partition_nr $size $start">> $TMP_DIR/partitions_unsorted
    done

    # do a numeric sort to have the partitions in numeric order (see #352)
    # add a uniq sort "-u" to filter duplicated lines (see #1301)
    sort -un  $TMP_DIR/partitions_unsorted > $TMP_DIR/partitions

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
    # Ensure $disk_label is valid to determine the partition name/type in the next step at 'declare type'
    # cf. https://github.com/rear/rear/issues/2801#issuecomment-1122015129
    # When a partition type is reported by parted that is not in the supported list
    # it must error out because our current code here in 200_partition_layout.sh
    # does not work with partition types that are not in the supported list
    # cf. https://github.com/rear/rear/pull/2803#issuecomment-1124800884
    if ! [[ "$disk_label" = "msdos" || "$disk_label" = "gpt" || "$disk_label" = "gpt_sync_mbr" || "$disk_label" = "dasd" ]] ; then
        Error "Unsupported partition table '$disk_label' on $device (must be one of 'msdos' 'gpt' 'gpt_sync_mbr' 'dasd')"
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

    ### Find partition name for GPT disks.
    # For the SUSE specific gpt_sync_mbr partitioning scheme
    # see https://github.com/rear/rear/issues/544
    # For s390 dasd disks parted does not show a partition name/type.
    # E.g. on s390 the parted output looks like
    #   # parted -s /dev/dasda unit MiB print
    #   Model: IBM S390 DASD drive (dasd)
    #   Disk /dev/dasda: 7043MiB
    #   Sector size (logical/physical): 512B/4096B
    #   Partition Table: dasd
    #   Disk Flags: 
    #   Number  Start    End      Size     File system     Flags
    #    1      0.09MiB  200MiB   200MiB   ext2
    #    2      200MiB   1179MiB  979MiB   linux-swap(v1)
    #    3      1179MiB  7043MiB  5864MiB  ext4
    # while on x86 the parted output looks like
    #   # parted -s /dev/sda unit MiB print
    #   Model: ATA WDC WD10EZEX-75M (scsi)
    #   Disk /dev/sda: 953870MiB
    #   Sector size (logical/physical): 512B/4096B
    #   Partition Table: gpt
    #   Disk Flags: 
    #   Number  Start      End        Size       File system     Name  Flags
    #    1      1.00MiB    501MiB     500MiB     fat16                 boot, esp
    #    2      501MiB     937911MiB  937410MiB  ext4
    #    3      937911MiB  953870MiB  15959MiB   linux-swap(v1)        swap
    # cf. https://github.com/rear/rear/pull/2142#discussion_r285594247
    # But on s390 'parted mkpart fs-type start end' requires a valid file system type
    # so that the above fallback type="rear-noname" that gets during "rear recover"
    # replaced with $(basename "$partition") via 100_include_partition_code.sh
    # does not work on s390 and lets parted fail with "invalid token",
    # see https://github.com/rear/rear/pull/2142#issuecomment-494742554
    #   +++ parted -s /dev/dasda mkpart ''\''dasda1'\''' 98304B 314621951B
    #   parted: invalid token: dasda1
    #   Error: Expecting a file system type.
    # Therefore we use a hardcoded fixed file system type 'ext2' as dummy for 'parted' which works
    # because the real file systems are set up afterwards via 'mkfs' commands during "rear recover"
    # and also YaST uses a fixed 'ext2' dummy file system type for 'parted mkpart' on s390,
    # cf. https://github.com/rear/rear/pull/2142#issuecomment-494813151
    if [[ "$disk_label" = "gpt" || "$disk_label" = "gpt_sync_mbr" || "$disk_label" = "dasd" ]] ; then
        if [[ "$FEATURE_PARTED_MACHINEREADABLE" ]] ; then
            while read partition_nr size start junk ; do
                if [[ "$disk_label" = "dasd" ]] ; then
                    type="ext2"
                else
                    # In case of GPT the 'type' field contains actually the GPT partition name.
                    type=$(grep "^$partition_nr:" $TMP_DIR/parted | cut -d ":" -f "6")
                    # There must not be any empty field in disklayout.conf
                    # because the fields in disklayout.conf are positional parameters
                    # that get assigned to variables via the 'read' shell builtin:
                    test "$type" || type="rear-noname"
                    # There must not be any IFS character in a field in disklayout.conf
                    # because IFS characters are used as field separators
                    # but in particular a GPT partition name can contain spaces
                    # like 'EFI System Partition' cf. https://github.com/rear/rear/issues/1563
                    # so that the partition name is stored as a percent-encoded string:
                    type=$( percent_encode "$type" )
                fi
                sed -i /^$partition_nr\ /s/$/\ $type/ $TMP_DIR/partitions
            done < $TMP_DIR/partitions-data
        else
            declare line line_length number numberfield
            init_columns "$(grep "Flags" $TMP_DIR/parted)"
            while read line ; do
                if [[ "$disk_label" = "dasd" ]] ; then
                    type="ext2"
                else
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

                    # In case of GPT the 'type' field contains actually the GPT partition name.
                    type=$(get_columns "$line" "name" | tr -d " " | tr -d ";")

                    # There must not be any empty field in disklayout.conf
                    # because the fields in disklayout.conf are positional parameters
                    # that get assigned to variables via the 'read' shell builtin:
                    test "$type" || type="rear-noname"

                    # There must not be any IFS character in a field in disklayout.conf
                    # because IFS characters are used as field separators
                    # but in particular a GPT partition name can contain spaces
                    # like 'EFI System Partition' cf. https://github.com/rear/rear/issues/1563
                    # so that the partition name is stored as a percent-encoded string:
                    type=$( percent_encode "$type" )
                fi
                sed -i /^$number\ /s/$/\ $type/ $TMP_DIR/partitions
            done < <(grep -E '^[ ]*[0-9]' $TMP_DIR/parted)
        fi
    fi

    declare flags flaglist
    ### Find the flags given by parted.
    if [[ "$FEATURE_PARTED_MACHINEREADABLE" ]] ; then
        while read partition_nr size start junk ; do
            # On s390 the parted output columns differ, see the above parted output on s390 versus on x86.
            # There is no 'Name' column so that the 'Flags' column is not the 7th column but the 6th column on s390:
            if [[ "$disk_label" = "dasd" ]] ; then
                flaglist=$( grep "^$partition_nr:" $TMP_DIR/parted | cut -d ":" -f "6" | tr -d "," | tr -d ";" )
            else
                flaglist=$( grep "^$partition_nr:" $TMP_DIR/parted | cut -d ":" -f "7" | tr -d "," | tr -d ";" )
            fi
            ### only report flags parted can actually recreate
            flags=""
            for flag in $flaglist ; do
                if [[ "$flag" = boot || "$flag" = esp || "$flag" = root || "$flag" = swap || "$flag" = hidden || "$flag" = raid || "$flag" = lvm || "$flag" = lba || "$flag" = palo || "$flag" = legacy_boot || "$flag" = bios_grub || "$flag" = prep ]] ; then
                    flags+="$flag,"
                elif [[ "$flag" = "type=06" ]] ; then
                    flags="${flags}prep,"
                fi
            done
            test "$flags" || flags="none"
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
                if [[ "$flag" = boot || "$flag" = root || "$flag" = swap || "$flag" = hidden || "$flag" = raid || "$flag" = lvm || "$flag" = lba || "$flag" = palo || "$flag" = legacy_boot || "$flag" = bios_grub || "$flag" = prep ]] ; then
                    flags+="$flag,"
                elif [[ "$flag" = "type=06" ]] ; then
                    flags="${flags}prep,"
                fi
            done

            test "$flags" || flags="none"
            sed -i /^$number\ /s/$/\ ${flags%,}/ $TMP_DIR/partitions
        done < <(grep -E '^[ ]*[0-9]' $TMP_DIR/parted)
    fi

    ### Find an extended partition if there is one
    if [[ "$disk_label" = "msdos" ]] && [[ "$has_logical" ]] ; then
        cp $TMP_DIR/partitions $TMP_DIR/partitions-data
        while read partition_nr size start type flags junk ; do
            (( $partition_nr > 4 )) && continue

            if has_binary sfdisk ; then
                # make sfdisk output safe against unwanted characters (in particular blanks)
                # cf. https://github.com/rear/rear/issues/1106
                declare partition_id=$( sfdisk -c $device $partition_nr | tr -c -d '[:alnum:]' )
                ### extended partitions are either DOS_EXT, EXT_LBA or LINUX_EXT
                if [[ "$partition_id" = 5 || "$partition_id" = f || "$partition_id" = 85 ]]; then
                    sed -i /^$partition_nr\ /s/\ primary\ /\ extended\ / $TMP_DIR/partitions
                fi
            else
                if [[ "${flags/lba/}" != "$flags" ]] ; then
                    sed -i /^$partition_nr\ /s/\ primary\ /\ extended\ / $TMP_DIR/partitions
                fi
            fi

            # Replace currently possibly wrong extended partition size value
            # by the value that parted reports if those values differ, cf.
            # https://github.com/rear/rear/pull/1733#issuecomment-368051895
            # In SLE10 there is GNU Parted 1.6.25.1 which supports 'unit B'
            # that is documented in 'info parted' (but not yet in 'man parted').
            # Example of a parted_extended_partition_line:
            #   # parted -s /dev/sdb unit B print | grep -w '3' | grep -w 'extended'
            #    3      1266679808B  1790967807B  524288000B  extended                  lba, type=0f
            # where the size is 524288000B i.e. parted_extended_partition_line[3]
            parted_extended_partition_line=( $( parted -s $device unit B print | grep -w "$partition_nr" | grep -w 'extended' ) )
            parted_extended_partition_size="${parted_extended_partition_line[3]%%B*}"
            # parted_extended_partition_size is empty (or perhaps whatever string that is not an integer number)
            # when it is no extended partition (i.e. when it is a primary partition or a logical partition)
            # so that the subsequent 'test' intentionally also fails when parted_extended_partition_size is not an integer
            # with bash stderr messages like 'unary operator expected' or 'integer expression expected'
            # that are suppressed here to not appear in the log, cf. https://github.com/rear/rear/issues/1931
            if test $size -ne $parted_extended_partition_size 2>/dev/null ; then
                 Log "Replacing probably wrong extended partition size $size by what parted reports $parted_extended_partition_size"
                 sed -i /^$partition_nr\ /s/\ $size\ /\ $parted_extended_partition_size\ / $TMP_DIR/partitions
            fi

        done < $TMP_DIR/partitions-data
    fi

    ### Write to layout file
    while read partition_nr size start type flags junk ; do
        # determine the name of the partition using the number
        # device=/dev/cciss/c0d0 ; partition_prefix=cciss/c0d0p
        # device=/dev/md127 ; partition_prefix=md127p
        # device=/dev/sda ; partition_prefix=sda
        # device=/dev/mapper/mpathbp1 ; partition_prefix=mpathbp
        partition_name="${device%/*}/${partition_prefix#*/}$partition_nr"
        partition_device="$( get_device_name $partition_name )"
        test -b "$partition_device" || Error "Invalid 'part $device' entry (partition device '$partition_device' is no block device)"
        # Ensure syntactically correct 'part' entries of the form
        #   part disk_device partition_size start_byte partition_label flags partition_device
        # Each value must exist and each value must be a single non-blank word.
        # When $junk contains something one of the values before was more than a single word:
        test "$junk" && Error "Invalid 'part $device' entry (some value is more than a single word)"
        # When $flags is empty at least one value is missing:
        test "$flags" || Error "Invalid 'part $device' entry (at least one value is missing)"
        # Some basic checks on the values happen in layout/save/default/950_verify_disklayout_file.sh
        echo "part $device $size $start $type $flags $partition_device"
    done < $TMP_DIR/partitions
}

Log "Saving disks and their partitions"

# Begin of group command that appends its stdout to DISKLAYOUT_FILE:
{
    for disk in /sys/block/* ; do
        blockd=${disk#/sys/block/}
        if [[ $blockd = hd* || $blockd = sd* || $blockd = cciss* || $blockd = vd* || $blockd = xvd* || $blockd = dasd* || $blockd = nvme* || $blockd = mmcblk* ]] ; then

            if [[ $blockd == dasd* && "$ARCH" == "Linux-s390" ]] ; then
                devname=$(get_device_name $disk)
                dasdnum=$( lsdasd | awk "\$3 == \"$blockd\" { print \$1}" )
                dasdstatus=$( lsdasd | awk "\$3 == \"$blockd\" { print \$2}" )
                # ECKD or FBA
                dasdtype=$( lsdasd | awk "\$3 == \"$blockd\" { print \$5}" )
                if [ "$dasdtype" != ECKD ] && [ "$dasdtype" != FBA ]; then
                    LogPrint "Type $dasdtype of DASD $blockd unexpected: neither ECKD nor FBA"
                fi

                echo "# every DASD bus and channel"
                echo "# Format: dasd_channel <bus-id> <device name>"
                echo "dasd_channel $dasdnum $blockd"

                # We need to print the dasd_channel line even for ignored devices,
                # otherwise we could have naming gaps and naming would change when
                # recreating layout.
                # E.g. if dasda is ignored, and dasdb is not, we would create only dasdb
                # during recreation, but it would be named dasda.
                if [ "$dasdstatus" != active ]; then
                    Log "Ignoring $blockd: it is not active (Status is $dasdstatus)"
                    continue
                fi
            fi

            #FIXME: exclude *rpmb (Replay Protected Memory Block) for nvme*, mmcblk* and uas
            # *rpmb = no read access && no write access
            # GNU Parted <= 3.2 -> Input/output error

            #Check if blockd is a path of a multipath device.
            if is_multipath_path ${blockd} ; then
                Log "Ignoring $blockd: it is a path of a multipath device"
            elif [[ ! ($blockd = *rpmb || $blockd = *[0-9]boot[0-9]) ]]; then # Silently skip Replay Protected Memory Blocks and others  
                devname=$(get_device_name $disk)
                devsize=$(get_disk_size ${disk#/sys/block/})
                # Ensure syntactically correct 'disk' entries:
                # Each value must exist and each value must be a single non-blank word so we 'test' without quoting the value:
                test $devname || Error "Invalid 'disk' entry (no disk device name for '$disk')"
                test $devsize || Error "Invalid 'disk $devname' entry (no device size for '$devname')"
                # Validation error can happen when /dev/sdX is an empty SD card slot without medium,
                # see https://github.com/rear/rear/issues/2810 https://github.com/rear/rear/issues/2958
                # this is normal, but such device must be skipped and not be added to the layout
                # - it does not contain any data anyway.
                # See https://github.com/rear/rear/pull/3047
                if ! validation_error=$(is_disk_valid $devname) ; then
                    LogPrintError "Ignoring $blockd: $validation_error"
                    continue
                fi
                disktype=$(parted -s $devname print | grep -E "Partition Table|Disk label" | cut -d ":" -f "2" | tr -d " ")
                test $disktype || Error "Invalid 'disk $devname' entry (no partition table type for '$devname')"
                if [ "$disktype" != "dasd" ]; then
                    echo "# Disk $devname"
                    echo "# Format: disk <devname> <size(bytes)> <partition label type>"
                    echo "disk $devname $devsize $disktype"
                elif [[ $blockd == dasd* && "$ARCH" == "Linux-s390" ]] ; then
                    layout=$(dasdview -x $devname |grep "^format"|awk '{print $7}')
                    case "$layout" in
                        (NOT)
                            # NOT -> dasdview has printed "NOT formatted"
                            LogPrintError "Ignoring $blockd: it is not formatted"
                            continue
                            ;;
                        (LDL|CDL)
                            ;;
                        (*)
                            BugError "Invalid 'disk $devname' entry (unknown DASD layout $layout)"
                            ;;
                    esac
                    test $disktype || Error "No partition label type for DASD entry 'disk $devname'"
                    blocksize=$( get_block_size "$blockd" )
                    if ! test $blocksize ; then
                        # fallback - ugly method
                        blocksize=$( dasdview -i $devname |grep blocksize|awk '{print $6}' )
                        test $blocksize || Error "Unknown block size of DASD $devname"
                    fi
                    dasdcyls=$( get_dasd_cylinders "$blockd" )
                    echo "# Disk $devname"
                    echo "# Format: disk <devname> <size(bytes)> <partition label type> <logical block size> <DASD layout> <DASD type> <size(cylinders)>"
                    echo "disk $devname $devsize $disktype $blocksize $layout $dasdtype $dasdcyls"
                else
                    Error "Invalid 'disk $devname' entry (DASD partition label on non-s390 arch $ARCH)"
                fi
                echo "# Partitions on $devname"
                echo "# Format: part <device> <partition size(bytes)> <partition start(bytes)> <partition type|name> <flags> /dev/<partition>"
                extract_partitions "$devname"
            fi
        fi
    done
} 1>>$DISKLAYOUT_FILE
# End of group command that appends its stdout to DISKLAYOUT_FILE

# parted and partprobe are required in the recovery system if disklayout.conf contains at least one 'disk' or 'part' entry
# see the create_disk and create_partitions functions in layout/prepare/GNU/Linux/100_include_partition_code.sh
# what program calls are written to diskrestore.sh and which programs will be run during "rear recover" in any case
# e.g. mdadm is not called in any case and sfdisk is only used in case of BLOCKCLONE_STRICT_PARTITIONING
# cf. https://github.com/rear/rear/issues/1963
grep -Eq '^disk |^part ' $DISKLAYOUT_FILE && REQUIRED_PROGS+=( parted partprobe ) || true

