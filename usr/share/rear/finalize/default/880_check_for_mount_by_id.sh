#
# Automatically adjusting /dev/disk/by-id entries in etc/fstab is not supported
# because we do not know how to set the original LUN IDs to the new / recovered hardware.
# To help the user we check for /dev/disk/by-id entries in etc/fstab
# and show the LUN IDs of SCSI disk devices via 'scsi_id'.
# TODO: For non-SCSI disk devices we show nothing.
# Non-SCSI disks are in particular NVMe devices and KVM 'VirtIO' virtual disks,
# see https://github.com/rear/rear/issues/3383
#

# TODO: Shouldn't this be at least reported to the user as LogPrintError?
test -e "$TARGET_FS_ROOT/etc/fstab" || return 0

# We ignore swap here because we treat it specially somewhere else.
# FIXME: Where exactly is that "somewhere else"?
#
# "man fstab" (from util-linux-2.39.3) tells (excerpts):
#   Lines starting with '#' are comments. Blank lines are ignored.
#   first field (fs_spec) ... block special device, remote filesystem or filesystem image for loop device ... or swap file or swap device
#   second field (fs_file) ...  For swap area, this field should be specified as 'none'
#   third field (fs_vfstype) ... An entry swap denotes a file or partition to be used for swapping
# so only the fs_vfstype field can be used to find out if it is a swap area.
local by_id_no_block_devices=()
local fs_spec fs_file fs_vfstype junk
while read fs_spec fs_file fs_vfstype junk ; do
    # Ignore swap:
    test "$fs_vfstype" = "swap" && continue
    # Skip fstab entries which are not /dev/disk/by-id/...:
    [[ $fs_spec =~ ^/dev/disk/by-id/ ]] || continue
    # No we have an /dev/disk/by-id/... entry which is not used as swap.
    # All is well with this one when it exist as block device on the replacement hardware:
    test -b "$fs_spec" && continue
    # Remember it when it does not exist as block device on the replacement hardware:
    by_id_no_block_devices+=( "$fs_spec" )
done < <( grep -E -v "^#|^[[:space:]]*$" "$TARGET_FS_ROOT/etc/fstab" ) # Ignore comments and blank lines

if test ${#by_id_no_block_devices[@]} -eq 0 ; then
    # All is well when all /dev/disk/by-id entries in etc/fstab exist as block devices in the recreated system.
    # In particular there is no need to show additional 'scsi_id' output.
    DebugPrint "All /dev/disk/by-id entries in etc/fstab exist as block devices in the recreated system"
    return 0
fi

# Something is mounted via /dev/disk/by-id in etc/fstab where its /dev/disk/by-id/...
# does not exist as block device in the ReaR recovery system on the replacement hardware
# cf. https://github.com/rear/rear/issues/3383#issuecomment-2652966699
# Tell the user that automatically adjusting /dev/disk/by-id entries is not supported:
LogPrintError "Automatically adjusting /dev/disk/by-id entries in etc/fstab is not supported:"
LogPrintError "  Check $TARGET_FS_ROOT/etc/fstab and manually adjust /dev/disk/by-id entries"
LogPrintError "  as needed to the actual values of the recreated system in $TARGET_FS_ROOT"
# Show the user the /dev/disk/by-id entries which are no block devices in the recreated system:
LogPrintError "  Those /dev/disk/by-id entries are no block devices in the recreated system:"
local by_id_no_block_device
for by_id_no_block_device in "${by_id_no_block_devices[@]}" ; do
    LogPrintError "  $by_id_no_block_device"
done

# Additional 'scsi_id' output:
# TODO: I <jsmeix@suse.de> wonder if 'scsi_id' output is still needed nowadays
# when neither NVMe disks nor KVM 'VirtIO' virtual disks are SCSI disks
# so perhaps that rather complicated code for 'scsi_id' output could be dropped?
#
# The supported options of scsi_id changed over time, so we try two commonly known ways to call it,
# cf. https://github.com/rear/rear/issues/3383#issuecomment-2618970742
# scsi_id is usually either /lib/udev/scsi_id (e.g. in SLES 11 SP4 with udev-147)
# or /usr/lib/udev/scsi_id (e.g. in SLES 12 SP5 with udev-228 or in SLES 15 SP6 with systemd 254 and udev-254)
# where /lib/udev/scsi_id supports e.g. '/lib/udev/scsi_id --export --whitelisted --device=/dev/sda'
# and /usr/lib/udev/scsi_id supports e.g. '/usr/lib/udev/scsi_id -x -g -d /dev/sda'
# cf. https://github.com/rear/rear/issues/3383#issuecomment-2618970742
if ! test -x /usr/lib/udev/scsi_id -o -x /lib/udev/scsi_id ; then
    # Give up. The above LogPrintError should be enough:
    Debug "Neither /usr/lib/udev/scsi_id nor /lib/udev/scsi_id is executable"
    return 1
fi

local major minor blocks name
local device_path
local scsi_id_output
local scsi_id_actual_result='no'
# It seems ID_VENDOR ID_MODEL ID_SERIAL are commonly reported values by scsi_id
# cf. https://github.com/rear/rear/issues/3383#issuecomment-2618157153
# and https://github.com/rear/rear/issues/3383#issuecomment-2618219758
# and https://github.com/rear/rear/issues/3383#issuecomment-2618970742
local egrep_pattern='^ID_VENDOR=|^ID_MODEL=|^ID_SERIAL='
# /proc/partitions looks like:
# major  minor   #blocks  name
#
#   254      0  15728640  sda
#   254      1      8192  sda1
#   254      2  13622272  sda2
#   254      3   2097135  sda3
#    11      0  16057344  sr0
# So the first two lines in /proc/partitions do not contain useful data.
while read major minor blocks name ; do
    # Skip lines in /proc/partitions where 'major' is not a positive integer,
    # cf. https://www.kernel.org/doc/Documentation/admin-guide/devices.txt
    is_positive_integer "$major" || continue
    # Get a clean kernel device path,
    # e.g. 'readlink -e /dev//sda1' results '/dev/sda1'
    # and 'readlink -e /dev/mapper/cr_root' would result something like '/dev/dm-0'
    # (regardless that /proc/partitions should not show symlinks as 'name')
    # and when 'readlink -e' fails device_path becomes empty:
    device_path="$( readlink -e /dev/$name )"
    # Skip when it does not exist (device_path empty) or is no block device:
    test -b "$device_path" || continue
    # Get the scsi_id output of ID_VENDOR ID_MODEL ID_SERIAL for the current device:
    scsi_id_output=''
    # Try the newer one /usr/lib/udev/scsi_id first and try the older one /lib/udev/scsi_id as fallback
    # cf. the "try several commands with same intent" example in https://github.com/rear/rear/wiki/Coding-Style#dirty-hacks-welcome
    if test -x /usr/lib/udev/scsi_id ; then
        # /usr/lib/udev/scsi_id from udev-254 on SLES 15 SP6 succeeds with non-existent device:
        #   # /usr/lib/udev/scsi_id -x -g -d /dev/QQQ && echo Y || echo N
        #   ID_SCSI=1
        #   ID_VENDOR=
        #   ID_VENDOR_ENC=
        #   ID_MODEL=
        #   ID_MODEL_ENC=
        #   ID_REVISION=
        #   ID_TYPE=
        #   Y
        # so we cannot use the /usr/lib/udev/scsi_id exit code
        # to determine whether or not scsi_id was actually successful.
        # Perhaps ID_SERIAL could be used because it is not set for a non-existent device
        # but it seems to be set for existent devices, see https://github.com/rear/rear/issues/3383
        # but how far could or should we rely on possibly changing scsi_id behaviour in general?
        # So we keep it simple and straightforward and focus on what we are actually interested in
        # i.e. only the scsi_id output of ID_VENDOR ID_MODEL ID_SERIAL (as a string without newlines):
        scsi_id_output="$( /usr/lib/udev/scsi_id -x -g -d $device_path | grep -E "$egrep_pattern" | tr -s '\n' ' ' )"
    else
        # Try the older one /lib/udev/scsi_id as fallback.
        # Above was already tested that /lib/udev/scsi_id is executable when /usr/lib/udev/scsi_id is not executable.
            scsi_id_output="$( /lib/udev/scsi_id --export --whitelisted --device=$device_path | grep -E "$egrep_pattern" | tr -s '\n' ' ' )"
    fi
    if ! contains_visible_char "$scsi_id_output" ; then
        # Give up with this device and continue with the next one:
        Debug "scsi_id: not any output of ID_VENDOR ID_MODEL ID_SERIAL for '$device_path'"
        continue
    fi
    # Now we have an actual scsi_id result, i.e. at least one of ID_VENDOR or ID_MODEL or ID_SERIAL is output:
    scsi_id_actual_result='yes'
    # Show the user what scsi_id reports for the current SCSI /proc/partitions device:
    LogPrint "  'scsi_id' reports '$device_path' $((blocks/1024))MiB: $scsi_id_output"
done </proc/partitions

# return 0 when there was at least one actual scsi_id result, otherwise return 1:
is_true $scsi_id_actual_result
