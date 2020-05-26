# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 300_load_archives.sh

LogPrint "Starting Borg restore"

# shellcheck disable=SC2168
local archive_cache_lines

# Store number of lines in BORGBACKUP_ARCHIVE_CACHE file for later use.
archive_cache_lines=$( wc -l "$BORGBACKUP_ARCHIVE_CACHE" | awk '{ print $1 }' )

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

# Pagination for selecting archives:
# Show BORGBACKUP_RESTORE_ARCHIVES_SHOW_MAX archives at a time, starting
# with the current ones.
# If no valid choice is given, cycle through older archives.
# Enabled by default (BORGBACKUP_RESTORE_ARCHIVES_SHOW_MAX=10).
# To disable pagination set BORGBACKUP_RESTORE_ARCHIVES_SHOW_MAX=0.

# shellcheck disable=SC2168
local archive_cache_last_shown=0

# For timestamp output of Borg archives ISO 8601 format is used:
# YYYY-MM-DDThh:mm:ss, e.g.: 2020-05-26T00:25:00

# When pagination is disabled by the user, show everything
[[ $BORGBACKUP_RESTORE_ARCHIVES_SHOW_MAX -eq 0 ]] \
    && BORGBACKUP_RESTORE_ARCHIVES_SHOW_MAX=$archive_cache_lines

while true ; do
    UserOutput ""
    LogUserOutput "$( cat -n "$BORGBACKUP_ARCHIVE_CACHE" \
        | awk '{ print "["$1"]", $4 "T" $5, $2 }' \
        | head -n $(( archive_cache_lines - archive_cache_last_shown )) \
        | tail -n "$BORGBACKUP_RESTORE_ARCHIVES_SHOW_MAX" )"
    (( archive_cache_last_shown += BORGBACKUP_RESTORE_ARCHIVES_SHOW_MAX ))
    UserOutput ""
    if [[ $archive_cache_last_shown -lt $archive_cache_lines ]]; then
        LogUserOutput "[0] Show (up to) $BORGBACKUP_RESTORE_ARCHIVES_SHOW_MAX older archives"
    else
        archive_cache_last_shown=0
        LogUserOutput "[0] Show all archives again"
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
        BORGBACKUP_ARCHIVE=$( sed "$choice!d" "$BORGBACKUP_ARCHIVE_CACHE" \
            | awk '{ print $1 }' )
        break
    # Exit
    elif [[ $choice -eq $(( archive_cache_lines + 1 )) ]]; then
        Error "Operation aborted by user"
    fi
done
