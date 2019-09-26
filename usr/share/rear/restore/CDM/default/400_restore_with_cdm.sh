# 400_restore_with_cdm.sh
#
#

LogPrint "Please start the restore process on the Rubrik (CDM) cluster."
LogPrint "Make sure all required data is restored to $TARGET_FS_ROOT ."
LogPrint ""
LogPrint "When the restore is finished type 'exit' to continue the recovery."
LogPrint "Info: You can check the recovery process i.e. with the command 'df'."
LogPrint ""

rear_shell "Has the restore been completed and are you ready to continue the recovery?"
