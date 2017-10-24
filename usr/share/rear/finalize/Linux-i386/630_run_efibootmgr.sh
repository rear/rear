# only useful for UEFI systems in combination with grub[2]-efi
is_true $USING_UEFI_BOOTLOADER || return 0 # empty or 0 means using BIOS

# check if $TARGET_FS_ROOT/boot/efi is mounted
[[ -d "$TARGET_FS_ROOT/boot/efi" ]]
StopIfError "Could not find directory $TARGET_FS_ROOT/boot/efi"

BootEfiDev="$( mount | grep "boot/efi" | awk '{print $1}' )"
Dev=$( get_device_name $BootEfiDev )    # /dev/sda1 or /dev/mapper/vol34_part2 or /dev/mapper/mpath99p4
ParNr=$( get_partition_number $Dev )  # 1 (must anyway be a low nr <9)
Disk=$( echo ${Dev%$ParNr} ) # /dev/sda or /dev/mapper/vol34_part or /dev/mapper/mpath99p

if [[ ${Dev/mapper//} != $Dev ]] ; then # we have 'mapper' in devname
    # we only expect mpath_partX  or mpathpX or mpath-partX
    case $Disk in
        (*p)     Disk=${Disk%p} ;;
        (*-part) Disk=${Disk%-part} ;;
        (*_part) Disk=${Disk%_part} ;;
        (*)      Log "Unsupported kpartx partition delimiter for $Dev"
    esac
fi
BootLoader=$( echo $UEFI_BOOTLOADER | cut -d"/" -f4- | sed -e 's;/;\\;g' ) # EFI\fedora\shim.efi
Log efibootmgr --create --gpt --disk ${Disk} --part ${ParNr} --write-signature --label \"${OS_VENDOR} ${OS_VERSION}\" --loader \"\\${BootLoader}\"
efibootmgr --create --gpt --disk ${Disk} --part ${ParNr} --write-signature --label "${OS_VENDOR} ${OS_VERSION}" --loader "\\${BootLoader}"
LogIfError "Problem occurred with creating an efibootmgr entry"

# ok, boot loader has been set-up - tell rear we are done using following var.
NOBOOTLOADER=
