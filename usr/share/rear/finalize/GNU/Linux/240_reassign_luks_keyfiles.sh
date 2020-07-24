# Re-assign original keyfiles to LUKS volumes
#
# In the 'layout/prepare' stage, temporary keyfiles were generated for password-less decryption. By now, the
# original keyfiles should have been restored from the backup. If so, the original keyfiles are re-assigned
# to their LUKS volumes and temporary keyfiles are discarded. Where an original keyfile was not restored
# to its expected location, an error message is displayed and the corresponding temporary keyfile will take
# over, so that the recovered system remains fully functional.

local target_name source_device original_keyfile

awk '
    $1 == "crypt" && / keyfile=/ {
        target_name = $2;
        sub("^/dev/mapper/", "", target_name);
        source_device = $3;

        sub("^.* keyfile=", "");
        sub("[ \t].*$", "");
        original_keyfile = $0;

        print target_name, source_device, original_keyfile;
    }
' "$LAYOUT_FILE" |
while read target_name source_device original_keyfile; do
    Log "Re-assigning keyfile $original_keyfile to LUKS device $target_name ($source_device)"

    # The scheme for generating a temporary keyfile path must be the same here and in the 'layout/prepare' stage:
    temp_keyfile="$TMP_DIR/LUKS-keyfile-$target_name"
    test -f "$temp_keyfile" || BugError "temporary LUKS keyfile $temp_keyfile not found"

    target_keyfile="$TARGET_FS_ROOT/$original_keyfile"

    if [ -f "$target_keyfile" ]; then
        # Assign the original keyfile to the LUKS volume, if successful, remove the temporary keyfile.
        cryptsetup --key-file "$temp_keyfile" luksAddKey "$source_device" "$target_keyfile"
        BugIfError "Could not add the keyfile $original_keyfile to LUKS device $target_name ($source_device)"
        cryptsetup luksRemoveKey "$source_device" "$temp_keyfile"
        BugIfError "Could not remove the temporary keyfile $temp_keyfile from LUKS device $target_name ($source_device)"
    else
        # The original keyfile was not restored from the backup - move the temporary keyfile to
        # the target location so that the LUKS volume can still be decrypted.
        mkdir -p "$(dirname $target_keyfile)"
        cp -p "$temp_keyfile" "$target_keyfile" &&  rm "$temp_keyfile"
        StopIfError "Could not restore keyfile $original_keyfile for LUKS device $target_name ($source_device) from temporary keyfile"
        LogPrintError "$original_keyfile was not restored from the backup - LUKS device $target_name ($source_device) has been assigned a new keyfile"
    fi
done
