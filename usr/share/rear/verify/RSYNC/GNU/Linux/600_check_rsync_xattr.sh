# is RSYNC_SELINUX=1 : means we need --xattr option with rsync (SELinux was not disabled during backup)
# we need this special (hidden) variable because SELinux is never active in ReaR
[[ $RSYNC_SELINUX ]] && {

	# if --xattrs is already set; no need to do it again
	if ! grep -q xattrs <<< "${BACKUP_RSYNC_OPTIONS[*]}" ; then
		BACKUP_RSYNC_OPTIONS+=( --xattrs )
	fi

}
