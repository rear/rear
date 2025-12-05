#
# Upgrade Shim and GRUB bootloaders on Debian 10
#
# Shim and GRUB are upgraded because Shim from the rescue system
# which is Debian12-based adds new entries to SBAT that leads to having
# non-SecureBoot compatible device after BMR.
#

if [ "$OS_VERSION" != "10" ]; then
    return 0
fi

if ! is_true "$USING_UEFI_BOOTLOADER"; then
    return 0
fi

if is_cove_in_azure; then
    return 0
fi

if is_true "$EFI_STUB"; then
    return 0
fi

if [ "${UEFI_BOOTLOADER##*/}" != "shimx64.efi" ]; then
    return 0
fi

declare -F sb_enabled >/dev/null || function sb_enabled() {
    local sb_var=/sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c
    if [ ! -f "$sb_var" ]; then
        return 1
    fi

    local sb_var_data=0
    sb_var_data=$(dd if=$sb_var bs=1 skip=4 count=1 2>/dev/null | hexdump -e '1/1 "%X"')

    [ "$sb_var_data" -eq 1 ]
}

if upgrade_bootloaders; then
    LogPrint "Upgraded signed Shim and GRUB bootloaders for this system."
else
    LogPrint "Failed to upgrade signed Shim and GRUB bootloaders for this system. UEFI Secure Boot might not be available."
fi
