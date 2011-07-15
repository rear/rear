# check if SELinux is in use, if not, just silently return
[[ -f /selinux/enforce ]] || return

# check global settings (see default.conf) - non-empty means disable SELinux during backup
if [ -n "$BACKUP_SELINUX_DISABLE" ]; then
        cat /selinux/enforce > $TMP_DIR/selinux.mode
        RSYNC_SELINUX=
        return
fi

#PROGS=( "${PROGS[@]}" setfiles chcon restorecon )

# SELinux is found to be available on this system; depending on backup program we may need to do different things
# So far, only rsync and tar has special options for selinux. Others, just disable SELinux during backup only!
case $(basename $BACKUP_PROG) in

	(rsync)
		if grep -q "no xattrs" "$TMP_DIR/rsync_protocol"; then
			# no xattrs compiled in remote rsync, so saving SELinux attributes are not possible
			Log "WARNING: --xattrs not possible on system ($RSYNC_HOST) (no xattrs compiled in rsync)"
			# $TMP_DIR/selinux.mode is a trigger during backup to disable SELinux
			cat /selinux/enforce > $TMP_DIR/selinux.mode
			RSYNC_SELINUX=		# internal variable used in recover mode (empty means disable SELinux)
		else
			# if --xattrs is already set; no need to do it again
			if ! grep -q xattrs <<< $(echo ${RSYNC_OPTIONS[@]}); then
				RSYNC_OPTIONS=( "${RSYNC_OPTIONS[@]}" --xattrs )
			fi
			RSYNC_SELINUX=1		# variable used in recover mode (means using xattr and not disable SELinux)
		fi
		touch $TMP_DIR/force.autorelabel	# after reboot the restored system do a forced SELinux relabeling
		;;

	(tar)
		if tar --usage | grep -q selinux  ; then
			# during backup we will NOT disable SELinux
			BACKUP_PROG_OPTIONS="--selinux"
			touch $TMP_DIR/force.autorelabel
		else
			# during backup we will disable SELinux
			cat /selinux/enforce > $TMP_DIR/selinux.mode
			# after reboot the restored system does a SELinux relabeling
		fi
		;;

	(*)
		# disable SELinux for unlisted BACKUP_PROGs
		cat /selinux/enforce > $TMP_DIR/selinux.mode
		;;

esac
