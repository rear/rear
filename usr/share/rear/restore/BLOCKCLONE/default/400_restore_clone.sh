# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 400_restore_clone.sh

LogPrint "Restoring $backuparchive to $BLOCKCLONE_SOURCE_DEV \
using $BLOCKCLONE_PROG"

# Target device does not exist, abort
if [ ! -b "$BLOCKCLONE_SOURCE_DEV" ]; then
    Error "Can't find target device $BLOCKCLONE_SOURCE_DEV"
fi

# Check if target device is mounted
local is_mounted=$(is_device_mounted $BLOCKCLONE_SOURCE_DEV)

if [[ "$BLOCKCLONE_ALLOW_MOUNTED" =~ ^[nN0] ]] && [ "$is_mounted" = "1" ]; then
    Error "Can't start restore, $BLOCKCLONE_SOURCE_DEV is mounted."
fi

local umount_res="-1"
local mp=""
if is_true "$BLOCKCLONE_TRY_UNMOUNT" && [ "$is_mounted" = "1" ]; then
    mp=$(get_mountpoint $BLOCKCLONE_SOURCE_DEV)
    # try unmount
    if [ ! -z "$mp" ]; then
        umount_mountpoint $mp
        umount_res=$?
    fi
fi

# Just put entry into log, that restore of mounted device was made
is_mounted=$(is_device_mounted $BLOCKCLONE_SOURCE_DEV)
if [ "$is_mounted" = "1" ]; then
    LogPrint "BLOCKCLONE was made on mounted device."
    LogPrint "Restore might be inconsistent: filesystem repair my be needed."
fi

# BLOCKCLONE progs could be handled here
case "$(basename ${BLOCKCLONE_PROG})" in
    (ntfsclone)
        ntfsclone -q --restore-image $BLOCKCLONE_PROG_OPTS \
        -O $BLOCKCLONE_SOURCE_DEV $backuparchive
    ;;
    (dd)
        dd $BLOCKCLONE_PROG_OPTS of=$BLOCKCLONE_SOURCE_DEV \
        if=$backuparchive
    ;;
esac

StopIfError "Failed to restore image."

# If $BLOCKCLONE_SOURCE_DEV was initially mounted AND successfully unmounted, 
# warn about remounting it before leaving
if [ "$umount_res" = "0" ]; then
    # Keys may have changed -- mounting is left as an exercise to the user
    LogPrint "Please remount $mp manually if needed."
fi
