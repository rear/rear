# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 10_load_archives.sh

LogPrint "Starting Borg restore"

# Do we have Borg binary?
# Missing Borg binary should not happen as it is copyied by
# backup/BORG/default/20_start_backup.sh
has_binary borg
BugIfError "Could not find Borg binary"

# Query Borg server for repoitory information and store it to archive_cache.
# This should avoid repeatingly quering Borg server, which could be slow.
archive_cache=$TMP_DIR/borg_archive
borg list $BORG_USERNAME@$BORG_HOST:$BORG_REPO > $archive_cache
StopIfError "Could not list Borg archive"

# Store number of lines in archive_cache file for later use
archive_cache_lines=$(wc -l $archive_cache | awk '{print $1}')

# This means empty repository
if [ $archive_cache_lines -eq 0 ]; then
    Error "Borg repository $BORG_REPO on $BORG_HOST is empty"
fi

# Display list of archives in repository
# Display header
echo ""
echo "=== Borg archives list ==="
echo "Host:       $BORG_HOST"
echo "Repository: $BORG_REPO"
echo ""

# Display archive_cache file content and prompt user for archive to restore
while(true); do
    cat -n $archive_cache | awk '{print "["$1"]", $2,"\t"$3,$4,$5}'

    # Show "Exit" option
    echo ""
    echo "[$(($archive_cache_lines+1))]" Exit
    echo ""

    # Read user input
    echo -n "Choose archive to recover from: "
    read choice

    # Evaluate user selection and save archive name to restore
    # Valid pick
    if [[ $choice -ge 1 && $choice -le $archive_cache_lines ]]; then
        ARCHIVE=$(sed "$choice!d" $archive_cache | awk '{print $1}')
        break;
    # Exit
    elif [[ $choice -eq $(($archive_cache_lines+1)) ]]; then
        Error "Operation aborted by user"
        break;
    fi
done
