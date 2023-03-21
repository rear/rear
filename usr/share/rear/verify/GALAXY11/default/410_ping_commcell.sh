# ping Commvault server (CommServe)

is_true "$PING" || return 0

local commvault_instance_properties=/etc/CommVaultRegistry/Galaxy/Instance001/CommServe/.properties

read junk CSHOSTNAME junk2 < <(
	grep CSHOSTNAME $commvault_instance_properties
)
if test "$CSHOSTNAME" ; then
	ping -c 5 -q "$CSHOSTNAME" >&2 || Error "Backup server [$CSHOSTNAME] not reachable via ping !"
else
	Error "Could not determine CommServe hostname. Check $commvault_instance_properties"
fi
