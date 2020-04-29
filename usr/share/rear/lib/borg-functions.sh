# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# borg-functions.sh

function borg_set_vars {
    # Construct Borg arguments for archive pruning.
    # No need to check config values of $BORG_PRUNE* family
    # Borg will bail out with error if values are wrong.
    BORGBACKUP_OPT_PRUNE=()
    if [ ! -z $BORGBACKUP_PRUNE_WITHIN ]; then
        BORGBACKUP_OPT_PRUNE+=("--keep-within=$BORGBACKUP_PRUNE_WITHIN ")
    fi
    if [ ! -z $BORGBACKUP_PRUNE_LAST ]; then
        BORGBACKUP_OPT_PRUNE+=("--keep-last=$BORGBACKUP_PRUNE_LAST ")
    fi
    if [ ! -z $BORGBACKUP_PRUNE_HOURLY ]; then
        BORGBACKUP_OPT_PRUNE+=("--keep-hourly=$BORGBACKUP_PRUNE_HOURLY ")
    fi
    if [ ! -z $BORGBACKUP_PRUNE_DAILY ]; then
        BORGBACKUP_OPT_PRUNE+=("--keep-daily=$BORGBACKUP_PRUNE_DAILY ")
    fi
    if [ ! -z $BORGBACKUP_PRUNE_WEEKLY ]; then
        BORGBACKUP_OPT_PRUNE+=("--keep-weekly=$BORGBACKUP_PRUNE_WEEKLY ")
    fi
    if [ ! -z $BORGBACKUP_PRUNE_MONTHLY ]; then
        BORGBACKUP_OPT_PRUNE+=("--keep-monthly=$BORGBACKUP_PRUNE_MONTHLY ")
    fi
    if [ ! -z $BORGBACKUP_PRUNE_YEARLY ]; then
        BORGBACKUP_OPT_PRUNE+=("--keep-yearly=$BORGBACKUP_PRUNE_YEARLY ")
    fi

    # Prepare option for Borg compression.
    # Empty BORGBACKUP_COMPRESSION will default to "none" compression.
    BORGBACKUP_OPT_COMPRESSION=""
    if [ ! -z $BORGBACKUP_COMPRESSION ]; then
        BORGBACKUP_OPT_COMPRESSION="--compression $BORGBACKUP_COMPRESSION"
    fi

    # Prepare option for Borg encryption.
    # Empty BORGBACKUP_ENC_TYPE will default to "repokey".
    BORGBACKUP_OPT_ENCRYPTION=""
    if [ ! -z $BORGBACKUP_ENC_TYPE ]; then
        BORGBACKUP_OPT_ENCRYPTION="--encryption $BORGBACKUP_ENC_TYPE"
    fi

    # Prepare option for Borg remote-path.
    # Empty BORGBACKUP_REMOTE_PATH will default to "borg".
    BORGBACKUP_OPT_REMOTE_PATH=""
    if [ ! -z $BORGBACKUP_REMOTE_PATH ]; then
        BORGBACKUP_OPT_REMOTE_PATH="--remote-path $BORGBACKUP_REMOTE_PATH"
    fi

    # Prepare option for Borg umask.
    # Empty BORGBACKUP_UMASK will default to 0077.
    BORGBACKUP_OPT_UMASK=""
    if [ ! -z $BORGBACKUP_UMASK ]; then
        BORGBACKUP_OPT_UMASK="--umask $BORGBACKUP_UMASK"
    fi

    # Set archive cache file
    BORGBACKUP_ARCHIVE_CACHE=$TMP_DIR/borg_archive

    # Set file to save borg stderr output
    BORGBACKUP_STDERR_FILE=$TMP_DIR/borg_stderr
}

function borg_list
{
    borg list $BORGBACKUP_OPT_REMOTE_PATH ${borg_dst_dev}${BORGBACKUP_REPO} \
    2> $BORGBACKUP_STDERR_FILE
}

# Query Borg server for repository information
# and store it to BORGBACKUP_ARCHIVE_CACHE.
# This avoids repeatedly querying Borg repository, which could be slow.
function borg_archive_cache_create
{
    borg_list > $BORGBACKUP_ARCHIVE_CACHE
}

function borg_create
{
    LogPrint "Creating backup archive \
'${BORGBACKUP_ARCHIVE_PREFIX}_$BORGBACKUP_SUFFIX' \
in Borg repository $BORGBACKUP_REPO on ${BORGBACKUP_HOST:-USB}"

    borg create $verbose --one-file-system $borg_additional_options \
    $BORGBACKUP_OPT_COMPRESSION $BORGBACKUP_OPT_REMOTE_PATH \
    $BORGBACKUP_OPT_UMASK --exclude-from $TMP_DIR/backup-exclude.txt \
    ${borg_dst_dev}${BORGBACKUP_REPO}::${BORGBACKUP_ARCHIVE_PREFIX}_$BORGBACKUP_SUFFIX \
    ${include_list[@]}
}
