# This file is part of Relax and Recover, licensed under the GNU General
# Public License. Refer to the included LICENSE for full text of license.

if has_binary duply; then
    # we found the duply program; check if a profile was defined
    [[ -z "$DUPLY_PROFILE" ]] && return

    # a real profile was detected - check if we can talk to the remote site
    duply "$DUPLY_PROFILE" backup >&2   # output is going to logfile
    StopIfError "Duply profile $DUPLY_PROFILE backup returned errors - see $LOGFILE"

    LogPrint "The last full backup taken with duply/duplicity was:"
    LogPrint "$( tail -10 $LOGFILE | grep Full )"
fi

