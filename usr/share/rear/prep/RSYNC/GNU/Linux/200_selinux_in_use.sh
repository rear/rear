# Return if SELinux is not in use
is_true "$SELINUX_IN_USE" || return

# SELinux is found to be available on this system;
# depending on backup program we may need to do different things
# So far, only rsync and tar has special options for selinux.
# Others, just disable SELinux during backup only!
case $(basename $BACKUP_PROG) in

    (rsync)
        if grep -q "no xattrs" "$TMP_DIR/rsync_protocol" ; then
            local host
            host="$(rsync_host "$BACKUP_URL")"
            # no xattrs compiled in remote rsync, so saving SELinux attributes are not possible
            Log "WARNING: --xattrs not possible on system ($host) (no xattrs compiled in rsync)"
            # internal variable used in recover mode (empty means disable SELinux)
            RSYNC_SELINUX=
            # after reboot the restored system do a forced SELinux relabeling
            touch $TMP_DIR/force.autorelabel
        else
            # if --xattrs is already set; no need to do it again
            if ! grep -q xattrs <<< "${BACKUP_RSYNC_OPTIONS[*]}" ; then
                BACKUP_RSYNC_OPTIONS+=( --xattrs )
            fi
            # variable used in recover mode (means using xattr and not disable SELinux)
            RSYNC_SELINUX=1
        fi
        ;;

    (tar)
        if tar --usage | grep -q selinux ; then
            # during backup we will NOT disable SELinux
            BACKUP_PROG_OPTIONS+=( "--selinux" )
        else
            # tar does not support --selinux, need to relabel after restore
            touch $TMP_DIR/force.autorelabel
        fi
        ;;

    (*)
        # backup program does not support SELinux context preservation
        touch $TMP_DIR/force.autorelabel
        ;;

esac
