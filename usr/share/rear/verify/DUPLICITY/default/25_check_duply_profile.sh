# This file is part of Relax and Recover, licensed under the GNU General
# Public License. Refer to the included LICENSE for full text of license.

[[ -z "$DUPLY_PROFILE" ]] && return

duply "$DUPLY_PROFILE" status >&2   # output is going to logfile
LogPrintIfError "Duply profile $DUPLY_PROFILE status returned errors - see $LOGFILE"
