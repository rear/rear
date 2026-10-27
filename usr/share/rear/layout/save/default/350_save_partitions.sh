# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 350_save_partitions.sh

if [ -z "$BLOCKCLONE_SAVE_MBR_DEV" ]; then
    return
fi

if [ ! -b "$BLOCKCLONE_SAVE_MBR_DEV" ]; then
    Error "BLOCKCLONE_SAVE_MBR_DEV is empty or incorrectly set!"
fi

# This layout will be later used if BLOCKCLONE_STRICT_PARTITIONING="yes"
local label=$(parted $BLOCKCLONE_SAVE_MBR_DEV print | \
grep "Partition Table" | awk -F ": " '{print $2}')

case "$label" in
    ("msdos")
        Log "Saving strict partition layout"

        sfdisk -d $BLOCKCLONE_SAVE_MBR_DEV > \
        $VAR_DIR/layout/$BLOCKCLONE_PARTITIONS_CONF_FILE

        StopIfError "Failed to save partition layout"

        # Save bootstrap code area
        # This will be used to restore bootstrap area code during
        # restore of NTFS partition.
        Log "Saving bootstrap code area of $BLOCKCLONE_SAVE_MBR_DEV"

        dd if=$BLOCKCLONE_SAVE_MBR_DEV \
        of=$VAR_DIR/layout/$BLOCKCLONE_MBR_FILE bs=446 count=1

        StopIfError "Failed to save bootstrap code area"
    ;;
    ("gpt")
        Log "Saving strict GPT partition layout"

        # 'sgdisk -b' saves the protective MBR, the primary and backup GPT
        # headers and the partition entry array into a single file, so the
        # disk GUID and every partition GUID are preserved. That matters
        # because a UEFI boot configuration can refer to the partition it
        # boots from by GUID.
        sgdisk -b $VAR_DIR/layout/$BLOCKCLONE_PARTITIONS_CONF_FILE \
        $BLOCKCLONE_SAVE_MBR_DEV

        StopIfError "Failed to save partition layout"

        # There is deliberately no bootstrap code area to save here: on a GPT
        # disk the boot loader is a file in the EFI System Partition, not code
        # in the MBR gap, so $BLOCKCLONE_MBR_FILE is not written in this case.
    ;;
    (*)
        BugError "Unknown partition table on $BLOCKCLONE_SAVE_MBR_DEV"
    ;;
esac

