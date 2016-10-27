# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# borg-functions.sh

function borg_set_vars {
    # Construct Borg arguments for archive pruning.
    # No need to check config values of $BORG_PRUNE* family
    # Borg will bail out with error if values are wrong.
    BORGBACKUP_OPT_PRUNE=()
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

    # Prepare for export of pass-phrase, when Borg repository is encrypted
    if [ ! -z $BORGBACKUP_PASSPHRASE ]; then
        export BORG_PASSPHRASE=$BORGBACKUP_PASSPHRASE
    fi

    # Custom directory for keeping repository encryption keys
    if [ ! -z $BORGBACKUP_KEYS_DIR ]; then
        export BORG_KEYS_DIR=$BORGBACKUP_KEYS_DIR
    fi

    # Custom Borg cache directory
    if [ ! -z $BORGBACKUP_CACHE_DIR ]; then
        export BORG_CACHE_DIR=$BORGBACKUP_CACHE_DIR
    fi

    # Custom value for confirmation of repository relocation dialog
    if [ ! -z $BORGBACKUP_RELOCATED_REPO_ACCESS_IS_OK ]; then
        export BORG_RELOCATED_REPO_ACCESS_IS_OK=$BORGBACKUP_RELOCATED_REPO_ACCESS_IS_OK
    fi

    # Custom value for confirmation of unencrypted repository access dialog
    if [ ! -z $BORGBACKUP_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK ]; then
        export BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=$BORGBACKUP_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK
    fi

    # Set archive cache file
    BORGBACKUP_ARCHIVE_CACHE=$TMP_DIR/borg_archive
}

# Query Borg server for repository information
# and store it to BORGBACKUP_ARCHIVE_CACHE.
# This should avoid repeatingly quering Borg server, which could be slow.
function borg_archive_cache_create {
    borg list $BORGBACKUP_OPT_REMOTE_PATH \
$BORGBACKUP_USERNAME@$BORGBACKUP_HOST:$BORGBACKUP_REPO \
2> /dev/null > $BORGBACKUP_ARCHIVE_CACHE
}
