# Generate code to partition the disks.

# The parted command is mandatory,
# see https://github.com/rear/rear/issues/1933#issuecomment-430207057
has_binary parted || Error "Cannot find 'parted' command"

#
# TODO: clean up that old code when parted doesn't support any unit.
# It's there since ages!
#

# True if parted accepts values in units other than mebibytes.
FEATURE_PARTED_ANYUNIT=

# Test by using the parted version numbers...
parted_version=$( get_version parted -v )

test "$parted_version" || BugError "Function get_version could not detect parted version"

if version_newer "$parted_version" 1.6.23 ; then
    FEATURE_PARTED_ANYUNIT="y"
fi

### Prepare a disk for partitioning/general usage.
create_disk() {
    local component disk size label junk
    read component disk size label junk < <(grep "^disk $1 " "$LAYOUT_FILE")

    cat >> "$LAYOUT_CODE" <<EOF

#
# Code handling disk '$disk'
#

### Disks should be block devices.
[ -b "$disk" ] || BugError "Disk $disk is not a block device."

Log "Stop mdadm"
if grep -q md /proc/mdstat 2>/dev/null; then
    mdadm --stop -s >&2 || echo "stop mdadm failed"
    # Prevent udev waking up mdadm later.
    # Reasoning: At least on RHEL6 when parted created a raid partition on disk,
    # udev (via /lib/udev/rules.d/65-md-incremental.rules) wakes up mdadm which locks the disk,
    # so further parted commands with the disk will fail since the disk is busy now.
    # The /lib/udev/rules.d/65-md-incremental.rules detects anaconda (the Red Hat installer),
    # and if it find itself running under anaconda, it will not run.
    # Accordingly also for other installers (in particular the ReaR installer)
    # this rule should not be there (and other Linux distros probably do not have it)
    # which means removing it is the right solution to make ReaR work also for RHEL6:
    if [ -e /lib/udev/rules.d/65-md-incremental.rules ] ; then
        rm -f /lib/udev/rules.d/65-md-incremental.rules || echo "rm 65-md-incremental.rules failed"
    fi
fi
Log "Erasing MBR of disk $disk"
dd if=/dev/zero of=$disk bs=512 count=1
sync

EOF

    create_partitions "$disk" "$label"

    cat >> "$LAYOUT_CODE" <<EOF
# Make sure device nodes are visible (eg. in RHEL4)
my_udevtrigger
my_udevsettle

# Clean up transient partitions and resize shrinked ones
delete_dummy_partitions_and_resize_real_ones

#
# End of code handling disk '$disk'
#

EOF
}

### Create partitions on a block device.
### The block device does not necessarily exist yet...
create_partitions() {
    local device=$1
    local label=$2

    ### List partition types/names to detect disk label type.
    local -a names=()
    local part disk size pstart name junk
    while read part disk size pstart name junk ; do
        names+=( $name )
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
    # For the SUSE specific gpt_sync_mbr partitioning scheme
    # see https://github.com/rear/rear/issues/544
    # For 'gpt_sync_mbr' labeled disks create_partitions was called e.g. as
    #   create_partitions /dev/sda gpt_sync_mbr
    # so that $label is not empty but still set to 'gpt_sync_mbr' here.

    cat >> "$LAYOUT_CODE" <<EOF
create_disk_label $device $label
EOF

    # There are certrain conditions below that test for AUTORESIZE_PARTITIONS
    # but all what belongs to autoresizing partitions must only happen in MIGRATION_MODE:
    local autoresize_partitions=""
    is_true "$MIGRATION_MODE" && autoresize_partitions="$AUTORESIZE_PARTITIONS"

    local block_size device_size sysfs_name
    if [[ -b $device ]] ; then
        sysfs_name=$(get_sysfs_name "$device")
        if [[ "$sysfs_name" ]] && [[ -d "/sys/block/$sysfs_name" ]] ; then
            block_size=$( get_block_size "$sysfs_name" )
            device_size=$( get_disk_size  "$sysfs_name" )

            ### GPT disks need 33 LBA blocks at the end of the disk
            # For the SUSE specific gpt_sync_mbr partitioning scheme
            # see https://github.com/rear/rear/issues/544
            # see https://github.com/rear/rear/pull/2142 for s390 partitioning
            #if [[ "$label" == "gpt" || "$label" == "gpt_sync_mbr" || "$label" == "dasd" ]] ; then
            if [[ "$label" == "gpt" || "$label" == "gpt_sync_mbr" ]] ; then
                device_size=$( mathlib_calculate "$device_size - 33*$block_size" )
                # Only if resizing all partitions is explicity wanted
                # resizing of arbitrary partitions may also happen via the code below
                # in addition to layout/prepare/default/430_autoresize_all_partitions.sh
                if is_true "$autoresize_partitions" ; then
                    Log "Size reductions of GPT partitions probably needed."
                fi
            fi
        fi
    fi

    local start end start_mb end_mb number last_number
    # let start=32768 # start after one cylinder 63*512 + multiple of 4k = 64*512
    let start=2097152 # start after cylinder 4096*512 (for grub2 - see issue #492)
    let end=0
    let last_number=0

    local flags partition
    while read part disk size pstart name flags partition junk; do

        # Get the partition number from the name
        number=$( get_partition_number "$partition" )

        # Because parted creates partitions starting at number 1 consecutively,
        # we expect the partition numbers to be increasing. Failing to do so
        # will make the parted command setting the file system type die in
        # error.

        if [[ $number -lt $last_number ]] ; then
            # Admin probably reordered entries in disklayout.conf, die
            Error "Device '$disk': partitions are not defined in expected order (partitions must be specified in ascending number)"
        elif [[ $number -eq $last_number ]] ; then
            Error "Device '$disk': partition with number $number is already defined"
        elif [[ $( mathlib_calculate "$number - $last_number" ) -gt 1 ]] && [[ -z "$FEATURE_PARTED_ANYUNIT" ]] ; then 
            Error "Device '$disk': there are gaps between partitions, this is not supported"
        fi
        let last_number=$number

        # In layout/save/GNU/Linux/200_partition_layout.sh
        # in particular a GPT partition name that can contain spaces
        # like 'EFI System Partition' cf. https://github.com/rear/rear/issues/1563
        # was stored as a percent-encoded string in disklayout.conf
        # so that here it needs to be percent-decoded:
        name=$( percent_decode "$name" )

        # Use the partition start value in disklayout.conf
        # unless resizing all partitions is explicity wanted:
        if ! is_true "$autoresize_partitions" && test "$pstart" != "unknown" ; then
            start="$pstart"
        fi

        end=$(( start + size ))

        ### Test to make sure we're not past the end of the disk.
        if [[ "$device_size" ]] && (( end > $device_size )) ; then
            LogPrint "Partition $name on $device: size reduced to fit on disk."
            Log "End changed from $end to $device_size."
            end="$device_size"
        fi

        # Extended partitions run to the end of disk (we assume)
        # only if resizing all partitions is explicity wanted:
        if is_true "$autoresize_partitions" ; then
            if [[ "$name" = "extended" ]] ; then
                if [[ "$device_size" ]] ; then
                    end="$device_size"
                else
                    ### We don't know the size of devices that don't exist yet
                    ### replaced by "100%" later on.
                    end=
                fi
            fi
        fi

        # Avoid naming multiple partitions "rear-noname" as this will trigger systemd log messages
        # "Dev dev-disk-by\x2dpartlabel-rear\x2dnoname.device appeared twice with different sysfs paths"
        if [[ "$name" == "rear-noname" ]] ; then
            name="$(basename "$partition")"
        fi

        if [[ "$FEATURE_PARTED_ANYUNIT" ]] ; then
            if [[ "$end" ]] ; then
                end=$( mathlib_calculate "$end - 1" )
            fi
            if [[ "$ARCH" == "Linux-s390" ]] ; then
                # LDL formatted disks are already partitioned and should not be partitioned with parted or fdasd , it will fail
                # the listDasdLdl array contains devices such as /dev/dasdb that are formatted as LDL
                # listDasdLdl is set in layout/prepare/Linux-s390/205_s390_enable_disk.sh 
                if ! IsInArray "$device" "${listDasdLdl[@]}" ; then
                    echo "not LDL dasd formated disk, create a partition"
                    cat >> "$LAYOUT_CODE" <<EOF
create_disk_partition "$device" "$name" $number $start $end
EOF
                fi
            else
                # default case when $ARCH is not "Linux-s390":
                cat >> "$LAYOUT_CODE" <<EOF
create_disk_partition "$device" "$name" $number $start $end
EOF
            fi
        else
            ### Old versions of parted accept only sizes in megabytes...
            if (( $start > 0 )) ; then
                start_mb=$( mathlib_calculate "$start / 1024 / 1024" )
            else
                start_mb=0
            fi
            end_mb=$( mathlib_calculate "$end / 1024 / 1024" )
            # The duplicated quoting "'$name'" is there because
            # parted's internal parser needs single quotes for values with blanks.
            # In particular a GPT partition name that can contain spaces
            # like 'EFI System Partition' cf. https://github.com/rear/rear/issues/1563
            # so that when calling parted on command line it must be done like
            #    parted -s /dev/sdb unit MiB mkpart "'partition name'" 12 34
            # where the outer quoting "..." is for bash so that
            # the inner quoting '...' is preserved for parted's internal parser:
            cat  >> "$LAYOUT_CODE" <<EOF
my_udevsettle
parted -s $device mkpart "'$name'" $start_mb $end_mb >&2
my_udevsettle
EOF
        fi

        # Only if resizing all partitions is explicity wanted
        # the start of the next partition is where this one ends.
        # We can't use $end for extended partitions
        # extended partitions have a small actual size as reported by sysfs
        # but this issue is meanwhile fixed via https://github.com/rear/rear/pull/1733 by
        # https://github.com/rear/rear/pull/1733/commits/6efb681d8b4c6a4d9f20b2900bbea79548c624a8
        # Additionally in front of a logical partition should be at least 512B empty space
        # which is probably wrong because certain places in the Internet mention a required gap
        # of at least 63 sectors (63 * 512 bytes) between extended partition and logical partition
        # e.g. cf. the German Wikipedia article about Master Boot Record that reads (excerpts):
        #   Primaere und erweiterte Partitionstabelle
        #   ...
        #   Alte Betriebssysteme erwarten den Start einer Partition immer an den Zylindergrenzen.
        #   Daher ergibt sich auch heute noch bei verbreiteten Betriebssystemen eine Luecke
        #   von 63 Sektoren zwischen erweiterter Partitionstabelle und dem Startsektor
        #   der entsprechenden logischen Partition.
        if is_true "$autoresize_partitions" && test "$name" = "logical" ; then
            # Without analysis I <jsmeix@suse.de> think by plain looking at the code
            # that this '+ $block_size' results bad alignment because it usually adds 512B
            # to the 'small actual size as reported by sysfs' which is e.g. 2 * 512B
            # so that the result is the original start of disklayout.conf + 3 * 512B
            # i.e. a new partition alignment to '3 * 512B' units:
            start=$( mathlib_calculate "$start + ${size%B} + $block_size" )
        else
            start=$( mathlib_calculate "$start + ${size%B}" )
        fi

        # round starting size to next multiple of 4096
        # 4096 is a good match for most device's block size
        # only if resizing all partitions is explicity wanted:
        if is_true "$autoresize_partitions" ; then
            start=$(( $start + 4096 - ( $start % 4096 ) ))
        fi

        local flags="$( echo $flags | tr ',' ' ' )"
        local flag
        for flag in $flags ; do
            if [[ "$flag" = "none" ]] ; then
                continue
            fi
            (
            echo "my_udevsettle"
            echo "parted -s $device set $number $flag on >&2"
            echo "my_udevsettle"
            ) >> $LAYOUT_CODE
        done

        # Explicitly name GPT partitions.
        # For the SUSE specific gpt_sync_mbr partitioning scheme
        # see https://github.com/rear/rear/issues/544
        # The quoted duplicated quoting \"'$name'\" is there because
        # parted's internal parser needs single quotes for values with blanks.
        # In particular a GPT partition name that can contain spaces
        # like 'EFI System Partition' cf. https://github.com/rear/rear/issues/1563
        # so that when calling parted on command line it must be done like
        #    parted -s /dev/sdb unit MiB mkpart "'partition name'" 12 34
        # where the outer quoting "..." is for bash which neeeds to be quoted \"...\" here
        # because there is a outermost quoting "..." of the echo command
        # and the inner quoting '...' is preserved for parted's internal parser:
        if [[ "$label" = "gpt" || "$label" == "gpt_sync_mbr" ]] && [[ "$name" != "rear-noname" ]] ; then
            (
            echo "my_udevsettle"
            echo "parted -s $device name $number \"'$name'\" >&2"
            echo "my_udevsettle"
            ) >> $LAYOUT_CODE
        fi
    done < <(grep "^part $device " $LAYOUT_FILE)

    # This will override all partition setup previously made,
    # and create exact copy of original disk layout
    # (ugly, ugly, ugly, but works)
    # TODO: add code for GPT
    if is_true "$BLOCKCLONE_STRICT_PARTITIONING" && [ -n "$BLOCKCLONE_SAVE_MBR_DEV" ]; then
        (
        echo ""
        echo "# WARNING:"
        echo "# This code will overwrite all partition changes previously made."
        echo "# If you want avoid this, set BLOCKCLONE_STRICT_PARTITIONING=\"no\""
        echo "sfdisk $device < $VAR_DIR/layout/$BLOCKCLONE_PARTITIONS_CONF_FILE"
        echo "dd if=$VAR_DIR/layout/$BLOCKCLONE_MBR_FILE of=$device bs=446 count=1"
        echo ""
        ) >> "$LAYOUT_CODE"
    fi

    # Try to ensure the kernel uses the new partitioning
    # see https://github.com/rear/rear/issues/793
    # First do a hardcoded sleep of 1 second so that
    # the kernel and udev get a bit of time to process
    # automated "read partition table changes" triggers
    # of nowadays parted.
    # Then to be backward compatible with traditional parted
    # call partprobe explicitly to trigger the kernel
    # to "read partition table changes" and if that fails
    # wait 10 seconds before a first retry and if that fails
    # wait 60 seconds before a final retry and if that fails
    # ignore that failure and proceed "bona fide" because
    # nowadays it should "just work" regardless of partprobe.
    (
    echo "sleep 1"
    echo "if ! partprobe -s $device >&2 ; then"
    echo "    LogPrint 'retrying partprobe $device after 10 seconds' "
    echo "    sleep 10"
    echo "    if ! partprobe -s $device >&2 ; then"
    echo "        LogPrint 'retrying partprobe $device after 1 minute' "
    echo "        sleep 60"
    echo "        if ! partprobe -s $device >&2 ; then"
    echo "            LogPrint 'partprobe $device failed, proceeding bona fide' "
    echo "        fi"
    echo "    fi"
    echo "fi"
    ) >> "$LAYOUT_CODE"
}

# vim: set et ts=4 sw=4:
