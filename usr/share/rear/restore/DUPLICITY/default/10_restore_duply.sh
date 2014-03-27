# This file is part of Relax and Recover, licensed under the GNU General
# Public License. Refer to the included LICENSE for full text of license.


if [ "$BACKUP_PROG" = "duply" ] && has_binary duply; then

    if [ -z "$DUPLY_PROFILE" ]; then
        # Backup-Method is DUPLICITY with DUPLY Frontend but no Duply-Profile given
        # so we have to do the restore manually 
        LogPrint "Restore with Duply failed, no DUPLY_PROFILE given."
        return
    else
    
        # we need to restore on a path that does not exist ;-/
        # that is why we add "restore" to /mnt/local
        duply "$DUPLY_PROFILE" restore /mnt/local/restore
        if (( $? > 1 )); then
            LogPrintIfError "duply $DUPLY_PROFILE restore /mnt/local failed"
            DUPLY_RESTORE_OK="n"
        else
            DUPLY_RESTORE_OK="y"
        
            # we need to move up one dir (to get restore almost empty)
            cd /mnt/local
        
            # file $VAR_DIR/recovery/mountpoint_device contains the mount points in / /boot etc order
            # we need to reverse it - to avoid tac we use sed instead
            for mntpt in $( awk '{print $1}' $VAR_DIR/recovery/mountpoint_device | sed -n '1!G;h;$p' )
            do
                mv restore${mntpt}/* .${mntpt} >&2   # mv restore/boot/*  ./boot
            done
        
            # double check on some important moint-points
            [[ ! -d /mnt/local/mnt ]]  && mkdir -m 755 /mnt/local/mnt
            [[ ! -d /mnt/local/proc ]] && mkdir -m 555 /mnt/local/proc
            [[ ! -d /mnt/local/tmp ]]  && mkdir -m 4777 /mnt/local/tmp
        
            cd - >/dev/null
        fi
    fi    
fi


