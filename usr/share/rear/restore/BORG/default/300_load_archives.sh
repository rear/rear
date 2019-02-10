# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 300_load_archives.sh

LogPrint "Starting Borg restore"

# Store number of lines in BORGBACKUP_ARCHIVE_CACHE file for later use.
archive_cache_lines=$(wc -l $BORGBACKUP_ARCHIVE_CACHE | awk '{print $1}')

# This means empty repository.
if [ $archive_cache_lines -eq 0 ]; then
    Error "Borg repository $BORGBACKUP_REPO on $BORGBACKUP_HOST is empty"
fi

# Display list of archives in repository.
# Display header.
LogUserOutput "
=== Borg archives list ===
Host:       $BORGBACKUP_HOST
Repository: $BORGBACKUP_REPO
"

# Display BORGBACKUP_ARCHIVE_CACHE file content
# and prompt user for archive to restore.
# Always ask which archive to restore (even if there is only one).
# This gives possibility to abort restore if repository doesn't contain
# desired archive, hence saves some time.
while true ; do
    LogUserOutput "$( cat -n $BORGBACKUP_ARCHIVE_CACHE | awk '{print "["$1"]", $2,"\t"$3,$4,$5}' )"

    # Show "Exit" option.
    UserOutput ""
    LogUserOutput "[$(($archive_cache_lines+1))]" Exit
    UserOutput ""

    # Read user input.
    choice="$( UserInput -I BORGBACKUP_ARCHIVE_TO_RECOVER -p "Choose archive to recover from" )"

    # Evaluate user selection and save archive name to restore.
    # Valid pick
    if [[ $choice -ge 1 && $choice -le $archive_cache_lines ]]; then
        BORGBACKUP_ARCHIVE=$(sed "$choice!d" $BORGBACKUP_ARCHIVE_CACHE \
        | awk '{print $1}')
        break;
    # Exit
    elif [[ $choice -eq $(($archive_cache_lines+1)) ]]; then
        Error "Operation aborted by user"
        break;
    fi
done
