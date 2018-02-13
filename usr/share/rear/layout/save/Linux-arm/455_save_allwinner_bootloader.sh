# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# Save the 2nd-stage bootloader on Allwinner devices

[ "$BOOTLOADER" = "ARM-ALLWINNER" ] || return 0

used_bootloader=( $( cat $VAR_DIR/recovery/bootloader ) )
base_dir="$VAR_DIR/recovery/allwinner-boot"
[ -d $base_dir ] || mkdir $base_dir

for block_device in /sys/block/* ; do
    blockd=${block_device#/sys/block/}
    # Continue with the next block device when the current block device is not a disk that can be used for booting:
    [[ $blockd = hd* || $blockd = sd* || $blockd = cciss* || $blockd = vd* || $blockd = xvd* || $blockd = nvme* || $blockd = mmcblk* || $blockd = dasd*  ]] || continue
    disk_device=$( get_device_name $block_device )
    Log "Saving Allwinner 2nd stage bootloader for device $disk_device"
    dd if=$disk_device bs=1024 skip=8 count=$((1024-8)) of=$base_dir/$blockd
done
