# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 10_load_archives.sh

# Do we have Borg binary?
has_binary borg
StopIfError "Could not find Borg binary"

# Query Borg server for repoitory information and store it to archive_cache.
# This should avoid repeatingly quering Borg server, which could be slow.
archive_cache=$TMP_DIR/borg_archive
borg list $BORG_USERNAME@$BORG_HOST:$BORG_REPO 2> /dev/null > $archive_cache

# If $rc == 0 we have repository present, but it is empty
# In my tests, Borg returned RC = 2, when repository was non-existent or
# due connection problems (bad hostname, etc ...)
# If repository is present but empty, rc will be set to 0, and initialization
# will be skipped
rc=$?

# TODO: Add security options for Borg repository initialization ...
# This might be an Borg connection error, or missing repository
# If initialization succeedes, we can cast out connection problems
if [ $rc -ne 0 ]; then
    Log "Creating new Borg repository $BORG_REPO on $BORG_HOST"
    borg init -e none $BORG_USERNAME@$BORG_HOST:$BORG_REPO
    rc=$?
    StopIfError "Could not initialize Borg repository"
fi

# Borg repository initilization failed in previous step,
# backup abort is inevitablee
if [ $rc -ne 0 ]; then
    Error "Could not initialize Borg repository"
fi

# Everything should be be OK now, we can extract information about archives
# Lets find largest suffix in use, and increment it by 1
SUFFIX=0

for i in \
$(cat $archive_cache | grep "^$BORG_ARCHIVE_PREFIX" | awk '{print $1}'); do
    suffix_tmp=$(echo $i | cut -d "_" -f 2)

    if [ $suffix_tmp -gt $SUFFIX ]; then
        SUFFIX=$suffix_tmp
    fi
done

SUFFIX=$(($SUFFIX + 1))
