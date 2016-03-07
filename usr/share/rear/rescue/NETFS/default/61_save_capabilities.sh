# save all found capapilities to file 

if is_true "$NETFS_RESTORE_CAPABILITIES" ; then
	getcap -r / 2>/dev/null | grep -v $ISO_DIR > $VAR_DIR/recovery/capabilities || Log "Error while saving capabilities to file."
fi
