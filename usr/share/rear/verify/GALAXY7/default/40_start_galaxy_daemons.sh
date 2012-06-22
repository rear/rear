#
# start galaxy daemons and check that they run and connect to the backup server
#
#
#

# Galaxy dies when it finds /lib/tls with libpthread
# Relax-and-Recover has a symlink from /lib to /lib/tls and I don't remember why (Schlomo)

# delete problematic symlink
rm -f /lib/tls

/opt/galaxy/Base/Galaxy start
if /opt/galaxy/Base/Galaxy list | grep -q N/A ; then
	Error "Galaxy daemon did not start. Please check with '/opt/galaxy/Base/Galaxy list'"
fi


