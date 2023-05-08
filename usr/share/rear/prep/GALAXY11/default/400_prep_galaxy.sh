#
# prepare stuff for Commvault 11
#

function set_variable_from_commvault_status {
	(( $# == 2 )) || BugError "set_variable_from_commvault_status not called with 2 args: $*"
	local var_name="$1" ; shift 
	local -n var=$var_name # $var is not a pointer to the variable to set
	local match="$1" ; shift
	var=$(sed -n -E -e "/$match/s/.*= //p" <<<"$commvault_status")
	var=${var## *} # strip trailing blanks
	contains_visible_char "$var" || Error "Could not set $var_name variable matching $match from 'commvault status':$LF$commvault_status"
}

# CommVault base paths, matching what commvault status knows
# example
# [ General ]
#  Version = 11.26.35
#  Media Revision = 1014
#  CommServe Host Name = commserv.some.domain
#  CommServe Client Name = commserv
#  Home Directory = /opt/commvault/Base
#  Log Directory = /var/log/commvault/Log_Files
#  Core Directory = /opt/commvault
#  Temp Directory = /opt/commvault/Base/Temp
#  Platform Type = 4
#  Cvd Port Number = 8400
# [ Package ]
#  1002/CVGxBase = File System Core
#  1101/CVGxIDA = File System
# [ Physical Machine/Cluster Groups ]
#  Name = client
#   - Client Hostname = client.some.domain
#   - Job Results Directory = /opt/commvault/iDataAgent/jobResults

local commvault_status
commvault_status=$(commvault status) || Error "Cannot determine CommVault status, check 'commvault status'"
Log "CommVault Status:\n$commvault_status"

if ! test "$GALAXY11_CORE_DIRECTORY" \
	-a "$GALAXY11_HOME_DIRECTORY" \
	-a "$GALAXY11_LOG_DIRECTORY" \
	-a "$GALAXY11_TEMP_DIRECTORY" \
	-a "$GALAXY11_JOBS_RESULTS_DIRECTORY" ; then
	set_variable_from_commvault_status GALAXY11_CORE_DIRECTORY "Core Directory"
	set_variable_from_commvault_status GALAXY11_HOME_DIRECTORY "Home Directory"
	set_variable_from_commvault_status GALAXY11_LOG_DIRECTORY "Log Directory"
	set_variable_from_commvault_status GALAXY11_TEMP_DIRECTORY "Temp Directory"
	set_variable_from_commvault_status GALAXY11_JOBS_RESULTS_DIRECTORY "Job Results Directory"
fi

COPY_AS_IS+=(
	"${COPY_AS_IS_GALAXY11[@]}"
	"$GALAXY11_CONFIG_DIRECTORY"
	"$GALAXY11_CORE_DIRECTORY"
	"$GALAXY11_HOME_DIRECTORY"
)
COPY_AS_IS_EXCLUDE+=(
	"${COPY_AS_IS_EXCLUDE_GALAXY11[@]}"
	"$GALAXY11_JOBS_RESULTS_DIRECTORY/*"
	"$GALAXY11_CORE_DIRECTORY/Updates/*"
	"$GALAXY11_LOG_DIRECTORY/*"
	"$GALAXY11_TEMP_DIRECTORY/*"
)

# detect is a tool installed by CommVault that helps their scripts to determine the platform they run on
REQUIRED_PROGS+=(chgrp touch commvault simpana detect)

# we need at least 1500MB free disk space
USE_RAMDISK=1500

# include argument file if specified
if test "$GALAXY11_Q_ARGUMENTFILE"; then
	if test -s "$GALAXY11_Q_ARGUMENTFILE"; then
		COPY_AS_IS+=("$GALAXY11_Q_ARGUMENTFILE")
	else
		Error "GALAXY11_Q_ARGUMENTFILE is set but not readable or empty!"
	fi
fi

unset set_variable_from_commvault_status
