# 500_request_pit_restore_parameters.sh

# Ask the operator for a Point-In-Time restore target. List the
# NetBackup catalog backups available for the source client (via
# 'bpclimagelist') and let the operator pick one, enter a date and
# time manually, or accept the default of the most recent backup. One
# point in time applies to all filesystems, used later as the
# 'bprestore' end time. True Image Restore (TIR) provides the actual
# accuracy needed for a correct Point-In-Time restore.

NBU_ENDTIME=""

local answer=""
local nbu_catalog_output="" nbu_catalog_rc=0 nbu_catalog_line=""
local nbu_catalog_header_line="" nbu_catalog_index=0 nbu_catalog_number=""
local nbu_tir_status="disabled"
local nbu_bpclimagelist=/usr/openv/netbackup/bin/bpclimagelist
local nbu_catalog_lines=() nbu_catalog_stamps=() nbu_catalog_header=()

# List the source client's catalog backups so the operator can pick one.
# No policy-type filter: 'bpclimagelist -t' is the backup type, not the
# policy type 'bprestore -t 0' uses. -Listseconds tells same-day backups
# apart. -T (NBU_TIR_FLAG) lists only backups with TIR info.
LogPrint ""
while true ; do
    LogPrint "Querying the NetBackup catalog for $NBU_CLIENT_SOURCE's backups..."
    nbu_catalog_output=$( "$nbu_bpclimagelist" -Listseconds -client "$NBU_CLIENT_SOURCE" $NBU_TIR_FLAG 2>&1 )
    nbu_catalog_rc=$?
    test $nbu_catalog_rc -eq 135 || break
    # EXIT STATUS 135: the source client is not yet authorized as an altname
    # of the destination on the Primary server. Give the operator a chance
    # to fix that and retry, instead of failing the whole restore outright.
    LogPrint ""
    LogPrintError "'bpclimagelist' failed: $NBU_CLIENT_SOURCE is not authorized as an altname"
    LogPrintError "of $NBU_CLIENT_NAME on the Primary server $NBU_SERVER."
    LogPrint ""
    LogPrint "Retry after changing the altname configuration on the Primary server."
    read -t $WAIT_SECS -r -p "Press ENTER to retry, or enter EXIT to abort [$WAIT_SECS secs]: " 0<&6 1>&7 2>&8
    if [[ "${REPLY^^}" == "EXIT" ]] ; then
        LogPrint ""
        Error "User aborted NetBackup restore to configure the altname authorization on the Primary server, update bp.conf or pick a different client name above."
    fi
done

test $nbu_catalog_rc -eq 0 || Error "Could not query the NetBackup catalog for $NBU_CLIENT_SOURCE ('bpclimagelist' rc=$nbu_catalog_rc)."

# Data rows start with "mm/dd/yyyy HH:MM:SS". Keep what precedes the
# first one (column header) to show above the numbered list:
while read -r nbu_catalog_line ; do
    if [[ "$nbu_catalog_line" =~ ^([0-9]{2}/[0-9]{2}/[0-9]{4})[[:space:]]+([0-9]{2}:[0-9]{2}:[0-9]{2}) ]] ; then
        nbu_catalog_lines+=( "$nbu_catalog_line" )
        nbu_catalog_stamps+=( "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}" )
    elif test ${#nbu_catalog_lines[@]} -eq 0 ; then
        nbu_catalog_header+=( "$nbu_catalog_line" )
    fi
done <<< "$nbu_catalog_output"

if [ ${#nbu_catalog_lines[@]} -gt 0 ] ; then
    UserOutput ""
    UserOutput "Available backups for $NBU_CLIENT_SOURCE in the NetBackup catalog (newest first):"
    UserOutput ""
    # Indented to roughly line up under the "N) " prefix of the data rows below:
    for nbu_catalog_header_line in "${nbu_catalog_header[@]}" ; do
        UserOutput "     ${nbu_catalog_header_line}"
    done
    for (( nbu_catalog_index = 0 ; nbu_catalog_index < ${#nbu_catalog_lines[@]} ; nbu_catalog_index++ )) ; do
        nbu_catalog_number=$( printf '%3d' $(( nbu_catalog_index + 1 )) )
        UserOutput "${nbu_catalog_number}) ${nbu_catalog_lines[nbu_catalog_index]}"
    done
    UserOutput ""
    UserOutput "NetBackup restores by default the latest backup data."
    UserOutput "Press only ENTER to restore the most recent available backup"
    UserOutput "or enter a number above to restore that Point-In-Time backup."
else
    LogPrintError "The NetBackup catalog query for $NBU_CLIENT_SOURCE returned no matching backups ('bpclimagelist' rc=0)."
    UserOutput ""
    UserOutput "NetBackup restores by default the latest backup data."
    UserOutput "Press only ENTER to restore the most recent available backup."
    UserOutput "Falling back to manual date/time entry."
    UserOutput "Alternatively specify a date and time for Point-In-Time Restore."
fi

# Let the user enter a catalog number or a date and time again and again
# until the input is valid, or the user pressed only ENTER to restore the
# most recent available backup:
while true ; do
    answer=$( UserInput -I NBU_RESTORE_PIT -r -p "Enter a catalog number or date and time (mm/dd/yyyy HH:MM:SS), or press ENTER" )
    # When the user pressed only ENTER, default to the newest backup
    # (catalog entry 1, newest first), unless there is no catalog to pick
    # from at all, in which case leave this script to restore the most
    # recent available backup:
    if test -z "$answer" ; then
        if [ ${#nbu_catalog_lines[@]} -eq 0 ] ; then
            UserOutput "Restore most recent backup."
            return
        fi
        answer="1"
    fi
    # A number picks straight from the catalog list shown above, already valid, no need to re-validate:
    if [[ "$answer" =~ ^[0-9]+$ ]] && [ "$answer" -ge 1 ] && [ "$answer" -le ${#nbu_catalog_lines[@]} ] ; then
        NBU_ENDTIME="${nbu_catalog_stamps[$(( answer - 1 ))]}"
        break
    fi
    # Otherwise only accept the exact documented format. Reject anything else
    # (e.g. "yesterday", "next monday", or a bare date with no time) that
    # `date -d` would otherwise loosely accept:
    if [[ ! "$answer" =~ ^[0-9]{2}/[0-9]{2}/[0-9]{4}[[:space:]]+[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]] ; then
        LogPrintError "Invalid catalog number or date/time '$answer' specified."
        continue
    fi
    # Accept only a valid calendar date and time (date -d rejects e.g. 13/45/2026):
    NBU_ENDTIME=$( date -d "$answer" '+%m/%d/%Y %T' ) && break
    LogPrintError "Invalid catalog number or date/time '$answer' specified."
done

test -n "$NBU_TIR_FLAG" && nbu_tir_status="enabled"

UserOutput ""
UserOutput "Perform a restore of all filesystem backups at or before $NBU_ENDTIME with True Image Restore (TIR) $nbu_tir_status."
UserOutput ""
