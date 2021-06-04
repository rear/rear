#
# start commvault daemons and check that they run and connect to the backup server
#
#
#

# Commvault dies when it finds /lib/tls with libpthread
# Relax-and-Recover has a symlink from /lib to /lib/tls and I don't remember why (Schlomo)

# delete problematic symlink
rm -f /lib/tls

/opt/commvault/Base/Galaxy start
if /opt/commvault/Base/Galaxy list | grep -q N/A ; then
	Error "Commvault daemon did not start. Please check with '/opt/commvault/Base/Galaxy list'"
fi


