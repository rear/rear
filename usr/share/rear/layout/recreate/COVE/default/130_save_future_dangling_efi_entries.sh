#
# Save future dangling EFI entries
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

# $1 - block device, e.g. /dev/sda or /dev/sdb
get_disk_partuuids() {
    if ! has_binary blkid; then
        return 1
    fi

    local disk=$1

    if [ ! -b "$disk" ]; then
        return 1
    fi

    disk="${disk}*"

    # shellcheck disable=SC2086
    blkid -s PARTUUID -o value $disk
}

get_partuuids_of_disks_to_be_overwritten() {
    if is_false "$DISKS_TO_BE_OVERWRITTEN" || [ -z "$DISKS_TO_BE_OVERWRITTEN" ]; then
        return 0
    fi

    local partuuids=""
    for disk in $DISKS_TO_BE_OVERWRITTEN; do
        local partuuids_for_disk
        partuuids_for_disk="$(get_disk_partuuids "$disk")" || continue
        partuuids+="$partuuids_for_disk"$'\n'
    done

    if [ -n "$partuuids" ]; then
        # Trim the result
        partuuids="${partuuids::-1}"
    fi

    echo "$partuuids" | sort -u
}

get_efi_entries() {
    if ! has_binary efibootmgr; then
        return 1
    fi

    efibootmgr -v 2>/dev/null
}

get_future_dangling_efi_entries() {
    local partuuids
    partuuids="$(get_partuuids_of_disks_to_be_overwritten)" || return 1

    local boot_numbers

    local entry
    while IFS= read -r entry; do
        local partuuid
        partuuid=$(echo "$entry" | grep -oP '(?<=GPT,|MBR,)[0-9a-fA-F-]+') || continue
        if echo "$partuuids" | grep -q "^$partuuid$"; then
            local boot_number
            boot_number="$(echo "$entry" | awk '{print $1}' | grep -oP '(?<=Boot)[0-9a-fA-F]+')" || continue
            boot_numbers+="$boot_number "
        fi
    done <<< "$(get_efi_entries)"

    if [ -n "$boot_numbers" ]; then
        # Trim the result
        boot_numbers="${boot_numbers::-1}"
    fi

    echo "$boot_numbers"
}

if is_true "$COVE_TESTS"; then
    return 0
fi

if FUTURE_DANGLING_EFI_ENTRIES=$(get_future_dangling_efi_entries); then
    LogPrint "Found future dangling EFI entries: $FUTURE_DANGLING_EFI_ENTRIES"
else
    LogPrint "Failed to identify future dangling EFI entries"
fi
