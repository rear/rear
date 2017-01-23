# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 400_restore_clone.sh

# Target device does not exist, abort
if [ ! -b "$BLOCKCLONE_SOURCE_DEV" ]; then
    Error "Can't find target device $BLOCKCLONE_SOURCE_DEV"
fi

case "$(basename ${BLOCKCLONE_PROG})" in
    (ntfsclone)
        LogPrint "Restoring $backuparchive to $BLOCKCLONE_SOURCE_DEV"

        ntfsclone -q --restore-image $BLOCKCLONE_PROG_OPTS \
        -O $BLOCKCLONE_SOURCE_DEV $backuparchive

        StopIfError "Failed to restore archive"
    ;;
    (dd)
        # This does not work yet, only a placeholder
        dd $BLOCKCLONE_PROG_OPTS of=$BLOCKCLONE_SOURCE_DEV \
        if=$backuparchive
    ;;
esac
