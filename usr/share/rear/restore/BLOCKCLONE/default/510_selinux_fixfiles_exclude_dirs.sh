# For UEFI we should avoid SElinux relabeling the
# vfat filesystem of the EFI System Partition (ESP)
# which is usually mounted at /boot/efi

# Skip if there is no etc/selinux/ directory (e.g. when SELinux is not used)
# and if there is no etc/selinux/ directory creating a fixfiles_exclude_dirs
# file therein (see the code at the end) cannot work anyway:
test -d $TARGET_FS_ROOT/etc/selinux || return 0

# The following four code parts are same also in
# finalize/Linux-i386/670_run_efibootmgr.sh

# USING_UEFI_BOOTLOADER empty or not true means using BIOS
is_true $USING_UEFI_BOOTLOADER || return 0

# We can't rely on standard detection of ESP.
# For EFI_STUB we consider ESP to be mountpoint holding EFISTUB capable kernel.
is_true $EFI_STUB && return 0

# UEFI_BOOTLOADER empty or not a regular file means using BIOS cf. rescue/default/850_save_sysfs_uefi_vars.sh
# Double quotes are mandatory here because 'test -f' without any (possibly empty) argument results true:
test -f "$UEFI_BOOTLOADER" || return 0

# Determine where the EFI System Partition (ESP) is mounted in the currently running recovery system:
esp_mountpoint=$( df -P "$TARGET_FS_ROOT/$UEFI_BOOTLOADER" | tail -1 | awk '{print $6}' )
# Use TARGET_FS_ROOT/boot/efi as fallback ESP mountpoint:
test "$esp_mountpoint" || esp_mountpoint="$TARGET_FS_ROOT/boot/efi"

# Skip if there is no esp_mountpoint directory (e.g. the fallback ESP mountpoint may not exist).
# Double quotes are mandatory here because 'test -d' without any (possibly empty) argument results true:
test -d "$esp_mountpoint" || return 0

# Do not overwrite an existing etc/selinux/fixfiles_exclude_dirs file
# An existing file is user data that was restored from his backup and
# user data is sacrosanct unless the user had confirmed otherwise:
if test -s $TARGET_FS_ROOT/etc/selinux/fixfiles_exclude_dirs ; then
    Log "Not overwriting the existing etc/selinux/fixfiles_exclude_dirs file"
    return 0
fi

# The ESP mountpoint directory values in fixfiles_exclude_dirs
# must match what there will be on the recreated target system
# i.e. esp_mountpoint without TARGET_FS_ROOT prefix:
target_esp_mountpoint=${esp_mountpoint#$TARGET_FS_ROOT}

# Create etc/selinux/fixfiles_exclude_dirs file from scratch:
cat > $TARGET_FS_ROOT/etc/selinux/fixfiles_exclude_dirs <<EOF
$target_esp_mountpoint
$target_esp_mountpoint(/.*)?
EOF
