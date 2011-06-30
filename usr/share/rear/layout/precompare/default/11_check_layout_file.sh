# Check if the disk layout file exists.

[[ -e "$ORIG_LAYOUT" ]]
StopIfError "Please create an initial rescue image of this server !"
