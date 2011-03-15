# Run the actual script

(
. $LAYOUT_CODE
)

if [ $? -ne 0 ] ; then
    abort_recreate
    
    Error "There was an error restoring the system layout. See $LOGFILE for details."
fi
