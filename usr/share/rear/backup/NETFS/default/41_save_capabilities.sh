# save all found capapilities to file 

if [ "$BACKUP_CAP" == "y" ] ; then
	Log "Saving capabilities to File." 
	if which getcap >/dev/null 2>&1 ; then
		getcap -r / 2>/dev/null | grep -v $ISO_DIR > $VAR_DIR/recovery/capabilities
	else
		Log "getcap binary not found."
	fi

fi
