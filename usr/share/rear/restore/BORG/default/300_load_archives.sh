# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 300_load_archives.sh

LogPrint "Starting Borg restore"

# Store number of lines in BORGBACKUP_ARCHIVE_CACHE file for later use.
archive_cache_lines=$( wc -l "$BORGBACKUP_ARCHIVE_CACHE" | awk '{print $1}' )

# This means empty repository.
if [ "$archive_cache_lines" -eq 0 ]; then
    Error "Borg repository $BORGBACKUP_REPO on ${BORGBACKUP_HOST:-USB} is empty!"
fi

# Display list of archives in repository.
# Display header.
LogUserOutput "
=== Borg archives list ===

Location:           ${BORGBACKUP_HOST:-USB}
Repository:         $BORGBACKUP_REPO
Number of archives: $archive_cache_lines"

# Display BORGBACKUP_ARCHIVE_CACHE file content
# and prompt user for archive to restore.
# Always ask which archive to restore (even if there is only one).
# This gives possibility to abort restore if repository doesn't contain
# desired archive, hence saves some time.
# Show BORGBACKUP_RESTORE_ARCHIVES_SHOW_NUMBER archives at a time, starting
# with the current ones.
# If no valid choice is given, cycle through older archives.
# To disable this pagination set BORGBACKUP_RESTORE_ARCHIVES_SHOW_NUMBER=0.

archive_cache_last_shown=0

while true ; do
    UserOutput ""
    if [[ $BORGBACKUP_RESTORE_ARCHIVES_SHOW_NUMBER -eq 0 ]]; then
        LogUserOutput "$( cat -n "$BORGBACKUP_ARCHIVE_CACHE" \
            | awk '{ print "["$1"]", $4 "T" $5, $2 }' )"
        UserOutput ""
        LogUserOutput "[0] Show all archives again"
    else
        LogUserOutput "$( cat -n "$BORGBACKUP_ARCHIVE_CACHE" \
            | tac \
            | awk '{print "["$1"]", $4 "T" $5, $2 }' \
            | tail -n +$(( archive_cache_last_shown + 1 )) \
            | head -n "$BORGBACKUP_RESTORE_ARCHIVES_SHOW_NUMBER" \
            | tac )"
        (( archive_cache_last_shown += BORGBACKUP_RESTORE_ARCHIVES_SHOW_NUMBER ))
        UserOutput ""
        if [[ $archive_cache_last_shown -lt $archive_cache_lines ]]; then
            LogUserOutput "[0] Show (up to) $BORGBACKUP_RESTORE_ARCHIVES_SHOW_NUMBER older archives"
        else
            archive_cache_last_shown=0
            LogUserOutput "[0] Show all archives again"
        fi
    fi

    # Show "Exit" option.
    UserOutput ""
    LogUserOutput "[$(( archive_cache_lines + 1 ))]" Exit
    UserOutput ""

    # Read user input.
    choice="$( UserInput -I BORGBACKUP_ARCHIVE_TO_RECOVER -p "Choose archive to recover from" )"

    # Evaluate user selection and save archive name to restore.
    # Valid pick
    if [[ $choice -ge 1 && $choice -le $archive_cache_lines ]]; then
        # shellcheck disable=SC2034
        BORGBACKUP_ARCHIVE=$(sed "$choice!d" "$BORGBACKUP_ARCHIVE_CACHE" \
            | awk '{print $1}')
        break
    # Exit
    elif [[ $choice -eq $(( archive_cache_lines + 1 )) ]]; then
        Error "Operation aborted by user"
        break
    fi
done
