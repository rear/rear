#
# start required daemons, like portmap
#
case "$NETFS_PROTO" in
	nfs)
		# newer Linux distros use rpcbind instead of portmap
		if type -p portmap >/dev/null ; then
			# note: portmap can be called multiple times without harm!
			portmap || Error "Could not start port mapper [portmap] !"
		elif type -p rpcbind >/dev/null ; then
			# rpcbind cannot be called multiple times, so start it only if
			# it is not yet running
			rpcinfo -p localhost >/dev/null 2>&1 ||	rpcbind || \
				Error "Could not start port mapper [rpcbind] !"
		else
			Error "Could not find any portmapper (tried portmap and rpcbind) !"
		fi

		# check that portmapper is running
		# note: on some systems portmap can take a second or two, to be accessible. Hence the loop.
		max_portmap_checks=5
		until rpcinfo -p localhost >/dev/null ; do
			test $max_portmap_checks -gt 0 || Error "portmapper is not running, even though we started it"
			let max_portmap_checks--
			sleep 1
		done

		# start stat daemon if found, some Linux distros use a kernel-based stat daemon
		if type -p rpc.statd >/dev/null ; then
			# statd should be started only once, check with rpcinfo if it is already there
			if rpcinfo -p localhost | grep -q status ; then
				: noop, status is running
			else
				rpc.statd || Error "Could not start rpc.statd !"
			fi
		fi
	;;
esac
