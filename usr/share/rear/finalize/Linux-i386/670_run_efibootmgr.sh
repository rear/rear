
# Only useful for UEFI systems in combination with grub[2]-efi

# USING_UEFI_BOOTLOADER empty or not true means using BIOS:
is_true $USING_UEFI_BOOTLOADER || return 0

# EFISTUB will handle boot entry creation separately
# (cf. finalize/Linux-i386/610_EFISTUB_run_efibootmgr.sh): 
is_true $EFI_STUB && return

# Do not create EFI Boot Manager entries in Azure, because these are created
# for OS disks. Having incorrect EFI entries for the Cove Rescue Media OS disk
# can make it non-bootable for further use.
if is_cove_in_azure; then
    LogPrint "Skip creating EFI Boot Manager entries in Azure"
    NOBOOTLOADER=""
    return 0
fi

LogPrint "Creating EFI Boot Manager entries..."

local esp_mountpoint esp_mountpoint_inside boot_efi_parts boot_efi_dev

# When UEFI_BOOTLOADER is not a regular file in the restored target system
# (cf. how esp_mountpoint is set below) it means BIOS is used
# (cf. rescue/default/850_save_sysfs_uefi_vars.sh)
# which includes that also an empty UEFI_BOOTLOADER means using BIOS
# because when UEFI_BOOTLOADER is empty the test below evaluates to
#   test -f /mnt/local/
# which also returns false because /mnt/local/ is a directory
# (cf. https://github.com/rear/rear/pull/2051/files#r258826856)
# but using BIOS conflicts with USING_UEFI_BOOTLOADER is true
# i.e. we should create EFI Boot Manager entries but we cannot:
if ! test -f "$TARGET_FS_ROOT/$UEFI_BOOTLOADER" ; then
    LogPrintError "Failed to create EFI Boot Manager entries (UEFI bootloader '$UEFI_BOOTLOADER' not found under target $TARGET_FS_ROOT)"
    return 1
fi

# When EFIBOOTMGR_CREATE_ENTRIES is specified by the user
# call 'efibootmgr' only to create the specified UEFI Boot Manager entries and nothing else.
# See https://github.com/rear/rear/issues/3459
# and https://github.com/rear/rear/pull/3466
# and https://github.com/rear/rear/pull/3471
if test "${#EFIBOOTMGR_CREATE_ENTRIES}" -gt 0 ; then
    LogPrint "Creating EFI Boot Manager entries as specified in EFIBOOTMGR_CREATE_ENTRIES"
    local efibootmgr_create_failed="no"
    local efibootmgr_create_entry efibootmgr_disk efibootmgr_part efibootmgr_loader efibootmgr_label spillover
    for efibootmgr_create_entry in "${EFIBOOTMGR_CREATE_ENTRIES[@]}" ; do
        LogPrint "Creating EFI Boot Manager entry as specified in '$efibootmgr_create_entry'"
        efibootmgr_disk=''
        efibootmgr_part=''
        efibootmgr_loader=''
        efibootmgr_label=''
        spillover=''
        # The 'read -r' option is mandatory because efibootmgr_loader is e.g. "EFI\sles\shim.efi"
        # and without the '-r' option efibootmgr_loader would then become "EFIslesshim.efi"
        read -r efibootmgr_disk efibootmgr_part efibootmgr_loader efibootmgr_label spillover <<<"$efibootmgr_create_entry"
            if test "$spillover" ; then
            LogPrintError "Cannot create EFI Boot Manager entry: more than 4 words in '$efibootmgr_create_entry'"
            continue
        fi
        if ! test -b $efibootmgr_disk ; then
            LogPrintError "efibootmgr cannot create entry using disk '$efibootmgr_disk' (no block device)"
            continue
        fi
        if ! test $efibootmgr_part -gt 0 ; then
            LogPrint "efibootmgr will use default partition number 1 (no positive partition number specified)"
            efibootmgr_part=1
        fi
        if ! test "$efibootmgr_loader" || test "$efibootmgr_loader" = 'automatic' ; then
            # FIXME: The hardcoded '-f4-' assumes UEFI_BOOTLOADER is like /boot/efi/EFI/sles/shim.efi (e.g. on SLES15-SP6)
            # where exactly the first 3 fields are the ESP mountpoint directory like /boot/efi/ (first field is empty)
            # to extract efibootmgr_loader from UEFI_BOOTLOADER which is it without the ESP mountpoint directory
            # and Linux directory separators '/' replaced by VFAT directory separators '\'
            # so that efibootmgr_loader is the VFAT filesystem path of the EFI binary in the ESP
            # e.g. from UEFI_BOOTLOADER /boot/efi/EFI/sles/shim.efi efibootmgr_loader becomes EFI\sles\shim.efi
            # which gets a leading '\' added via "\\$efibootmgr_loader" so in the end \EFI\sles\shim.efi
            # is the absolute VFAT filesystem path in the ESP to what the UEFI Boot Manager should launch:
            efibootmgr_loader="$( echo $UEFI_BOOTLOADER | cut -d"/" -f4- | sed -e 's;/;\\;g' )"
            LogPrint "efibootmgr will use loader '$efibootmgr_loader' from UEFI_BOOTLOADER='$UEFI_BOOTLOADER' (no loader specified)"
        else
            efibootmgr_loader="$( octal_decode "$efibootmgr_loader" )"
        fi
        if ! contains_visible_char "$efibootmgr_label" ; then
            LogPrint "efibootmgr will use default label '$OS_VENDOR $OS_VERSION' (no visible label specified)"
            efibootmgr_label="$OS_VENDOR $OS_VERSION"
        else
            efibootmgr_label="$( octal_decode "$efibootmgr_label" )"
        fi
        LogPrint "Creating EFI Boot Manager entry '$efibootmgr_label' for '$efibootmgr_loader' on disk '$efibootmgr_disk' partition $efibootmgr_part"
        if ! efibootmgr --create --gpt --disk $efibootmgr_disk --part $efibootmgr_part --write-signature --label "$efibootmgr_label" --loader "\\$efibootmgr_loader" ; then
            LogPrintError "efibootmgr failed to create '$efibootmgr_label' entry for '$efibootmgr_loader' on disk '$efibootmgr_disk' partition $efibootmgr_part"
            efibootmgr_create_failed="yes"
        fi
    done
    is_false $efibootmgr_create_failed && NOBOOTLOADER=''
    # Return even if it failed to create an EFI Boot Manager entry on one of the specified EFIBOOTMGR_CREATE_ENTRIES
    # because then the user gets an explicit WARNING via finalize/default/890_finish_checks.sh
    is_true $NOBOOTLOADER && return 1 || return 0
fi

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
if ! test -d "$esp_mountpoint" ; then
    LogPrintError "Failed to create EFI Boot Manager entries (no ESP mountpoint directory $esp_mountpoint)"
    return 1
fi

# Mount point inside the target system,
# accounting for possible trailing slashes in TARGET_FS_ROOT
esp_mountpoint_inside="${esp_mountpoint#${TARGET_FS_ROOT%%*(/)}}"

# Find all partitions with the ESP mount point and skip all other transitive
# 'fs' and 'btrfsmountedsubvol' components in LAYOUT_DEPS (var/lib/rear/layout/diskdeps.conf)
# to support ESP on software RAID (cf. https://github.com/rear/rear/pull/2608).
boot_efi_parts=$( find_partition "fs:$esp_mountpoint_inside" 'btrfsmountedsubvol fs' )
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

local bootloader partition_block_device partition_number disk efipart

# EFI\fedora\shim.efi
bootloader=$( echo $UEFI_BOOTLOADER | cut -d"/" -f4- | sed -e 's;/;\\;g' )

for efipart in $boot_efi_parts ; do
    # /dev/sda1 or /dev/mapper/vol34_part2 or /dev/mapper/mpath99p4
    partition_block_device=$( get_device_name $efipart )
    # 1 or 2 or 4 for the examples above
    partition_number=$( get_partition_number $partition_block_device )
    if ! disk=$( get_device_from_partition $partition_block_device $partition_number ) ; then
        LogPrintError "Cannot create EFI Boot Manager entry for ESP $partition_block_device (unable to find the underlying disk)"
        # do not error out - we may be able to locate other disks if there are more of them
        continue
    fi
    LogPrint "Creating  EFI Boot Manager entry '$OS_VENDOR $OS_VERSION' for '$bootloader' (UEFI_BOOTLOADER='$UEFI_BOOTLOADER') "
    Log efibootmgr --create --gpt --disk $disk --part $partition_number --write-signature --label \"${OS_VENDOR} ${OS_VERSION}\" --loader \"\\${bootloader}\"
    if efibootmgr --create --gpt --disk $disk --part $partition_number --write-signature --label "${OS_VENDOR} ${OS_VERSION}" --loader "\\${bootloader}" ; then
        # ok, boot loader has been set-up - continue with other disks (ESP can be on RAID)
        NOBOOTLOADER=''
    else
        LogPrintError "efibootmgr failed to create EFI Boot Manager entry on $disk partition $partition_number (ESP $partition_block_device )"
    fi
done

is_true $NOBOOTLOADER || return 0
LogPrintError "efibootmgr failed to create EFI Boot Manager entry for '$bootloader' (UEFI_BOOTLOADER='$UEFI_BOOTLOADER')"
return 1
