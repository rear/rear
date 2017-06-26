# Test if ORIG_LAYOUT and TEMP_LAYOUT are the same

diff -u <(grep -v '^#' $ORIG_LAYOUT) <(grep -v '^#' $TEMP_LAYOUT) >/dev/null

if [ $? -eq 0 ] ; then
    LogPrint "Disk layout is identical."
else
    LogPrint "Disk layout has changed."
    diff -u <(grep -v '^#' $ORIG_LAYOUT) <(grep -v '^#' $TEMP_LAYOUT) >&2
    EXIT_CODE=1
fi
