# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 30_prune_old_backups.sh

prune_opts=()

# Construct Borg arguments for archive purging
# No need to check config values of $BORG_PRUNE* family
# Borg will boil out with error if values are wrong
if [ ! -z $BORG_PRUNE_HOURLY ]; then
    prune_opts+=("--keep-hourly=$BORG_PRUNE_HOURLY ")
fi

if [ ! -z $BORG_PRUNE_DAILY ]; then
    prune_opts+=("--keep-daily=$BORG_PRUNE_DAILY ")
fi

if [ ! -z $BORG_PRUNE_WEEKLY ]; then
    prune_opts+=("--keep-weekly=$BORG_PRUNE_WEEKLY ")
fi

if [ ! -z $BORG_PRUNE_MONTHLY ]; then
    prune_opts+=("--keep-monthly=$BORG_PRUNE_MONTHLY ")
fi

if [ ! -z $BORG_PRUNE_YEARLY ]; then
    prune_opts+=("--keep-yearly=$BORG_PRUNE_YEARLY ")
fi

if [ ! -z $prune_opts ]; then
    # Purge old archives according user settings
    Log "Purging old Borg archives in repository $BORG_REPO"
    borg prune -v --list ${prune_opts[@]} $BORG_USERNAME@$BORG_HOST:$BORG_REPO
    StopIfError "Failed to purge old backups"
else
    # Purge is not set
    Log "Purgining of old Borg archives not set, skipping"
fi
