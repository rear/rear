# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 30_init_archive.sh

# Do we have Borg binary?
has_binary borg
StopIfError "Could not find Borg binary"

# Query Borg server for repository information and store it to ARCHIVE_CACHE.
# This should avoid repeatingly quering Borg server, which could be slow.
borg_archive_cache_create

# If $rc == 0 we have repository present, but it is empty.
# In my tests, Borg returned RC = 2, when repository was non-existent or
# due connection problems (bad hostname, etc ...).
# If repository is present but empty, rc will be set to 0, and initialization
# will be skipped.
rc=$?

# This might be a Borg connection error, or missing repository.
# If initialization succeeds, we can rule out connection problems.
if [ $rc -ne 0 ]; then
    Log "Failed to list $BORGBACKUP_REPO on $BORGBACKUP_HOST"
    Log "Creating new Borg repository $BORGBACKUP_REPO on $BORGBACKUP_HOST"
    borg init $OPT_ENCRYPTION $OPT_REMOTE_PATH \
    $BORGBACKUP_USERNAME@$BORGBACKUP_HOST:$BORGBACKUP_REPO
    rc=$?
fi

# Borg repository initialization failed in previous step,
# backup abort is inevitable.
if [ $rc -ne 0 ]; then
    Error "Could not initialize Borg repository"
fi
