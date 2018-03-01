#
# layout/prepare/default/420_autoresize_last_partitions.sh
#
# Try to automatically resize active last partitions on all active disks
# if the disk size had changed (i.e. only in migration mode).
#
# When AUTORESIZE_PARTITIONS is false, no partition is resized.
#
# When AUTORESIZE_PARTITIONS is true, all active partitions on all active disks
# get resized by the separated 430_autoresize_all_partitions.sh script. 
#
# A true or false value must be the first one in the AUTORESIZE_PARTITIONS array.
#
# When the first value in AUTORESIZE_PARTITIONS is neither true nor false
# only the last active partition on each active disk gets resized.
#
# All other values in the AUTORESIZE_PARTITIONS array specify partition device nodes
# e.g. as in AUTORESIZE_PARTITIONS=( /dev/sda2 /dev/sdb3 )
# where last partitions with those partition device nodes should be resized
# regardless of what is specified in the AUTORESIZE_EXCLUDE_PARTITIONS array.
#
# The values in the AUTORESIZE_EXCLUDE_PARTITIONS array specify partition device nodes
# where partitions with those partition device nodes are excluded from being resized.
# The special values 'boot', 'swap', and 'efi' specify that
#  - partitions where its filesystem mountpoint contains 'boot' or 'bios' or 'grub'
#    or where its GPT name or flags contain 'boot' or 'bios' or 'grub' (anywhere case insensitive)
#  - partitions for which an active 'swap' entry exists in disklayout.conf
#    or where its GPT name or flags contain 'swap' (anywhere case insensitive)
#  - partitions where its filesystem mountpoint contains 'efi' or 'esp'
#    or where its GPT name or flags contains 'efi' or 'esp' (anywhere case insensitive)
# are excluded from being resized e.g. as in
# AUTORESIZE_EXCLUDE_PARTITIONS=( boot swap efi /dev/sdb3 /dev/sdc4 )
#
# The last active partition on each active disk gets resized but nothing more.
# In particular this does not resize volumes on top of the affected partitions.
# To migrate volumes on disk where the disk size had changed the user must in advance
# manually adapt his disklayout.conf file before he runs "rear recover".
#
# In general ReaR is not meant to somehow "optimize" a system during "rear recover".
# ReaR is meant to recreate a system as much as possible exactly as it was before.
# Accordingly this automated resizing implements a "minimal changes" approach:
#
# When the new disk is a bit smaller (at most AUTOSHRINK_DISK_SIZE_LIMIT_PERCENTAGE percent),
# only the last (active) partition gets shrinked but all other partitions are not changed.
# When the new disk is smaller than AUTOSHRINK_DISK_SIZE_LIMIT_PERCENTAGE percent it errors out.
# To migrate onto a substantially smaller new disk the user must in advance
# manually adapt his disklayout.conf file before he runs "rear recover".
#
# When the new disk is only a bit bigger (less than AUTOINCREASE_DISK_SIZE_THRESHOLD_PERCENTAGE percent),
# no partition gets increased (which leaves the bigger disk space at the end of the disk unused).
# When the new disk is substantially bigger (at least AUTOINCREASE_DISK_SIZE_THRESHOLD_PERCENTAGE percent),
# only the last (active) partition gets increased but all other partitions are not changed.
# To migrate various partitions onto a substantially bigger new disk the user must in advance
# manually adapt his disklayout.conf file before he runs "rear recover".
#
# Because only the end value of the last partition may get changed, the partitioning alignment
# of the original system is not changed, cf. https://github.com/rear/rear/issues/102
#
# Because only the last active (i.e. not commented in disklayout.conf) partition on a disk
# may get changed, things go wrong if another partition is actually the last one on the disk
# but that other partition is commented in disklayout.conf (e.g. because that partition
# is a partition of another operating system that is not mounted during "rear mkrescue").
# To migrate a system with a non-active last partition onto a bigger or smaller new disk
# the user must in advance manually adapt his disklayout.conf file before he runs "rear recover".

# Skip if not in migration mode:
is_true "$MIGRATION_MODE" || return 0

# Skip if automatically resize partitions is explicity unwanted:
is_false "$AUTORESIZE_PARTITIONS" && return 0

# Skip resizing only the last partition if resizing all partitions is explicity wanted
# which is done by the separated 430_autoresize_all_partitions.sh script:
is_true "$AUTORESIZE_PARTITIONS" && return 0

# Write new disklayout with resized partitions to LAYOUT_FILE.resized_last_partition:
local disklayout_resized_last_partition="$LAYOUT_FILE.resized_last_partition"
cp "$LAYOUT_FILE" "$disklayout_resized_last_partition"
save_original_file "$LAYOUT_FILE"

# Set fallbacks if mandatory values are not set (should be set in default.conf):
test "$AUTORESIZE_EXCLUDE_PARTITIONS" || AUTORESIZE_EXCLUDE_PARTITIONS=( boot swap efi )
test "$AUTOINCREASE_DISK_SIZE_THRESHOLD_PERCENTAGE" || AUTOINCREASE_DISK_SIZE_THRESHOLD_PERCENTAGE=10
test "$AUTOSHRINK_DISK_SIZE_LIMIT_PERCENTAGE" || AUTOSHRINK_DISK_SIZE_LIMIT_PERCENTAGE=2
# Avoid 'set -e -u' exit because of "AUTORESIZE_PARTITIONS[@]: unbound variable"
# note that an empty array AUTORESIZE_PARTITIONS=() does not help here:
test "$AUTORESIZE_PARTITIONS" || AUTORESIZE_PARTITIONS=''

# Try to care about possible errors
# see https://github.com/rear/rear/wiki/Coding-Style
set -e -u -o pipefail

# The original disk space usage was written by layout/save/GNU/Linux/510_current_disk_usage.sh
local original_disk_space_usage_file="$VAR_DIR/layout/config/df.txt"

local component_type junk
local disk_device old_disk_size
local sysfsname new_disk_size
local max_part_start last_part_dev last_part_start last_part_size last_part_type last_part_flags last_part_end
local extended_part_dev extended_part_start extended_part_size
local disk_dev part_size part_start part_type part_flags part_dev
local last_part_is_resizeable last_part_filesystem_entry last_part_filesystem_mountpoint egrep_pattern
local last_part_is_boot last_part_is_swap last_part_is_efi
local extended_part_to_be_increased
local MiB new_disk_size_MiB new_disk_remainder_start new_last_part_size new_extended_part_size
local last_part_disk_space_usage last_part_used_bytes
local disk_size_difference increase_threshold_difference last_part_shrink_difference max_shrink_difference

# Example 'disk' entries in disklayout.conf:
#
#   # Disk /dev/sda
#   # Format: disk <devname> <size(bytes)> <partition label type>
#   disk /dev/sda 21474836480 msdos
#
#   # Disk /dev/sdb
#   # Format: disk <devname> <size(bytes)> <partition label type>
#   disk /dev/sdb 2147483648 msdos
#
while read component_type disk_device old_disk_size junk ; do
    DebugPrint "Examining $disk_device to automatically resize its last active partition"

    sysfsname=$( get_sysfs_name $disk_device )
    test "$sysfsname" || Error "Failed to get_sysfs_name() for $disk_device"
    test -d "/sys/block/$sysfsname" || Error "No '/sys/block/$sysfsname' directory for $disk_device"

    new_disk_size=$( get_disk_size "$sysfsname" )
    is_positive_integer $new_disk_size || Error "Failed to get_disk_size() for $disk_device"
    # Skip if the size of the new disk (e.g. sda) is same as the size of the old disk (e.g. also sda):
    if test $new_disk_size -eq $old_disk_size ; then
        DebugPrint "Skipping $disk_device (size of new disk same as size of old disk)"
        continue
    fi

    # Find the last partition for the current disk in disklayout.conf:
    # Example partitions 'part' entries in disklayout.conf:
    #
    #   # Partitions on /dev/sda
    #   # Format: part <device> <partition size(bytes)> <partition start(bytes)> <partition type|name> <flags> /dev/<partition>
    #   part /dev/sda 1569718272 1048576 primary none /dev/sda1
    #   part /dev/sda 19904069632 1570766848 primary boot /dev/sda2
    #
    #   # Partitions on /dev/sdb
    #   # Format: part <device> <partition size(bytes)> <partition start(bytes)> <partition type|name> <flags> /dev/<partition>
    #   part /dev/sdb 838860800 8388608 primary none /dev/sdb1
    #   part /dev/sdb 419430400 847249408 primary none /dev/sdb2
    #   part /dev/sdb 524288000 1266679808 extended lba /dev/sdb3
    #   part /dev/sdb 95420416 1267728384 logical none /dev/sdb5
    #   part /dev/sdb 209715200 1468006400 logical none /dev/sdb6
    #
    # Note the gaps around the second logical partition /dev/sdb6 and
    # the gap from the end of the extended partition to the end of the sdb disk
    # (see above the sdb disk size is 2147483648):
    #   1208MiB start extended
    #   1209MiB start logical1
    #   1300MiB end logical1
    #   gap
    #   1400MiB start logical2
    #   1600MiB end logical2
    #   gap
    #   1708MiB end extended
    #   gap
    #   2048MiB end disk
    # cf. https://github.com/rear/rear/pull/1733#issuecomment-367317079
    #
    # The last partition is the /dev/<partition> with biggest <partition start(bytes)> value.
    max_part_start=0
    last_part_dev=""
    last_part_start=0
    last_part_size=0
    extended_part_dev=""
    extended_part_start=0
    extended_part_size=0
    while read component_type disk_dev part_size part_start part_type part_flags part_dev junk ; do
        DebugPrint "Checking $part_dev if it is the last partition on $disk_device"
        if test $part_start -ge $max_part_start ; then
            max_part_start=$part_start
            last_part_dev="$part_dev"
            last_part_start="$part_start"
            last_part_size="$part_size"
            last_part_type="$part_type"
            last_part_flags="$part_flags"
            last_part_end=$( mathlib_calculate "$last_part_start + $last_part_size - 1" )
        fi
        # Remember the values of an extended partition to be able
        # to also adjust the end value of the extended "container" partition
        # when the last partition is a logical partition
        # cf. https://github.com/rear/rear/pull/1733#issuecomment-367317079
        # because only at most one extended partition is allowed
        # cf. https://de.wikipedia.org/wiki/Master_Boot_Record#Prim%C3%A4re_und_erweiterte_Partitionstabelle
        # it is sufficient to remember at most one single extended_part_size value:
        if test "extended" = "$part_type" ; then
            DebugPrint "Found extended partition $part_dev on $disk_device"
            extended_part_dev="$part_dev"
            extended_part_start="$part_start"
            extended_part_size="$part_size"
        fi
    done < <( grep "^part $disk_device" "$LAYOUT_FILE" )
    test "$last_part_dev" || Error "Failed to determine device node for last partition on $disk_device"
    is_positive_integer $last_part_start || Error "Failed to determine partition start for $last_part_dev"
    DebugPrint "Found '$last_part_type' partition $last_part_dev as last partition on $disk_device"

    # Determine if the last partition is resizeable:
    DebugPrint "Determining if last partition $last_part_dev is resizeable"
    last_part_is_resizeable=""
    if IsInArray "$last_part_dev" ${AUTORESIZE_PARTITIONS[@]} ; then
        last_part_is_resizeable="yes"
        DebugPrint "Last partition should be resized ($last_part_dev in AUTORESIZE_PARTITIONS)"
    else
        # Example filesystem 'fs' entry in disklayout.conf (excerpt):
        #  # Format: fs <device> <mountpoint> <fstype> ...
        #  fs /dev/sda3 /boot/efi vfat ...
        last_part_filesystem_entry=( $( grep "^fs $last_part_dev " "$LAYOUT_FILE" ) )
        last_part_filesystem_mountpoint="${last_part_filesystem_entry[2]}"
        # Intentionally all tests to exclude a partition from being resized are run
        # to get all reasons shown (in the log) why one same partition is not resizeable.
        # Do not resize partitions that are explicitly specified to be excluded from being resized:
        if IsInArray "$last_part_dev" ${AUTORESIZE_EXCLUDE_PARTITIONS[@]} ; then
            last_part_is_resizeable="no"
            DebugPrint "Last partition $last_part_dev not resizeable (excluded from being resized in AUTORESIZE_EXCLUDE_PARTITIONS)"
        fi
        # Do not resize partitions that are used during boot:
        if IsInArray "boot" ${AUTORESIZE_EXCLUDE_PARTITIONS[@]} ; then
            last_part_is_boot=''
            # A partition is considered to be used during boot
            # when its GPT name or flags contain 'boot' or 'bios' or 'grub' (anywhere case insensitive):
            egrep_pattern='boot|bios|grub'
            grep -E -i "$egrep_pattern" <<< $( echo $last_part_type ) && last_part_is_boot="yes"
            grep -E -i "$egrep_pattern" <<< $( echo $last_part_flags ) && last_part_is_boot="yes"
            # Also test if the mountpoint of the filesystem of the partition
            # contains 'boot' or 'bios' or 'grub' (anywhere case insensitive)
            # because it is not reliable to assume that the boot flag is set in the partition table,
            # cf. https://github.com/rear/rear/commit/91a6d2d11d2d605e7657cbeb95847497b385e148
            grep -E -i "$egrep_pattern" <<< $( echo $last_part_filesystem_mountpoint ) && last_part_is_boot="yes"
            if is_true "$last_part_is_boot" ; then
                last_part_is_resizeable="no"
                DebugPrint "Last partition $last_part_dev not resizeable (used during boot)"
            fi
        fi
        # Do not resize partitions that are used as swap partitions:
        if IsInArray "swap" ${AUTORESIZE_EXCLUDE_PARTITIONS[@]} ; then
            last_part_is_swap=''
            # Do not resize a partition for which an active 'swap' entry exists,
            # cf. https://github.com/rear/rear/issues/71
            grep "^swap $last_part_dev " "$LAYOUT_FILE" && last_part_is_swap="yes"
            # A partition is considered to be used as swap partition
            # when its GPT name or flags contain 'swap' (anywhere case insensitive):
            grep -i 'swap' <<< $( echo $last_part_type ) && last_part_is_swap="yes"
            grep -i 'swap' <<< $( echo $last_part_flags ) && last_part_is_swap="yes"
            if is_true "$last_part_is_swap" ; then
                last_part_is_resizeable="no"
                DebugPrint "Last partition $last_part_dev not resizeable (used as swap partition)"
            fi
        fi
        # Do not resize partitions that are used for UEFI:
        if IsInArray "efi" ${AUTORESIZE_EXCLUDE_PARTITIONS[@]} ; then
            last_part_is_efi=''
            # A partition is considered to be used for UEFI
            # when its GPT name or flags contain 'efi' or 'esp' (anywhere case insensitive):
            egrep_pattern='efi|esp'
            grep -E -i "$egrep_pattern" <<< $( echo $last_part_type ) && last_part_is_efi="yes"
            grep -E -i "$egrep_pattern" <<< $( echo $last_part_flags ) && last_part_is_efi="yes"
            # Also test if the mountpoint of the filesystem of the partition
            # contains 'efi' or 'esp' (anywhere case insensitive):
            grep -E -i "$egrep_pattern" <<< $( echo $last_part_filesystem_mountpoint ) && last_part_is_efi="yes"
            if is_true "$last_part_is_efi" ; then
                last_part_is_resizeable="no"
                DebugPrint "Last partition $last_part_dev not resizeable (used for UEFI)"
            fi
        fi
    fi

    # Determine if an extended partition should be increased
    # independent of whether or not the last partition will be also increased:
    if test "$extended_part_dev" ; then
        extended_part_to_be_increased=""
        if IsInArray "$extended_part_dev" ${AUTORESIZE_PARTITIONS[@]} ; then
            extended_part_to_be_increased="yes"
            DebugPrint "Extended partition should be increased ($extended_part_dev in AUTORESIZE_PARTITIONS)"
        fi
    fi

    # Determine the desired new size of the last partition (with 1 MiB alignment)
    # so that the new sized last partition would go up to the end of the new disk:
    DebugPrint "Determining new size for last partition $last_part_dev"
    MiB=$( mathlib_calculate "1024 * 1024" )
    # mathlib_calculate cuts integer remainder so that for a disk of e.g. 12345.67 MiB size new_disk_size_MiB = 12345
    new_disk_size_MiB=$( mathlib_calculate "$new_disk_size / $MiB" )
    # The first byte of the unusable remainder (with 1 MiB alignment) is the first byte after the last MiB on the disk
    # i.e. the first byte after the last MiB on a disk is the start of the unused disk space remainder at the end.
    # This value has same semantics as the partition start values (which are the first byte of a partition).
    # For a disk of 12345.67 MiB size the new_disk_remainder_start = 12944670720
    new_disk_remainder_start=$( mathlib_calculate "$new_disk_size_MiB * $MiB" )
    # When last_part_start is e.g. at 12300.00 MiB = at the byte 12897484800
    # then new_last_part_size = 12944670720 - 12897484800 = 45.00 MiB
    # so that on a disk of e.g. 12345.67 MiB size the last 0.67 MiB is left unused (as intended for 1 MiB alignment):
    new_last_part_size=$( mathlib_calculate "$new_disk_remainder_start - $last_part_start" )

    # When the desired new size of the last partition (with 1 MiB alignment) is not at least 1 MiB
    # the last partition can no longer be on the new disk (when only the last partition is shrinked):
    test $new_last_part_size -ge $MiB || Error "No space for last partition $last_part_dev on new disk (new last partition size would be less than 1 MiB)"

    # When the last partition is a logical partition determine the desired new size
    # of its extended "container" partition (with 1 MiB alignment) so that
    # also the new sized extended partition would go up to the end of the new disk.
    # When new_extended_part_size is zero it means that there is no extended partition
    # or it means that an existing extended partition does not need to be resized
    # (e.g. because the last partition is a primary partition after the extended partition):
    new_extended_part_size=0
    if test "logical" = "$last_part_type" ; then
        new_extended_part_size=$( mathlib_calculate "$new_disk_remainder_start - $extended_part_start" )
    fi

    # When the desired new size of the last partition is not at least its original disk space usage
    # the new last partition would be too small if the files of the last partition were restored from the backup
    # but it is unknown here whether any files of the last partition are included in the backup so that
    # it cannot be an Error() here when the new last partition is smaller than its original disk space usage
    # but at least the user gets informed here about the possible problem.
    # Example original_disk_space_usage_file content (in MiB units, 1 MiB = 1024 * 1024 = 1048576):
    #   Filesystem     1048576-blocks    Used Available Capacity Mounted on
    #   /dev/sdb5             143653M 115257M    27358M      81% /
    #   /dev/sdb3                161M      5M      157M       3% /boot/efi
    #   /dev/sda2             514926M    983M   487765M       1% /data
    last_part_disk_space_usage=( $( grep "^$last_part_dev " $original_disk_space_usage_file ) )
    last_part_used_bytes=$( mathlib_calculate "${last_part_disk_space_usage[2]%%M*} * $MiB" )
    # Neither original_disk_space_usage_file may exist nor may it contain an entry for last_part_dev
    # so that the two above commands may fail but the next test ensures last_part_used_bytes is valid:
    if is_positive_integer $last_part_used_bytes ; then
        # One of the rare cases where a "WARNING" is justified (see above why we cannot error out here)
        # cf. http://blog.schlomo.schapiro.org/2015/04/warning-is-waste-of-my-time.html
        test $new_last_part_size -ge $last_part_used_bytes || LogUserOutput "WARNING: New size of last partition $last_part_dev will be smaller than its disk usage was"
    fi

    # Determine if an extended partition actually needs to be shrinked or should be increased and do it if needed.
    # If new_extended_part_size has a positive value it means the last partition is a logical partition (cf. above)
    # which means there is no further partition beyond the end of the extended partition
    # (only one extended partition is allowed so that all logical partitions must be in one extended partition)
    # so that the extended partition can actually be shrinked or increased:
    if is_positive_integer $new_extended_part_size ; then
        # The extended partition actually needs to be shrinked (regardless if the last partition needs to be shrinked)
        # if the new size (which is up to the end of the new disk) is smaller than it was on the old disk because
        # otherwise the end of the extended partition would be beyond the end of the new disk (with 1 MiB alignment):
        if test $new_extended_part_size -lt $extended_part_size ; then
            LogPrint "Shrinking extended partition $extended_part_dev to end of disk"
            sed -r -i "s|^part $disk_device $extended_part_size $extended_part_start (.+) $extended_part_dev\$|part $disk_device $new_extended_part_size $extended_part_start \1 $extended_part_dev|" "$disklayout_resized_last_partition"
            LogPrint "Shrinked extended partition $extended_part_dev size from $extended_part_size to $new_extended_part_size bytes"
            # Set new_extended_part_size to zero to avoid that the extended partition
            # will be also shrinked when the last partition gets actually shrinked below:
            new_extended_part_size=0
        fi
        # The extended partition should be increased independent of whether or not the last partition will be also increased:
        if is_true "$extended_part_to_be_increased" ; then
            # The extended partition can only be actually increased (regardless if the last partition will also be increased)
            # if the new size (which is up to the end of the new disk) is greater than it was on the old disk (with 1 MiB alignment):
            if test $new_extended_part_size -gt $extended_part_size ; then
                LogPrint "Increasing extended partition $extended_part_dev to end of disk"
                sed -r -i "s|^part $disk_device $extended_part_size $extended_part_start (.+) $extended_part_dev\$|part $disk_device $new_extended_part_size $extended_part_start \1 $extended_part_dev|" "$disklayout_resized_last_partition"
                LogPrint "Increased extended partition $extended_part_dev size from $extended_part_size to $new_extended_part_size bytes"
                # Set new_extended_part_size to zero to avoid that the extended partition
                # will be also increased when the last partition gets actually increased below:
                new_extended_part_size=0
            else
                # Inform the user when the extended partition cannot be resized regardless of his setting in AUTORESIZE_PARTITIONS:
                LogPrint "Extended partition $extended_part_dev cannot be increased (new size less than what it was on old disk)"
            fi
        fi
    fi

    # Determine if the last partition actually needs to be increased or shrinked and
    # go on or error out or continue with the next disk depending on the particular case:
    DebugPrint "Determining if last partition $last_part_dev actually needs to be increased or shrinked"
    disk_size_difference=$( mathlib_calculate "$new_disk_size - $old_disk_size" )
    if test $disk_size_difference -gt 0 ; then
        # The size of the new disk is bigger than the size of the old disk:
        DebugPrint "New $disk_device is $disk_size_difference bigger than old disk"
        increase_threshold_difference=$( mathlib_calculate "$old_disk_size / 100 * $AUTOINCREASE_DISK_SIZE_THRESHOLD_PERCENTAGE" )
        if test $disk_size_difference -lt $increase_threshold_difference ; then
            if is_true "$last_part_is_resizeable" ; then
                # Inform the user when last partition cannot be resized regardless of his setting in AUTORESIZE_PARTITIONS:
                LogPrint "Last partition $last_part_dev cannot be resized (new disk less than $AUTOINCREASE_DISK_SIZE_THRESHOLD_PERCENTAGE% bigger)"
            else
                DebugPrint "Skip increasing last partition $last_part_dev (new disk less than $AUTOINCREASE_DISK_SIZE_THRESHOLD_PERCENTAGE% bigger)"
            fi
            # Continue with next disk:
            continue
        fi
        if is_false "$last_part_is_resizeable" ; then
            DebugPrint "Skip increasing last partition $last_part_dev (not resizeable)"
            # Continue with next disk:
            continue
        fi
        test $new_last_part_size -ge $last_part_size || BugError "New last partition size $new_last_part_size is not bigger than old size $last_part_size"
        LogPrint "Increasing last partition $last_part_dev up to end of disk (new disk at least $AUTOINCREASE_DISK_SIZE_THRESHOLD_PERCENTAGE% bigger)"
        is_positive_integer $new_extended_part_size && LogPrint "Increasing extended partition $extended_part_dev up to end of disk"
    else
        # The size of the new disk is smaller than the size of the old disk:
        # Currently disk_size_difference is negative but we prefer to use its absolute value:
        disk_size_difference=$( mathlib_calculate "0 - $disk_size_difference" )
        DebugPrint "New $disk_device is $disk_size_difference smaller than old disk"
        # There is no need to shrink the last partition when the original last partition still fits on the new smaller disk:
        if test $last_part_end -le $new_disk_remainder_start ; then
            if is_true "$last_part_is_resizeable" ; then
                # Inform the user when last partition will not be resized regardless of his setting in AUTORESIZE_PARTITIONS:
                LogPrint "Last partition $last_part_dev will not be resized (original last partition still fits on the new smaller disk)"
            else
                DebugPrint "Skip shrinking last partition $last_part_dev (original last partition still fits on the new smaller disk)"
            fi
            # Continue with next disk:
            continue
        fi
        last_part_shrink_difference=$( mathlib_calculate "$last_part_size - $new_last_part_size" )
        LogPrint "Last partition $last_part_dev must be shrinked by $last_part_shrink_difference bytes to still fit on disk"
        max_shrink_difference=$( mathlib_calculate "$old_disk_size / 100 * $AUTOSHRINK_DISK_SIZE_LIMIT_PERCENTAGE" )
        if test $disk_size_difference -gt $max_shrink_difference ; then
            Error "Last partition $last_part_dev cannot be shrinked (new disk more than $AUTOSHRINK_DISK_SIZE_LIMIT_PERCENTAGE% smaller)"
        fi
        is_false "$last_part_is_resizeable" && Error "Cannot shrink $last_part_dev (non-resizeable partition)"
        test $new_last_part_size -le $last_part_size || BugError "New last partition size $new_last_part_size is not smaller than old size $last_part_size"
        LogPrint "Shrinking last partition $last_part_dev to end of disk (new disk at most $AUTOSHRINK_DISK_SIZE_LIMIT_PERCENTAGE% smaller)"
    fi

    # Replace the size value of the last partition by its new size value in LAYOUT_FILE.resized_last_partition:
    sed -r -i "s|^part $disk_device $last_part_size $last_part_start (.+) $last_part_dev\$|part $disk_device $new_last_part_size $last_part_start \1 $last_part_dev|" "$disklayout_resized_last_partition"
    LogPrint "Changed last partition $last_part_dev size from $last_part_size to $new_last_part_size bytes"
    # When the last partition is a logical partition its extended "container" partition may also need to be resized.
    # The extended partition only needs to be resized if there is a positive new size value for the extended partition (cf. above)
    # and that only happens when the extended partition needs to be increased (shrinking was already done above if needed):
    if is_positive_integer $new_extended_part_size ; then
        sed -r -i "s|^part $disk_device $extended_part_size $extended_part_start (.+) $extended_part_dev\$|part $disk_device $new_extended_part_size $extended_part_start \1 $extended_part_dev|" "$disklayout_resized_last_partition"
        LogPrint "Increased extended partition $extended_part_dev size from $extended_part_size to $new_extended_part_size bytes"
    fi

done < <( grep "^disk " "$LAYOUT_FILE" )

# Use the new LAYOUT_FILE.resized_last_partition with the resized partitions:
mv "$disklayout_resized_last_partition" "$LAYOUT_FILE"

# Restore the ReaR default bash flags and options (see usr/sbin/rear):
apply_bash_flags_and_options_commands "$DEFAULT_BASH_FLAGS_AND_OPTIONS_COMMANDS"

