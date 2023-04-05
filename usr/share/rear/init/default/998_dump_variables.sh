
# Output all variable values into the log file
# which may also output possibly confidential values 
# so do this only in debugscripts mode where the 'set -x' output
# in general already reveals possibly confidential information:
test "$DEBUGSCRIPTS" || return 0

# Suppress output that contains 'pass' or 'key' or 'crypt' (ignore case) to skip output
# e.g. for BACKUP_PROG_CRYPT_KEY or SSH_ROOT_PASSWORD or  LUKS_CRYPTSETUP_OPTIONS
# cf. https://github.com/rear/rear/issues/2967
Debug "Runtime Configuration:$LF$( declare -p | egrep -vi 'pass|key|crypt' )"
