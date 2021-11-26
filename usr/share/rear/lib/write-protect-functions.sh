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
    test -b "$device" || BugError "write_protected_candidate_device called for '$1' but '$device' is no block device"
    echo "$device"
}

function write_protection_ids() {
    local device="$( write_protected_candidate_device "$1" )"
    # Output the IDs for write-protection, each ID on a separated line.

    # At least for OUTPUT=USB $device is of the form /dev/disk/by-label/$USB_DEVICE_FILESYSTEM_LABEL
    # which is a symlink to the ReaR data partition (e.g. /dev/sdb3 on a USB disk /dev/sdb).
    # On a USB disk that was formatted with "rear format" there is only one layer of child devices
    # (i.e. there are only partitions like /dev/sdb1 /dev/sdb2 /dev/sdb3 on a USB disk /dev/sdb).
    # So we only need to use the direct parent device to get all IDs of the whole disk
    # because the goal is to write-protect the whole disk by using all its IDs
    # cf. https://github.com/rear/rear/pull/2703#issuecomment-952888484
    local parent_device=""
    # Older Linux distributions do not contain lsblk (e.g. SLES10)
    # and older lsblk versions do not support the output column PKNAME
    # e.g. lsblk in util-linux 2.19.1 in SLES11 supports NAME and KNAME but not PKNAME
    # cf. https://github.com/rear/rear/pull/2626#issuecomment-856700823
    # We ignore lsblk failures and error messages and we skip empty lines in the output via 'awk NF'
    # cf. https://unix.stackexchange.com/questions/274708/most-elegant-pipe-to-get-rid-of-empty-lines-you-can-think-of
    # and https://stackoverflow.com/questions/23544804/how-awk-nf-filename-is-working
    # (an empty line appears for a whole disk device e.g. /dev/sdb that has no PKNAME)
    # and we use only the topmost reported PKNAME:
    parent_device="$( lsblk -inpo PKNAME "$device" 2>/dev/null | awk NF | head -n1 )"
    # parent_device is empty when lsblk does not support PKNAME.
    # Without quoting an empty parent_device would result plain "test -b" which would (falsely) succeed:
    test -b "$parent_device" && device="$parent_device"

    local column
    # The default WRITE_PROTECTED_ID_TYPES are UUID PTUUID PARTUUID WWN.
    # Older lsblk versions do not support all output columns UUID PTUUID PARTUUID WWN
    # e.g. lsblk in util-linux 2.19.1 in SLES11 only supports UUID but neither PTUUID nor PARTUUID nor WWN
    # cf. https://github.com/rear/rear/pull/2626#issuecomment-856700823
    # When an unsupported output column is specified lsblk aborts with "unknown column" error message
    # without output for supported output columns so we run lsblk for each output column separately
    # and ignore lsblk failures and error messages and we skip empty lines in the output via 'awk NF'
    # (empty lines appear when a partition does not have a filesystem UUID or for the whole device that has no PARTUUID
    #  or for all columns except UUID when a child device is a /dev/mapper/* device
    #  and some devices do not have any WWN set)
    # and we remove duplicate reported IDs (in particular PTUUID is reported also for each partition):
    for column in $WRITE_PROTECTED_ID_TYPES ; do lsblk -ino $column "$device" 2>/dev/null ; done | awk NF | sort -u
}

function is_write_protected_by_id() {
    local device="$(write_protected_candidate_device "$1")"
    # returns 0 if one of the device's IDs is in the list of write-protected IDs.

    local ids id
    ids="$( write_protection_ids "$device" )"
    # ids is a string of IDs separated by newline characters
    if ! test "$ids" ; then
        LogPrintError "Cannot check write protection by ID for $device (no ID found)"
        # It would be safer to assume a disk without ID is protected (and return 0)
        # instead of assuming that it is not protected and proceed.
        # But in practice that does not work sufficiently well because it can happen
        # that a disk has no ID (by default non of UUID PTUUID PARTUUID WWN)
        # which usually means there is nothing on the disk so that empty disks
        # get excluded as write-protected from being used to recreate the system
        # cf. https://github.com/rear/rear/pull/2703#discussion_r757393547
        # By default we write protect ReaR's own disk where the recovery system is and
        # we assume it cannot happen that this disk has none of UUID PTUUID PARTUUID WWN
        # so it should be safe to assume a disk without UUID PTUUID PARTUUID WWN is empty
        # and meant to be used to recreate the system so it should not be write-protected:
        return 1
    fi
    for id in $ids ; do
        if IsInArray "$id" "${WRITE_PROTECTED_IDS[@]}" ; then
            Log "$device is designated as write-protected by ID $id"
            return 0
        fi
    done
    Log "$device is not write-protected by ID"
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
    Log "$device is not write-protected by file system label"
    return 1
}

function is_write_protected() {
    local device="$(write_protected_candidate_device "$1")"
    # returns 0 if the device is designated as write-protected by any of the above means.

    is_write_protected_by_id "$device" || is_write_protected_by_fs_label "$device"
}
