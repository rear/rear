test "$SECURE_BOOT_BOOTLOADER" && return 0

# Note:
# this is more of a hack than a really good solution.
# The good solution would check the EFI variables for the bootloader
# that is used to boot the system. But this is not implemented yet for
# secure boot.
#
# The code in usr/share/rear/rescue/default/850_save_sysfs_uefi_vars.sh
# could be used as a starting point for this, however currently
# it tries to read the actual boot loader# used only as a last resort
# if well-known files are not found.
#
if type -p mokutil ; then
    PROGS+=( mokutil )
    local secureboot_status
    if secureboot_status=$(mokutil --sb-state 2>&1) ; then
        if grep -q "SecureBoot enabled" <<<"$secureboot_status" ; then
            # Check first for arch-specific and then generic shim file, nullglob will give us the first one found and we ignore the others.
            # shellcheck disable=SC2206
            SECURE_BOOT_BOOTLOADER=( /boot/efi/EFI/*/shim$EFI_ARCH.efi /boot/efi/EFI/*/shim.efi )
            # shellcheck disable=SC2128
            LogPrint "Secure Boot auto-configuration using '$SECURE_BOOT_BOOTLOADER' as UEFI bootloader"
        else
            DebugPrint "Secure Boot is disabled:$LF$secureboot_status"
        fi
    else
        DebugPrint "Secure Boot is not supported:$LF$secureboot_status"
    fi
else
    DebugPrint "mokutil not found, cannot detect Secure Boot status"
fi

return 0
