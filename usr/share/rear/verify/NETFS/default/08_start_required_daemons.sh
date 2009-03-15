#
# start required daemons, like portmap
#
case "$NETFS_PROTO" in
	nfs)
		# newer Linux distros use rpcbind instead of portmap
		if type -p portmap >/dev/null ; then
			portmap || Error "Could not start port mapper [portmap] !"
		elif type -p rpcbind >/dev/null ; then
			rpcbind || Error "Could not start port mapper [rpcbind] !"
		else
			Error "Could not find any portmapper (tried portmap and rpcbind) !"
		fi

		# start stat daemon if found, some Linux distros use a kernel-based stat daemon
		if type -p rpc.statd >/dev/null ; then
			rpc.statd || Error "Could not start rpc.statd !"
		fi
	;;
esac
