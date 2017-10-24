#  This script is meant for UEFI based systems using ELILO (SLES)
#

# skip if another bootloader was installed
if [[ -z "$NOBOOTLOADER" ]] ; then
    return
fi

# for UEFI systems we defined USING_UEFI_BOOTLOADER=1; BIOS based is 0 or ""
is_true $USING_UEFI_BOOTLOADER || return 0 # when set to 0

# Only for elilo
[[ "$BOOTLOADER" == "ELILO" ]] || return 0 # only continue when bootloader is elilo based

[[ $(type -p elilo) ]]
StopIfError "Could not find elilo executable"


LogPrint "Installing ELILO boot loader"
mount -t proc none $TARGET_FS_ROOT/proc
#for virtual_filesystem in /dev /dev/pts /proc /sys ; do mount -B $virtual_filesystem $TARGET_FS_ROOT$virtual_filesystem ; done

if [[ -r "$LAYOUT_FILE" && -r "$LAYOUT_DEPS" ]]; then

    # Check if we find the vfat file system /boot/efi where we expect it
    [[ -d "$TARGET_FS_ROOT/boot/efi" ]]
    StopIfError "Could not find directory /boot/efi"

    # the UEFI_BOOTLOADER was saved in /etc/rear/rescue.conf file by rear mkrescue/mkbackup
    [[ -f "$TARGET_FS_ROOT$UEFI_BOOTLOADER" ]]
    StopIfError "Could not find elilo.efi"

    [[ -r "$TARGET_FS_ROOT/etc/elilo.conf" ]]
    LogIfError "Unable to find /etc/elilo.conf"

    # Find the disks that need a new ELILO
    disks=$(grep '^disk \|^multipath ' $LAYOUT_FILE | cut -d' ' -f2)
    [[ "$disks" ]]
    StopIfError "Unable to find any disks"


    chroot $TARGET_FS_ROOT elilo -v >&2

    if (( $? == 0 )); then
        NOBOOTLOADER=
    fi
fi


#for virtual_filesystem in /dev /dev/pts /proc /sys ; do umount $TARGET_FS_ROOT$virtual_filesystem ; done
umount $TARGET_FS_ROOT/proc
