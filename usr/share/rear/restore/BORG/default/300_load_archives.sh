# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 300_load_archives.sh

LogPrint "Starting Borg restore"

# shellcheck disable=SC2168
local archive_cache_lines_total

# Store number of lines in BORGBACKUP_ARCHIVE_CACHE file for later use.
archive_cache_lines_total=$( wc -l "$BORGBACKUP_ARCHIVE_CACHE" | awk '{ print $1 }' )

# This means empty repository.
if [ "$archive_cache_lines_total" -eq 0 ]; then
    Error "Borg repository $BORGBACKUP_REPO on ${BORGBACKUP_HOST:-USB} is empty!"
fi

# Display list of archives in repository.
# Display header.
LogUserOutput "
=== Borg archives list ===

Location:           ${BORGBACKUP_HOST:-USB}
Repository:         $BORGBACKUP_REPO
Number of archives: $archive_cache_lines_total"

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
local archive_cache_lines_last_shown=0

# For timestamp output of Borg archives ISO 8601 format is used:
# YYYY-MM-DDThh:mm:ss, e.g.: 2020-05-26T00:25:00

# When pagination is disabled by the user, show everything
[[ $BORGBACKUP_RESTORE_ARCHIVES_SHOW_MAX -eq 0 ]] \
    && BORGBACKUP_RESTORE_ARCHIVES_SHOW_MAX=$archive_cache_lines_total
# -----------------------------------------------------------------------------
# Optional: Node-specific archive restriction for BORG restores
#
# If ENABLE_BORG_NODE_FILTER is set to "yes" (e.g. in /etc/rear/local.conf),
# this section restricts the available restore archives to only the most recent
# (highest-numbered) backup with this node's BORGBACKUP_ARCHIVE_PREFIX.
#
# This prevents accidental restore of the wrong system in shared repositories,
# especially in unattended/AUTO_CONFIRM scenarios.
#
# If no matching archive is found, ReaR aborts with a clear error and NEVER
# restores from another node's backup.
#
# This block is fully backward compatible: if ENABLE_BORG_NODE_FILTER is not "yes",
# ReaR shows all available BORG archives as before.
# -----------------------------------------------------------------------------
if is_true "$ENABLE_BORG_NODE_FILTER"; then
    [[ -n $BORGBACKUP_ARCHIVE_PREFIX ]] || Error "ENABLE_BORG_NODE_FILTER=yes but BORGBACKUP_ARCHIVE_PREFIX is empty"
    [[ -s $BORGBACKUP_ARCHIVE_CACHE ]] || Error "ENABLE_BORG_NODE_FILTER=yes but Borg archive cache '$BORGBACKUP_ARCHIVE_CACHE' is missing or empty"

    # Find highest-numbered archive for this node prefix (archive names are ${BORGBACKUP_ARCHIVE_PREFIX}_<number>)
    latest_archive=$( grep "^${BORGBACKUP_ARCHIVE_PREFIX}_" "$BORGBACKUP_ARCHIVE_CACHE" | LC_ALL=C sort -t_ -k2,2n | tail -n 1 )
    if [[ -n $latest_archive ]]; then
        printf '%s\n' "$latest_archive" > "$BORGBACKUP_ARCHIVE_CACHE"
        archive_cache_lines_total=1
        BORGBACKUP_RESTORE_ARCHIVES_SHOW_MAX=1
        LogUserOutput "ENABLE_BORG_NODE_FILTER enabled: restricting restore candidates to the latest ${BORGBACKUP_ARCHIVE_PREFIX}_* archive."
    else
        Error "ENABLE_BORG_NODE_FILTER=yes but no archives with prefix '${BORGBACKUP_ARCHIVE_PREFIX}_' exist in Borg repository $BORGBACKUP_REPO on ${BORGBACKUP_HOST:-USB}. Aborting to avoid restoring from a different node."
    fi
fi
while true ; do
    UserOutput ""
    LogUserOutput "$( cat -n "$BORGBACKUP_ARCHIVE_CACHE" \
        | awk '{ print "["$1"]", $4 "T" $5, $2 }' \
        | head -n $(( archive_cache_lines_total - archive_cache_lines_last_shown )) \
        | tail -n "$BORGBACKUP_RESTORE_ARCHIVES_SHOW_MAX" )"
    (( archive_cache_lines_last_shown += BORGBACKUP_RESTORE_ARCHIVES_SHOW_MAX ))
    UserOutput ""
    if [[ $archive_cache_lines_last_shown -lt $archive_cache_lines_total ]]; then
        LogUserOutput "[0] Show (up to) $BORGBACKUP_RESTORE_ARCHIVES_SHOW_MAX older archives"
    else
        archive_cache_lines_last_shown=0
        LogUserOutput "[0] Show all archives again"
    fi

    local abort_choice
    (( abort_choice = archive_cache_lines_total + 1 ))
    # Show "Exit" option.
    UserOutput ""
    LogUserOutput "[$abort_choice]" Exit
    UserOutput ""

    # Read user input.
    choice="$( UserInput -I BORGBACKUP_ARCHIVE_TO_RECOVER -D "$archive_cache_lines_total" -p "Choose archive to recover from" )"

    # Evaluate user selection and save archive name to restore.
    # Valid pick
    if [[ $choice -ge 1 && $choice -le $archive_cache_lines_total ]]; then
        # shellcheck disable=SC2034
        BORGBACKUP_ARCHIVE=$( sed "$choice!d" "$BORGBACKUP_ARCHIVE_CACHE" \
            | awk '{ print $1 }' )
        break
    # Exit
    elif [[ $choice -eq $abort_choice ]]; then
        Error "Operation aborted by user"
    fi
done
