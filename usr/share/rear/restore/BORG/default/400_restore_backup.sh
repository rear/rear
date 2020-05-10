# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 400_restore_backup.sh

# Borg restores to cwd.
# Switch current working directory or die.
pushd "$TARGET_FS_ROOT" >/dev/null \
    || Error "Could not change directory to $TARGET_FS_ROOT!"

# User might specify some additional output options in Borg.
# Output shown by Borg is not controlled by `rear --verbose' nor `rear --debug'
# only, if BORGBACKUP_SHOW_PROGRESS is true.

# shellcheck disable=SC2168
local borg_additional_options=()

BORGBACKUP_EXTRACT_SHOW_PROGRESS=${BORGBACKUP_EXTRACT_SHOW_PROGRESS:-$BORGBACKUP_SHOW_PROGRESS}
BORGBACKUP_EXTRACT_SHOW_LIST=${BORGBACKUP_EXTRACT_SHOW_LIST:-$BORGBACKUP_SHOW_LIST}
BORGBACKUP_EXTRACT_SHOW_RC=${BORGBACKUP_EXTRACT_SHOW_RC:-$BORGBACKUP_SHOW_RC}

is_true "$BORGBACKUP_EXTRACT_SHOW_PROGRESS" && borg_additional_options+=( --progress )
is_true "$BORGBACKUP_EXTRACT_SHOW_LIST" && borg_additional_options+=( --list )
is_true "$BORGBACKUP_EXTRACT_SHOW_RC" && borg_additional_options+=( --show-rc )

# Borg writes all log output to stderr by default.
# See https://borgbackup.readthedocs.io/en/stable/usage/general.html#logging
#
# If we want to have the Borg log output appearing in the rear logfile, we
# don't have to do anything, since Borg writes all log output to stderr and
# that is what rear is saving in the rear logfile.
#
# If `--progress` is used for `borg extract` we don't want the Borg log output
# in the rear logfile, since it contains control sequences. If not used, we
# want the Borg output in the rear logfile. The amount of log output written by
# Borg is determined by other options above e.g. by `--stats` or `--list`.

# https://github.com/rear/rear/pull/2382#issuecomment-621707505
# Depending on BORGBACKUP_SHOW_PROGRESS and VERBOSE variables
# 3 cases are there for `borg_extract` to log to rear logfile or not.
#
# 1. BORGBACKUP_SHOW_PROGRESS true:
#    No logging to rear logfile because of control characters.
#
# 2. VERBOSE true:
#    stdout (1) is going to rear logfile and copied to real stdout (7).
#    stderr (2) is going to rear logfile and copied to real stderr (8).
#
# 3. Third case:
#    stdout (1) and stderr (2) are untouched, hence only going to rear logfile.

# Start actual restore.
if is_true "$BORGBACKUP_EXTRACT_SHOW_PROGRESS"; then
    borg_extract 0<&6 1>&7 2>&8
elif is_true "$VERBOSE"; then
    borg_extract 0<&6 1>> >( tee -a "$RUNTIME_LOGFILE" 1>&7 ) 2>> >( tee -a "$RUNTIME_LOGFILE" 1>&8 )
else
    borg_extract 0<&6
fi

LogPrintIfError "Borg reported error during restore, borg rc $?!"
LogPrint 'Borg OS restore finished successfully.'
popd >/dev/null \
    || Error "Could not change back directory from $TARGET_FS_ROOT!"
