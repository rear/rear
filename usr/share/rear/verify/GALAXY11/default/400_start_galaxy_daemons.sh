#
# start commvault daemons and check that they run and connect to the backup server
#
#
#

# Commvault dies when it finds /lib/tls with libpthread
# Relax-and-Recover has a symlink from /lib to /lib/tls and I don't remember why (Schlomo)

# delete problematic symlink
rm -f /lib/tls

Galaxy start
sleep 3 # give CommVault 3 seconds to start or to fail
if Galaxy list | grep -q N/A; then
	Error "CommVault daemon did not start. Check with 'Galaxy list'"
fi
