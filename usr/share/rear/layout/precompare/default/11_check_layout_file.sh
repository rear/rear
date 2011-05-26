# Check if the disk layout file exists.

[[ -e "$ORIG_LAYOUT" ]]
StopIfError "Please run \"# rear savelayout\" first."
