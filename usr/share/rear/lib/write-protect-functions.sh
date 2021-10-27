#!/bin/bash
#
# Functions to identify write-protected disks and partitions
#

function write_protected_candidate_device() {
    local device="$1"
    # prints the path of the block device, translating it if given as /sys/block/*.

    if [[ "$device" == /sys/block/* ]]; then
        device="$( get_device_name "$device" )"
    fi
    test -b "$device" || BugError "write_protected_candidate_device called for '$device' which is no block device"
    echo "$device"
}

function write_protection_uuids() {
    local device="$( write_protected_candidate_device "$1") "
    # Output the UUIDs for write-protection, each UUID on a separated line.
    # UUIDs are those that 'lsblk' reports (which depends on the lsblk version):
    #       UUID filesystem UUID
    #     PTUUID partition table identifier (usually UUID)
    #   PARTUUID partition UUID

    local column
    # Older lsblk versions do not support all output columns UUID PTUUID PARTUUID
    # e.g. lsblk in util-linux 2.19.1 in SLES11 only supports UUID but neither PTUUID no PARTUUID
    # cf. https://github.com/rear/rear/pull/2626#issuecomment-856700823
    # When an unsupported output column is specified lsblk aborts with "unknown column" error message
    # without output for supported output columns so we run lsblk for each output column separately
    # and ignore lsblk failures and error messages and we skip empty lines in the output via 'awk NF'
    # cf. https://unix.stackexchange.com/questions/274708/most-elegant-pipe-to-get-rid-of-empty-lines-you-can-think-of
    # and https://stackoverflow.com/questions/23544804/how-awk-nf-filename-is-working
    # (empty lines appear when a partition does not have a filesystem UUID or for the whole device that has no PARTUUID)
    # and we remove duplicate reported UUIDs (in particular PTUUID is reported also for each partition):
    for column in UUID PTUUID PARTUUID ; do lsblk -ino $column "$USB_DEVICE" 2>/dev/null ; done | awk NF | sort -u
}

function is_write_protected_by_uuid() {
    local device="$(write_protected_candidate_device "$1")"
    # returns 0 if one of the device's UUID is in the list of write-protected UUIDs.

    local uuids uuid
    uuids="$( write_protection_uuids "$device" )"
    # uuids is a string of UUIDs separated by newline characters
    if ! test "$uuids" ; then
        LogPrintError "Cannot check write protection by UUID for $device (no UUID found)"
        return 1
    fi
    for uuid in $uuids ; do
        if IsInArray "$uuid" "${WRITE_PROTECTED_UUIDS[@]}" ; then
            Log "$device is designated as write-protected by UUID $uuid"
            return 0
        fi
    done
    Log "$device is not write-protected by UUID"
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
            for write_protected_pattern in "${WRITE_PROTECTED_FS_LABEL_PATTERNS[@]}"; do
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

    is_write_protected_by_uuid "$device" || is_write_protected_by_fs_label "$device"
}
