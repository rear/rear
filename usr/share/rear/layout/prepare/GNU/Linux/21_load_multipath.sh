
if grep -q ^multipath $LAYOUT_FILE ; then
    Log "Activating multipath"
    modprobe dm-multipath >&2
    multipath >&2
    if [ $? -ne 0 ] ; then
        LogPrint "Failed to activate multipath. Please do this now:"
        rear_shell "Did you activate the multipath devices?"
    fi
fi
