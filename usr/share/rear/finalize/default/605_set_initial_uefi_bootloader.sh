
# Inital UEFI bootloader is the first stage bootloader, executed by the UEFI
# firmware. It can be the real bootloader (like GRUB), or the shim.
# See the explanation of Shim in 250_populate_efibootimg.sh

is_true $USING_UEFI_BOOTLOADER || return 0

INITIAL_UEFI_BOOTLOADER="${SECURE_BOOT_BOOTLOADER-}"

if test -f "$TARGET_FS_ROOT/$INITIAL_UEFI_BOOTLOADER" ; then
    DebugPrint "Will use Shim SECURE_BOOT_BOOTLOADER='$SECURE_BOOT_BOOTLOADER' as first stage UEFI bootloader of the recovered system"
    return 0
else
    LogPrintError "Not using Shim SECURE_BOOT_BOOTLOADER='$SECURE_BOOT_BOOTLOADER' in the recovered system, file $TARGET_FS_ROOT/$INITIAL_UEFI_BOOTLOADER not found"
    # no return, try UEFI_BOOTLOADER now
fi

# no shim, or not found...
INITIAL_UEFI_BOOTLOADER="${UEFI_BOOTLOADER-}"

if test -f "$TARGET_FS_ROOT/$INITIAL_UEFI_BOOTLOADER" ; then
    DebugPrint "Will use UEFI_BOOTLOADER='$UEFI_BOOTLOADER' as the UEFI bootloader of the recovered system"
    return 0
fi
