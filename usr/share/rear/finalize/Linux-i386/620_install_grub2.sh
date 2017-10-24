#  This  script is an improvement over the default grub-install '(hd0)'
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
    return 0
fi

# for UEFI systems with grub2 we should use efibootmgr instead
is_true $USING_UEFI_BOOTLOADER && return # when set to 1

# Only for GRUB2 - GRUB Legacy will be handled by its own script
[[ $(type -p grub-probe) || $(type -p grub2-probe) ]] || return 0

LogPrint "Installing GRUB2 boot loader"
mount -t proc none $TARGET_FS_ROOT/proc
#for virtual_filesystem in /dev /dev/pts /proc /sys ; do mount -B $virtual_filesystem $TARGET_FS_ROOT$virtual_filesystem ; done

if [[ -r "$LAYOUT_FILE" && -r "$LAYOUT_DEPS" ]]; then

    # Check if we find GRUB where we expect it
    [[ -d "$TARGET_FS_ROOT/boot" ]]
    StopIfError "Could not find directory /boot"

    # grub2 can be in /boot/grub or /boot/grub2
    grub_name="grub2"
    if [[ ! -d "$TARGET_FS_ROOT/boot/$grub_name" ]] ; then
        grub_name="grub"
        [[ -d "$TARGET_FS_ROOT/boot/$grub_name" ]]
        StopIfError "Could not find directory /boot/$grub_name"
    fi
    [[ -r "$TARGET_FS_ROOT/boot/$grub_name/grub.cfg" ]]
    LogIfError "Unable to find /boot/$grub_name/grub.cfg."

    # Find exclusive partition(s) belonging to /boot
    # or / (if /boot is inside root filesystem)
    if [[ "$( filesystem_name $TARGET_FS_ROOT/boot )" == "$TARGET_FS_ROOT" ]]; then
        bootparts=$(find_partition fs:/)
        grub_prefix=/boot/grub2
    else
        bootparts=$(find_partition fs:/boot)
        grub_prefix=/grub2
    fi
    # Should never happen
    [[ "$bootparts" ]]
    BugIfError "Unable to find any /boot partitions"

    # Find the disks that need a new GRUB MBR
    disks=$(grep '^disk \|^multipath ' $LAYOUT_FILE | cut -d' ' -f2)
    [[ "$disks" ]]
    StopIfError "Unable to find any disks"

    for disk in $disks; do
        # Installing grub on an LVM PV will wipe the metadata so we skip those
        if is_disk_a_pv "$disk" ; then
            continue
        fi
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
            #chroot $TARGET_FS_ROOT $grub_name-mkconfig -o /boot/$grub_name/grub.cfg
	    #chroot $TARGET_FS_ROOT $grub_name-install "$bootdisk"
	    $grub_name-install --root-directory=$TARGET_FS_ROOT $bootdisk
        else
            chroot $TARGET_FS_ROOT $grub_name-mkconfig -o /boot/$grub_name/grub.cfg
	    #chroot $TARGET_FS_ROOT $grub_name-install "$bootdisk"
	    $grub_name-install --root-directory=$TARGET_FS_ROOT $bootdisk
        fi

        if (( $? == 0 )); then
            NOBOOTLOADER=
        fi
    done
fi

if [[ "$NOBOOTLOADER" ]]; then
    if chroot $TARGET_FS_ROOT grub2-install "$disk" >&2 ; then
        NOBOOTLOADER=
    fi
fi

#for virtual_filesystem in /dev /dev/pts /proc /sys ; do umount $TARGET_FS_ROOT$virtual_filesystem ; done
umount $TARGET_FS_ROOT/proc
