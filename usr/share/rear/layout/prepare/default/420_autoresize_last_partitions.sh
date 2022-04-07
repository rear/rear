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

# Avoid 'set -e -u' exit e.g. because of "AUTORESIZE_PARTITIONS[@]: unbound variable"
# note that assigning an empty array like AUTORESIZE_PARTITIONS=() does not help
# against array elements like AUTORESIZE_PARTITIONS[0] are unbound variables:
${AUTORESIZE_PARTITIONS:=}
${AUTORESIZE_EXCLUDE_PARTITIONS:=}
# Set fallbacks (same as default.conf) if mandatory numbers are not set (the user may set them empty):
${AUTOSHRINK_DISK_SIZE_LIMIT_PERCENTAGE:=2}
${AUTOINCREASE_DISK_SIZE_THRESHOLD_PERCENTAGE:=10}

# Skip if not in migration mode:
is_true "$MIGRATION_MODE" || return 0

# Skip if automatically resize partitions is explicity unwanted:
is_false "$AUTORESIZE_PARTITIONS" && return

# Skip resizing only the last partition if resizing all partitions is explicity wanted
# which is done by the separated 430_autoresize_all_partitions.sh script:
is_true "$AUTORESIZE_PARTITIONS" && return

LogPrint "Trying to automatically resize last partition when disk size changed"

# Write new disklayout with resized partitions to LAYOUT_FILE.resized_last_partition:
local disklayout_resized_last_partition="$LAYOUT_FILE.resized_last_partition"
cp "$LAYOUT_FILE" "$disklayout_resized_last_partition"
save_original_file "$LAYOUT_FILE"

# The original disk space usage was written by layout/save/GNU/Linux/510_current_disk_usage.sh
local original_disk_space_usage_file="$VAR_DIR/layout/config/df.txt"

local layout_type junk
local disk_device old_disk_size disk_label new_disk_size new_disk_block_size
local sysfsname
local raid_device raid_options raid_option raid_component_devs
local raid_component_dev disklayout_entry
local raid_disks=()
local raid_component_dev_disk raid_component_dev_disk_size
local old_disk_sizes_sum new_disk_sizes_sum old_disk_sizes_difference old_raid_device_size new_raid_device_size
local old_smallest_size new_smallest_size
local message_prefix message_suffix
# bash works up to numbers of 2^63 - 1 = 9223372036854775807
# see "bash integer arithmetic range limitation" in lib/global-functions.sh
local bash_int_max=9223372036854775807

function autoresize_last_partition () { 
    local partitions_device disk_size_difference
    local max_part_start last_part_dev last_part_start last_part_size last_part_type last_part_flags last_part_end
    local extended_part_dev extended_part_start extended_part_size
    local partitions_dev part_size part_start part_type part_flags part_dev
    local last_part_is_resizeable
    local last_part_crypt_entry last_part_fs_dev last_part_fs_entry last_part_fs_mountpoint
    local egrep_pattern
    local last_part_is_boot last_part_is_swap last_part_is_efi
    local extended_part_to_be_increased
    local MiB secondary_GPT_size new_disk_size_MiB new_disk_remainder_start new_last_part_size new_extended_part_size
    local last_part_disk_space_usage last_part_used_bytes
    local increase_threshold_difference last_part_shrink_difference max_shrink_difference

    test $1 && partitions_device=$1 || BugError "autoresize_last_partition() called without partitions_device argument"
    test $2 && old_disk_size=$2 || BugError "autoresize_last_partition() called without old_disk_size argument"
    test $3 && disk_label=$3 || BugError "autoresize_last_partition() called without disk_label argument"
    test $4 && new_disk_size=$4 || BugError "autoresize_last_partition() called without new_disk_size argument"
    test $5 && new_disk_block_size=$5 || BugError "autoresize_last_partition() called without new_disk_block_size argument"

    # Continue with next disk if the current one has no partitions
    # (i.e. when there is no 'part' entry in disklayout.conf for the current disk)
    # otherwise the "Find the last partition for the current disk" code below fails
    # cf. https://github.com/rear/rear/issues/2134
    # This also skips disks that are RAID1 component devices
    # because the partitions exist on the RAID device like
    #   disk /dev/sda 12884901888 gpt
    #   disk /dev/sdc 12884901888 gpt
    #   raid /dev/md127 level=raid1 raid-devices=2 devices=/dev/sda,/dev/sdc name=raid1sdab ...
    #   part /dev/md127 10485760 1048576 rear-noname bios_grub /dev/md127p1
    #   part /dev/md127 12739067392 11534336 rear-noname none /dev/md127p2
    # so this function can be called for all 'disk' entries
    # without causing errors when a disk is a RAID1 component device:
    grep -q "^part $partitions_device " "$LAYOUT_FILE" || return 0
    
    DebugPrint "Examining $disk_label device $partitions_device to automatically resize its last active partition"

    # Skip if the size of the new disk (e.g. sda) is same as the size of the old disk (e.g. also sda):
    disk_size_difference=$( mathlib_calculate "$new_disk_size - $old_disk_size" )
    if test 0 -eq $disk_size_difference ; then
        DebugPrint "Skipping $partitions_device (size of new device same as size of old device)"
        return
    fi
    if test $disk_size_difference -gt 0 ; then
        DebugPrint "New $partitions_device is $disk_size_difference bytes bigger than old device"
    else
        # When disk_size_difference is less than null show its absolute value and use the word 'smaller':
        DebugPrint "New $partitions_device is $(( 0 - disk_size_difference )) bytes smaller than old device"
    fi

    # Find the last partition for the current partitions device in disklayout.conf:
    # Example partitions 'part' entries in disklayout.conf:
    #
    #   # Partitions on /dev/sda
    #   # Format: part <device> <partition size(bytes)> <partition start(bytes)> <partition type|name> <flags> /dev/<partition>
    #   part /dev/sda 1569718272 1048576 primary none /dev/sda1
    #   part /dev/sda 19904069632 1570766848 primary boot /dev/sda2
    #    
    #   # Partitions on /dev/md127
    #   # Format: part <device> <partition size(bytes)> <partition start(bytes)> <partition type|name> <flags> /dev/<partition>
    #   part /dev/md127 10485760 1048576 rear-noname bios_grub /dev/md127p1
    #   part /dev/md127 12739067392 11534336 rear-noname none /dev/md127p2
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
    # partitions_dev gets the same value as partitions_device
    while read layout_type partitions_dev part_size part_start part_type part_flags part_dev junk ; do
        DebugPrint "Checking $part_dev if it is the last partition on $partitions_dev"
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
            DebugPrint "Found extended partition $part_dev on $partitions_dev"
            extended_part_dev="$part_dev"
            extended_part_start="$part_start"
            extended_part_size="$part_size"
        fi
    done < <( grep "^part $partitions_device " "$LAYOUT_FILE" )
    test "$last_part_dev" || Error "Failed to determine device node for last partition on $partitions_device"
    is_positive_integer $last_part_start || Error "Failed to determine partition start for $last_part_dev"
    DebugPrint "Found '$last_part_type' partition $last_part_dev as last partition on $partitions_device"

    # Determine if the last partition is resizeable:
    DebugPrint "Determining if last partition $last_part_dev is resizeable"
    last_part_is_resizeable=""
    if IsInArray "$last_part_dev" "${AUTORESIZE_PARTITIONS[@]}" ; then
        last_part_is_resizeable="yes"
        DebugPrint "Last partition should be resized ($last_part_dev in AUTORESIZE_PARTITIONS)"
    else
        # Example filesystem 'fs' entries in disklayout.conf (excerpts):
        #
        #   # Format: fs <device> <mountpoint> <fstype> ...
        #   fs /dev/sda3 /boot/efi vfat ...
        #
        #   part /dev/md127 12739067392 11534336 rear-noname none /dev/md127p2
        #   fs /dev/mapper/cr_root / btrfs ...
        #   crypt /dev/mapper/cr_root /dev/md127p2 type=luks1 ...
        #
        # Note the indirection in the second case where LUKS is in between:
        # last_part_dev is /dev/md127p2 (the second partition on a RAID device /dev/md127)
        # but last_part_dev itself does not contain a filesystem because LUKS is in between
        # so the filesystem is on the LUKS volume /dev/mapper/cr_root that is on /dev/md127p2
        # and therefore we first try if we find a 'crypt' entry that matches last_part_dev:
        last_part_crypt_entry=( $( grep "^crypt [^ ][^ ]* $last_part_dev " "$LAYOUT_FILE" ) )
        test "$last_part_crypt_entry" && last_part_fs_dev="${last_part_crypt_entry[1]}" || last_part_fs_dev=$last_part_dev
        last_part_fs_entry=( $( grep "^fs $last_part_fs_dev " "$LAYOUT_FILE" ) )
        last_part_fs_mountpoint="${last_part_fs_entry[2]}"
        # Intentionally all tests to exclude a partition from being resized are run
        # to get all reasons shown (in the log) why one same partition is not resizeable.
        # Do not resize partitions that are explicitly specified to be excluded from being resized:
        if IsInArray "$last_part_dev" "${AUTORESIZE_EXCLUDE_PARTITIONS[@]}" ; then
            last_part_is_resizeable="no"
            DebugPrint "Last partition $last_part_dev not resizeable (excluded from being resized in AUTORESIZE_EXCLUDE_PARTITIONS)"
        fi
        # Do not resize partitions that are used during boot:
        if IsInArray "boot" "${AUTORESIZE_EXCLUDE_PARTITIONS[@]}" ; then
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
            grep -E -i "$egrep_pattern" <<< $( echo $last_part_fs_mountpoint ) && last_part_is_boot="yes"
            if is_true "$last_part_is_boot" ; then
                last_part_is_resizeable="no"
                DebugPrint "Last partition $last_part_dev not resizeable (used during boot)"
            fi
        fi
        # Do not resize partitions that are used as swap partitions:
        if IsInArray "swap" "${AUTORESIZE_EXCLUDE_PARTITIONS[@]}" ; then
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
        if IsInArray "efi" "${AUTORESIZE_EXCLUDE_PARTITIONS[@]}" ; then
            last_part_is_efi=''
            # A partition is considered to be used for UEFI
            # when its GPT name or flags contain 'efi' or 'esp' (anywhere case insensitive):
            egrep_pattern='efi|esp'
            grep -E -i "$egrep_pattern" <<< $( echo $last_part_type ) && last_part_is_efi="yes"
            grep -E -i "$egrep_pattern" <<< $( echo $last_part_flags ) && last_part_is_efi="yes"
            # Also test if the mountpoint of the filesystem of the partition
            # contains 'efi' or 'esp' (anywhere case insensitive):
            grep -E -i "$egrep_pattern" <<< $( echo $last_part_fs_mountpoint ) && last_part_is_efi="yes"
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
        if IsInArray "$extended_part_dev" "${AUTORESIZE_PARTITIONS[@]}" ; then
            extended_part_to_be_increased="yes"
            DebugPrint "Extended partition should be increased ($extended_part_dev in AUTORESIZE_PARTITIONS)"
        fi
    fi

    # Determine the desired new size of the last partition (with 1 MiB alignment)
    # so that the new sized last partition would go up to the end of the usable space on the new device:
    DebugPrint "Determining new size for last partition $last_part_dev"
    MiB=$( mathlib_calculate "1024 * 1024" )
    # GPT disks need 33 LBA blocks reserved space at the end of the disk
    # for the secondary GPT (with GPT default size) at the end of the disk
    # cf. https://en.wikipedia.org/wiki/GUID_Partition_Table
    # and https://github.com/rear/rear/issues/2182
    # and the code in layout/prepare/GNU/Linux/100_include_partition_code.sh
    if test "$disk_label" = "gpt" -o "$disk_label" = "gpt_sync_mbr" ; then
        secondary_GPT_size=$( mathlib_calculate "33 * $new_disk_block_size" )
    else
        secondary_GPT_size=0
    fi
    # mathlib_calculate cuts integer remainder so that for a disk of e.g. 12345.67 MiB size new_disk_size_MiB = 12345
    # which results the 1 MiB alignment of the end of the used space on the new disk:
    new_disk_size_MiB=$( mathlib_calculate "( $new_disk_size - $secondary_GPT_size ) / $MiB" )
    # The first byte of the unusable remainder (with 1 MiB alignment) is the first byte after the last used MiB on the disk
    # i.e. the first byte after the last used MiB on a disk is the start of the unused disk space remainder at the end.
    # This value has same semantics as the partition start values (which are the first byte of a partition).
    # For a non-GPT disk of 12345.67 MiB size the new_disk_remainder_start = 12944670720 = 12345 * 1024 * 1024.
    # For a GPT disk of 6789 MiB size with 512 bytes block size secondary_GPT_size = 16896 = 33 * 512 bytes
    # so that its usable size = ( 6789 * 1024 * 1024 - 16896 ) / 1024 / 1024 = 6788.98388671875 MiB
    # which results new_disk_size_MiB = 6788 and new_disk_remainder_start = 7117733888 = 6788 * 1024 * 1024.
    new_disk_remainder_start=$( mathlib_calculate "$new_disk_size_MiB * $MiB" )
    # When last_part_start is e.g. at 12300.00 MiB = at the byte 12897484800
    # then new_last_part_size = 12944670720 - 12897484800 = 45.00 MiB
    # so that on a disk of e.g. 12345.67 MiB size the last 0.67 MiB is left unused (as intended for 1 MiB alignment):
    new_last_part_size=$( mathlib_calculate "$new_disk_remainder_start - $last_part_start" )

    # When the desired new size of the last partition (with 1 MiB alignment) is not at least 1 MiB
    # the last partition can no longer be on the new device (when only the last partition is shrinked):
    test $new_last_part_size -ge $MiB || Error "No space for last partition $last_part_dev on new device (new last partition size would be less than 1 MiB)"

    # When the last partition is a logical partition determine the desired new size
    # of its extended "container" partition (with 1 MiB alignment) so that
    # also the new sized extended partition would go up to the end of the new device.
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
    # Example var/lib/rear/layout/config/df.txt contents (in MiB units, 1 MiB = 1024 * 1024 = 1048576):
    #
    #   Filesystem     1048576-blocks    Used Available Capacity Mounted on
    #   /dev/sdb5             143653M 115257M    27358M      81% /
    #   /dev/sdb3                161M      5M      157M       3% /boot/efi
    #   /dev/sda2             514926M    983M   487765M       1% /data
    #
    #   Filesystem          1048576-blocks  Used Available Capacity Mounted on
    #   /dev/md127p1                11023M 2998M     7446M      29% /
    #   /dev/mapper/cr_home          9006M   37M     8493M       1% /home
    #
    # The second example is from a system with a RAID0 array that has a LUKS encrypted /home partition:
    #   # lsblk -ipo NAME,TYPE,FSTYPE,SIZE,MOUNTPOINT /dev/md127
    #   NAME                    TYPE  FSTYPE      SIZE MOUNTPOINT
    #   /dev/md127              raid0              22G
    #   |-/dev/md127p1          part  ext4         11G /
    #   `-/dev/md127p2          part  crypto_LUKS   9G
    #     `-/dev/mapper/cr_home crypt ext4          9G /home
    #
    # Neither original_disk_space_usage_file may exist nor may it contain an entry for last_part_dev and
    # then we output e.g. "/dev/sda2 No_original_disk_space_usage_info 0M" to get ${last_part_disk_space_usage[2]%%M*} = 0.
    # Because $original_disk_space_usage_file is not empty, grep cannot hang up here by reading from stdin:
    last_part_disk_space_usage=( $( grep "^$last_part_dev " $original_disk_space_usage_file || echo $last_part_dev No_original_disk_space_usage_info 0M ) )
    last_part_used_bytes=$( mathlib_calculate "${last_part_disk_space_usage[2]%%M*} * $MiB" )
    # The is_positive_integer test ensures the WARNING could be only shown when last_part_used_bytes is actually valid:
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
        # if the new size (which is up to the end of the new device) is smaller than it was on the old device because
        # otherwise the end of the extended partition would be beyond the end of the new device (with 1 MiB alignment):
        if test $new_extended_part_size -lt $extended_part_size ; then
            LogPrint "Shrinking extended partition $extended_part_dev to end of device"
            sed -r -i "s|^part $partitions_device $extended_part_size $extended_part_start (.+) $extended_part_dev\$|part $partitions_device $new_extended_part_size $extended_part_start \1 $extended_part_dev|" "$disklayout_resized_last_partition"
            LogPrint "Shrinked extended partition $extended_part_dev size from $extended_part_size to $new_extended_part_size bytes"
            # Set new_extended_part_size to zero to avoid that the extended partition
            # will be also shrinked when the last partition gets actually shrinked below:
            new_extended_part_size=0
        fi
        # The extended partition should be increased independent of whether or not the last partition will be also increased:
        if is_true "$extended_part_to_be_increased" ; then
            # The extended partition can only be actually increased (regardless if the last partition will also be increased)
            # if the new size (which is up to the end of the new device) is greater than it was on the old device (with 1 MiB alignment):
            if test $new_extended_part_size -gt $extended_part_size ; then
                LogPrint "Increasing extended partition $extended_part_dev to end of device"
                sed -r -i "s|^part $partitions_device $extended_part_size $extended_part_start (.+) $extended_part_dev\$|part $partitions_device $new_extended_part_size $extended_part_start \1 $extended_part_dev|" "$disklayout_resized_last_partition"
                LogPrint "Increased extended partition $extended_part_dev size from $extended_part_size to $new_extended_part_size bytes"
                # Set new_extended_part_size to zero to avoid that the extended partition
                # will be also increased when the last partition gets actually increased below:
                new_extended_part_size=0
            else
                # Inform the user when the extended partition cannot be resized regardless of his setting in AUTORESIZE_PARTITIONS:
                LogPrint "Extended partition $extended_part_dev cannot be increased (new size less than what it was on old device)"
            fi
        fi
    fi

    # Determine if the last partition actually needs to be increased or shrinked and
    # go on or error out or skip the rest (i.e. return) depending on the particular case:
    DebugPrint "Determining if last partition $last_part_dev actually needs to be increased or shrinked"
    if test $disk_size_difference -gt 0 ; then
        # The size of the new partitions device is bigger than the size of the old one:
        increase_threshold_difference=$( mathlib_calculate "$old_disk_size / 100 * $AUTOINCREASE_DISK_SIZE_THRESHOLD_PERCENTAGE" )
        if test $disk_size_difference -lt $increase_threshold_difference ; then
            if is_true "$last_part_is_resizeable" ; then
                # Inform the user when last partition cannot be resized regardless of his setting in AUTORESIZE_PARTITIONS:
                LogPrint "Last partition $last_part_dev cannot be resized (new device less than $AUTOINCREASE_DISK_SIZE_THRESHOLD_PERCENTAGE% bigger)"
            else
                DebugPrint "Skip increasing last partition $last_part_dev (new device less than $AUTOINCREASE_DISK_SIZE_THRESHOLD_PERCENTAGE% bigger)"
            fi
            # Skip the rest:
            return
        fi
        if is_false "$last_part_is_resizeable" ; then
            DebugPrint "Skip increasing last partition $last_part_dev (not resizeable)"
            # Skip the rest:
            return
        fi
        test $new_last_part_size -ge $last_part_size || BugError "New last partition size $new_last_part_size is not bigger than old size $last_part_size"
        LogPrint "Increasing last partition $last_part_dev up to end of device (new device at least $AUTOINCREASE_DISK_SIZE_THRESHOLD_PERCENTAGE% bigger)"
        is_positive_integer $new_extended_part_size && LogPrint "Increasing extended partition $extended_part_dev up to end of device"
    else
        # The size of the new partitions device is smaller than the size of the old device:
        # Currently disk_size_difference is negative but we prefer to use its absolute value:
        disk_size_difference=$( mathlib_calculate "0 - $disk_size_difference" )
        # There is no need to shrink the last partition when the original last partition still fits on the new smaller device:
        if test $last_part_end -le $new_disk_remainder_start ; then
            if is_true "$last_part_is_resizeable" ; then
                # Inform the user when last partition will not be resized regardless of his setting in AUTORESIZE_PARTITIONS:
                LogPrint "Last partition $last_part_dev will not be resized (original last partition still fits on the new smaller device)"
            else
                DebugPrint "Skip shrinking last partition $last_part_dev (original last partition still fits on the new smaller device)"
            fi
            # Skip the rest:
            return
        fi
        last_part_shrink_difference=$( mathlib_calculate "$last_part_size - $new_last_part_size" )
        LogPrint "Last partition $last_part_dev must be shrinked by $last_part_shrink_difference bytes to still fit on device"
        max_shrink_difference=$( mathlib_calculate "$old_disk_size / 100 * $AUTOSHRINK_DISK_SIZE_LIMIT_PERCENTAGE" )
        if test $disk_size_difference -gt $max_shrink_difference ; then
            # Show also the config variable name AUTOSHRINK_DISK_SIZE_LIMIT_PERCENTAGE (not only its value)
            # so the user knows what he could change which helps to move forward when "rear recover" errors out here:
            Error "Last partition $last_part_dev cannot be shrinked (new device more than $AUTOSHRINK_DISK_SIZE_LIMIT_PERCENTAGE% smaller, see AUTOSHRINK_DISK_SIZE_LIMIT_PERCENTAGE)"
        fi
        if is_false "$last_part_is_resizeable" ; then
            # Show also the config variable name AUTORESIZE_EXCLUDE_PARTITIONS so the user knows what he could change:
            Error "Cannot shrink $last_part_dev (non-resizeable partition, see AUTORESIZE_EXCLUDE_PARTITIONS)"
        fi
        test $new_last_part_size -le $last_part_size || BugError "New last partition size $new_last_part_size is not smaller than old size $last_part_size"
        LogPrint "Shrinking last partition $last_part_dev to end of device (new device at most $AUTOSHRINK_DISK_SIZE_LIMIT_PERCENTAGE% smaller)"
    fi

    # Replace the size value of the last partition by its new size value in LAYOUT_FILE.resized_last_partition:
    sed -r -i "s|^part $partitions_device $last_part_size $last_part_start (.+) $last_part_dev\$|part $partitions_device $new_last_part_size $last_part_start \1 $last_part_dev|" "$disklayout_resized_last_partition"
    LogPrint "Changed last partition $last_part_dev size from $last_part_size to $new_last_part_size bytes"
    # When the last partition is a logical partition its extended "container" partition may also need to be resized.
    # The extended partition only needs to be resized if there is a positive new size value for the extended partition (cf. above)
    # and that only happens when the extended partition needs to be increased (shrinking was already done above if needed):
    if is_positive_integer $new_extended_part_size ; then
        sed -r -i "s|^part $partitions_device $extended_part_size $extended_part_start (.+) $extended_part_dev\$|part $partitions_device $new_extended_part_size $extended_part_start \1 $extended_part_dev|" "$disklayout_resized_last_partition"
        LogPrint "Increased extended partition $extended_part_dev size from $extended_part_size to $new_extended_part_size bytes"
    fi
}

# Autoresize the last partition for 'disk' entries in disklayout.conf
#
# Example 'disk' entries in disklayout.conf
#
#   # Disk /dev/sda
#   # Format: disk <devname> <size(bytes)> <partition label type>
#   disk /dev/sda 21474836480 msdos
#
#   # Disk /dev/sdb
#   # Format: disk <devname> <size(bytes)> <partition label type>
#   disk /dev/sdb 2147483648 msdos
#
#   # Disk /dev/vda
#   # Format: disk <devname> <size(bytes)> <partition label type>
#   disk /dev/vda 53687091200 gpt
#
#   # Disk /dev/dasda
#   # Format: disk <devname> <size(bytes)> <partition label type>
#   disk /dev/dasda 7385333760 dasd
#
while read layout_type disk_device old_disk_size disk_label junk ; do
    if ! test "$disk_device" ; then
        LogPrintError "Cannot autoresize disk ('disk' entry without disk device in $LAYOUT_FILE)"
        # Continue with the next 'disk' entry in disklayout.conf
        continue
    fi
    message_prefix="Cannot autoresize disk $disk_device"
    if ! is_positive_integer $old_disk_size ; then
        LogPrintError "$message_prefix ('disk' entry without disk size in $LAYOUT_FILE)"
        continue
    fi
    if ! test "$disk_label" ; then
        LogPrintError "$message_prefix ('disk' entry without disk label in $LAYOUT_FILE)"
        continue
    fi
    message_suffix="for $disk_device"
    # Get the new disk size and block size of the current disk device in the recovery system:
    sysfsname=$( get_sysfs_name $disk_device )
    sysfsname=$( get_sysfs_name $disk_device )
    if ! test "$sysfsname" ; then
        LogPrintError "$message_prefix (get_sysfs_name failed $message_suffix)"
        continue
    fi
    if ! test -d "/sys/block/$sysfsname" ; then
        LogPrintError "$message_prefix (no '/sys/block/$sysfsname' directory $message_suffix)"
        continue
    fi
    new_disk_size=$( get_disk_size "$sysfsname" )
    if ! is_positive_integer $new_disk_size ; then
        LogPrintError "$message_prefix (get_disk_size failed $message_suffix)"
        continue
    fi
    new_disk_block_size=$( get_block_size "$sysfsname" )
    if ! is_positive_integer $new_disk_block_size ; then
        LogPrintError "$message_prefix (get_block_size failed $message_suffix)"
        continue
    fi
    autoresize_last_partition $disk_device $old_disk_size $disk_label $new_disk_size $new_disk_block_size
done < <( grep "^disk " "$LAYOUT_FILE" )

# Autoresize the last partition for 'raid' entries in disklayout.conf
#
# Example 'raid' related entries in disklayout.conf (excerpts) for a RAID1 array:
#
#   # Format: disk <devname> <size(bytes)> <partition label type>
#   disk /dev/sda 12884901888 gpt
#   disk /dev/sdc 12884901888 gpt
#
#   # Format: raid /dev/<kernel RAID device> level=<RAID level> raid-devices=<nr of active devices> devices=<component device1,component device2,...> ...
#   raid /dev/md127 level=raid1 raid-devices=2 devices=/dev/sda,/dev/sdc ...
#   # Partitions on /dev/md127
#   # Format: part <device> <partition size(bytes)> <partition start(bytes)> <partition type|name> <flags> /dev/<partition>
#   part /dev/md127 10485760 1048576 rear-noname bios_grub /dev/md127p1
#   part /dev/md127 12739067392 11534336 rear-noname none /dev/md127p2
#
#   # Format: fs <device> <mountpoint> <fstype> ...
#   fs /dev/mapper/cr_root / btrfs ...
#
#   crypt /dev/mapper/cr_root /dev/md127p2 type=luks1 ...
#
# Example 'raid' related entries in disklayout.conf (excerpts) for a RAID0 array
# that consists of the partitions /dev/sda3 and /dev/sdb2 and the raw disk /dev/sdc
#
#   # Format: disk <devname> <size(bytes)> <partition label type>
#   disk /dev/sda 10737418240 gpt
#   disk /dev/sdb 8589934592 gpt
#   disk /dev/sdc 6442450944 unknown
#   # Format: part <device> <partition size(bytes)> <partition start(bytes)> <partition type|name> <flags> /dev/<partition>
#   part /dev/sda 8388608 1048576 rear-noname bios_grub /dev/sda1
#   part /dev/sda 1065353216 9437184 rear-noname legacy_boot /dev/sda2
#   part /dev/sda 9652142080 1074790400 rear-noname raid /dev/sda3
#   part /dev/sdb 1073741824 1048576 rear-noname swap /dev/sdb1
#   part /dev/sdb 7504658432 1074790400 rear-noname raid /dev/sdb2
#
#   # Format: raid /dev/<kernel RAID device> level=<RAID level> raid-devices=<nr of active devices> devices=<component device1,component device2,...> ...
#   raid /dev/md127 level=raid0 raid-devices=3 devices=/dev/sda3,/dev/sdb2,/dev/sdc ...
#   # Partitions on /dev/md127
#   # Format: part <device> <partition size(bytes)> <partition start(bytes)> <partition type|name> <flags> /dev/<partition>
#   part /dev/md127 11810635776 1572864 rear-noname none /dev/md127p1
#   part /dev/md127 9663676416 11812208640 rear-noname none /dev/md127p2
#
#   # Format: fs <device> <mountpoint> <fstype> ...
#   fs /dev/mapper/cr_home /home ext4 ...
#   fs /dev/md127p1 / ext4 ...
#
#   crypt /dev/mapper/cr_home /dev/md127p2 type=luks1 ...
#
while read layout_type raid_device junk ; do
    if ! test "$raid_device" ; then
        LogPrintError "Cannot autoresize RAID ('raid' entry without RAID device in $LAYOUT_FILE)"
        # Continue with the next 'raid' entry in disklayout.conf
        continue
    fi
    message_prefix="Cannot autoresize RAID $raid_device"

    # For each 'raid' entry get its raid_component_devs as a string
    # cf. the code in layout/prepare/GNU/Linux/120_include_raid_code.sh
    read layout_type raid_device raid_options < <(grep "^raid $raid_device " "$LAYOUT_FILE")
    for raid_option in $raid_options ; do
        case "$raid_option" in
            (level=*)
                raid_level=${raid_option#level=}
                ;;
            (devices=*)
                # E.g. when raid_option is "devices=/dev/sda,/dev/sdb,/dev/sdc"
                # then ${raid_option#devices=} is "/dev/sda,/dev/sdb,/dev/sdc"
                # so that echo ${raid_option#devices=} | tr ',' ' '
                # results raid_component_devs="/dev/sda /dev/sdb /dev/sdc"
                raid_component_devs="$( echo ${raid_option#devices=} | tr ',' ' ' )"
                ;;
        esac
    done
    if ! test "$raid_component_devs" ; then
        LogPrintError "$message_prefix ('raid' entry without RAID component devices in $LAYOUT_FILE)"
        # Continue with the next 'raid' entry in disklayout.conf
        continue
    fi

    # create_partitions() sets label="gpt" when it was called without label and
    # create_partitions() is called without label in layout/prepare/GNU/Linux/120_include_raid_code.sh
    # so RAID devices get a GPT partition table
    disk_label="gpt"

    case "$raid_level" in
        (raid0)
            # Autoresize the last partition on a RAID0 device:
            # Determine the sum of the sizes of the old and new component devices
            # and a disk label (GPT or MBR) of one of the component devices
            # and the block size of one of the component devices:
            old_disk_sizes_sum=0
            new_disk_sizes_sum=0
            raid_disks=()
            for raid_component_dev in $raid_component_devs ; do
                # Get the old disk size in disklayout.conf
                disklayout_entry=( $( grep "^disk $raid_component_dev " "$LAYOUT_FILE" ) )
                if test "$disklayout_entry" ; then
                    raid_component_dev_disk="$raid_component_dev"
                else
                    message_suffix="for RAID component device $raid_component_dev in $LAYOUT_FILE"
                    # When there is no 'disk' entry try if there is a 'part' entry for the RAID component device.
                    # The '$' at the end is crucial to distinguish between "part ... /dev/sda1" and "part ... /dev/sda12":
                    disklayout_entry=( $( grep "^part .* $raid_component_dev\$" "$LAYOUT_FILE" ) )
                    if ! test "$disklayout_entry" ; then
                        LogPrintError "$message_prefix (neither 'disk' nor 'part' entry found $message_suffix)"
                        # Continue with the next 'raid' entry in disklayout.conf
                        continue 2
                    fi
                    # Get the disk where the partition is:
                    raid_component_dev_disk="${disklayout_entry[1]}"
                    disklayout_entry=( $( grep "^disk $raid_component_dev_disk " "$LAYOUT_FILE" ) )
                    if ! test "$disklayout_entry" ; then
                        LogPrintError "$message_prefix (no 'disk' found for 'part' entry $message_suffix)"
                        # Continue with the next 'raid' entry in disklayout.conf
                        continue 2
                    fi
                fi
                # Do not count a particular RAID disk several times
                # e.g. when a RAID0 array consists of several partitions on the same disk:
                IsInArray "$raid_component_dev_disk" "${raid_disks[@]}" && continue
                raid_disks+=( $raid_component_dev_disk )
                raid_component_dev_disk_size="${disklayout_entry[2]}"
                (( old_disk_sizes_sum += raid_component_dev_disk_size ))
                message_suffix="for RAID component device disk $raid_component_dev_disk"
                # Get the new disk size of the current disk device in the recovery system
                # cf. the code above to "Autoresize the last partition for 'disk' entries in disklayout.conf"
                sysfsname=$( get_sysfs_name $raid_component_dev_disk )
                if ! test "$sysfsname" ; then
                    LogPrintError "$message_prefix (get_sysfs_name failed $message_suffix)"
                    # Continue with the next 'raid' entry in disklayout.conf
                    continue 2
                fi
                if ! test -d "/sys/block/$sysfsname" ; then
                    LogPrintError "$message_prefix (no '/sys/block/$sysfsname' directory $message_suffix)"
                    # Continue with the next 'raid' entry in disklayout.conf
                    continue 2
                fi
                new_disk_size=$( get_disk_size "$sysfsname" )
                if ! is_positive_integer $new_disk_size ; then
                    LogPrintError "$message_prefix (get_disk_size failed $message_suffix)"
                    # Continue with the next 'raid' entry in disklayout.conf
                    continue 2
                fi
                (( new_disk_sizes_sum += new_disk_size ))
                # We cannot get the block size of the RAID device like /dev/md127
                # because the RAID device does not yet exist when this code is run
                # so we use the block size of the RAID component devices
                # as a best effort attempt:
                new_disk_block_size=$( get_block_size "$sysfsname" )
                if ! is_positive_integer $new_disk_block_size ; then
                    LogPrintError "$message_prefix (get_block_size failed $message_suffix)"
                    # Continue with the next 'raid' entry in disklayout.conf
                    continue 2
                fi
            done
            # Get the old RAID device size in disklayout.conf
            message_suffix="for RAID device $raid_device in $LAYOUT_FILE"
            disklayout_entry=( $( grep "^raiddisk $raid_device " "$LAYOUT_FILE" ) )
            if test "$disklayout_entry" ; then
                old_raid_device_size="${disklayout_entry[2]}"
            else
                LogPrintError "$message_prefix (no 'raiddisk' found $message_suffix)"
                # Continue with the next 'raid' entry in disklayout.conf
                continue
            fi
            # The new RAID device size differs from the old RAID device size
            # by the difference between new_disk_sizes_sum and old_disk_sizes_sum
            # i.e. by the difference of the sum of the RAID component device sizes:
            old_disk_sizes_difference=$(( new_disk_sizes_sum - old_disk_sizes_sum ))
            # When the new RAID component device sizes are bigger the difference is greater than null
            # and when the new RAID component device sizes are smaller the difference is less than null:
            new_raid_device_size=$(( old_raid_device_size + old_disk_sizes_difference ))
            # Autoresize the last partition on the RAID0 device like /dev/md127
            # but not on each component device of the array like /dev/sda3 and /dev/sdb2 and /dev/sdc
            autoresize_last_partition $raid_device $old_raid_device_size $disk_label $new_raid_device_size $new_disk_block_size
            # Continue with the next 'raid' entry in disklayout.conf
            continue
            ;;
        (raid1)
            # Autoresize the last partition on a RAID1 device:
            # Determine the old and new smallest component device and a disk label (GPT or MBR)
            # and the block size of the new smallest component device:
            old_smallest_size=$bash_int_max
            new_smallest_size=$bash_int_max
            for raid_component_dev in $raid_component_devs ; do
                # Get the old disk size in disklayout.conf
                disklayout_entry=( $( grep "^disk $raid_component_dev " "$LAYOUT_FILE" ) )
                if test "$disklayout_entry" ; then
                    raid_component_dev_disk="$raid_component_dev"
                else
                    message_suffix="for RAID component device $raid_component_dev in $LAYOUT_FILE"
                    # When there is no 'disk' entry try if there is a 'part' entry for the RAID component device.
                    # The '$' at the end is crucial to distinguish between "part ... /dev/sda1" and "part ... /dev/sda12":
                    disklayout_entry=( $( grep "^part .* $raid_component_dev\$" "$LAYOUT_FILE" ) )
                    if ! test "$disklayout_entry" ; then
                        LogPrintError "$message_prefix (neither 'disk' nor 'part' entry found $message_suffix)"
                        # Continue with the next 'raid' entry in disklayout.conf
                        continue 2
                    fi
                    # Get the disk where the partition is:
                    raid_component_dev_disk="${disklayout_entry[1]}"
                    disklayout_entry=( $( grep "^disk $raid_component_dev_disk " "$LAYOUT_FILE" ) )
                    if ! test "$disklayout_entry" ; then
                        LogPrintError "$message_prefix (no 'disk' found for 'part' entry $message_suffix)"
                        # Continue with the next 'raid' entry in disklayout.conf
                        continue 2
                    fi
                fi
                raid_component_dev_disk_size="${disklayout_entry[2]}"
                # Set the old smallest disk size and use its disk label in the autoresize_last_partition() call:
                if test $raid_component_dev_disk_size -lt $old_smallest_size ; then
                    old_smallest_size=$raid_component_dev_disk_size
                fi
                message_suffix="for RAID component device disk $raid_component_dev_disk"
                # Get the new disk size of the current disk device in the recovery system
                # cf. the code above to "Autoresize the last partition for 'disk' entries in disklayout.conf"
                sysfsname=$( get_sysfs_name $raid_component_dev_disk )
                if ! test "$sysfsname" ; then
                    LogPrintError "$message_prefix (get_sysfs_name failed $message_suffix)"
                    # Continue with the next 'raid' entry in disklayout.conf
                    continue 2
                fi
                if ! test -d "/sys/block/$sysfsname" ; then
                    LogPrintError "$message_prefix (no '/sys/block/$sysfsname' directory $message_suffix)"
                    # Continue with the next 'raid' entry in disklayout.conf
                    continue 2
                fi
                new_disk_size=$( get_disk_size "$sysfsname" )
                if ! is_positive_integer $new_disk_size ; then
                    LogPrintError "$message_prefix (get_disk_size failed $message_suffix)"
                    # Continue with the next 'raid' entry in disklayout.conf
                    continue 2
                fi
                # Set the new smallest disk size and use its block size in the autoresize_last_partition() call:
                if test $new_disk_size -lt $new_smallest_size ; then
                    new_smallest_size=$new_disk_size
                    # We cannot get the block size of the RAID device like /dev/md127
                    # because the RAID device does not yet exist when this code is run
                    # so we use the block size of the smallest RAID component device
                    # as a best effort attempt:
                    new_disk_block_size=$( get_block_size "$sysfsname" )
                    if ! is_positive_integer $new_disk_block_size ; then
                        LogPrintError "$message_prefix (get_block_size failed $message_suffix)"
                        # Continue with the next 'raid' entry in disklayout.conf
                        continue 2
                    fi
                fi
            done
            # We assume a real RAID1 device size is not 2^63 - 1 ( 2^63 - 1 = $bash_int_max ) or bigger
            # because 2^63 - 1 = 1024^4 * 1024 * 1024 * 8 - 1 = 1 TiB * 1024 * 1024 * 8 - 1 = 8 EiB -1
            # and https://en.wikipedia.org/wiki/History_of_hard_disk_drives reads (excerpt dated Dec. 2021)
            # "As of August 2020, the largest hard drive is 20 TB (while SSDs can be much bigger at 100 TB"
            # and https://www.alphr.com/largest-hard-drive-you-can-buy/ reads (excerpt dated Dec. 2021)
            # "There’s a lot of talk right now about 200TB drives and even 1,000TB drives"
            # which is still several thousand times smaller than 2^63 - 1
            # but a RAID0 array of very many such drives could exceed the 2^63 - 1 limit in theory
            # while in practice a RAID0 array of thousands of disks probably will not work reliably:
            if ! test $old_smallest_size -lt $bash_int_max -a $new_smallest_size -lt $bash_int_max ; then
                LogPrintError "$message_prefix (no disk size found or size not less than 2^63 - 1)"
                continue
            fi
            # Autoresize the last partition on the RAID1 device like /dev/md127
            # but not on each component device of the array like /dev/sda and /dev/sdc
            autoresize_last_partition $raid_device $old_smallest_size $disk_label $new_smallest_size $new_disk_block_size
            # Continue with the next 'raid' entry in disklayout.conf
            continue
            ;;
        (*)
            # Currently only RAID1 and RAID0 are supported for autoresize:
            LogPrintError "$message_prefix (autoresizing is not supported for RAID level '$raid_level')"
            # Continue with the next 'raid' entry in disklayout.conf
            continue
            ;;
    esac

done < <( grep "^raid " "$LAYOUT_FILE" )

# Use the new LAYOUT_FILE.resized_last_partition with the resized partitions:
mv "$disklayout_resized_last_partition" "$LAYOUT_FILE"

# Local functions must be 'unset' because bash does not support 'local function ...'
unset -f autoresize_last_partition

