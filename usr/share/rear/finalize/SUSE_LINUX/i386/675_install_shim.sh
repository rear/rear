# PAN, 2019-04-09: Introduce SUSE-specific EFI shim install

# Only useful for UEFI systems in combination with grub[2]-efi

# Begin of same tests as in finalize/Linux-i386/670_run_efibootmgr.sh

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

# End of same tests as in finalize/Linux-i386/670_run_efibootmgr.sh

# If the BOOTLOADER variable (read by finalize/default/050_prepare_checks.sh)
# is not "GRUB2-EFI", skip this script:
test "GRUB2-EFI" = "$BOOTLOADER" || return 0

# Skip if GRUB2 (cf. "GRUB2-EFI" = "$BOOTLOADER" above) was not successfully installed
# because a successfully installed GRUB2 bootloader is a precondition for installing shim.
# In this case NOBOOTLOADER is true, cf. finalize/default/050_prepare_checks.sh
if is_true $NOBOOTLOADER ; then
    LogPrintError "Cannot install secure boot loader (shim) because GRUB2 was not successfully installed"
    return 1
fi

LogPrint "Installing secure boot loader (shim)..."

local shiminstall_binary=$( chroot $TARGET_FS_ROOT /bin/bash -c 'PATH=/sbin:/usr/sbin:/usr/bin:/bin type -P shim-install' )

if ! test "$shiminstall_binary" ; then
    LogPrintError "Cannot run shim-install (no shim-install found in $TARGET_FS_ROOT)"
    # Tell the user we did not install the bootloader completely (cf. finalize/default/050_prepare_checks.sh)
    # shim-install is needed in addition to GRUB2 at least on SUSE systems, see https://github.com/rear/rear/issues/2116
    NOBOOTLOADER=1
    return 1
fi

# PATH must be set for shim-install to run successfully:
if ! chroot $TARGET_FS_ROOT /bin/bash -c "PATH=/sbin:/usr/sbin:/usr/bin:/bin $shiminstall_binary --config-file=/boot/grub2/grub.cfg --no-nvram --removable" ; then
    LogPrintError "$shiminstall_binary failed to install secure boot loader (shim) in $TARGET_FS_ROOT"
    # Tell the user we did not install the bootloader completely (cf. finalize/default/050_prepare_checks.sh)
    # shim-install is needed in addition to GRUB2 at least on SUSE systems, see https://github.com/rear/rear/issues/2116
    NOBOOTLOADER=1
    return 1
fi

