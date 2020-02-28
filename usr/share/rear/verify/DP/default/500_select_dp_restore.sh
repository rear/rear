##############################################################################
#
# Select dataprotector backup to be restored
#
# Ends in:
#   $TMP_DIR/dp_recovery_host     - the host to be restored
#   $TMP_DIR/dp_recovery_devs     - the devices used during backup
#   $TMP_DIR/dp_recovery_session  - the session to be restored
#   $TMP_DIR/dp_recovery_datalist - the datalist to be restored
#

#set -e

[ -f $TMP_DIR/DP_GUI_RESTORE ] && return # GUI restore explicetely requested


OMNIDB=/opt/omni/bin/omnidb
OMNICELLINFO=/opt/omni/bin/omnicellinfo

HOST="`hostname`"

DPGetBackupList() {
  if test $# -gt 0 ; then
    HOST=$1
  else
    HOST="`hostname`"
  fi >&2
  test -f $TMP_DIR/dp_list_of_sessions.in && rm -f $TMP_DIR/dp_list_of_sessions.in
  touch $TMP_DIR/dp_list_of_sessions.in
  ${OMNIDB} -filesystem | grep "${HOST}" | cut -d"'" -f -2 > $TMP_DIR/dp_list_of_fs_objects
  cat $TMP_DIR/dp_list_of_fs_objects | while read object; do
    host_fs=`echo ${object} | awk '{print $1}'`
    fs=`echo ${object} | awk '{print $1}' | cut -d: -f 2`
    label=`echo "${object}" | cut -d"'" -f 2`
    ${OMNIDB} -filesystem $host_fs "$label" | grep -v "^SessionID" | grep -v "^===========" | awk '{ print $1 }' >> $TMP_DIR/dp_list_of_sessions.in
  done
  sort -u -r -V < $TMP_DIR/dp_list_of_sessions.in > $TMP_DIR/dp_list_of_sessions
  cat $TMP_DIR/dp_list_of_sessions | while read sessid; do
    datalist=$(${OMNIDB} -session $sessid -report | grep BSM | cut -d\" -f 2 | head -1)
    device=$(${OMNIDB} -session $sessid -detail | grep "Device name" | cut -d: -f 2 | awk '{ print $1 }' | sort -u)
    media=$(${OMNIDB} -session $sessid -media | grep -v "^Medium Label" | grep -v "^=====" | awk '{ print $1 }' | sort -u)
    if test -n "$datalist"; then
      echo -e "$sessid\t$datalist\t$(echo $device)\t$(echo $media)\t$HOST"
    fi
  done
}

DPChooseBackup() {
  if test $# -gt 0 ; then
    HOST=$1
  else
    HOST="`hostname`"
  fi >&2
  LogPrint "Scanning for DP backups for Host ${HOST}"
  DPGetBackupList $HOST > $TMP_DIR/backup.list
  > $TMP_DIR/backup.list.part

  SESSION=$(head -1 $TMP_DIR/backup.list | cut -f 1)
  DATALIST=$(head -1 $TMP_DIR/backup.list | cut -f 2)
  DEVS=$(head -1 $TMP_DIR/backup.list | cut -f 3)
  MEDIA=$(head -1 $TMP_DIR/backup.list | cut -f 4)
  HOST=$(head -1 $TMP_DIR/backup.list | cut -f 5)

  while true; do
    LogPrint ""
    LogPrint "Found DP-Backup:"
    LogPrint ""
    LogPrint "  [H] Host........: $HOST"
    LogPrint "  [D] Datalist....: $DATALIST"
    LogPrint "  [S] Session.....: $SESSION"
    LogPrint "      Device(s)...: $DEVS"
    LogPrint "      Media(s)....: $MEDIA"
    LogPrint ""
    unset REPLY
    # Use the original STDIN STDOUT and STDERR when rear was launched by the user
    # to get input from the user and to show output to the user (cf. _input-output-functions.sh):
    read -t $WAIT_SECS -r -n 1 -p "press ENTER or choose H,D,S [$WAIT_SECS secs]: " 0<&6 1>&7 2>&8

    if test -z "${REPLY}"; then
      echo $HOST > $TMP_DIR/dp_recovery_host
      echo $SESSION > $TMP_DIR/dp_recovery_session
      echo $DATALIST > $TMP_DIR/dp_recovery_datalist
      echo $DEVS > $TMP_DIR/dp_recovery_devs
      LogPrint "ok"
      return
    elif test "${REPLY}" = "h" -o "${REPLY}" = "H"; then
      DPChangeHost
      return
    elif test "${REPLY}" = "d" -o "${REPLY}" = "D"; then
      local DL=test
      DPChangeDataList
      > $TMP_DIR/backup.list.part
      cat $TMP_DIR/backup.list | while read s; do
        DATALIST=$(echo "$s" | cut -f 2)
        if test $DATALIST = $DL; then echo "$s" >> $TMP_DIR/backup.list.part; fi
      done
      SESSION=$(head -1 $TMP_DIR/backup.list.part | cut -f 1)
      DATALIST=$(head -1 $TMP_DIR/backup.list.part | cut -f 2)
      DEVS=$(head -1 $TMP_DIR/backup.list.part | cut -f 3)
      MEDIA=$(head -1 $TMP_DIR/backup.list.part | cut -f 4)
      HOST=$(head -1 $TMP_DIR/backup.list.part | cut -f 5)
    elif test "${REPLY}" = "s" -o "${REPLY}" = "S"; then
      local SESS=$SESSION
      DPChangeSession
      SESSION=$SESS
      DATALIST=$(grep "^$SESS" $TMP_DIR/backup.list | cut -f 2)
      DEVS=$(grep "^$SESS" $TMP_DIR/backup.list| cut -f 3)
      MEDIA=$(grep "^$SESS" $TMP_DIR/backup.list | cut -f 4)
      HOST=$(grep "^$SESS" $TMP_DIR/backup.list | cut -f 5)
    fi
  done
}

DPChangeHost() {
  valid=0
  while test $valid -eq 0; do
    UserOutput ""
    # Use the original STDIN STDOUT and STDERR when rear was launched by the user
    # to get input from the user and to show output to the user (cf. _input-output-functions.sh):
    read -r -p "Enter host: " 0<&6 1>&7 2>&8
    if test -z "${REPLY}"; then
      DPChooseBackup
      return
    fi
    if ${OMNICELLINFO} -cell | grep -q "host=\"${REPLY}\""; then
      valid=1
    else
      LogPrint "Invalid hostname '${REPLY}'!"
    fi
  done
  DPChooseBackup ${REPLY}
}

DPChangeDataList() {
  valid=0
  while test $valid -eq 0; do
    LogPrint ""
    LogPrint ""
    LogPrint "Available datalists for host:"
    LogPrint ""
    i=0
    cat $TMP_DIR/backup.list | while read s; do echo "$s" | cut -f 2; done | sort -u | while read s; do
      i=$(expr $i + 1)
      LogPrint "  [$i] $s"
    done
    i=$(cat $TMP_DIR/backup.list | while read s; do echo "$s" | cut -f 2; done | sort -u | wc -l)
    LogPrint ""
    # Use the original STDIN STDOUT and STDERR when rear was launched by the user
    # to get input from the user and to show output to the user (cf. _input-output-functions.sh):
    read -r -p "Please choose datalist [1-$i]: " 0<&6 1>&7 2>&8
    if test "${REPLY}" -ge 1 -a "${REPLY}" -le $i 2>/dev/null ; then
      DL=$(cat $TMP_DIR/backup.list | while read s; do echo "$s" | cut -f 2; done | sort -u | head -${REPLY} | tail -1)
      valid=1
    else
      LogPrint "Invalid number '${REPLY}'!"
    fi
  done
}

DPChangeSession() {
  valid=0
  while test $valid -eq 0; do
    LogPrint ""
    LogPrint ""
    LogPrint "Available sessions for datalist:"
    LogPrint ""
    i=0
    if test ! -s $TMP_DIR/backup.list.part; then cp $TMP_DIR/backup.list $TMP_DIR/backup.list.part; fi
    cat $TMP_DIR/backup.list.part | while read s; do echo "$s" | cut -f 1; done | sort -u -r -V | while read s; do
      i=$(expr $i + 1)
      LogPrint "  [$i] $s"
    done
    i=$(cat $TMP_DIR/backup.list.part | while read s; do echo "$s" | cut -f 1; done | sort -u -r -V | wc -l)
    echo
    # Use the original STDIN STDOUT and STDERR when rear was launched by the user
    # to get input from the user and to show output to the user (cf. _input-output-functions.sh):
    read -r -p "Please choose session [1-$i]: " 0<&6 1>&7 2>&8
    if test "${REPLY}" -ge 1 -a "${REPLY}" -le $i 2>/dev/null ; then
      SESS=$(cat $TMP_DIR/backup.list.part | while read s; do echo "$s" | cut -f 1; done | sort -u -r -V | head -${REPLY} | tail -1)
      valid=1
    else
      LogPrint "Invalid number '${REPLY}!"
    fi
  done
}

DPChooseBackup
