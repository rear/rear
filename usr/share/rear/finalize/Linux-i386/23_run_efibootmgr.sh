# only useful for UEFI systems in combination with grub[2]-efi
(( USING_UEFI_BOOTLOADER )) || return  # empty or 0 means using BIOS

# check if /mnt/local/boot/efi is mounted
[[ -d "/mnt/local/boot/efi" ]]
StopIfError "Could not find directory /mnt/local/boot/efi"

BootEfiDev="$( mount | grep "boot/efi" | awk '{print $1}' )"
Dev=$( get_device_name $BootEfiDev )    # /dev/sda1
Disk=$( echo ${Dev} | sed -e 's/[0-9]//g' )  # /dev/sda
ParNr=$( echo ${Dev} | sed -e 's/.*\([0-9]\).*/\1/' )  # 1 (must anyway be a low nr <9)
BootLoader=$( echo $UEFI_BOOTLOADER | cut -d"/" -f4- | sed -e 's;/;\\;g' ) # EFI\fedora\shim.efi
Log efibootmgr --create --gpt --disk ${Disk} --part ${ParNr} --write-signature --label \"${OS_VENDOR} ${OS_VERSION}\" --loader \"\\${BootLoader}\"
efibootmgr --create --gpt --disk ${Disk} --part ${ParNr} --write-signature --label "${OS_VENDOR} ${OS_VERSION}" --loader "\\${BootLoader}"
LogIfError "Problem occurred with creating an efibootmgr entry"

# ok, boot loader has been set-up - tell rear we are done using following var.
NOBOOTLOADER=
