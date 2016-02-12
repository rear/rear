# restore capabilities if capabilities are in the backup
	if test -s $VAR_DIR/recovery/capabilities ; then
		Log "Restoring Capabilities."
		if which setcap >/dev/null 2>&1 ; then
			while read file cap ; do
				setcap $cap ${TARGET_FS_ROOT}/${file}	
			done < <(cat $VAR_DIR/recovery/capabilities | sed 's/=//')
		else
			Log "setcap binary not found."
		fi
	fi
