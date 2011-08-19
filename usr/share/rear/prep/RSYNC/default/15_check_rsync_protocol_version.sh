# try to grab the rsync protocol version of rsync on the remote server
if [ -z "$RSYNC_PROTOCOL_VERSION" ]; then

	case $RSYNC_PROTO in

	(ssh)
		ssh ${RSYNC_USER}@${RSYNC_HOST} rsync --version >"$TMP_DIR/rsync_protocol" 2>&1
		StopIfError "Secure shell connection not setup properly [$RSYNC_USER@$RSYNC_HOST]"
		grep -q "protocol version" "$TMP_DIR/rsync_protocol"
		if [ $? -eq 0 ]; then
			RSYNC_PROTOCOL_VERSION=$(grep 'protocol version' "$TMP_DIR/rsync_protocol" | awk '{print $6}')
		else
			RSYNC_PROTOCOL_VERSION=29	# being conservative (old rsync version < 3.0)
		fi
		;;

	(rsync)
		Log "Warning: no way to check remote rsync protocol without ssh access"
		RSYNC_PROTOCOL_VERSION=29 # being conservative (old rsync)
		;;
	esac
	Log "Remote rsync system ($RSYNC_HOST) uses rsync protocol version $RSYNC_PROTOCOL_VERSION"

else

	Log "Remote rsync system ($RSYNC_HOST) uses rsync protocol version $RSYNC_PROTOCOL_VERSION (overruled by user)"

fi

if [ "${RSYNC_USER}" != "root" ]; then
	if [ $RSYNC_PROTOCOL_VERSION -gt 29 ]; then
		if grep -q "no xattrs" "$TMP_DIR/rsync_protocol"; then
			# no xattrs available in remote rsync, so --fake-super is not possible
			Error "rsync --fake-super not possible on system ($RSYNC_HOST) (no xattrs compiled in rsync)"
		else
			# when using --fake-super we must have user_xattr mount options on the remote mntpt
			_mntpt=$(ssh ${RSYNC_USER}@${RSYNC_HOST} 'cd ${RSYNC_PATH}; df -P .' 2>/dev/null | tail -1 | awk '{print $6}')
			ssh ${RSYNC_USER}@${RSYNC_HOST} mount 2>/dev/null | grep "$_mntpt" | grep -q user_xattr
			StopIfError "Remote file system $_mntpt does not have user_xattr mount option set!"
			BACKUP_RSYNC_OPTIONS=( "${BACKUP_RSYNC_OPTIONS[@]}" --xattrs --rsync-path="""rsync --fake-super""" )
		fi
	else
		Error "rsync --fake-super not possible on system ($RSYNC_HOST) (please upgrade rsync to 3.x)"
	fi
fi
