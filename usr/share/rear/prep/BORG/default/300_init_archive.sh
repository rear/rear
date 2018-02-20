# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 300_init_archive.sh

# Do we have Borg binary?
has_binary borg
StopIfError "Could not find Borg binary"

# Query Borg server for repository information
# and store it to BORGBACKUP_ARCHIVE_CACHE.
# This should avoid repeatingly quering Borg server, which could be slow.
borg_archive_cache_create

# If $rc == 0 we have repository present, but it is empty.
# In my tests, Borg returned RC = 2, when repository was non-existent or
# due connection problems (bad hostname, etc ...).
# If repository is present but empty, rc will be set to 0, and initialization
# will be skipped.
rc=$?

# This might be a Borg connection / mount error, or missing repository.
# If initialization succeeds, we can rule out connection problems.
# `borg init` has to be triggered in "prep" stage if user decides to include
# keyfiles to Relax-and-Recover rescue/recovery system using COPY_AS_IS_BORG.
if [ $rc -ne 0 ]; then
    LogPrint "Failed to list $BORGBACKUP_REPO"
    LogPrint "Creating new Borg repository $BORGBACKUP_REPO"

    borg init $BORGBACKUP_OPT_ENCRYPTION $BORGBACKUP_OPT_REMOTE_PATH \
    $BORGBACKUP_OPT_UMASK ${borg_dst_dev}${BORGBACKUP_REPO}
    rc=$?
fi

# Borg repository initialization failed in previous step,
# backup abort is inevitable.
if [ $rc -ne 0 ]; then
    Error "Could not initialize Borg repository"
fi
