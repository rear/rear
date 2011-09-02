# Stop SELinux if present - see prep/RSYNC/default/20_selinux_in_use.sh
[ -f $TMP_DIR/selinux.mode ] || return
case "$(basename ${BACKUP_PROG})" in
	(tar|rsync)
		#cat /selinux/enforce > $TMP_DIR/selinux.mode
		echo "0" > $SELINUX_ENFORCE
		Log "Temporarely stop SELinux enforce mode with BACKUP=${BACKUP} and BACKUP_PROG=${BACKUP_PROG} backup"
	;;
	(*) # do nothing
		:
	;;
esac
