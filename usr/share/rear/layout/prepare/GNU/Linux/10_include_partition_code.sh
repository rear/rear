# Generate code to partition the disks.

if ! has_binary parted; then
    return
fi

# Test for features of parted.

# True if parted accepts values in units other than mebibytes.
FEATURE_PARTED_ANYUNIT=
# True if parted can align partitions.
FEATURE_PARTED_ALIGNMENT=

# Test by using the parted version numbers...
parted_version=$(get_version parted -v)

[ "$parted_version" ]
BugIfError "Function get_version could not detect parted version."

if version_newer "$parted_version" 2.0 ; then
    # All features supported
    FEATURE_PARTED_ANYUNIT="y"
    FEATURE_PARTED_ALIGNMENT="y"
elif version_newer "$parted_version" 1.6.23 ; then
    FEATURE_PARTED_ANYUNIT="y"
fi

### Prepare a disk for partitioning/general usage.
create_disk() {
    local component disk size label junk
    read component disk size label junk < <(grep "^disk $1 " "$LAYOUT_FILE")

    ### Disks should be block devices.
    [[ -b "$disk" ]]
    BugIfError "Disk $disk is not a block device."

    ### Find out the actual disk size.
    local disk_size=$( get_disk_size $(get_sysfs_name "$disk") )

    [[ "$disk_size" ]]
    BugIfError "Could not determine size of disk $disk, please file a bug."

    [[ $disk_size -gt 0 ]]
    StopIfError "Disk $disk has size $disk_size, unable to continue."

    cat >> "$LAYOUT_CODE" <<EOF
Log "Stop mdadm and pause udev"
if [ -d "/dev/md" ] && ls /dev/md?* &>/dev/null; then
    mdadm --stop /dev/md?* >&2
fi
type -p udevadm >/dev/null && udevadm control --stop-exec-queue || udevcontrol stop_exec_queue
Log "Erasing MBR of disk $disk"
dd if=/dev/zero of=$disk bs=512 count=1
sync
EOF

    create_partitions "$disk" "$label"

    cat >> "$LAYOUT_CODE" <<EOF
Log "Resume udev"
type -p udevadm >/dev/null && udevadm control --start-exec-queue || udevcontrol start_exec_queue
# Wait some time before advancing
sleep 10

# Make sure device nodes are visible (eg. in RHEL4)
my_udevtrigger
my_udevsettle
EOF
}

### Create partitions on a block device.
### The block device does not necessarily exist yet...
create_partitions() {
    local device=$1
    local label=$2

    ### List partition types/names to detect disk label type.
    local -a names=()
    local part size pstart name junk
    while read part disk size pstart name junk ; do
        names=( "${names[@]}" $name )
        case $name in
            (primary|extended|logical)
                if [[ -z "$label" ]] ; then
                    Log "Disk label for $device detected as msdos."
                    label="msdos"
                fi
                ;;
        esac
    done < <( grep "^part $device " "$LAYOUT_FILE" )

    ### Early return for devices without partitions.
    if [[ ${#names[@]} -eq 0 ]] ; then
        Log "No partitions on device $device."
        return 0
    fi

    if [[ -z "$label" ]] ; then
        label="gpt"
        ### msdos label types are detected earlier.
    fi

    cat >> "$LAYOUT_CODE" <<EOF
LogPrint "Creating partitions for disk $device ($label)"
parted -s $device mklabel $label >&2
sleep 1
EOF

    local block_size device_size sysfs_name
    if [[ -b $device ]] ; then
        sysfs_name=$(get_sysfs_name "$device")
        if [[ "$sysfs_name" ]] && [[ -d "/sys/block/$sysfs_name" ]] ; then
            block_size=$( get_block_size "$sysfs_name" )
            device_size=$( get_disk_size  "$sysfs_name" )

            ### GPT disks need 33 LBA blocks at the end of the disk
            if [[ "$label" == "gpt" ]] ; then
                device_size=$(( device_size - 33*block_size ))
                if [[ "$MIGRATION_MODE" ]] ; then
                    Log "Size reductions of GPT partitions probably needed."
                fi
            fi
        fi
    fi

    local start end start_mb end_mb
    let start=32768 # start after one cylinder 63*512 + multiple of 4k = 64*512
    let end=0

    local flags partition
    while read part disk size pstart name flags partition junk; do

        ### If not in migration mode and start known, use original start.
        if [ -z "$MIGRATION_MODE" ] && ! [ "$pstart" = "unknown" ] ; then
            start="$pstart"
        fi

        end=$(( start + size ))

        ### Test to make sure we're not past the end of the disk.
        if [[ "$device_size" ]] && (( end > $device_size )) ; then
            LogPrint "Partition $name on $device: size reduced to fit on disk."
            Log "End changed from $end to $device_size."
            end="$device_size"
        fi

        ### Extended partitions run to the end of disk... (we assume).
        if [[ "$name" = "extended" ]] ; then
            if [[ "$device_size" ]] ; then
                end="$device_size"
            else
                ### We don't know the size of devices that don't exist yet
                ### replaced by "100%" later on.
                end=
            fi
        fi

        # The 'name' could contain spaces (were replaced with 0%20; need to change this again).
        name=$(echo "$name" | sed -e 's/0x20/ /g')

        if [[ "$FEATURE_PARTED_ANYUNIT" ]] ; then
            if [[ "$end" ]] ; then
                end="$(($end-1))B"
            else
                end="100%"
            fi
            cat >> "$LAYOUT_CODE" <<EOF
parted -s $device mkpart '"$name"' ${start}B $end >&2
sleep 1
EOF
        else
            ### Old versions of parted accept only sizes in megabytes...
            if (( $start > 0 )) ; then
                start_mb=$(( start/1024/1024 ))
            else
                start_mb=0
            fi
            end_mb=$(( end/1024/1024 ))
            cat  >> "$LAYOUT_CODE" <<EOF
parted -s $device mkpart '"$name"' $start_mb $end_mb >&2
sleep 1
EOF
        fi

        # the start of the next partition is where this one ends
        # We can't use $end because of extended partitions
        # extended partitions have a small actual size as reported by sysfs
        # in front of a logical partition should be at least 512B empty space
        if [ -n "$MIGRATION_MODE" ] && [ "$name" = "logical" ] ; then
            start=$(( start + ${size%B} + block_size ))
        else
            start=$(( start + ${size%B} ))
        fi

        # round starting size to next multiple of 4096
        # 4096 is a good match for most device's block size
        start=$( echo "$start" | awk '{printf "%u", $1+4096-($1%4096);}')

        # Get the partition number from the name
        local number=$(get_partition_number "$partition")

        local flags="$(echo $flags | tr ',' ' ')"
        local flag
        for flag in $flags ; do
            if [[ "$flag" = "none" ]] ; then
                continue
            fi
            echo "parted -s $device set $number $flag on >&2" >> $LAYOUT_CODE
        done

        # Explicitly name GPT partitions.
        if [[ "$label" = "gpt" ]] && [[ "$name" != "rear-noname" ]] ; then
            echo "parted -s $device name $number '\"$name\"' >&2" >> $LAYOUT_CODE
        fi
    done < <(grep "^part $device " $LAYOUT_FILE)

    # Ensure we have the new partitioning on the device.
    echo "partprobe -s $device >&2" >> "$LAYOUT_CODE"
}
