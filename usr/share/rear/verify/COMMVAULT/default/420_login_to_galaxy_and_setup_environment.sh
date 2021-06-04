#
# Commvault requires a logon to the backup system that is independent from the system
# logon. The logon stores a session file on the system (/opt/commvault/qsession.0) so that
# a session might exist already.

# set path to Commvault
export PATH=$PATH:/opt/commvault/Base

# we first try to run a Commvault command and try to logon if it fails
qlist backupset -c $HOSTNAME -a Q_LINUX_FS >/dev/null
let ret=$?
[ $ret -eq 0 -o $ret -eq 2 ]
StopIfError "Unknown error in qlist [$ret], check log file"

if test $ret -eq 2 ; then
	# try to logon
	Print "Please logon to your Commvault CommServe with suitable credentials:"
	qlogin $(test "$COMMVAULT_Q_ARGUMENTFILE" && echo "-af $COMMVAULT_Q_ARGUMENTFILE")
	StopIfError "Could not logon to Commvault CommServe. Check the log file."
fi



