#
# Remove dangling EFI entries
#

if ! is_true "$USING_UEFI_BOOTLOADER"; then
    return 0
fi

if is_cove_in_azure; then
    return 0
fi

if is_true "$EFI_STUB"; then
    return 0
fi

# $1 - EFI entry id
function remove_efi_entry() {
    if ! has_binary efibootmgr; then
        return 1
    fi

    local id=$1

    efibootmgr -b "$id" -B 2>/dev/null
}

function remove_dangling_efi_entries() {
    if [ -z "$FUTURE_DANGLING_EFI_ENTRIES" ]; then
        return 0
    fi

    for id in $FUTURE_DANGLING_EFI_ENTRIES; do
        LogPrint "Removing EFI Boot Manager entry with '$id' entry ID"
        if ! remove_efi_entry "$id"; then
            LogPrint "Failed to remove EFI Boot Manager entry with '$id' entry ID"
        fi
    done
}

if is_true "$COVE_TESTS"; then
    return 0
fi

remove_dangling_efi_entries
