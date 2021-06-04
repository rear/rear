# ping Commvault server (CommServe)

if test "$PING" ; then
	read junk CSHOSTNAME junk2 < <(
		grep CSHOSTNAME /etc/CommVaultRegistry/Galaxy/Instance001/CommServe/.properties
	)
	if test "$CSHOSTNAME" ; then
		ping -c 5 -q "$CSHOSTNAME" >&2
		StopIfError "Backup server [$CSHOSTNAME] not reachable !"
	else
		LogPrint "WARNING ! Could not determine CommServe hostname !"
		Log "Please check /etc/CommVaultRegistry/Galaxy/Instance001/CommServe/.properties"
	fi
else
	Log "Skipping ping test"
fi
