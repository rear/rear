#
# start commvault daemons and check that they run and connect to the backup server
#
#
#

# Commvault dies when it finds /lib/tls with libpthread
# Relax-and-Recover has a symlink from /lib to /lib/tls and I don't remember why (Schlomo)

# delete problematic symlink
rm -f /lib/tls

local commvault_base_dir=/opt/commvault/Base64

$commvault_base_dir/Galaxy start
if $commvault_base_dir/Galaxy list | grep -q N/A ; then
	Error "CommVault daemon did not start. Check with '$commvault_base_dir/Galaxy list'"
fi
