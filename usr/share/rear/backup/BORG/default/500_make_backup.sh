# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 500_make_backup.sh

# shellcheck disable=SC2168
local include_list=()

# Check if backup-include.txt (created by 400_create_include_exclude_files.sh),
# really exists.
if [ ! -r "$TMP_DIR/backup-include.txt" ]; then
    Error "Can't find include list"
fi

function check_BORG_create_return_code() {

    borg_create_exit_code=$1

    # 'borg_create' function returns one of the following codes:
    #   0     success
    #   1     warning (operation reached its normal end, but there were warnings)
    #   2     error (like a fatal error)
    #   128+N killed by signal
    # They corresponde to the borg return codes:
    # https://borgbackup.readthedocs.io/en/stable/usage/general.html#return-codes
    #
    # Warning (rc=1) can happen if a file changed while backing it up.
    # $BORGBACKUP_IGNORE_WARNING="yes" makes rear ignoring warnings (rc=1).
    if test "$BORGBACKUP_IGNORE_WARNING" = "yes" && test $borg_create_exit_code -eq 1; then
        LogUserOutput "[BORG rc=1] borg create backup operation completed with at least one warning message that was ignored (see rear log file)"
        return 0
    fi

    if test $borg_create_exit_code -eq 0; then
        LogUserOutput "[BORG] borg create operation completed successfully"
    else
        LogUserOutput "[BORG] borg create operation completed with 'borg create' exit code $borg_create_exit_code"
        test $borg_create_exit_code -eq 1 && LogUserOutput "[BORG rc=1] borg create backup operation completed with at least one warning message"
        test $borg_create_exit_code -eq 2 && LogUserOutput "[BORG rc=2] borg create backup operation completed with at least one error message"
        test $borg_create_exit_code -ge 128 && LogUserOutput "[BORG rc=$borg_create_exit_code] borg create backup operation was killed by signal"
        return $borg_create_exit_code
    fi
}

# Create Borg friendly include list.
while IFS= read -r include; do
    include_list+=( "$include" )
done < "$TMP_DIR/backup-include.txt"

# User might specify some additional output options in Borg.
# Output shown by Borg is not controlled by `rear --verbose' nor `rear --debug'
# only, if BORGBACKUP_SHOW_PROGRESS is true.

# shellcheck disable=SC2168
local borg_additional_options=()

BORGBACKUP_CREATE_SHOW_PROGRESS=${BORGBACKUP_CREATE_SHOW_PROGRESS:-$BORGBACKUP_SHOW_PROGRESS}
BORGBACKUP_CREATE_SHOW_STATS=${BORGBACKUP_CREATE_SHOW_STATS:-$BORGBACKUP_SHOW_STATS}
BORGBACKUP_CREATE_SHOW_LIST=${BORGBACKUP_CREATE_SHOW_LIST:-$BORGBACKUP_SHOW_LIST}
BORGBACKUP_CREATE_SHOW_RC=${BORGBACKUP_CREATE_SHOW_RC:-$BORGBACKUP_SHOW_RC}

is_true "$BORGBACKUP_CREATE_SHOW_PROGRESS" && borg_additional_options+=( --progress )
is_true "$BORGBACKUP_CREATE_SHOW_STATS" && borg_additional_options+=( --stats )
is_true "$BORGBACKUP_CREATE_SHOW_LIST" && borg_additional_options+=( --list --filter AME )
is_true "$BORGBACKUP_CREATE_SHOW_RC" && borg_additional_options+=( --show-rc )
is_true "$BORGBACKUP_EXCLUDE_CACHES" && borg_additional_options+=( --exclude-caches )
is_true "$BORGBACKUP_EXCLUDE_IF_NOBACKUP" && borg_additional_options+=( --exclude-if-present .nobackup )
[[ -n $BORGBACKUP_TIMESTAMP ]] && borg_additional_options+=( --timestamp "$BORGBACKUP_TIMESTAMP" )

# Borg writes all log output to stderr by default.
# See https://borgbackup.readthedocs.io/en/stable/usage/general.html#logging
#
# If we want to have the Borg log output appearing in the rear logfile, we
# don't have to do anything, since Borg writes all log output to stderr and
# that is what rear is saving in the rear logfile.
#
# If `--progress` is used for `borg create` we don't want the Borg log output
# in the rear logfile, since it contains control sequences. If not used, we
# want the Borg output in the rear logfile. The amount of log output written by
# Borg is determined by other options above e.g. by `--stats` or
# `--list --filter=AME`.

# https://github.com/rear/rear/pull/2382#issuecomment-621707505
# Depending on BORGBACKUP_SHOW_PROGRESS and VERBOSE variables
# 3 cases are there for `borg_create` to log to rear logfile or not.
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

# Start actual Borg backup.
if is_true "$BORGBACKUP_CREATE_SHOW_PROGRESS"; then
    borg_create 0<&6 1>&7 2>&8
elif is_true "$VERBOSE"; then
    borg_create 0<&6 1>> >( tee -a "$RUNTIME_LOGFILE" 1>&7 ) 2>> >( tee -a "$RUNTIME_LOGFILE" 1>&8 )
else
    borg_create 0<&6
fi
borg_exit_code=$?

check_BORG_create_return_code $borg_exit_code
StopIfError "Borg failed to create backup archive, borg rc $?!"
