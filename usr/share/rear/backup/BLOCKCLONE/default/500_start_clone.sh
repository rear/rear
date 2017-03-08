# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 500_start_clone.sh

LogPrint "Creating $backuparchive from $BLOCKCLONE_SOURCE_DEV \
using $BLOCKCLONE_PROG"

# Check if source device is mounted
local is_mounted=$(is_device_mounted $BLOCKCLONE_SOURCE_DEV)

if [[ "$BLOCKCLONE_ALLOW_MOUNTED" =~ ^[nN0] ]] && [ $is_mounted = "1" ]; then
    Error "Can't start backup, $BLOCKCLONE_SOURCE_DEV is mounted."
fi

# Just put entry into log, that backup of mounted device was made
if [ $is_mounted = "1" ]; then
    LogPrint "BLOCKCLONE was made on mounted device."
    LogPrint "Backup might be inconsistent."
fi

# BLOCKCLONE progs could be handled here
case "$(basename ${BLOCKCLONE_PROG})" in
    (ntfsclone)
        ntfsclone --save-image $BLOCKCLONE_PROG_OPTS \
        -O $backuparchive $BLOCKCLONE_SOURCE_DEV
    ;;
    (dd)
        dd $BLOCKCLONE_PROG_OPTS if=$BLOCKCLONE_SOURCE_DEV \
        of=$backuparchive
    ;;
esac

StopIfError "Failed to create archive with $BLOCKCLONE_SOURCE_DEV"
