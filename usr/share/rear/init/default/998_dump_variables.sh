
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# To help with debugging dump all currently existing variable values into the log file.
#
# Because this will also output possibly confidential values into the log file
# (like passwords, encryption keys, authentication tokens, ...)
# this happens only if rear is run by the user with the 'expose-secrets' option
# see https://github.com/rear/rear/issues/2967

# 'declare -p' is a secret command so '$( declare -p )' is also a secret command
# because 'set -x' prints the result of $( declare -p ) as part of the LogSecret argument:
if { LogSecret "Runtime Configuration:$LF$( declare -p )" ; } 2>>/dev/$SECRET_OUTPUT_DEV ; then
    # Show the log file name here in any case because sbin/rear shows "Using log file ..." only in verbose mode:
    LogUserOutput "Dumped all variable values (including possibly confidential values) into $RUNTIME_LOGFILE"
else
    Debug "Skipped dumping all variable values into the log file (use 'expose-secrets' for that)"
fi
