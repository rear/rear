# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 300_init_archive.sh

# Do we have Borg binary?
has_binary borg
StopIfError "Could not find Borg binary"

# User might specify some additional options in Borg.
local borg_additional_options=()

is_true "$BORGBACKUP_INIT_MAKE_PARENT_DIRS" && borg_additional_options+=( --make-parent-dirs )

# Query Borg server for repository information
# and store it to BORGBACKUP_ARCHIVE_CACHE.
# This should avoid repeatingly quering Borg server, which could be slow.
borg_archive_cache_create
rc=$?

# Check Borg return code of `borg list`.
# See https://borgbackup.readthedocs.io/en/stable/usage/general.html#return-codes
#
# If $rc == 0 we have a repository present, maybe it is empty.
# Borg returns $rc == 2 in case of fatal error like local or remote exceptions.
# This might be a Borg connection / mount error or a missing repository.
#
# If Borg reports `Repository doesn't exist`, we try to create it.
# `borg init` has to be triggered in "prep" stage, if user decides to include
# keyfiles to Relax-and-Recover rescue/recovery system using COPY_AS_IS_BORG.
if [ $rc -ne 0 ]; then
    LogPrint "Couldn't list Borg repository '$BORGBACKUP_REPO' on ${BORGBACKUP_HOST:-USB}"

    if [ -e "$BORGBACKUP_STDERR_FILE" ]; then
        if grep --quiet 'Failed to create/acquire the lock' "$BORGBACKUP_STDERR_FILE"; then
            LogPrint "Borg: $( cat "$BORGBACKUP_STDERR_FILE" )"
            Error "Borg failed to create/acquire the lock, borg rc $rc!"
        fi

        if grep --quiet 'Repository' "$BORGBACKUP_STDERR_FILE" \
            && grep --quiet 'does not exist' "$BORGBACKUP_STDERR_FILE"; then
            LogPrint "Borg: $( cat "$BORGBACKUP_STDERR_FILE" )"
            LogPrint "Hence initializing new Borg repository '$BORGBACKUP_REPO' on ${BORGBACKUP_HOST:-USB}"

            # Has to be $verbose, not "$verbose", since it's used as option.
            # shellcheck disable=SC2086
            borg init $verbose "${borg_additional_options[@]}" \
            "${BORGBACKUP_OPT_ENCRYPTION[@]}" "${BORGBACKUP_OPT_REMOTE_PATH[@]}" \
            "${BORGBACKUP_OPT_UMASK[@]}" "${borg_dst_dev}${BORGBACKUP_REPO}" \
            2> "$BORGBACKUP_STDERR_FILE"
            rc=$?
        fi
    fi
fi

# Borg repository initialization failed in previous step
# or there was still another error from `borg list` before.
# Nevertheless backup abort is inevitable.
if [ $rc -ne 0 ]; then
    LogPrint "Borg: $( cat "$BORGBACKUP_STDERR_FILE" )"
    Error "Failed to initialize Borg repository, borg rc $rc!"
fi

LogPrint 'Successfully initialized Borg repository.'
