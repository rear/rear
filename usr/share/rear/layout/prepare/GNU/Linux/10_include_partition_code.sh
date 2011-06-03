# Generate code to partition the disks

if ! type -p parted &>/dev/null ; then
    return
fi

# Test for features in parted

# true if parted accepts values in units other than mebibytes
FEATURE_PARTED_ANYUNIT=
# true if parted can align partitions
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

# Partition a disk
partition_disk() {
    local component disk size label junk
    read component disk size label junk <$1

    if [ -z "$label" ] ; then
        # LVM on whole disk can lead to no label available.
        Log "No disk label information for disk $disk."
        return 0
    fi

    # Find out the actual disk size
    local disk_size=$( get_disk_size "$disk" )

    [ "$disk_size" ]
    BugIfError "Could not determine size of disk $disk, please file a bug."

    [ $disk_size -gt 0 ]
    StopIfError "Disk $disk has size $disk_size, unable to continue."

    cat >> $LAYOUT_CODE <<EOF
LogPrint "Creating partitions for disk $disk ($label)"
parted -s $disk mklabel $label 1>&2
EOF

    local start end start_mb end_mb
    let start=32768 # start after one cylinder 63*512 + multiple of 4k = 64*512
    let end=0

    local part odisk size parttype flags name junk
    while read part odisk size parttype flags name junk; do
        
        # calculate the end of the partition.
        let end=$start+$size
        
        # test to make sure we're not past the end of the disk
        if [ $end -gt $disk_size ] ; then
            LogPrint "Partition $name size reduced to fit on disk."
            let end=$disk_size
        fi
        
        # extended partitions run to the end of disk...
        if [ "$parttype" = "extended" ] ; then
            let end=$disk_size
        fi
        
        if [ -n "$FEATURE_PARTED_ANYUNIT" ] ; then
cat <<EOF >> $LAYOUT_CODE
parted -s $disk mkpart $parttype ${start}B $(($end-1))B 1>&2
EOF
        else
            # Old versions of parted accept only sizes in megabytes...
            if [ $start -gt 0 ] ; then
                let start_mb=$start/1024/1024
            else
                start_mb=0
            fi
            let end_mb=$end/1024/1024
cat <<EOF >> $LAYOUT_CODE
parted -s $disk mkpart $parttype $start_mb $end_mb 1>&2
EOF
        fi

        # the start of the next partition is where this one ends
        # We can't use $end because of extended partitions
        # extended partitions have a small actual size as reported by sysfs
        let start=$start+${size%B}
        
        # round starting size to next multiple of 4096
        # 4096 is a good match for most device's block size
        start=$( echo "$start" | awk '{print $1+4096-($1%4096);}')
        
        # Get the partition number from the name
        local number=$(echo "$name" | grep -o -E "[0-9]+$")
        
        local flags="$(echo $flags | tr ',' ' ')"
        local flag
        for flag in $flags ; do
            if [ "$flag" = "none" ] ; then
                continue
            fi
            echo "parted -s $disk set $number $flag on 1>&2" >> $LAYOUT_CODE
        done
    done < <(grep "^part $disk" $LAYOUT_FILE)

cat >> $LAYOUT_CODE <<EOF
# Wait some time before advancing
sleep 10

# Make sure device nodes are visible (eg. in RHEL4)
my_udevtrigger
my_udevsettle
EOF
}
