# 450_check_cdm_client.sh
# 
# This script checks if a Rubrik CDM client is installed and running
#

Log "Backup method is Rubrik (CDM): check backup_agent_main"
if [ ! -x /usr/bin/rubrik/backup_agent_main ]; then
    Error "Please install Rubrik (CDM) client software."
fi

ps ax | grep backup_agent_main | grep -v grep  1>/dev/null
StopIfError $? "Rubrik (CDM) RBS backup_agent_main was not running on this client."

