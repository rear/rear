# This script is an improvement over the default grub-install '(hd0)'
#
# However the following issues still exist:
#
#  * We don't know what the first disk will be, so we cannot be sure the MBR
#    is written to the correct disk(s). That's why we make all disks bootable.
#
#  * There is no guarantee that GRUB was the boot loader used originally. One
#    solution is to save and restore the MBR for each disk, but this does not
#    guarantee a correct boot-order, or even a working boot-lader config (eg.
#    GRUB stage2 might not be at the exact same location)

# skip if another bootloader was installed
if [[ -z "$NOBOOTLOADER" ]] ; then
    return
fi

# for UEFI systems with grub legacy with should use efibootmgr instead
(( USING_UEFI_BOOTLOADER )) && return # set to 1 means UEFI booting

# check the BOOTLOADER variable (read by 01_prepare_checks.sh script)
if [[ "$BOOTLOADER" = "GRUB" ]]; then
    if [[ $(type -p grub-probe) || $(type -p grub2-probe) ]]; then
        # grub2 script should handle this instead
        return
    fi
fi

# Only for GRUB Legacy - GRUB2 will be handled by its own script
if [[ -z "$(type -p grub)" ]]; then
    return
fi

LogPrint "Installing GRUB boot loader"
mount -t proc none /mnt/local/proc

if [[ -r "$LAYOUT_FILE" && -r "$LAYOUT_DEPS" ]]; then

    # Check if we find GRUB stage 2 where we expect it
    [[ -d "/mnt/local/boot" ]]
    StopIfError "Could not find directory /boot"
    [[ -d "/mnt/local/boot/grub" ]]
    StopIfError "Could not find directory /boot/grub"
    [[ -r "/mnt/local/boot/grub/stage2" ]]
    StopIfError "Unable to find /boot/grub/stage2."

    # Find exclusive partition(s) belonging to /boot
    # or / (if /boot is inside root filesystem)
    if [[ "$(filesystem_name /mnt/local/boot)" == "/mnt/local" ]]; then
        bootparts=$(find_partition fs:/)
        grub_prefix=/boot/grub
    else
        bootparts=$(find_partition fs:/boot)
        grub_prefix=/grub
    fi
    # Should never happen
    [[ "$bootparts" ]]
    BugIfError "Unable to find any /boot partitions"

    # Find the disks that need a new GRUB MBR
    disks=$(grep '^disk \|^multipath ' $LAYOUT_FILE | cut -d' ' -f2)
    [[ "$disks" ]]
    StopIfError "Unable to find any disks"

    for disk in $disks; do
        # Use first boot partition by default
        part=$(echo $bootparts | cut -d' ' -f1)

        # Use boot partition that matches with this disk, if any
        for bootpart in $bootparts; do
            bootdisk=$(find_disk_and_multipath "$bootpart")
            if [[ "$disk" == "$bootdisk" ]]; then
                part=$bootpart
                break
            fi
        done

        # Find boot-disk and partition number
        bootdisk=$(find_disk_and_multipath "$part")
        partnr=${part#$bootdisk}
        partnr=${partnr#p}
        partnr=$((partnr - 1))

        if [[ "$bootdisk" == "$disk" ]]; then
            # Best case scenario is to have /boot on disk with MBR booted
            chroot /mnt/local grub --batch --no-floppy >&2 <<EOF
device (hd0) $disk
root (hd0,$partnr)
setup --stage2=/boot/grub/stage2 --prefix=$grub_prefix (hd0)
quit
EOF
        else
            # hd1 is a best effort guess, we cannot predict how numbering
            # changes when a disk fails.
            chroot /mnt/local grub --batch --no-floppy >&2 <<EOF
device (hd0) $disk
device (hd1) $bootdisk
root (hd1,$partnr)
setup --stage2=/boot/grub/stage2 --prefix=$grub_prefix (hd0)
quit
EOF
        fi

        if (( $? == 0 )); then
            NOBOOTLOADER=
        fi
    done
fi

if [[ "$NOBOOTLOADER" ]]; then
    if chroot /mnt/local grub-install '(hd0)' >&2 ; then
        NOBOOTLOADER=
    fi
fi

umount /mnt/local/proc
