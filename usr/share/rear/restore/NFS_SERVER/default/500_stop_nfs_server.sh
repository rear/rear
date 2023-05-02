# 500_stop_nfs_server.sh

rpc.nfsd 0 || :

kill $(pidof rpc.mountd) || :
