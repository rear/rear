[[ $DEBUGSCRIPTS -eq 1 ]] && return   # to avoid throwing an error in DEBUG mode
grep -iq "no space left" $RUNTIME_LOGFILE && Error "write error: No space left on device"
# do not return 1 if grep fails - that's normal and expected
return 0
