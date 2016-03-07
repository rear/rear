# this script has a simple goal: check if this client system has been properly
# defined on the NBU master server and that a backup specification has been
# made for this client - no more no less

Log "Running: /usr/openv/netbackup/bin/bplist command"
LANG=C /usr/openv/netbackup/bin/bplist -l -s `date -d "-5 days" \
	"+%m/%d/%Y"` / >&8
[ $? -gt 0 ] && LogPrint "WARNING: Netbackup bplist check failed with error code $?.
See $LOGFILE for more details."
