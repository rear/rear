# DASD_FORMAT_CODE is the script to recreate the dasd formatting (dasdformat.sh).

local component disk size label junk
local blocksize layout dasdtype dasdcyls junk2


save_original_file "$DASD_FORMAT_CODE"

# Initialize

echo '#!/bin/bash' >"$DASD_FORMAT_CODE"

# Show the current output of lsdasd, it can be useful for identifying disks
# (in particular it shows the Linux device name <-> virtual device number mapping,
# formatted / unformatted status and the number/size of blocks when formatted )
echo "# Current output of 'lsdasd':" >>"$DASD_FORMAT_CODE"
lsdasd | TextPrefix '# ' >>"$DASD_FORMAT_CODE"

cat <<EOF >>"$DASD_FORMAT_CODE"

LogPrint "Start DASD format restoration."

set -e
set -x

EOF

while read component disk size label junk; do
    if [ "$label" == dasd ]; then
        # Ignore excluded components.
        # Normally they are removed in 520_exclude_components.sh,
        # but we run before it, so we must skip them here as well.
        if IsInArray "$disk" "${EXCLUDE_RECREATE[@]}" ; then
            Log "Excluding $disk from DASD reformatting."
            continue
        fi
        # dasd has more fields - junk is not junk anymore
        read blocksize layout dasdtype dasdcyls junk2 <<<$junk
        dasd_format_code "$disk" "$size" "$blocksize" "$layout" "$dasdtype" "$dasdcyls" >> "$DASD_FORMAT_CODE" || \
            LogPrintError "Error producing DASD format code for $disk"
    fi
done < <(grep "^disk " "$LAYOUT_FILE")

cat <<EOF >>"$DASD_FORMAT_CODE"

set +x
set +e

LogPrint "DASD(s) formatted."

EOF
