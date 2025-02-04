# prep/NETFS/default/040_inspect_configuration_files.sh
# Purpose of this script is to inspect configuration items which may change over time
# such as the BACKUP_PROG_OPTIONS variable that becomes an array in rear-2.3

# If the user defines in local.conf for example: BACKUP_PROG_OPTIONS="--option1 --option2" then you will see 
# the following error message to turn your local setting into an array
[[ ${#BACKUP_PROG_OPTIONS[@]} -eq 1 && "$BACKUP_PROG_OPTIONS" == *\ * ]] && \
Error "The BACKUP_PROG_OPTIONS variable is now a Bash array and not a string. Please update your configuration to look like this:${IFS}BACKUP_PROG_OPTIONS+=( $BACKUP_PROG_OPTIONS )"

# We can add other checks below (in the future)

# Return successfully when there was no Error() above
return 0
