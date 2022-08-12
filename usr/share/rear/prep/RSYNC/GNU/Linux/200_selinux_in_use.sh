
# check if SELinux is in use, if not, just return
if [ -f /selinux/enforce ] ; then
    SELINUX_ENFORCE=/selinux/enforce
elif [ -f /sys/fs/selinux/enforce ] ; then
    SELINUX_ENFORCE=/sys/fs/selinux/enforce
else
    Log "SELinux is not in use (neither /selinux/enforce nor /sys/fs/selinux/enforce exists)"
    return
fi

# check global settings (see default.conf)
if is_true "$BACKUP_SELINUX_DISABLE" ; then
    cat $SELINUX_ENFORCE > $TMP_DIR/selinux.mode
    RSYNC_SELINUX=
    return
fi

#PROGS+=( setfiles chcon restorecon )

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
            # $TMP_DIR/selinux.mode is a trigger during backup to disable SELinux
            cat $SELINUX_ENFORCE > $TMP_DIR/selinux.mode
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
            # include SELinux utilities and /etc/selinux directory
            # so rescue/restore ReaR image can run with SELinux enabled
            PROGS+=( getenforce setenforce sestatus setfiles chcon restorecon )
            COPY_AS_IS+=( /etc/selinux )
            # alter kernel command line to explicitly enable SELinux
            # replace 'selinux=0' with 'selinux=1' if 'selinux=0' exists
            # or append 'selinux=1' if no 'selinux=1' exists
            KERNEL_CMDLINE=$( echo $KERNEL_CMDLINE | sed -e 's/selinux=0/selinux=1/' )
            echo $KERNEL_CMDLINE | grep -q 'selinux=1' || KERNEL_CMDLINE+=" selinux=1"	
        else
            # during backup we will disable SELinux
            cat $SELINUX_ENFORCE > $TMP_DIR/selinux.mode
            touch $TMP_DIR/force.autorelabel
            # after reboot the restored system does a SELinux relabeling
        fi
        ;;

    (*)
        # disable SELinux for unlisted BACKUP_PROGs
        cat $SELINUX_ENFORCE > $TMP_DIR/selinux.mode
        touch $TMP_DIR/force.autorelabel
        ;;

esac
