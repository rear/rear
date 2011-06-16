# try to grab the rsync protocol version of rsync on the remote server
[ ! -z "$RSYNC_PROTOCOL_VERSION" ] && return	# seems to be defined by user

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

if [ $RSYNC_PROTOCOL_VERSION -gt 29 ]; then
	if grep -q "no xattrs" "$TMP_DIR/rsync_protocol"; then
		# no xattrs available in remote rsync, so --fake-super is not possible
		RSYNC_FAKE_SUPER=""
	else
		RSYNC_FAKE_SUPER="--xattrs --rsync-path=\"rsync --fake-super\""
	fi
fi
[ "${RSYNC_USER}" == "root" ] && RSYNC_FAKE_SUPER=""	# if root is used no need to fake super
