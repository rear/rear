#
# Ask to recreate HP's Smart Array line of hardware RAID controllers
# and actually recreate that before the actual restoration takes place.
#
# This script is only about HP Smart Array hardware RAID controllers
# that are supported by the 'cciss' kernel module.
# Newer HP Smart Array hardware RAID controllers that need
# the 'hpsa' kernel module are not supported by this script.
# Cf.
# http://cciss.sourceforge.net/
# which reads (excerpt):
#  The cciss driver has been removed from RHEL7 and SLES12.
#  If you really want cciss on RHEL7 checkout the elrepo directory.
#  A new Smart Array driver called "hpsa" has been accepted into
#  the main line linux kernel as of Dec 18, 2009, in linux-2.6.33-rc1.
#  This new driver will support new Smart Array products going
#  forward, and the cciss driver will eventually be deprecated.
#

# Skip that unless the cciss kernel module
# (for HP Smart Array hardware RAID controllers)
# is loaded:
grep -q '^cciss ' /proc/modules || return 0

# The code below calls layout-functions like create_device()
# that append code to a file referenced by the global LAYOUT_CODE variable
# so that we must also use that global variable name in this script
# but with a special value only for this script here:
orig_LAYOUT_CODE="$LAYOUT_CODE"
LAYOUT_CODE=$VAR_DIR/layout/hpraid.sh

# Initialize our special LAYOUT_CODE:
cat <<EOF >$LAYOUT_CODE
# Recreate HP Smart Array hardware RAID
LogPrint "Recreating HP Smart Array hardware RAID"
set -e
# Unload CCISS kernel module to make sure nothing is using it:
rmmod cciss || Error "Failed to unload 'cciss' kernel module, something is using it"
modprobe cciss
sleep 2
EOF

# First recreate HP Smart Array controllers or skip some via user dialog:
controllers_to_be_recreated=()
echo "# First recreate HP Smart Array controllers" >>$LAYOUT_CODE
while read type name junk ; do
    prompt="Recreate HP Smart Array controller '$name' (yes/no)?"
    input_value=""
    wilful_input=""
    # Generate a runtime-specific user_input_ID so that for each HP Smart Array controller
    # a different user_input_ID is used for the UserInput call so that the user can specify
    # for each HP Smart Array controller a different predefined user input.
    # Only uppercase letters and digits are used to ensure the user_input_ID is a valid bash variable name
    # (otherwise the UserInput call could become invalid which aborts 'rear recover' with a BugError) and
    # hopefully only uppercase letters and digits are sufficient to distinguish different controllers:
    controller_basename_alnum_uppercase="$( basename "$name" | tr -d -c '[:alnum:]' | tr '[:lower:]' '[:upper:]' )"
    test "$controller_basename_alnum_uppercase" || controller_basename_alnum_uppercase="CONTROLLER"
    user_input_ID="HP_SMART_ARRAY_$controller_basename_alnum_uppercase"
    input_value="$( UserInput -I $user_input_ID -p "$prompt" -D 'YES' )" && wilful_input="yes" || wilful_input="no"
    if is_true "$input_value" ; then
        is_true "$wilful_input" && LogPrint "User confirmed recreating HP Smart Array controller '$name'" || LogPrint "Recreating HP Smart Array controller '$name' by default"
        echo "# Recreate HP Smart Array controller '$name'" >>$LAYOUT_CODE
        create_device "$name" 'smartarray'
        controllers_to_be_recreated+=( $name )
    fi
done < <( grep '^smartarray ' $LAYOUT_FILE )

# Then recreate all logical drives for those controllers that will be recreated:
echo "# Then recreate all logical drives for those controllers that were recreated" >>$LAYOUT_CODE
while read type name remainder junk ; do
    ctrl=$( echo "$remainder" | cut -d " " -f1 | cut -d "|" -f1 )
    if IsInArray "$ctrl" "${controllers_to_be_recreated[@]}" ; then
        echo "# Recreate logical drive '$name'" >>$LAYOUT_CODE
        create_device "$name" 'logicaldrive'
    fi
done < <( grep '^logicaldrive ' $LAYOUT_FILE )

# Finally engage SCSI for the hosts in /proc/driver/cciss/cciss?
cat <<'EOF' >>$LAYOUT_CODE
# Finally engage SCSI for the hosts in /proc/driver/cciss/cciss?
# engage scsi can fail in certain cases
set +e
# make the CCISS tape device visible
for host in /proc/driver/cciss/cciss? ; do
    Log "Engage SCSI on host $host"
    echo engage scsi >$host
done
sleep 2
EOF

# Run the HP Smart Array recreation script only if at least one HP Smart Array controller will be recreated:
if test ${#controllers_to_be_recreated} -gt 0 ; then
    # Call function to find proper Smart Storage Administrator CLI command
    # (it defines the HPSSACLI variable):
    define_HPSSACLI
    # Run our special LAYOUT_CODE
    # i.e. actually recreate the HP Smart Array stuff here
    # cf. the code in layout/recreate/default/200_run_layout_code.sh
    rear_workflow="rear $WORKFLOW"
    rear_shell_history="$( echo -e "$HPSSACLI ctrl all show detail\n$HPSSACLI ctrl all show config detail\n$HPSSACLI ctrl all show config" )"
    unset choices
    choices[0]="Rerun HP Smart Array recreation script ($LAYOUT_CODE)"
    choices[1]="View '$rear_workflow' log file ($RUNTIME_LOGFILE)"
    choices[2]="Edit HP Smart Array recreation script ($LAYOUT_CODE)"
    choices[3]="Use Relax-and-Recover shell and return back to here"
    choices[4]="Abort '$rear_workflow'"
    prompt="The HP Smart Array recreation script failed"
    choice=""
    wilful_input=""
    # When USER_INPUT_HP_SMART_ARRAY_CODE_RUN has any 'true' value be liberal in what you accept and
    # assume choices[0] 'Run disk recreation script again' was actually meant:
    is_true "$USER_INPUT_HP_SMART_ARRAY_CODE_RUN" && USER_INPUT_HP_SMART_ARRAY_CODE_RUN="${choices[0]}"
    # Run the disk layout recreation code (diskrestore.sh)
    # again and again until it succeeds or the user aborts:
    while true ; do
        # Run LAYOUT_CODE in a sub-shell because it sets 'set -e'
        # so that it exits the running shell in case of an error
        # but that exit must not exit this running bash here:
        ( source $LAYOUT_CODE )
        # Since bash 4.x one must explicitly test whether or not $? is zero in a separated bash command
        # otherwise the 'set -e' inside the sourced script would be noneffective
        # cf. layout/recreate/default/200_run_layout_code.sh
        # and https://github.com/rear/rear/pull/1573#issuecomment-344303590
        # Break the outer while loop when LAYOUT_CODE succeeded:
        (( $? == 0 )) && break
        # Run an inner while loop with a user dialog so that the user can fix things when LAYOUT_CODE failed:
        while true ; do
            choice="$( UserInput -I LAYOUT_CODE_RUN -p "$prompt" -D "${choices[0]}" "${choices[@]}" )" && wilful_input="yes" || wilful_input="no"
            case "$choice" in
                (${choices[0]})
                    # Rerun disk recreation script:
                    is_true "$wilful_input" && LogPrint "User reruns HP Smart Array recreation script" || LogPrint "Rerunning HP Smart Array recreation script by default"
                    # Only break the inner while loop (i.e. the user dialog loop):
                    break
                    ;;
                (${choices[1]})
                    # Run 'less' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
                    less $RUNTIME_LOGFILE 0<&6 1>&7 2>&8
                    ;;
                (${choices[2]})
                    # Run 'vi' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
                    vi $LAYOUT_CODE 0<&6 1>&7 2>&8
                    ;;
                (${choices[3]})
                    # rear_shell runs 'bash' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
                    rear_shell "" "$rear_shell_history"
                    ;;
                (${choices[4]})
                    abort_recreate
                    Error "User chose to abort '$rear_workflow' in ${BASH_SOURCE[0]}"
                    ;;
            esac
        done
    done
fi

# It is crucial for the subsequent scripts
# that the normal LAYOUT_CODE value is restored:
LAYOUT_CODE="$orig_LAYOUT_CODE"

