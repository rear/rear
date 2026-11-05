# 500_request_pit_restore_parameters.sh

# Ask the operator for a Point-In-Time restore target. List the
# NetBackup catalog backups available for the source client (via
# 'bpclimagelist') and let the operator pick one, enter a date and
# time manually, or accept the default of the most recent backup. One
# point in time applies to all filesystems, used later as the
# 'bprestore' end time. True Image Restore (TIR) provides the actual
# accuracy needed for a correct Point-In-Time restore.
# Then ask for a complete backup image restore (the default, without excludes)
# or a partial backup image restore (with excludes of folders and paths of /),
# which 400_restore_with_nbu.sh passes to 'bprestore' as '!' entries.

NBU_ENDTIME=""
NBU_STARTTIME=""
NBU_RESTORE_EXCLUDES=()

local answer=""
local nbu_catalog_output="" nbu_catalog_rc=0 nbu_catalog_line=""
local nbu_catalog_header_line="" nbu_catalog_index=0 nbu_catalog_number=""
local nbu_tir_status="disabled"
local nbu_bpclimagelist=/usr/openv/netbackup/bin/bpclimagelist
local nbu_catalog_lines=() nbu_catalog_stamps=() nbu_catalog_header=()
local nbu_restore_mode="" nbu_bplist_output="" nbu_bplist_rc=0 nbu_bplist_line=""
local nbu_top_path="" nbu_top_index=0 nbu_top_number=""
local nbu_top_paths=() nbu_top_locked=() nbu_top_skip=()
local nbu_pseudofs="" nbu_is_locked="" nbu_token="" nbu_from=0 nbu_to=0 nbu_number=0
local nbu_selection_valid="" nbu_target_epoch="" nbu_stamp_epoch=""
local nbu_bplist=/usr/openv/netbackup/bin/bplist
local nbu_extra_paths=() nbu_rejected=() nbu_candidates=() nbu_path="" nbu_candidate="" nbu_other="" nbu_skip_it="" nbu_confirmed=""

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
    REPLY=""
    read -t $WAIT_SECS -r -p "Enter a catalog number or date and time (mm/dd/yyyy HH:MM:SS), or press ENTER [$WAIT_SECS secs]: " 0<&6 1>&7 2>&8
    answer="$REPLY"
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

# 'bprestore' with only -e defaults -s to 01/01/1970, which replays every
# image ever taken. Use the nearest full backup at or before the end time
# as the start time (catalog is newest first). The catalog list is empty
# only for a manually entered date, then query it for that date.
nbu_target_epoch=$( date -d "$NBU_ENDTIME" '+%s' ) || Error "Cannot parse selected restore point in time '$NBU_ENDTIME'."
if [ ${#nbu_catalog_lines[@]} -eq 0 ] ; then
    nbu_catalog_output=$( "$nbu_bpclimagelist" -Listseconds -client "$NBU_CLIENT_SOURCE" $NBU_TIR_FLAG 2>/dev/null )
    while read -r nbu_catalog_line ; do
        if [[ "$nbu_catalog_line" =~ ^([0-9]{2}/[0-9]{2}/[0-9]{4})[[:space:]]+([0-9]{2}:[0-9]{2}:[0-9]{2}) ]] ; then
            nbu_catalog_lines+=( "$nbu_catalog_line" )
            nbu_catalog_stamps+=( "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}" )
        fi
    done <<< "$nbu_catalog_output"
fi
for (( nbu_catalog_index = 0 ; nbu_catalog_index < ${#nbu_catalog_lines[@]} ; nbu_catalog_index++ )) ; do
    nbu_stamp_epoch=$( date -d "${nbu_catalog_stamps[nbu_catalog_index]}" '+%s' ) || continue
    test "$nbu_stamp_epoch" -le "$nbu_target_epoch" || continue
    if [[ "${nbu_catalog_lines[nbu_catalog_index]}" == *"Full Backup"* ]] ; then
        NBU_STARTTIME="${nbu_catalog_stamps[nbu_catalog_index]}"
        break
    fi
done
test -n "$NBU_STARTTIME" || Error "No full NetBackup backup found at or before '$NBU_ENDTIME' for client $NBU_CLIENT_SOURCE, cannot do Point-In-Time Restore."

while true ; do
    REPLY=""
    read -t $WAIT_SECS -r -p "Enter PARTIAL for a list of top-level folders with the option to define excludes
or press ENTER to restore everything included in the backup image [$WAIT_SECS secs]: " 0<&6 1>&7 2>&8
    case "${REPLY^^}" in
        "") nbu_restore_mode="complete" ; break ;;
        PARTIAL) nbu_restore_mode="partial" ; break ;;
    esac
    LogPrintError "Invalid input '$REPLY', enter PARTIAL or press ENTER."
done

test "$nbu_restore_mode" = "complete" && return 0

UserOutput ""
# Same options as the 'bprestore' call in 400_restore_with_nbu.sh.
# -R 1 lists only the top level of /.
LogPrint "Listing the top-level folders of / in the backup of $NBU_CLIENT_SOURCE..."
nbu_bplist_output=$( "$nbu_bplist" -t 0 -s ${NBU_STARTTIME} -e ${NBU_ENDTIME} -C "$NBU_CLIENT_SOURCE" $NBU_TIR_FLAG -R 1 -l / 2>&1 )
nbu_bplist_rc=$?
if test $nbu_bplist_rc -ne 0 ; then
    LogPrintError "'bplist' failed (return code = $nbu_bplist_rc), falling back to a complete backup image restore."
    return 0
fi

# 'bplist' prints the listing once per backup image in the chain, so de-duplicate.
# Data rows end with the path, directories with a trailing slash and a blank.
while read -r nbu_bplist_line ; do
    [[ "$nbu_bplist_line" =~ ^[-dl][^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+[0-9]+[[:space:]]+[A-Za-z]{3}[[:space:]]+[0-9]+[[:space:]]+[0-9:]+[[:space:]]+(/.*)$ ]] || continue
    nbu_top_path="${BASH_REMATCH[1]%"${BASH_REMATCH[1]##*[![:space:]]}"}"
    nbu_top_path="${nbu_top_path%/}"
    [[ "$nbu_top_path" =~ ^/[^/]+$ ]] || continue
    echo "$nbu_top_path"
done <<< "$nbu_bplist_output" | sort -u > $TMP_DIR/nbu_top_paths
while read -r nbu_top_path ; do
    nbu_top_paths+=( "$nbu_top_path" )
done < $TMP_DIR/nbu_top_paths

if test ${#nbu_top_paths[@]} -eq 0 ; then
    LogPrintError "'bplist' returned no top-level folders, falling back to a complete backup image restore."
    return 0
fi

# Mark the pseudo filesystems that are always excluded (see 400_restore_with_nbu.sh):
for (( nbu_top_index = 0 ; nbu_top_index < ${#nbu_top_paths[@]} ; nbu_top_index++ )) ; do
    nbu_is_locked=""
    for nbu_pseudofs in /dev /run /proc /sys ; do
        test "${nbu_top_paths[nbu_top_index]}" = "$nbu_pseudofs" && nbu_is_locked="yes"
    done
    nbu_top_locked[nbu_top_index]="$nbu_is_locked"
done

UserOutput ""
for (( nbu_top_index = 0 ; nbu_top_index < ${#nbu_top_paths[@]} ; nbu_top_index++ )) ; do
    nbu_top_number=$( printf '%3d' $(( nbu_top_index + 1 )) )
    if test -n "${nbu_top_locked[nbu_top_index]}" ; then
        UserOutput "${nbu_top_number}) ${nbu_top_paths[nbu_top_index]} (always excluded)"
    else
        UserOutput "${nbu_top_number}) ${nbu_top_paths[nbu_top_index]}"
    fi
done
UserOutput ""
UserOutput "All folders are restored unless you exclude them. Enter the numbers and/or paths to exclude,"
UserOutput "e.g. '1 3 5-8 /var/lib/mysql'. Press only ENTER to exclude nothing (complete backup image restore)."
UserOutput ""
UserOutput "If critical folders or file systems (e.g. /boot /etc /usr /var) are excluded,"
UserOutput "the restored system may not boot or may not be fully usable."

while true ; do
    REPLY=""
    read -t $WAIT_SECS -r -p "Enter the numbers and/or paths of the folders to exclude, or press ENTER [$WAIT_SECS secs]: " 0<&6 1>&7 2>&8
    answer="$REPLY"
    NBU_RESTORE_EXCLUDES=()
    nbu_top_skip=()
    nbu_extra_paths=()
    nbu_rejected=()
    nbu_selection_valid="yes"
    test -z "$answer" && break
    for nbu_token in ${answer//,/ } ; do
        if [[ "$nbu_token" == /* ]] ; then
            # A path: collapse repeated slashes, drop the trailing one, then test it
            # against the backup image ('bplist' returns 0 only for an existing path).
            nbu_path="$nbu_token"
            while [[ "$nbu_path" == *//* ]] ; do nbu_path="${nbu_path//\/\//\/}" ; done
            nbu_path="${nbu_path%/}"
            if test -z "$nbu_path" ; then
                nbu_rejected+=( "$nbu_token (the whole of / cannot be excluded)" )
                continue
            fi
            nbu_skip_it=""
            for nbu_pseudofs in /dev /run /proc /sys ; do
                if [[ "$nbu_path" == "$nbu_pseudofs" || "$nbu_path" == "$nbu_pseudofs"/* ]] ; then
                    nbu_skip_it="yes"
                fi
            done
            if test -n "$nbu_skip_it" ; then
                nbu_rejected+=( "$nbu_path (always excluded)" )
                continue
            fi
            if "$nbu_bplist" -t 0 -s ${NBU_STARTTIME} -e ${NBU_ENDTIME} -C "$NBU_CLIENT_SOURCE" $NBU_TIR_FLAG -R 0 "$nbu_path" &>/dev/null ; then
                nbu_extra_paths+=( "$nbu_path" )
            else
                nbu_rejected+=( "$nbu_path (not found in the backup image)" )
            fi
            continue
        fi
        if [[ "$nbu_token" =~ ^([0-9]+)-([0-9]+)$ ]] ; then
            nbu_from="${BASH_REMATCH[1]}"
            nbu_to="${BASH_REMATCH[2]}"
        elif [[ "$nbu_token" =~ ^[0-9]+$ ]] ; then
            nbu_from="$nbu_token"
            nbu_to="$nbu_token"
        else
            nbu_selection_valid=""
            break
        fi
        if test "$nbu_from" -lt 1 || test "$nbu_to" -lt "$nbu_from" || test "$nbu_to" -gt ${#nbu_top_paths[@]} ; then
            nbu_selection_valid=""
            break
        fi
        for (( nbu_number = nbu_from ; nbu_number <= nbu_to ; nbu_number++ )) ; do
            if test -n "${nbu_top_locked[nbu_number-1]}" ; then
                nbu_selection_valid=""
                break 2
            fi
            nbu_top_skip[nbu_number-1]="yes"
        done
    done
    if test -z "$nbu_selection_valid" ; then
        LogPrintError "Invalid selection '$answer'. Use numbers, ranges or absolute paths, not the always excluded folders."
        continue
    fi
    for nbu_candidate in "${nbu_rejected[@]}" ; do
        LogPrintError "Ignored: $nbu_candidate"
    done

    # Numbered folders plus validated paths, without duplicates and without
    # paths below another excluded path.
    nbu_candidates=()
    for (( nbu_top_index = 0 ; nbu_top_index < ${#nbu_top_paths[@]} ; nbu_top_index++ )) ; do
        test -n "${nbu_top_locked[nbu_top_index]}" && continue
        test -n "${nbu_top_skip[nbu_top_index]}" && nbu_candidates+=( "${nbu_top_paths[nbu_top_index]}" )
    done
    nbu_candidates+=( "${nbu_extra_paths[@]}" )
    for nbu_candidate in "${nbu_candidates[@]}" ; do
        nbu_skip_it=""
        for nbu_other in "${nbu_candidates[@]}" ; do
            test "$nbu_other" = "$nbu_candidate" && continue
            [[ "$nbu_candidate" == "$nbu_other"/* ]] && nbu_skip_it="yes"
        done
        for nbu_other in "${NBU_RESTORE_EXCLUDES[@]}" ; do
            test "$nbu_other" = "$nbu_candidate" && nbu_skip_it="yes"
        done
        test -n "$nbu_skip_it" || NBU_RESTORE_EXCLUDES+=( "$nbu_candidate" )
    done

    # Everything typed was rejected, ask again instead of silently restoring everything:
    if test ${#NBU_RESTORE_EXCLUDES[@]} -eq 0 && test ${#nbu_rejected[@]} -gt 0 ; then
        continue
    fi
    test ${#NBU_RESTORE_EXCLUDES[@]} -eq 0 && break

    UserOutput ""
    UserOutput "Partial backup image restore, these folders will NOT be restored: ${NBU_RESTORE_EXCLUDES[*]}"
    nbu_confirmed=""
    while true ; do
        REPLY=""
        read -t $WAIT_SECS -r -p "Press ENTER to proceed or enter REPEAT to change the selection [$WAIT_SECS secs]: " 0<&6 1>&7 2>&8
        case "${REPLY^^}" in
            "") nbu_confirmed="yes" ; break ;;
            REPEAT) break ;;
        esac
        LogPrintError "Invalid input '$REPLY', press ENTER or enter REPEAT."
    done
    test -n "$nbu_confirmed" && break
done

if test ${#NBU_RESTORE_EXCLUDES[@]} -eq 0 ; then
    UserOutput ""
    UserOutput "No folders excluded, doing a complete backup image restore."
fi
