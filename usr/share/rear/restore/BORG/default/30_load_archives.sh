# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 30_load_archives.sh

LogPrint "Starting Borg restore"

# Do we have Borg binary?
has_binary borg
BugIfError "Could not find Borg binary"

# Query Borg server for repository information and store it to ARCHIVE_CACHE.
# This should avoid repeatingly quering Borg server, which could be slow.
borg_archive_cache_create
StopIfError "Could not list Borg archive"

# Store number of lines in ARCHIVE_CACHE file for later use.
archive_cache_lines=$(wc -l $ARCHIVE_CACHE | awk '{print $1}')

# This means empty repository.
if [ $archive_cache_lines -eq 0 ]; then
    Error "Borg repository $BORGBACKUP_REPO on $BORGBACKUP_HOST is empty"
fi

# Display list of archives in repository.
# Display header.
echo ""
echo "=== Borg archives list ==="
echo "Host:       $BORGBACKUP_HOST"
echo "Repository: $BORGBACKUP_REPO"
echo ""

# Display ARCHIVE_CACHE file content and prompt user for archive to restore.
# Always ask which archive to restore (even if there is only one).
# This gives possibility to abort restore if repository doesn't contain
# desired archive, hence saves some time.
while(true); do
    cat -n $ARCHIVE_CACHE | awk '{print "["$1"]", $2,"\t"$3,$4,$5}'

    # Show "Exit" option.
    echo ""
    echo "[$(($archive_cache_lines+1))]" Exit
    echo ""

    # Read user input.
    echo -n "Choose archive to recover from: "
    read choice

    # Evaluate user selection and save archive name to restore.
    # Valid pick
    if [[ $choice -ge 1 && $choice -le $archive_cache_lines ]]; then
        ARCHIVE=$(sed "$choice!d" $ARCHIVE_CACHE | awk '{print $1}')
        break;
    # Exit
    elif [[ $choice -eq $(($archive_cache_lines+1)) ]]; then
        Error "Operation aborted by user"
        break;
    fi
done
