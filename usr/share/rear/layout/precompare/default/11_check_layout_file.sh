# Check if the disk layout file exists.

if [ ! -e "$ORIG_LAYOUT" ] ; then
    Error "Please run \"# rear savelayout\" first."
fi
