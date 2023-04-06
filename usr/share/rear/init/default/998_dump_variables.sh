
# Output all variable values into the log file
# which may also output possibly confidential values 
# so do this only in debugscript mode where the 'set -x' output
# in general already reveals possibly confidential information:
test "$DEBUGSCRIPTS" || return 0

# For now disable this script until https://github.com/rear/rear/issues/2967 is solved.
# Users who need this script can disable the next two lines:
DebugPrint "Skipped init/default/998_dump_variables.sh for legal liability worries, see https://github.com/rear/rear/issues/2967"
return 1

# Suppress output that contains 'pass' or 'key' or 'crypt' (ignore case) to skip output
# e.g. for BACKUP_PROG_CRYPT_KEY or SSH_ROOT_PASSWORD or LUKS_CRYPTSETUP_OPTIONS
# cf. https://github.com/rear/rear/issues/2967
Debug "Runtime Configuration (except what contains 'pass' or 'key' or 'crypt'):$LF$( declare -p | egrep -vi 'pass|key|crypt' )"
