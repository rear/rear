#
# Compare disks from the original system to this system.
#
# This implements some basic autodetection during "rear recover"
# when disks on the replacement hardware seem to not match compared to
# what there was stored in disklayout.conf on the original system.
# If a mismatch is autodetected then ReaR goes into its
# MIGRATION_MODE where it asks via user dialogs what to do.
# Only the disk size is used to determine whether or not
# disks on the replacement hardware match the disks on the original system.
# Problems only appear when more than one disk with same size is used.
# Examples:
# When on the original system and on the replacement hardware two disks
# with same size are used the disk devices may get interchanged
# so that what there was on /dev/sda on the original system may get
# recreated on /dev/sdb on the replacement hardware and vice versa.
# When on the original system one disk is used for the system and
# another disk with same size for the ReaR recovery system and backup
# the disk devices may get interchanged on the replacement hardware
# so that "rear recover" could result an ultimate disaster
# (instead of a recovery from a disaster) if it recreated the system
# on the disk where the ReaR recovery system and backup is
# which would overwrite/destroy the backup via parted and mkfs
# (cf. https://github.com/rear/rear/issues/1271).
# Therefore to be on the safe side and to avoid such problems
# ReaR goes by default automatically into its MIGRATION_MODE
# when more than one disk with same size is used on the original system
# or when for one of the used disk sizes on the original system
# more than one disk with same size is found on the replacement hardware
# i.e. when there is more than one possible target disk.
# Accordingly ReaR goes by default not into its MIGRATION_MODE
# only if for each used disk size on the original system eaxctly one
# possible target disk with same size is found on the replacement hardware.

# Nothing to do when MIGRATION_MODE is already set:
if is_true "$MIGRATION_MODE" ; then
    LogPrint "Enforced manual disk layout configuration (MIGRATION_MODE is 'true')"
    return
fi

# Nothing to do when MIGRATION_MODE is already set:
if is_false "$MIGRATION_MODE" ; then
    LogPrint "Enforced recreating disk layout as specified in '$LAYOUT_FILE' (MIGRATION_MODE is 'false')"
    return
fi

# Compare disks to determine whether or not MIGRATION_MODE must be used:
LogPrint "Comparing disks"

# Determine the actually used disk sizes on the original system and
# remember each one only once in the original_system_used_disk_sizes array
# and remember each old/original disk with its size in the old_disks_and_sizes array
# which is an array of strings that have the form "old_device old_device_size"
local old_disks_and_sizes=()
local original_system_used_disk_sizes=()
local more_than_one_same_orig_size=''
# Cf. the "Compare disks one by one" code below:
while read disk dev size junk ; do
    old_disks_and_sizes+=( "$dev $size" )
    if IsInArray "$size" "${original_system_used_disk_sizes[@]}" ; then
        more_than_one_same_orig_size='true'
    else
        original_system_used_disk_sizes+=( "$size" )
    fi
done < <( grep -E '^disk |^multipath ' "$LAYOUT_FILE" )
# MIGRATION_MODE is needed when more than one disk with same size is used on the original system:
if is_true "$more_than_one_same_orig_size" ; then
    LogPrint "Ambiguous disk layout needs manual configuration (more than one disk with same size used in '$LAYOUT_FILE')"
    MIGRATION_MODE='true'
fi

# Determine disabled disks (but not disabled multipath devices) on the original system
# (perhaps disabled multipath devices should also be remembered?)
# and remember each one with its size in the old_disabled_disks_and_sizes array
# which is an array of strings that have the form "old_disabled_device old_device_size"
local old_disabled_disks_and_sizes=()
while read disk dev size junk ; do
    old_disabled_disks_and_sizes+=( "$dev $size" )
    # Disks are disabled by ReaR in disklayout.conf with a leading '#' without added space (so it is '#disk'):
done < <( grep '^#disk ' "$LAYOUT_FILE" )

# Determine what non-zero block device sizes exists on the replacement hardware
# and remember each new disk with its size in the new_disks_and_sizes array
# which is an array of strings that have the form "new_device new_device_size"
local new_disks_and_sizes=()
local replacement_hardware_disk_sizes=()
local current_device_path=''
local current_disk_name=''
local current_size=''
local current_kname
local old_disk_and_size
# Cf. the "loop over all current block devices" code
# in layout/prepare/default/300_map_disks.sh
for current_device_path in /sys/block/* ; do
    current_disk_name="${current_device_path#/sys/block/}"
    # Continue with next block device if the device is a multipath device slave
    is_multipath_path $current_disk_name && continue
    # Continue with next block device if the current one has no queue directory:
    test -d $current_device_path/queue || continue
    # Continue with next block device if the current one is a removable device
    # for example CDROM is removable because /sys/block/sr0/removable contains '1'
    # but a USB disk is not removable because /sys/block/sdb/removable contains '0'
    # so this condition is primarily there to skip CDROM devices
    # (in particular the device where the ReaR recovery system was booted from)
    # because we cannot test /sys/block/sr0/ro which usually contains '0'
    # because that is usually a CD/DVD-RW device that can write (depending on the medium)
    # cf. https://unix.stackexchange.com/questions/22019/how-can-i-test-whether-a-block-device-is-read-only-from-sys-or-proc
    test "$( < $current_device_path/removable )" = "1" && continue
    # Continue with next block device if the current one is designated as write-protected:
    is_write_protected $current_device_path && continue
    # Continue with next block device if no size can be read for the current one:
    test -r $current_device_path/size || continue
    current_size=$( get_disk_size $current_disk_name )
    test "$current_size" -gt '0' && replacement_hardware_disk_sizes+=( "$current_size" )
    # Add the current one to the old_and_new_disks_and_sizes array:
    current_kname="/dev/$current_disk_name"
    new_disks_and_sizes+=( "$current_kname $current_size" )
done

# No further disk comparisons are needed when MIGRATION_MODE is already set true above:
if ! is_true "$MIGRATION_MODE" ; then
    # For each of the used disk sizes on the original system
    # determine if that disk size exists more than once on the replacement hardware.
    # Only the used disk sizes on the original system are tested here
    # because there could be many same non-zero block device sizes on the replacement hardware
    # of whatever non-disk block devices that are irrelevant for disk layout recreation.
    local found_orig_size_on_replacement_hardware=0
    local orig_size=''
    for orig_size in "${original_system_used_disk_sizes[@]}" ; do
        found_orig_size_on_replacement_hardware=0
        for current_size in "${replacement_hardware_disk_sizes[@]}" ; do
            test "$current_size" -eq "$orig_size" && (( found_orig_size_on_replacement_hardware += 1 ))
            # MIGRATION_MODE is needed when more than one possible target disk exists for a disk on the original system:
            if test "$found_orig_size_on_replacement_hardware" -gt 1 ; then
                MIGRATION_MODE='true'
                break 2
            fi
        done
    done
    is_true "$MIGRATION_MODE" && LogPrint "Ambiguous possible target disks need manual configuration (more than one with same size found)"
fi

# No further disk comparisons are needed when MIGRATION_MODE is already set true above:
if ! is_true "$MIGRATION_MODE" ; then
    # Compare original disks and their possible target disk one by one:
    while read disk dev size junk ; do
        dev=$( get_sysfs_name $dev )
        Log "Comparing $dev"
        if test -e "/sys/block/$dev" ; then
            Log "Device /sys/block/$dev exists"
            newsize=$( get_disk_size $dev )
            if test "$newsize" -eq "$size" ; then
                if is_write_protected "/sys/block/$dev"; then
                    LogPrint "Device $dev is designated as write-protected (needs manual configuration)"
                    MIGRATION_MODE='true'
                else
                    LogPrint "Device $dev has expected (same) size $size bytes (will be used for '$WORKFLOW')"
                fi
            else
                LogPrint "Device $dev has size $newsize bytes but $size bytes is expected (needs manual configuration)"
                MIGRATION_MODE='true'
            fi
        else
            LogPrint "Device $dev does not exist (manual configuration needed)"
            MIGRATION_MODE='true'
        fi
    done < <( grep -E '^disk |^multipath ' "$LAYOUT_FILE" )
fi

# Show the result to the user:
if is_true "$MIGRATION_MODE" ; then
    LogPrint "Switching to manual disk layout configuration (GiB sizes rounded down to integer)"
    local old_disk_and_size old_disk old_size old_size_GiB
    local new_disk_and_size new_disk new_size new_size_GiB
    # Whole disks that are smaller than one GiB are expected to be so rare
    # that we do not need to implement special case handling for such disks
    # so disks less than one GiB are shown as "... size_in_bytes (0 GiB)"
    # which is OK because the exact size in bytes is always shown:
    local GiB=$(( 1024 * 1024 * 1024 ))
    # Show info about old disks:
    for old_disk_and_size in "${old_disks_and_sizes[@]}" "${old_disabled_disks_and_sizes[@]}" ; do
        old_disk=${old_disk_and_size%% *}
        old_size=${old_disk_and_size##* }
        old_size_GiB=$(( old_size / GiB ))
        for new_disk_and_size in "${new_disks_and_sizes[@]}" ; do
            new_disk=${new_disk_and_size%% *}
            new_size=${new_disk_and_size##* }
            new_size_GiB=$(( new_size / GiB ))
            if test "$old_disk" = "$new_disk" ; then
                if test "$old_size" = "$new_size" ; then
                    LogPrint "$old_disk has same size $old_size ($old_size_GiB GiB)"
                else
                    LogPrint "$old_disk had size $old_size ($old_size_GiB GiB) but is now $new_size ($new_size_GiB GiB)"
                fi
                continue 2
            fi
        done
        LogPrint "$old_disk had size $old_size ($old_size_GiB GiB) but it does no longer exist"
    done
    # Show info about actually new disks (i.e. new disks that did not exist as old disk or old disabled disk):
    for new_disk_and_size in "${new_disks_and_sizes[@]}" ; do
        new_disk=${new_disk_and_size%% *}
        new_size=${new_disk_and_size##* }
        new_size_GiB=$(( new_size / GiB ))
        for old_disk_and_size in "${old_disks_and_sizes[@]}" "${old_disabled_disks_and_sizes[@]}" ; do
            old_disk=${old_disk_and_size%% *}
            test "$old_disk" = "$new_disk" && continue 2
        done
        LogPrint "$new_disk was not used on the original system and has now $new_size ($new_size_GiB GiB)"
    done
else
    LogPrint "Disk configuration looks identical"
    # To be on the safe side a user confirmation dialog is shown here
    # with a relatively short timeout to avoid too much delay by default
    # but sufficient time for the user to read and understand the message
    # so that the user could deliberately intervene and enforce MIGRATION_MODE:
    local timeout=30
    # Have that timeout not bigger than USER_INPUT_TIMEOUT
    # e.g. for automated testing a small USER_INPUT_TIMEOUT may be specified and
    # we do not want to delay it here more than what USER_INPUT_TIMEOUT specifies:
    test "$timeout" -gt "$USER_INPUT_TIMEOUT" && timeout="$USER_INPUT_TIMEOUT"
    local prompt="Proceed with '$WORKFLOW' (yes) otherwise manual disk layout configuration is enforced"
    local input_value=""
    local wilful_input=""
    input_value="$( UserInput -I DISK_LAYOUT_PROCEED_RECOVERY -t "$timeout" -p "$prompt" -D 'yes' )" && wilful_input="yes" || wilful_input="no"
    if is_true "$input_value" ; then
        is_true "$wilful_input" && LogPrint "User confirmed to proceed with '$WORKFLOW'" || LogPrint "Proceeding with '$WORKFLOW' by default"
    else
        # The user enforced MIGRATION_MODE uses the special 'TRUE' value in upper case letters
        # that is needed to overrule the prepare/default/270_overrule_migration_mode.sh script:
        MIGRATION_MODE='TRUE'
        LogPrint "User enforced manual disk layout configuration"
    fi
fi

