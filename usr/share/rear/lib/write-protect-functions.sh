#!/bin/bash
#
# Functions to identify write-protected disks and partitions
#

function write_protected_candidate_device() {
    local device="$1"
    # prints the path of the block device, translating it if given as /sys/block/*.

    if [[ "$device" == /sys/block/* ]]; then
        device="$(get_device_name "$device")"
    fi
    [[ ! -b "$device" ]] && Error "Could not check '$1' ('$device') for write protection – not a block device"
    echo "$device"
}

function is_write_protected_by_pt_uuid() {
    local device="$(write_protected_candidate_device "$1")"
    # returns 0 if the device's partition table UUID is in the list of write-protected UUIDs.

    local partition_table_uuid="$(lsblk --output PTUUID --noheadings --nodeps "$device")"

    if [[ " ${WRITE_PROTECTED_PARTITION_TABLE_UUIDS[*]} " == *" $partition_table_uuid "* ]]; then
        Log "$device is designated as write-protected by partition table UUID '$partition_table_uuid'"
        return 0
    fi

    return 1
}

function is_write_protected_by_fs_label() {
    local device="$(write_protected_candidate_device "$1")"
    # returns 0 if one of the device's file system labels matches a prefix from the list of write-protected
    # label prefixes.

    # Check all partitions of a device for a matching label
    local write_protected_pattern
    while read -r partition_label; do
        if [[ -n "$partition_label" ]]; then
            for write_protected_pattern in "${WRITE_PROTECTED_FILE_SYSTEM_LABEL_PATTERNS[@]}"; do
                if [[ "$partition_label" == $write_protected_pattern ]]; then
                    Log "$device is designated as write-protected, its label '$partition_label' matches '$write_protected_pattern'"
                    return 0
                fi
            done
        fi
    done < <(lsblk --output LABEL --noheadings "$device")

    return 1
}

function is_write_protected() {
    local device="$(write_protected_candidate_device "$1")"
    # returns 0 if the device is designated as write-protected by any of the above means.

    is_write_protected_by_pt_uuid "$device" || is_write_protected_by_fs_label "$device"
}
