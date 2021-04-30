
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

LogPrint "Creating EFI Boot Manager entries..."
# Determine where the EFI System Partition (ESP) is mounted in the currently running recovery system:
esp_mountpoint=$( filesystem_name "$TARGET_FS_ROOT/$UEFI_BOOTLOADER" )
# Use TARGET_FS_ROOT/boot/efi as fallback ESP mountpoint (filesystem_name returns "/"
# if mountpoint not found otherwise):
if [ "$esp_mountpoint" = "/" ] ; then
    esp_mountpoint="$TARGET_FS_ROOT/boot/efi"
    LogPrint "Mountpoint of $TARGET_FS_ROOT/$UEFI_BOOTLOADER not found, trying $esp_mountpoint"
fi

# Skip if there is no esp_mountpoint directory (e.g. the fallback ESP mountpoint may not exist).
# Double quotes are mandatory here because 'test -d' without any (possibly empty) argument results true:
test -d "$esp_mountpoint" || return 0

# Mount point inside the target system,
# accounting for possible trailing slashes in TARGET_FS_ROOT
esp_mountpoint_inside="${esp_mountpoint#${TARGET_FS_ROOT%%*(/)}}"

boot_efi_parts=$( find_partition "fs:$esp_mountpoint_inside" fs )
if ! test "$boot_efi_parts" ; then
    LogPrint "Unable to find ESP $esp_mountpoint_inside in layout"
    LogPrint "Trying to determine device currently mounted at $esp_mountpoint as fallback"
    boot_efi_dev="$( mount | grep "$esp_mountpoint" | awk '{print $1}' )"
    if ! test "$boot_efi_dev" ; then
        LogPrintError "Cannot create EFI Boot Manager entry (unable to find ESP $esp_mountpoint among mounted devices)"
        return 1
    fi
    if test $(get_component_type "$boot_efi_dev") = part ; then
        boot_efi_parts="$boot_efi_dev"
    else
        boot_efi_parts=$( find_partition "$boot_efi_dev" )
    fi
    if ! test "$boot_efi_parts" ; then
        LogPrintError "Cannot create EFI Boot Manager entry (unable to find partition for $boot_efi_dev)"
        return 1
    fi
    LogPrint "Using fallback EFI boot partition(s) $boot_efi_parts (unable to find ESP $esp_mountpoint_inside in layout)"
fi

# EFI\fedora\shim.efi
BootLoader=$( echo $UEFI_BOOTLOADER | cut -d"/" -f4- | sed -e 's;/;\\;g' )

for efipart in $boot_efi_parts ; do
    # /dev/sda1 or /dev/mapper/vol34_part2 or /dev/mapper/mpath99p4
    Dev=$( get_device_name $efipart )
    # 1 or 2 or 4 for the examples above
    ParNr=$( get_partition_number $Dev )
    Disk=$( get_device_from_partition $Dev $ParNr )
    LogPrint "Creating  EFI Boot Manager entry '$OS_VENDOR $OS_VERSION' for '$BootLoader' (UEFI_BOOTLOADER='$UEFI_BOOTLOADER') "
    Log efibootmgr --create --gpt --disk ${Disk} --part ${ParNr} --write-signature --label \"${OS_VENDOR} ${OS_VERSION}\" --loader \"\\${BootLoader}\"
    if efibootmgr --create --gpt --disk ${Disk} --part ${ParNr} --write-signature --label "${OS_VENDOR} ${OS_VERSION}" --loader "\\${BootLoader}" ; then
        # ok, boot loader has been set-up - continue with other disks (ESP can be on RAID)
        NOBOOTLOADER=''
    else
        LogPrintError "efibootmgr failed to create EFI Boot Manager entry on $Disk partition $ParNr (ESP $Dev)"
    fi
done

is_true $NOBOOTLOADER || return 0
LogPrintError "efibootmgr failed to create EFI Boot Manager entry for '$BootLoader' (UEFI_BOOTLOADER='$UEFI_BOOTLOADER')"
