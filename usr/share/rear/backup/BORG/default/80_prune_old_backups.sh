# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 30_prune_old_backups.sh

prune_opts=()

# Construct Borg arguments for archive pruning.
# No need to check config values of $BORG_PRUNE* family
# Borg will bail out with error if values are wrong.
if [ ! -z $BORGBACKUP_PRUNE_HOURLY ]; then
    prune_opts+=("--keep-hourly=$BORGBACKUP_PRUNE_HOURLY ")
fi

if [ ! -z $BORGBACKUP_PRUNE_DAILY ]; then
    prune_opts+=("--keep-daily=$BORGBACKUP_PRUNE_DAILY ")
fi

if [ ! -z $BORGBACKUP_PRUNE_WEEKLY ]; then
    prune_opts+=("--keep-weekly=$BORGBACKUP_PRUNE_WEEKLY ")
fi

if [ ! -z $BORGBACKUP_PRUNE_MONTHLY ]; then
    prune_opts+=("--keep-monthly=$BORGBACKUP_PRUNE_MONTHLY ")
fi

if [ ! -z $BORGBACKUP_PRUNE_YEARLY ]; then
    prune_opts+=("--keep-yearly=$BORGBACKUP_PRUNE_YEARLY ")
fi

if [ ! -z $prune_opts ]; then
    # Purge old archives according user settings.
    Log "Purging old Borg archives in repository $BORGBACKUP_REPO"
    borg prune -v --list ${prune_opts[@]} \
    $BORGBACKUP_USERNAME@$BORGBACKUP_HOST:$BORGBACKUP_REPO
    StopIfError "Failed to purge old backups"
else
    # Purge is not set.
    Log "Purging of old Borg archives not set, skipping"
fi
