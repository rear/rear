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
################################################################
# THIS SCRIPT CONTAINS PPC64/PPC64LE SPECIFIC
#################################################################
# skip if another bootloader was installed
if [[ -z "$NOBOOTLOADER" ]] ; then
    return
fi

# Only for GRUB2 - GRUB Legacy will be handled by its own script
[[ $(type -p grub-probe) || $(type -p grub2-probe) ]] || return 0

LogPrint "Installing GRUB2 boot loader"
mount -t proc none $TARGET_FS_ROOT/proc

if [[ -r "$LAYOUT_FILE" ]]; then

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

    # Find PPC PReP Boot partition
    part_list=$( awk -F ' ' '/^part / {if ($6 ~ /prep/) {print $7}}' $LAYOUT_FILE )

    # If software RAID1 is used, several boot device will be found
    # need to install grub2 on each of them
    for part in $part_list ; do
        if [ -n "$part" ]; then
            LogPrint "Boot partition found: $part"
            dd if=/dev/zero of=$part
            # Run grub-install/grub2-install directly in chroot without a login shell in between, see https://github.com/rear/rear/issues/862
            # When software RAID1 is used, grub2 needs correct PATH to access other tools
            if chroot $TARGET_FS_ROOT /usr/bin/env PATH=/sbin:/usr/sbin:/usr/bin:/bin $grub_name-install $part ; then
                LogPrint "GRUB2 installed on $part"
                NOBOOTLOADER=
            else
                LogPrint "Failed to install GRUB2 on $part"
            fi
        fi
    done
fi

if [[ "$NOBOOTLOADER" ]]; then
    LogIfError "No bootloader configuration found. Install boot partition manually"
fi

umount $TARGET_FS_ROOT/proc
