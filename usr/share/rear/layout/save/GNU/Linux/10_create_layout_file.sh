# Create the layout file

Log "Preparing layout directory."
mkdir -p $VAR_DIR/layout

if [ -e "$DISKLAYOUT_FILE" ] ; then
    Log "Removing old layout file."
fi
: > $DISKLAYOUT_FILE
