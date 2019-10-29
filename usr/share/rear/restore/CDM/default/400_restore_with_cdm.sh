# 400_restore_with_cdm.sh
#
#

LogPrint "Please start the restore process on the Rubrik (CDM) cluster."

if is_true $CDM_NEW_AGENT_UUID; then
  LogPrint ""
  LogPrint "Register the appropriate IP address from this list with Rubrik (CDM):"
  LogPrint "$( ip addr | grep inet | cut -d / -f 1 | grep -v 127.0.0.1 | grep -v ::1 )"
  LogPrint ""
fi
LogPrint "Make sure all required data is restored to $TARGET_FS_ROOT ."
LogPrint ""
LogPrint "Next type 'exit' to continue the recovery."
LogPrint "Info: You can check the recovery process i.e. with the command 'df'."
LogPrint ""

rear_shell "Has the restore been completed and are you ready to continue the recovery?"
