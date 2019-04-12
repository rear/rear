# PAN, 2019-04-09: Introduce SUSE-specific EFI shim install

# only useful for UEFI systems in combination with grub[2]-efi
is_true $USING_UEFI_BOOTLOADER || return 0 # empty or 0 means using BIOS

# If the BOOTLOADER variable (read by finalize/default/010_prepare_checks.sh)
# is not "GRUB2-EFI", skip this script
test "GRUB2-EFI" = "$BOOTLOADER" || return 0

# check if $TARGET_FS_ROOT/boot/efi is mounted
[[ -d "$TARGET_FS_ROOT/boot/efi" ]]
StopIfError "Could not find directory $TARGET_FS_ROOT/boot/efi"

my_udevtrigger
sleep 5
mount -t proc none $TARGET_FS_ROOT/proc
mount -t sysfs none $TARGET_FS_ROOT/sys

LogPrint "Running shim-install (inside chroot)..."
local shiminstall_binary=$( chroot $TARGET_FS_ROOT /bin/bash -c 'PATH=/sbin:/usr/sbin:/usr/bin:/bin type -P shim-install' )
if test $shiminstall_binary ; then
    # $PATH MUST BE SET for shim-install to run successfully.
    if chroot $TARGET_FS_ROOT /bin/bash -c "PATH=/sbin:/usr/sbin:/usr/bin:/bin $shiminstall_binary --config-file=/boot/grub2/grub.cfg --no-nvram --removable" >&2 ; then
        LogPrint "Re-installed shims ($shiminstall_binary)."
    else
        LogPrint "WARNING:
Failed to re-install shims ($shiminstall_binary).
Check '$RUNTIME_LOGFILE' to see the error messages in detail
and decide yourself, whether the system will boot or not.
"
    fi
else
    LogPrint "WARNING:
Cannot re-install shims (found no shim-install in the recreated system).
Check the recreated system (mounted at $TARGET_FS_ROOT)
and decide yourself, whether the system will boot or not.
"
fi

umount $TARGET_FS_ROOT/proc $TARGET_FS_ROOT/sys

# ok, boot loader has been set-up - tell rear we are done using following var.
NOBOOTLOADER=
