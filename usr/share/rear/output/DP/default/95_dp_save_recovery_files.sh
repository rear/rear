#
# saving recovery files for DP

ProgressStart "Saving recovery files for DP"

test -z "$DP_RECOVERY_FILE_PATH" && DP_RECOVERY_FILE_PATH="$CONFIG_DIR/DP"

if test -d "$DP_RECOVERY_FILE_PATH" ; then
  rm -rf "$DP_RECOVERY_FILE_PATH"
fi

if ! test -d "$DP_RECOVERY_FILE_PATH" ; then
         mkdir -v -p "$DP_RECOVERY_FILE_PATH" 1>&8
         ProgressStopIfError $? "Could not create '$DP_RECOVERY_FILE_PATH'"
fi


cp -r "$VAR_DIR/recovery" "$DP_RECOVERY_FILE_PATH"

ProgressStop

#set +x
