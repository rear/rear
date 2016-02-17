# restore capabilities if capabilities are in the backup
	if is_true "$NETFS_RESTORE_CAPABILITIES" ; then
		if test -s $VAR_DIR/recovery/capabilities ; then
			Log "Restoring Capabilities."
			while IFS="=" read file cap ; do
				file="${file% }"
				cap="${cap# }"
				setcap "${cap}" "${TARGET_FS_ROOT}/${file}" 2>/dev/null || Log "Error while setting capabilties to \"${file}\""
			done < <(cat $VAR_DIR/recovery/capabilities)
		else
			Log "No saved capabilities found"
		fi
	fi
