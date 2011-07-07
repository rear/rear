# check if SELinux is in use, if not, just silently return
[[ -f /selinux/enforce ]] || return

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
		;;

	(tar)
		tar --usage | grep -q selinux && BACKUP_PROG_OPTIONS="--selinux" || cat /selinux/enforce > $TMP_DIR/selinux.mode
		;;

	(*)
		# disable SELinux for unlisted BACKUP_PROGs
		cat /selinux/enforce > $TMP_DIR/selinux.mode
		;;

esac
