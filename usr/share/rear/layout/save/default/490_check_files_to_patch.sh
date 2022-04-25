# FILES_TO_PATCH_PATTERNS is a space-separated list of shell glob patterns.
# Files that match are eligible for a final migration of UUIDs and other
# identifiers after recovery (if the layout recreation process has led
# to a change of an UUID or a device name and a corresponding change needs
# to be performed on restored configuration files ).
# See finalize/GNU/Linux/280_migrate_uuid_tags.sh
# We should add all such files to CHECK_CONFIG_FILES - if they change,
# we risk inconsistencies between the restored files and recreated layout,
# or failures of UUID migration.

local file final_file symlink_target

# The patterns are relative to /, change directory there
# so that the shell finds the files during pathname expansion
pushd / >/dev/null
# The variable expansion is deliberately not quoted in order to perform
# pathname expansion on the variable value.
for file in $FILES_TO_PATCH_PATTERNS ; do
    final_file="/$file"
    IsInArray "$final_file" "${CHECK_CONFIG_FILES[@]}" && continue
    # Symlink handling (partially from 280_migrate_uuid_tags.sh):
    # avoid dead symlinks, and symlinks to files on dynamic filesystems
    # ( /proc etc.) - they are expected to change and validating
    # their checksums has no sense
    if test -L "$final_file" ; then
        if symlink_target="$( readlink -e "$final_file" )" ; then
            # If the symlink target contains /proc/ /sys/ /dev/ or /run/ we skip it because then
            # the symlink target is considered to not be a restored file that needs to be patched
            # and thus we don't need to generate and check its hash, either
            # cf. https://github.com/rear/rear/pull/2047#issuecomment-464846777
            if echo $symlink_target | egrep -q '/proc/|/sys/|/dev/|/run/' ; then
                Log "Skip adding symlink $final_file target $symlink_target on /proc/ /sys/ /dev/ or /run/ to CHECK_CONFIG_FILES"
                continue
            fi
            Debug "Adding symlink $final_file with target $symlink_target to CHECK_CONFIG_FILES"
        else
            LogPrint "Skip adding dead symlink $final_file to CHECK_CONFIG_FILES"
            continue
        fi
    fi
    CHECK_CONFIG_FILES+=( "$final_file" )
done
popd >/dev/null
