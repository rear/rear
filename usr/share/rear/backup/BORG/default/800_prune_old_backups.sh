# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 800_prune_old_backups.sh

# User might specify some additional output options in Borg.
local borg_additional_options=''

is_true $BORGBACKUP_SHOW_PROGRESS && borg_additional_options+='--progress '
is_true $BORGBACKUP_SHOW_STATS && borg_additional_options+='--stats '
is_true $BORGBACKUP_SHOW_LIST && borg_additional_options+='--list '
is_true $BORGBACKUP_SHOW_RC && borg_additional_options+='--show-rc '

if [ ! -z $BORGBACKUP_OPT_PRUNE ]; then
    # Purge old archives according user settings.
    LogPrint "Purging old Borg archives in repository $BORGBACKUP_REPO"
    borg prune $verbose $borg_additional_options ${BORGBACKUP_OPT_PRUNE[@]} \
    $BORGBACKUP_OPT_REMOTE_PATH $BORGBACKUP_OPT_UMASK \
    --prefix ${BORGBACKUP_ARCHIVE_PREFIX}_ \
    ${borg_dst_dev}${BORGBACKUP_REPO}

    StopIfError "Failed to purge old backups"
else
    # Purge is not set.
    Log "Purging of old Borg archives not set, skipping"
fi
