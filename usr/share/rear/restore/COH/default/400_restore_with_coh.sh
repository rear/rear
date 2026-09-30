# 400_restore_with_coh.sh
# Purpose: Hand off the actual data restore to the Cohesity Data Cloud console
# and/or its REST API, then wait for confirmation before continuing 'rear recover'.

LogPrint "
Initiate and monitor the restore of this host's data from the
Cohesity Data Cloud console and/or its REST API now.

Restore the data into: $TARGET_FS_ROOT

If this recovery host has a different IP address than the original system,
you may need to re-register the Cohesity agent with the cluster before the
restore can proceed (see the previous 'verify' step for details).

Next type 'exit' to continue the recovery.
Info: You can check the recovery progress i.e. with the command 'df'.
"

rear_shell "Has the restore been completed and are you ready to continue the recovery?"
