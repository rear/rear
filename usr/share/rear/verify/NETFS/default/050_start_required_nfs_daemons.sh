#
# start required daemons for NFS
# portmap on older systems or rpcbind on newer systems
# and rpc.statd if available
#
# use plain 'rpcinfo -p' to check if RPC service is available
# instead of using 'rpcinfo -p localhost' because the latter
# does not work on some systems while the former works everywhere
# see https://github.com/rear/rear/issues/889
#
# make it no longer fatal when RPC status rpc.statd is unavailable
# see https://github.com/rear/rear/issues/870
#
# we do not use the progress bar any more
# therefore all references to FD8 are removed
# in particular '>/dev/null 2>&1' is replaced by '&>/dev/null'
# because the progress bar mechanism had swallowed all data
# see https://github.com/rear/rear/pull/874
# and https://github.com/rear/rear/issues/887
#
# furthermore all kind of '2>/dev/null' (i.e. also '&>/dev/null')
# are removed (so that '&>/dev/null' is replaced by '1>/dev/null')
# because in general '2>/dev/null' is unhelpful here
# cf. https://github.com/rear/rear/issues/2250#issuecomment-541041571
# because it needlessly suppresses error messages in the log
# that would be helpful to see when something fails
# cf. https://github.com/rear/rear/pull/2142#discussion_r282784504
#
# first steps to be prepared for 'set -eu' by
# using 'command || Error' instead of 'command ; StopIfError'
# and predefining all used variables
# see https://github.com/rear/rear/wiki/Coding-Style
#
local backup_url_scheme=$( url_scheme "$BACKUP_URL" )
# nothing to do when backup_url_scheme is not "nfs"
test "nfs" = "$backup_url_scheme" || return 0
# predefine all used variables
local attempt=""
local portmapper_program=""
# the actual work
LogPrint "Starting required daemons for NFS: RPC portmapper (portmap or rpcbind) and rpc.statd if available."

# newer Linux distros use rpcbind instead of portmap
if has_binary portmap ; then
    portmapper_program="portmap"
    # just run portmap because portmap can be called multiple times without harm
    portmap || Error "Starting RPC portmapper '$portmapper_program' failed."
    LogPrint "Started RPC portmapper '$portmapper_program'".
elif has_binary rpcbind ; then
    portmapper_program="rpcbind"
    # rpcbind cannot be called multiple times so start it only if it is not yet running
    # '-s' avoids that in some cases rpcbind is not started / not available in the recovery system
    # cf. https://github.com/rear/rear/issues/2672
    rpcinfo -p 1>/dev/null || rpcbind -s || Error "Starting RPC portmapper '$portmapper_program' failed."
    LogPrint "Started RPC portmapper '$portmapper_program'".
else
    Error "Could not find a RPC portmapper program (tried portmap and rpcbind)."
fi
# check that RPC portmapper service is available and wait for it as needed
# on some systems portmap/rpcbind can take some time to be accessible
# hence 5 attempts each second to check that RPC portmapper service is available
for attempt in $( seq 5 ) ; do
    # on SLES11 and on openSUSE Leap 42.1 'rpcinfo -p' lists the RPC portmapper as
    #   program vers proto   port  service
    #    100000    2   udp    111  portmapper
    #    100000    4   tcp    111  portmapper
    rpcinfo -p | grep -q 'portmapper' && { attempt="ok" ; break ; }
    sleep 1
done
test "ok" = $attempt || Error "RPC portmapper '$portmapper_program' unavailable."
LogPrint "RPC portmapper '$portmapper_program' available."
# rpc.statd should be started only once
# check if RPC status service is already available
# on SLES11 and on openSUSE Leap 42.1 'rpcinfo -p' lists the RPC status as
#   program vers proto   port  service
#    100024    1   udp  33482  status
#    100024    1   tcp  36929  status
if rpcinfo -p | grep -q 'status' ; then
    LogPrint "RPC status rpc.statd available."
else
    # start rpc.statd daemon if found
    # some Linux distros use a kernel-based RPC status daemon
    if has_binary rpc.statd ; then
        rpc.statd && LogPrint "Started rpc.statd." || LogPrint "Starting rpc.statd failed."
    else
        LogPrint "Could not find rpc.statd program."
    fi
    # do a final check if RPC status service is available
    # regardless of the result of starting rpc.statd
    if rpcinfo -p | grep -q 'status' ; then
        LogPrint "RPC status rpc.statd available."
    else
        LogPrint "RPC status rpc.statd unavailable (you may have to mount NFS without locking 'nolock')."
    fi
fi

# NFSv4 related daemons: rpc.idmapd is the bare mininum when dealing with nfsv4 and security 'sys'
if has_binary rpc.idmapd ; then
    # so far it is always a daemon process
    rpc.idmapd $RPCIDMAPDARGS && LogPrint "Started rpc.idmapd." || LogPrint "Starting rpc.idmapd failed."
    modprobe nfsd  1>/dev/null
    modprobe nfsv4 1>/dev/null
    modprobe nfsv3 1>/dev/null
    mount -t rpc_pipefs -n sunrpc /var/lib/nfs/rpc_pipefs
    mount -t nfsd -n nfsd /proc/fs/nfsd
fi
