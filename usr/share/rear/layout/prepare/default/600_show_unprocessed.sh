# Warn for missing components.

while read -u 3 status name type junk ; do
    LogPrint "No code has been generated to restore device $name ($type).
    Please add code to $LAYOUT_CODE to manually install it or choose abort."
    # Use the original STDIN STDOUT and STDERR when rear was launched by the user
    # to get input from the user and to show output to the user (cf. _input-output-functions.sh):
    select choice in "Continue" "Abort" ; do
        if [ "$choice" = "Continue" ] || [ "$choice" = "Abort" ] ; then
            break;
        fi
    done 0<&6 1>&7 2>&8

    if [ "$choice" = "Abort" ] ; then
        abort_recreate
        Error "User chose to abort the recovery."
    fi
done 3< <(grep "^todo" "$LAYOUT_TODO")
