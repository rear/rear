# is RSYNC_SELINUX=1 : means we need --xattr option with rsync (SELinux was not disabled during backup)
# we need this special (hidden) variable because SELinux is never active in ReaR
[[ $RSYNC_SELINUX ]] && {

	# if --xattrs is already set; no need to do it again
	if ! grep -q xattrs <<< $(echo ${RSYNC_OPTIONS[@]}); then
		RSYNC_OPTIONS=( "${RSYNC_OPTIONS[@]}" --xattrs )
	fi

}
