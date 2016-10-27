# 45_check_nsr_client.sh
# this script has a simple goal: check if this client system knows the networker server?

Log "Backup method is NetWorker (NSR): check nsrexecd"
[ ! -x /usr/sbin/nsrexecd ] && Error "Please install EMC NetWorker (Legato) client software."

ps ax | grep nsrexecd | grep -v grep  1>&8
StopIfError $? "EMC NetWorker (Legato) nsrexecd was not running on this client."

