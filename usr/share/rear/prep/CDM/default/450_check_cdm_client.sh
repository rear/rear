# 450_check_cdm_client.sh
# 
# This script checks if a Rubrik CDM client is installed and running
#

Log "Backup method is Rubrik (CDM): check backup_agent_main"
if [ ! -x /usr/bin/rubrik/backup_agent_main ]; then
    StopIfError 1 "Please install Rubrik (CDM) RBS client software."
fi

ps ax | grep -v grep | grep backup_agent_main
StopIfError $? "Rubrik (CDM) RBS backup_agent_main was not running on this client."

