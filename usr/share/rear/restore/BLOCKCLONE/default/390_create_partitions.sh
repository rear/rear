# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 390_create_partitions.sh

# BLOCKCLONE_SAVE_MBR_DEV was not set, we will not have necessary files
# to create partitions
if [ -z "$BLOCKCLONE_SAVE_MBR_DEV" ]; then
    return
fi

local scheme="$( url_scheme "$BACKUP_URL" )"
local path="$( url_path "$BACKUP_URL" )"
local opath="$( backup_path "$scheme" "$path" )"

# Destination partition is not present, try to recreate.
if [ ! -b "$BLOCKCLONE_SOURCE_DEV" ]; then
    LogPrint "Did not found $BLOCKCLONE_SOURCE_DEV, trying to create it"

    LogUserOutput "Device $BLOCKCLONE_SOURCE_DEV was not found."
    LogUserOutput "Restore partition layout to (^c to abort): [$BLOCKCLONE_SAVE_MBR_DEV]"
    change_default BLOCKCLONE_SAVE_MBR_DEV

    if [ -b "$BLOCKCLONE_SAVE_MBR_DEV" ]; then
        # Display warning if parent of restore target device
        # (BLOCKCLONE_SOURCE_DEV) and user defined parent
        # (BLOCKCLONE_SAVE_MBR_DEV) differ.
        # This basically means that partitions will be created on /dev/diskX
        # and restore will be done to /dev/diskY which will most probably lead
        # to failure.
        # I don't want to make this decision transparently for user as it
        # could lead to confusedness by ignoring user defined
        # BLOCKCLONE_SAVE_MBR_DEV in ReaR configuration files.
        # By allowing such wrong decision user could inadvertently overwrite
        # wrong partition table.
        # Anyhow there might be a case when such decision makes sense,
        # and as we are in GNU/Linux world, we let user to shoot him self
        # in the foot ...

        # A naive check if we are dealing with same disk.
        # At this stage kernel is missing any info about BLOCKCLONE_SOURCE_DEV,
        # so we can't reliably determine relation between disks.
        if [ $(echo $BLOCKCLONE_SOURCE_DEV | \
            grep -c ^$BLOCKCLONE_SAVE_MBR_DEV) -eq 0 ]; then

            LogPrint "$BLOCKCLONE_SAVE_MBR_DEV is not \
the parent of $BLOCKCLONE_SOURCE_DEV"

            LogUserOutput "WARNING: $BLOCKCLONE_SAVE_MBR_DEV looks not to be a \
parent of $BLOCKCLONE_SOURCE_DEV.
You might be attempting to create partitions on wrong disk.
This might lead to corruption of existing data and \
overall failure of restore."
            LogUserOutput "Would you like to continue? [Y/N]"
            local tmp_continue
            # Use the original STDIN STDOUT and STDERR when 'rear' was launched by the user
            # because 'read' outputs non-error stuff also to STDERR (e.g. its prompt):
            read tmp_continue 0<&6 1>&7 2>&8

            if is_true "$tmp_continue" ; then
                LogPrint "User confirmed continue with restore operation"
            else
                Error "Operation aborted by user"
            fi
        fi

        LogPrint "Creating partition layout on $BLOCKCLONE_SAVE_MBR_DEV"

        # Which tool restores the layout is decided by what was saved, so no
        # additional configuration variable is needed: 350_save_partitions.sh
        # writes an 'sfdisk -d' text dump for msdos labelled disks, whose
        # first line is "label: dos", and an 'sgdisk -b' binary backup for
        # GPT disks.
        #
        # This distinction cannot be skipped by always calling sfdisk,
        # because sfdisk does not fail on the binary file -- it reports
        # ">>> line 1: unsupported command", leaves the disk untouched and
        # exits 0, so StopIfError does not trigger and the restore continues
        # against a disk that still has no partitions.
        if grep -q -m1 '^label:' \
            "$opath/$BLOCKCLONE_PARTITIONS_CONF_FILE" 2>/dev/null ; then

            # This will fail if BLOCKCLONE_SAVE_MBR_DEV is mounted
            sfdisk $BLOCKCLONE_SAVE_MBR_DEV < \
            $opath/$BLOCKCLONE_PARTITIONS_CONF_FILE

            StopIfError "Failed to restore partition layout"

            LogPrint "Copying bootstrap code to $BLOCKCLONE_SOURCE_DEV"

            dd if=$opath/$BLOCKCLONE_MBR_FILE of=$BLOCKCLONE_SAVE_MBR_DEV \
            bs=446 count=1

            StopIfError \
            "Failed to copy bootstrap code area to $BLOCKCLONE_SAVE_MBR_DEV"
        else
            # 'sgdisk -l' writes back the protective MBR, both GPT headers
            # and the partition entry array, so the disk GUID and the
            # partition GUIDs are restored along with the sizes.
            sgdisk -l "$opath/$BLOCKCLONE_PARTITIONS_CONF_FILE" \
            "$BLOCKCLONE_SAVE_MBR_DEV"

            StopIfError "Failed to restore GPT partition layout"

            # No bootstrap code area is saved for GPT disks, see
            # 350_save_partitions.sh. The boot loader lives in the EFI System
            # Partition, which has to be restored as a partition of its own.
            Log "GPT disk, no bootstrap code area to copy"
        fi

        # This might be useless nowadays
        partprobe $BLOCKCLONE_SAVE_MBR_DEV

    else
        Error "$BLOCKCLONE_SAVE_MBR_DEV is not valid block device"
    fi

    # This can happen if user decides to restore to /dev/sdX and
    # BLOCKCLONE_SAVE_MBR_DEV is set to /dev/sdY
    LogPrint "Checking if $BLOCKCLONE_SOURCE_DEV exists"
    if [ -b "$BLOCKCLONE_SOURCE_DEV" ]; then
        LogPrint "Found $BLOCKCLONE_SOURCE_DEV, continue with restore"
    else
        Error "Failed to locate target partition $BLOCKCLONE_SOURCE_DEV"
    fi
fi
