# migrate lun_wwid_mapping

# skip if no mappings
test -s "$LUN_WWID_MAP" || return 0

Log "TAG-15-migrate-wwid: $LUN_WWID_MAP"

# create the SED_SCRIPT
SED_SCRIPT=""
while read old_wwid new_wwid device ; do
        SED_SCRIPT="$SED_SCRIPT;/${old_wwid}/s/${old_wwid}/${new_wwid}/g"
done < <(sort -u $LUN_WWID_MAP)

# debug line:
Log "$SED_SCRIPT"

# Careful in case of 'return' after 'pushd' (must call the matching 'popd' before 'return'):
pushd $TARGET_FS_ROOT >&2

# now run sed

# the funny [] around the first letter make sure that shopt -s nullglob removes this file from the list if it does not exist
# the files without a [] are mandatory, like fstab
for file in [e]tc/elilo.conf \
            [e]tc/fstab
        do

        #[[ -d "$file" ]] && continue # skip directory
        [[ ! -f "$file" ]] && continue # skip directory and file not found
        # sed -i bails on symlinks, so we follow the symlink and patch the result
        # on dead links we warn and skip them
        # TODO: maybe we must put this into a chroot so that absolute symlinks will work correctly
	    if test -L "$file" ; then
            if linkdest="$(readlink -f "$file")" ; then
                # if link destination is residing on /proc we skip it silently
			    echo $linkdest | grep -q "^/proc" && continue
			    LogPrint "Patching '$linkdest' instead of '$file'"
			    file="$linkdest"
		    else
                LogPrint "Not patching dead link '$file'"
			    continue
			fi
        fi

        LogPrint "Patching file '$file'"
        sed -i "$SED_SCRIPT" "$file"
        StopIfError "Patching '$file' with sed failed."
done

popd >&2

