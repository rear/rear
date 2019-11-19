# 400_verify_cdm.sh
# Start the Rubrik (CDM) client after resetting the UUID

RBA_DIR=/etc/rubrik
AGENT_UUID=${RBA_DIR}/conf/uuid
RBA_BIN_DIR=/usr/bin/rubrik

mv ${AGENT_UUID} ${AGENT_UUID}.old
/usr/bin/uuidgen > ${AGENT_UUID}

BOOTSTRAP_DAEMON_OPTS="`cat ${RBA_DIR}/conf/bootstrap_flags.conf`"
AGENT_DAEMON_OPTS="`cat ${RBA_DIR}/conf/agent_flags.conf`"
BOOTSTRAP_DAEMON=$RBA_BIN_DIR/bootstrap_agent_main
AGENT_DAEMON=$RBA_BIN_DIR/backup_agent_main

$BOOTSTRAP_DAEMON $BOOTSTRAP_DAEMON_OPTS
$AGENT_DAEMON $AGENT_DAEMON_OPTS

Log "Rubrik (CDM) agent started"
