# 450_start_cdm_rbs.sh
# Start the Rubrik (CDM) RBS Agent

RBA_DIR=/etc/rubrik
RBA_BIN_DIR=/usr/bin/rubrik

BOOTSTRAP_DAEMON_OPTS="$( < ${RBA_DIR}/conf/bootstrap_flags.conf )"
AGENT_DAEMON_OPTS="$( < ${RBA_DIR}/conf/agent_flags.conf )"
BOOTSTRAP_DAEMON=$RBA_BIN_DIR/bootstrap_agent_main
AGENT_DAEMON=$RBA_BIN_DIR/backup_agent_main

$BOOTSTRAP_DAEMON $BOOTSTRAP_DAEMON_OPTS
StopIfError "Unable to start RBS Bootstrap service"
$AGENT_DAEMON $AGENT_DAEMON_OPTS
StopIfError "Unable to start RBS Agent service"

LogPrint "Rubrik (CDM) RBS agent started."
