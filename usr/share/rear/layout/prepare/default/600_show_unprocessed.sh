# Warn for missing components.

while read -u 3 status name type junk ; do
    LogPrint "No code has been generated to restore device $name ($type).
    Please add code to $LAYOUT_CODE to manually install it or choose abort."
    select choice in "Continue" "Abort" ; do
        if [ "$choice" = "Continue" ] || [ "$choice" = "Abort" ] ; then
            break;
        fi
    done 2>&1

    if [ "$choice" = "Abort" ] ; then
        abort_recreate
        Error "User chose to abort the recovery."
    fi
done 3< <(grep "^todo" "$LAYOUT_TODO")
