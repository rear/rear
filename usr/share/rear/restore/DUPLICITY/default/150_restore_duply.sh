# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.


if [ "$BACKUP_PROG" = "duply" ] && has_binary duply; then

    if [ -z "$DUPLY_PROFILE" ]; then
        # Backup-Method is DUPLICITY with DUPLY Frontend but no Duply-Profile given
        # so we have to do the restore manually
        LogPrint "Restore with Duply failed, no DUPLY_PROFILE given."
        return
    else

        # we need to restore on a path that does not exist ;-/
        # that is why we add "restore" to $TARGET_FS_ROOT (by default /mnt/local)
        LogPrint "Starting restore with duply/duplicity with profile $DUPLY_PROFILE"
        duply "$DUPLY_PROFILE" restore $TARGET_FS_ROOT/restore
        if (( $? > 1 )); then
            LogPrintIfError "duply $DUPLY_PROFILE restore $TARGET_FS_ROOT failed"
            DUPLY_RESTORE_OK="n"
        else
            DUPLY_RESTORE_OK="y"

            # we need to move up one dir (to get restore almost empty)
            pushd $TARGET_FS_ROOT >/dev/null

            # file $VAR_DIR/recovery/mountpoint_device contains the mount points in / /boot etc order
            # we need to reverse it - to avoid tac we use sed instead
            for mntpt in $( awk '{print $1}' $VAR_DIR/recovery/mountpoint_device | sed -n '1!G;h;$p' )
            do
                mv restore${mntpt}/* .${mntpt} >&2   # mv restore/boot/*  ./boot
            done

            # double check on some important moint-points
            [[ ! -d $TARGET_FS_ROOT/mnt ]]  && mkdir -m 755 $TARGET_FS_ROOT/mnt
            [[ ! -d $TARGET_FS_ROOT/proc ]] && mkdir -m 555 $TARGET_FS_ROOT/proc
            [[ ! -d $TARGET_FS_ROOT/tmp ]]  && mkdir -m 4777 $TARGET_FS_ROOT/tmp

            popd >/dev/null
        fi
    fi
fi


