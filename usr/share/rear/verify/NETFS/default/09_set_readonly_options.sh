# on restore it is better to mount the remote filesystem ro

# if it is empty then the result is ro, else the result is ro,$NETFS_OPTIONS
NETFS_OPTIONS="ro${NETFS_OPTIONS:+,}$NETFS_OPTIONS"

