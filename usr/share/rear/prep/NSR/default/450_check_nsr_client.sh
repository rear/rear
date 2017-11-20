# 450_check_nsr_client.sh
# 
# This script checks if a EMC Legato client is installed and running
#

Log "Backup method is NetWorker (NSR): check nsrexecd"
if [ ! -x /usr/sbin/nsrexecd ] \
&& [ ! -x /opt/networker/sbin/nsrexecd ]; then
    Error "Please install EMC NetWorker (Legato) client software."
fi

ps ax | grep nsrexecd | grep -v grep  1>/dev/null
StopIfError $? "EMC NetWorker (Legato) nsrexecd was not running on this client."

