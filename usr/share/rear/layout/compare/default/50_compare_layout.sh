# Test if ORIG_LAYOUT and TEMP_LAYOUT are the same

diff $ORIG_LAYOUT $TEMP_LAYOUT >/dev/null

if [ $? -eq 0 ] ; then
    LogPrint "Disk layout is identical."
else
    LogPrint "Disk layout has changed."
    diff -u $ORIG_LAYOUT $TEMP_LAYOUT >&2
fi
