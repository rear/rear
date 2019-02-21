
# Only useful for UEFI systems in combination with grub[2]-efi

# USING_UEFI_BOOTLOADER empty or not true means using BIOS:
is_true $USING_UEFI_BOOTLOADER || return 0

# EFISTUB will handle boot entry creation separately
# (cf. finalize/Linux-i386/610_EFISTUB_run_efibootmgr.sh): 
is_true $EFI_STUB && return

# When UEFI_BOOTLOADER is not a regular file in the restored target system
# (cf. how esp_mountpoint is set below) it means BIOS is used
# (cf. rescue/default/850_save_sysfs_uefi_vars.sh)
# which includes that also an empty UEFI_BOOTLOADER means using BIOS
# because when UEFI_BOOTLOADER is empty the test below evaluates to
#   test -f /mnt/local/
# which also returns false because /mnt/local/ is a directory
# (cf. https://github.com/rear/rear/pull/2051/files#r258826856):
test -f "$TARGET_FS_ROOT/$UEFI_BOOTLOADER" || return 0

# Determine where the EFI System Partition (ESP) is mounted in the currently running recovery system:
esp_mountpoint=$( df -P "$TARGET_FS_ROOT/$UEFI_BOOTLOADER" | tail -1 | awk '{print $6}' )
# Use TARGET_FS_ROOT/boot/efi as fallback ESP mountpoint:
test "$esp_mountpoint" || esp_mountpoint="$TARGET_FS_ROOT/boot/efi"

# Skip if there is no esp_mountpoint directory (e.g. the fallback ESP mountpoint may not exist).
# Double quotes are mandatory here because 'test -d' without any (possibly empty) argument results true:
test -d "$esp_mountpoint" || return 0

BootEfiDev="$( mount | grep "$esp_mountpoint" | awk '{print $1}' )"
# /dev/sda1 or /dev/mapper/vol34_part2 or /dev/mapper/mpath99p4
Dev=$( get_device_name $BootEfiDev )
# 1 (must anyway be a low nr <9)
ParNr=$( get_partition_number $Dev )
# /dev/sda or /dev/mapper/vol34_part or /dev/mapper/mpath99p
Disk=$( echo ${Dev%$ParNr} )

# we have 'mapper' in devname
if [[ ${Dev/mapper//} != $Dev ]] ; then
    # we only expect mpath_partX  or mpathpX or mpath-partX
    case $Disk in
        (*p)     Disk=${Disk%p} ;;
        (*-part) Disk=${Disk%-part} ;;
        (*_part) Disk=${Disk%_part} ;;
        (*)      Log "Unsupported kpartx partition delimiter for $Dev"
    esac
fi

# EFI\fedora\shim.efi
BootLoader=$( echo $UEFI_BOOTLOADER | cut -d"/" -f4- | sed -e 's;/;\\;g' )
LogPrint "Creating  EFI Boot Manager entry '$OS_VENDOR $OS_VERSION' for '$BootLoader' (UEFI_BOOTLOADER='$UEFI_BOOTLOADER')"
Log efibootmgr --create --gpt --disk ${Disk} --part ${ParNr} --write-signature --label \"${OS_VENDOR} ${OS_VERSION}\" --loader \"\\${BootLoader}\"
if efibootmgr --create --gpt --disk ${Disk} --part ${ParNr} --write-signature --label "${OS_VENDOR} ${OS_VERSION}" --loader "\\${BootLoader}" ; then
    # ok, boot loader has been set-up - tell rear we are done using following var.
    NOBOOTLOADER=''
    return
fi

LogPrintError "efibootmgr failed to create EFI Boot Manager entry for '$BootLoader' (UEFI_BOOTLOADER='$UEFI_BOOTLOADER')"

