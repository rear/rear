#!/bin/bash
#
# Function to identify write-protected disks and partitions.

function is_write_protected() {
    local given_device="$1"
    # Provided a matching device node exists for the given device
    # return 0 when the given device is write-protected by ID
    # or when it is write-protected by file system label
    # otherwise return 1 (i.e. when it is not write-protected).
    # For example /sys/block/sda has matching device node /dev/sda
    # and /sys/block/nvme0n1 has matching device node /dev/nvme0n1
    # but not all /sys/block/* entries have a matching device node
    # in particular /sys/block/nvme0c0n1 has no /dev/nvme0c0n1
    # see https://github.com/rear/rear/issues/3085

    # When both WRITE_PROTECTED_IDS and WRITE_PROTECTED_FS_LABEL_PATTERNS are empty
    # no device is write-protected:
    if (( ${#WRITE_PROTECTED_IDS[@]} )) || (( ${#WRITE_PROTECTED_FS_LABEL_PATTERNS[@]} )) ; then
        Log "Checking write protection for '$given_device'"
    else
        Log "'$given_device' is not write-protected (empty WRITE_PROTECTED_IDS and WRITE_PROTECTED_FS_LABEL_PATTERNS)"
            return 1
    fi

    # Determine the matching device node, translate it if given as /sys/block/*
    # But $device_node could be also symlink to the actual device node, for example
    # for OUTPUT=USB $given_device is of the form /dev/disk/by-label/$USB_DEVICE_FILESYSTEM_LABEL
    # which is a symlink to the ReaR data partition (e.g. /dev/sdb3 on a USB disk /dev/sdb).
    local device_node="$given_device"
    [[ "$given_device" == /sys/block/* ]] && device_node="$( get_device_name "$given_device" )"

    # Because this is meant to identify write-protected disks and partitions
    # only given devices with a matching device node are considered for write protection
    # so given devices without matching device node get reported as not write protected:
    if test -e "$device_node" ; then
        test -b "$device_node" || BugError "is_write_protected called for '$given_device' but '$device_node' is no block device"
    else
        Log "'$given_device' is not write-protected ('$device_node' does not exist)"
        return 1
    fi
    # The matching device node exists and is a block device
    # so given_device and device_node are non empty words.

    # Determine the IDs of the disk device that belongs to the given device:
    # At least for OUTPUT=USB $given_device is of the form /dev/disk/by-label/$USB_DEVICE_FILESYSTEM_LABEL
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
    parent_device="$( lsblk -inpo PKNAME "$device_node" 2>/dev/null | awk NF | head -n1 )"
    # parent_device is empty when lsblk does not support PKNAME.
    # In this case use device_node as fallback for parent_device.
    # Without quoting an empty parent_device would result plain "test -b" which would (falsely) succeed:
    test -b "$parent_device" || parent_device="$device_node"
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
    local ids column
    ids="$( for column in $WRITE_PROTECTED_ID_TYPES ; do lsblk -ino $column "$parent_device" 2>/dev/null ; done | awk NF | sort -u )"

    # Determine if it is write-protected by ID
    # i.e. return 0 if one of the device IDs is in the list of write-protected IDs.
    local id
    # ids is a string of IDs separated by newline characters
    if test "$ids" ; then
        for id in $ids ; do
            if IsInArray "$id" "${WRITE_PROTECTED_IDS[@]}" ; then
                Log "$given_device is designated as write-protected by ID '$id'"
                return 0
            fi
        done
        Log "$given_device is not write-protected by ID"
    else
        LogPrintError "Cannot check write protection by ID for $given_device (no ID found)"
        # It would be safer to assume a disk without ID is protected (and return 0)
        # instead of assuming that it is not protected and proceed.
        # But in practice that does not work sufficiently well because it can happen
        # that a disk has no ID (by default non of UUID PTUUID PARTUUID WWN)
        # which usually means there is nothing on the disk so that empty disks
        # would get excluded as write-protected from being used to recreate the system
        # cf. https://github.com/rear/rear/pull/2703#discussion_r757393547
        # By default we write protect ReaR's own disk where the recovery system is and
        # we assume it cannot happen that this disk has none of UUID PTUUID PARTUUID WWN
        # so it should be safe to assume a disk without UUID PTUUID PARTUUID WWN is empty
        # and meant to be used to recreate the system so it should not be write-protected by ID.
    fi

    # Determine if it is write-protected by file system labels
    # i.e. return 0 if one of the device file system labels
    # matches one of the WRITE_PROTECTED_FS_LABEL_PATTERNS.
    # lsblk in util-linux 2.19.1 in SLES11 supports '-ino LABEL'
    # cf. https://github.com/rear/rear/pull/2626#issuecomment-856700823
    local device_label fs_label_pattern
    while read -r device_label ; do
        test "$device_label" || continue
        for fs_label_pattern in "${WRITE_PROTECTED_FS_LABEL_PATTERNS[@]}" ; do
            if [[ "$device_label" == $fs_label_pattern ]] ; then
                Log "$given_device is designated as write-protected (its label '$device_label' matches '$fs_label_pattern')"
                return 0
            fi
        done
    done < <( lsblk -ino LABEL "$device_node" )
    Log "$given_device is not write-protected by file system label"

    # The given device is neither write-protected by ID
    # nor is it write-protected by file system label:
    Log "$given_device is not write-protected"
    return 1
}
