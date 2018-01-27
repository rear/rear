# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# Restore the 2nd-Stage Bootloader on Allwinner Devices

# Skip if another boot loader is already installed
# (then $NOBOOTLOADER is not a true value cf. finalize/default/010_prepare_checks.sh):
is_true $NOBOOTLOADER || return 0

[ "$BOOTLOADER" = "ARM-ALLWINNER" ] || return 0

# Parted can output machine parseable information
FEATURE_PARTED_MACHINEREADABLE=

parted_version=$(get_version parted -v)
[[ "$parted_version" ]]
BugIfError "Function get_version could not detect parted version."

if version_newer "$parted_version" 1.8.2 ; then
    FEATURE_PARTED_MACHINEREADABLE=y
fi

used_bootloader=( $( cat $VAR_DIR/recovery/bootloader ) )

base_dir="$VAR_DIR/recovery/allwinner-boot"
[ -d $base_dir ] || Error "No Saved Allwinner 2nd Stage Bootloader"

for block_device in /sys/block/* ; do
    blockd=${block_device#/sys/block/}
    # Continue with the next block device when the current block device is not a disk that can be used for booting:
    [[ $blockd = hd* || $blockd = sd* || $blockd = cciss* || $blockd = vd* || $blockd = xvd* || $blockd = nvme* || $blockd = mmcblk* || $blockd = dasd*  ]] || continue
    disk_device=$( get_device_name $block_device )

    if [[ $FEATURE_PARTED_MACHINEREADABLE ]] ; then
        disk_label=$(parted -m -s $disk_device print | grep ^/ | cut -d ":" -f "6")
    else
        disk_label=$(parted -s $disk_device print | grep -E "Partition Table|Disk label" | cut -d ":" -f "2" | tr -d " ")
    fi
    # Don't overwrite Raw Disks
    if [ -f $base_dir/$blockd ] && [ "$disk_label" = "msdos" ]; then
        NOBOOTLOADER=""
        LogPrint "Restoring Allwinner 2nd Stage Bootloader on Device $disk_device"
        dd if=$base_dir/$blockd of=$disk_device bs=1024 seek=8
    fi
done

is_true $NOBOOTLOADER && Error "Failed to install Allwinner 2nd Stage Bootloader."

