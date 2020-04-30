# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 800_prune_old_backups.sh

# User might specify some additional output options in Borg.
# Output shown by Borg is not controlled by `rear --verbose` nor `rear --debug`
# only, if BORGBACKUP_SHOW_PROGRESS is true.
local borg_additional_options=''

BORGBACKUP_PRUNE_SHOW_PROGRESS=${BORGBACKUP_PRUNE_SHOW_PROGRESS:-$BORGBACKUP_SHOW_PROGRESS}
BORGBACKUP_PRUNE_SHOW_STATS=${BORGBACKUP_PRUNE_SHOW_STATS:-$BORGBACKUP_SHOW_STATS}
BORGBACKUP_PRUNE_SHOW_LIST=${BORGBACKUP_PRUNE_SHOW_LIST:-$BORGBACKUP_SHOW_LIST}
BORGBACKUP_PRUNE_SHOW_RC=${BORGBACKUP_PRUNE_SHOW_RC:-$BORGBACKUP_SHOW_RC}

is_true $BORGBACKUP_PRUNE_SHOW_PROGRESS && borg_additional_options+='--progress '
is_true $BORGBACKUP_PRUNE_SHOW_STATS && borg_additional_options+='--stats '
is_true $BORGBACKUP_PRUNE_SHOW_LIST && borg_additional_options+='--list '
is_true $BORGBACKUP_PRUNE_SHOW_RC && borg_additional_options+='--show-rc '

# https://github.com/rear/rear/pull/2382#issuecomment-621707505
# Depending on BORGBACKUP_SHOW_PROGRESS and VERBOSE variables
# 3 cases are there for `borg_prune` to log to rear log file or not.
#
# 1. BORGBACKUP_SHOW_PROGRESS true:
#    No logging to rear log file because of control characters.
#
# 2. VERBOSE true:
#    stderr (2) is copied to real stderr (8):
#    2 is going to rear logfile
#    8 is shown because of VERBOSE true
#
# 3. Third case:
#    stderr (2) is untouched, hence only going to rear logfile.

if [ ! -z $BORGBACKUP_OPT_PRUNE ]; then
    # Prune old backup archives according to user settings.
    if is_true $BORGBACKUP_PRUNE_SHOW_PROGRESS; then
        borg_prune 0<&6 1>&7 2>&8
    elif is_true $VERBOSE; then
        borg_prune 0<&6 1>> >( tee -a $RUNTIME_LOGFILE 1>&7 ) 2>> >( tee -a $RUNTIME_LOGFILE 1>&8 )
    else
        borg_prune 0<&6
    fi

    StopIfError "Borg failed to prune old backup archives, borg rc $?!"
else
    # Pruning is not set.
    Log "Pruning of old backup archives is not set, skipping."
fi
