#
# start required daemons, like portmap
#
local scheme=$(url_scheme "$BACKUP_URL")
case "$scheme" in
	nfs)
		# newer Linux distros use rpcbind instead of portmap
		if has_binary portmap; then
			# note: portmap can be called multiple times without harm!
			portmap
			StopIfError "Could not start port mapper [portmap] !"
		elif has_binary rpcbind; then
			# rpcbind cannot be called multiple times, so start it only if
			# it is not yet running
			rpcinfo -p localhost >&8 2>&1 || rpcbind
			StopIfError "Could not start port mapper [rpcbind] !"
		else
			Error "Could not find any portmapper (tried portmap and rpcbind) !"
		fi

		# check that portmapper is running
		# note: on some systems portmap can take a second or two, to be accessible. Hence the loop.
		max_portmap_checks=5
		until rpcinfo -p localhost >&8 2>&1; do
			[ $max_portmap_checks -gt 0 ]
			StopIfError "portmapper is not running, even though we started it"
			let max_portmap_checks--
			sleep 1
		done

		# start stat daemon if found, some Linux distros use a kernel-based stat daemon
		if has_binary rpc.statd; then
			# statd should be started only once, check with rpcinfo if it is already there
			if rpcinfo -p localhost | grep -q status ; then
				: noop, status is running
			else
				rpc.statd
				StopIfError "Could not start rpc.statd !"
			fi
		fi
	;;
esac
