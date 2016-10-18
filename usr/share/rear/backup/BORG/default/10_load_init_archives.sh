# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 10_load_archives.sh

# Check if BORG_ARCHIVE_PREFIX is correctly set
# Using '_' could result to some unpleasant site effects,
# as this character is used as delimiter in latter `for' loop ...
# Excluding other non aplhanum characeters is not really necessary,
# however it looks safer to me.
# I'm sure archive handling can be done better, but no time for it now ...
if [[ $BORG_ARCHIVE_PREFIX =~ [^a-zA-Z0-9] ]] \
|| [[ -z $BORG_ARCHIVE_PREFIX ]]; then
    Error "BORG_ARCHIVE_PREFIX must be alphanumeric non emply value only"
fi

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
$(cat $archive_cache | grep "^$BORG_ARCHIVE_PREFIX_" | awk '{print $1}'); do
    suffix_tmp=$(echo $i | cut -d "_" -f 2)

    if [ $suffix_tmp -gt $SUFFIX ]; then
        SUFFIX=$suffix_tmp
    fi
done

SUFFIX=$(($SUFFIX + 1))
