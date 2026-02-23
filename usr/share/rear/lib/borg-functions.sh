# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# borg-functions.sh

function borg_set_vars {
    # Construct Borg arguments for archive pruning.
    # No need to check config values of $BORG_PRUNE* family
    # Borg will bail out with error if values are wrong.
    BORGBACKUP_OPT_PRUNE=()
    if [[ -n $BORGBACKUP_PRUNE_KEEP_WITHIN ]]; then
        BORGBACKUP_OPT_PRUNE+=( --keep-within "$BORGBACKUP_PRUNE_KEEP_WITHIN" )
    elif [[ -n $BORGBACKUP_PRUNE_WITHIN ]]; then
        LogPrint "BORGBACKUP_PRUNE_WITHIN is deprecated, use BORGBACKUP_PRUNE_KEEP_WITHIN instead!"
        BORGBACKUP_OPT_PRUNE+=( --keep-within "$BORGBACKUP_PRUNE_WITHIN" )
    fi
    if [[ -n $BORGBACKUP_PRUNE_KEEP_LAST ]]; then
        BORGBACKUP_OPT_PRUNE+=( --keep-last "$BORGBACKUP_PRUNE_KEEP_LAST" )
    elif [[ -n $BORGBACKUP_PRUNE_LAST ]]; then
        LogPrint "BORGBACKUP_PRUNE_LAST is deprecated, use BORGBACKUP_PRUNE_KEEP_LAST instead!"
        BORGBACKUP_OPT_PRUNE+=( --keep-last "$BORGBACKUP_PRUNE_LAST" )
    fi
    if [[ -n $BORGBACKUP_PRUNE_KEEP_MINUTELY ]]; then
        BORGBACKUP_OPT_PRUNE+=( --keep-minutely "$BORGBACKUP_PRUNE_KEEP_MINUTELY" )
    elif [[ -n $BORGBACKUP_PRUNE_MINUTELY ]]; then
        LogPrint "BORGBACKUP_PRUNE_MINUTELY is deprecated, use BORGBACKUP_PRUNE_KEEP_MINUTELY instead!"
        BORGBACKUP_OPT_PRUNE+=( --keep-minutely "$BORGBACKUP_PRUNE_MINUTELY" )
    fi
    if [[ -n $BORGBACKUP_PRUNE_KEEP_HOURLY ]]; then
        BORGBACKUP_OPT_PRUNE+=( --keep-hourly "$BORGBACKUP_PRUNE_KEEP_HOURLY" )
    elif [[ -n $BORGBACKUP_PRUNE_HOURLY ]]; then
        LogPrint "BORGBACKUP_PRUNE_HOURLY is deprecated, use BORGBACKUP_PRUNE_KEEP_HOURLY instead!"
        BORGBACKUP_OPT_PRUNE+=( --keep-hourly "$BORGBACKUP_PRUNE_HOURLY" )
    fi
    if [[ -n $BORGBACKUP_PRUNE_KEEP_DAILY ]]; then
        BORGBACKUP_OPT_PRUNE+=( --keep-daily "$BORGBACKUP_PRUNE_KEEP_DAILY" )
    elif [[ -n $BORGBACKUP_PRUNE_DAILY ]]; then
        LogPrint "BORGBACKUP_PRUNE_DAILY is deprecated, use BORGBACKUP_PRUNE_KEEP_DAILY instead!"
        BORGBACKUP_OPT_PRUNE+=( --keep-daily "$BORGBACKUP_PRUNE_DAILY" )
    fi
    if [[ -n $BORGBACKUP_PRUNE_KEEP_WEEKLY ]]; then
        BORGBACKUP_OPT_PRUNE+=( --keep-weekly "$BORGBACKUP_PRUNE_KEEP_WEEKLY" )
    elif [[ -n $BORGBACKUP_PRUNE_WEEKLY ]]; then
        LogPrint "BORGBACKUP_PRUNE_WEEKLY is deprecated, use BORGBACKUP_PRUNE_KEEP_WEEKLY instead!"
        BORGBACKUP_OPT_PRUNE+=( --keep-weekly "$BORGBACKUP_PRUNE_WEEKLY" )
    fi
    if [[ -n $BORGBACKUP_PRUNE_KEEP_MONTHLY ]]; then
        BORGBACKUP_OPT_PRUNE+=( --keep-monthly "$BORGBACKUP_PRUNE_KEEP_MONTHLY" )
    elif [[ -n $BORGBACKUP_PRUNE_MONTHLY ]]; then
        LogPrint "BORGBACKUP_PRUNE_MONTHLY is deprecated, use BORGBACKUP_PRUNE_KEEP_MONTHLY instead!"
        BORGBACKUP_OPT_PRUNE+=( --keep-monthly "$BORGBACKUP_PRUNE_MONTHLY" )
    fi
    if [[ -n $BORGBACKUP_PRUNE_KEEP_YEARLY ]]; then
        BORGBACKUP_OPT_PRUNE+=( --keep-yearly "$BORGBACKUP_PRUNE_KEEP_YEARLY" )
    elif [[ -n $BORGBACKUP_PRUNE_YEARLY ]]; then
        LogPrint "BORGBACKUP_PRUNE_YEARLY is deprecated, use BORGBACKUP_PRUNE_KEEP_YEARLY instead!"
        BORGBACKUP_OPT_PRUNE+=( --keep-yearly "$BORGBACKUP_PRUNE_YEARLY" )
    fi

    # Prepare option for Borg compression.
    # Empty BORGBACKUP_COMPRESSION will default to "none" compression.
    BORGBACKUP_OPT_COMPRESSION=()
    if [[ -n $BORGBACKUP_COMPRESSION ]]; then
        BORGBACKUP_OPT_COMPRESSION=( --compression "$BORGBACKUP_COMPRESSION" )
    fi

    # Prepare option for Borg encryption.
    # Empty BORGBACKUP_ENC_TYPE will default to "repokey".
    BORGBACKUP_OPT_ENCRYPTION=()
    if [[ -n $BORGBACKUP_ENC_TYPE ]]; then
        # shellcheck disable=SC2034
        BORGBACKUP_OPT_ENCRYPTION=( --encryption "$BORGBACKUP_ENC_TYPE" )
    fi

    # Prepare option for Borg remote-path.
    # Empty BORGBACKUP_REMOTE_PATH will default to "borg".
    BORGBACKUP_OPT_REMOTE_PATH=()
    if [[ -n $BORGBACKUP_REMOTE_PATH ]]; then
        BORGBACKUP_OPT_REMOTE_PATH=( --remote-path "$BORGBACKUP_REMOTE_PATH" )
    fi

    # Prepare option for Borg umask.
    # Empty BORGBACKUP_UMASK will default to 0077.
    BORGBACKUP_OPT_UMASK=()
    if [[ -n $BORGBACKUP_UMASK ]]; then
        BORGBACKUP_OPT_UMASK=( --umask "$BORGBACKUP_UMASK" )
    fi

    # Set archive cache file
    BORGBACKUP_ARCHIVE_CACHE=$TMP_DIR/borg_archive

    # Set file to save borg stderr output
    BORGBACKUP_STDERR_FILE=$TMP_DIR/borg_stderr

    BORGBACKUP_RESTORE_ARCHIVES_SHOW_MAX=${BORGBACKUP_RESTORE_ARCHIVES_SHOW_MAX:-10}

    [[ $BORGBACKUP_RESTORE_ARCHIVES_SHOW_MAX -ge 0 ]] \
        || Error "BORGBACKUP_RESTORE_ARCHIVES_SHOW_MAX '$BORGBACKUP_RESTORE_ARCHIVES_SHOW_MAX' must be >= 0"
}

function borg_list
{
    # shellcheck disable=SC2154
    borg list "${BORGBACKUP_OPT_REMOTE_PATH[@]}" "${borg_dst_dev}${BORGBACKUP_REPO}" \
    2> "$BORGBACKUP_STDERR_FILE"
}

# Query Borg server for repository information
# and store it to BORGBACKUP_ARCHIVE_CACHE.
# This avoids repeatedly querying Borg repository, which could be slow.
function borg_archive_cache_create
{
    borg_list > "$BORGBACKUP_ARCHIVE_CACHE"
}

function borg_create
{
    LogPrint "Creating backup archive \
'${BORGBACKUP_ARCHIVE_PREFIX}_$BORGBACKUP_SUFFIX' \
in Borg repository $BORGBACKUP_REPO on ${BORGBACKUP_HOST:-USB}"

    # Has to be $verbose, not "$verbose", since it's used as option.
    # shellcheck disable=SC2086,SC2154
    borg create $verbose --one-file-system "${borg_additional_options[@]}" \
    "${BORGBACKUP_OPT_COMPRESSION[@]}" "${BORGBACKUP_OPT_REMOTE_PATH[@]}" \
    "${BORGBACKUP_OPT_UMASK[@]}" --exclude-from "$TMP_DIR/backup-exclude.txt" \
    "${borg_dst_dev}${BORGBACKUP_REPO}::${BORGBACKUP_ARCHIVE_PREFIX}_$BORGBACKUP_SUFFIX" \
    "${include_list[@]}"
}

function borg_prune
{
    LogPrint "Pruning old backup archives in Borg repository $BORGBACKUP_REPO \
on ${BORGBACKUP_HOST:-USB}"

    # Has to be $verbose, not "$verbose", since it's used as option.
    # shellcheck disable=SC2086
    borg prune $verbose "${borg_additional_options[@]}" "${BORGBACKUP_OPT_PRUNE[@]}" \
    "${BORGBACKUP_OPT_REMOTE_PATH[@]}" "${BORGBACKUP_OPT_UMASK[@]}" \
    --glob-archives "${BORGBACKUP_ARCHIVE_PREFIX}_*" \
    "${borg_dst_dev}${BORGBACKUP_REPO}"
}

function borg_extract
{
    # Scope of LC_ALL is only within run of `borg extract'.
    # This avoids Borg problems with restoring UTF-8 encoded files names in archive
    # and should not interfere with remaining stages of rear recover.
    # This is still not the ideal solution, but best I can think of so far :-/.

    LogPrint "Recovering from backup archive $BORGBACKUP_REPO::$BORGBACKUP_ARCHIVE \
on ${BORGBACKUP_HOST:-USB}"

    # Has to be $verbose, not "$verbose", since it's used as option.
    # shellcheck disable=SC2086
    LC_ALL=en_US.UTF-8 \
    borg extract $verbose --sparse "${borg_additional_options[@]}" \
    "${BORGBACKUP_OPT_REMOTE_PATH[@]}" \
    "${borg_dst_dev}${BORGBACKUP_REPO}::$BORGBACKUP_ARCHIVE"
}
