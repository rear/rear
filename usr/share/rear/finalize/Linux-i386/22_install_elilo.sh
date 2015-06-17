#  This script is meant for UEFI based systems using ELILO (SLES)
#

# skip if another bootloader was installed
if [[ -z "$NOBOOTLOADER" ]] ; then
    return
fi

# for UEFI systems we defined USING_UEFI_BOOTLOADER=1; BIOS based is 0 or ""
(( USING_UEFI_BOOTLOADER )) || return # when set to 0

# Only for elilo
[[ "$BOOTLOADER" == "ELILO" ]] || return  # only continue when bootloader is elilo based

[[ $(type -p elilo) ]]
StopIfError "Could not find elilo executable"


LogPrint "Installing ELILO boot loader"
mount -t proc none /mnt/local/proc
#for i in /dev /dev/pts /proc /sys; do mount -B $i /mnt/local${i} ; done

if [[ -r "$LAYOUT_FILE" && -r "$LAYOUT_DEPS" ]]; then

    # Check if we find the vfat file system /boot/efi where we expect it
    [[ -d "/mnt/local/boot/efi" ]]
    StopIfError "Could not find directory /boot/efi"

    # the UEFI_BOOTLOADER was saved in /etc/rear/rescue.conf file by rear mkrescue/mkbackup
    [[ ! -f "/mnt/local${UEFI_BOOTLOADER}" ]]
    StopIfError "Could not find elilo.efi"

    [[ -r "/mnt/local/etc/elilo.conf" ]]
    LogIfError "Unable to find /etc/elilo.conf"

    # Find the disks that need a new ELILO
    disks=$(grep '^disk \|^multipath ' $LAYOUT_FILE | cut -d' ' -f2)
    [[ "$disks" ]]
    StopIfError "Unable to find any disks"


    chroot /mnt/local elilo -v >&2

    if (( $? == 0 )); then
        NOBOOTLOADER=
    fi
fi


#for i in /dev /dev/pts /proc /sys; do umount  /mnt/local${i} ; done
umount /mnt/local/proc
