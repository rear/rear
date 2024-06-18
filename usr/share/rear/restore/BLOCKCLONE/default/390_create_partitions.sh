# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 390_create_partitions.sh

# BLOCKCLONE_SAVE_MBR_DEV was not set, we will not have necessary files
# to create partitions
if [ -z "$BLOCKCLONE_SAVE_MBR_DEV" ]; then
    return
fi

local backup_path="$( url_path "$BACKUP_URL" )"
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

        # Just a naive check if we are dealing with same disk.
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

        # TODO: @gozora add gpt support
        LogPrint "Creating partition layout on $BLOCKCLONE_SAVE_MBR_DEV"

        # This will fail if BLOCKCLONE_SAVE_MBR_DEV is mounted
        sfdisk $BLOCKCLONE_SAVE_MBR_DEV < \
        $opath/$BLOCKCLONE_PARTITIONS_CONF_FILE

        StopIfError "Failed to restore partition layout"

        LogPrint "Copying bootstrap code to $BLOCKCLONE_SOURCE_DEV"

        dd if=$opath/$BLOCKCLONE_MBR_FILE of=$BLOCKCLONE_SAVE_MBR_DEV \
        bs=446 count=1

        StopIfError \
        "Failed to copy bootstrap code area to $BLOCKCLONE_SAVE_MBR_DEV"

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
