if test "$PRE_RECOVERY_SCRIPT" ; then
	LogPrint "Running PRE_RECOVERY_SCRIPT '${PRE_RECOVERY_SCRIPT[@]}'"
	eval "${PRE_RECOVERY_SCRIPT[@]}"
fi
