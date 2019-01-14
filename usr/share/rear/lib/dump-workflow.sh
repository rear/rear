# dump-workflow.sh
#
# dump workflow for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

LOCKLESS_WORKFLOWS=( ${LOCKLESS_WORKFLOWS[@]} dump )
WORKFLOW_dump_DESCRIPTION="dump configuration and system information"
WORKFLOWS=( ${WORKFLOWS[@]} dump )
WORKFLOW_dump () {

    # The dump workflow is always verbose (see usr/sbin/rear).

    # Do nothing in simulation mode, cf. https://github.com/rear/rear/issues/1939
    if is_true "$SIMULATE" ; then
        LogPrint "${BASH_SOURCE[0]} dumps configuration and system information"
        return 0
    fi

    # Get all array variable names in an array:
    array_variable_names=( $( declare -a | cut -d ' ' -f3 | cut -d '=' -f1 ) )

    LogPrint "Dumping out configuration and system information"

    if [ "$ARCH" != "$REAL_ARCH" ] ; then
        LogPrint "This is a '$REAL_ARCH' system, compatible with '$ARCH'."
    fi

    LogPrint "System definition:"
    for var in "ARCH" "OS" \
               "OS_MASTER_VENDOR" "OS_MASTER_VERSION" "OS_MASTER_VENDOR_ARCH" "OS_MASTER_VENDOR_VERSION" "OS_MASTER_VENDOR_VERSION_ARCH" \
               "OS_VENDOR" "OS_VERSION" "OS_VENDOR_ARCH" "OS_VENDOR_VERSION" "OS_VENDOR_VERSION_ARCH" ; do
        LogPrint "$( printf "%40s='%s'" "$var" "${!var}" )"
    done

    LogPrint "Configuration tree:"
    for config in "$ARCH" "$OS" \
                  "$OS_MASTER_VENDOR" "$OS_MASTER_VENDOR_ARCH" "$OS_MASTER_VENDOR_VERSION" "$OS_MASTER_VENDOR_VERSION_ARCH" \
                  "$OS_VENDOR" "$OS_VENDOR_ARCH" "$OS_VENDOR_VERSION" "$OS_VENDOR_VERSION_ARCH" ; do
        if [ "$config" ] ; then
            LogPrint "$( printf "%40s : %s" "$config".conf "$( test -s $SHARE_DIR/conf/"$config".conf && echo OK || echo missing/empty )" )"
        fi
    done
    for config in site local ; do
        LogPrint "$( printf "%40s : %s" "$config".conf "$( test -s $CONFIG_DIR/"$config".conf && echo OK || echo missing/empty )" )"
    done

    LogPrint "Backup with $BACKUP:"
    # Output all $BACKUP_* config variable values e.g. for BACKUP=NETFS as something like
    #   NETFS_CONFIG_STRING='string of words'
    # or when it is an array variable than as
    #   NETFS_CONFIG_ARRAY='first element' 'second element' ...
    for variable_name in $( eval echo '${!'"$BACKUP"'_*}' ) ; do
        # The command substitution for the list of items in the above 'for' loop evaluates
        # to all $BACKUP_* config variable names e.g. for BACKUP=NETFS to something like:
        #   ++ eval echo '${!NETFS_*}'
        #   +++ echo NETFS_CONFIG_STRING NETFS_CONFIG_ARRAY ...
        if IsInArray $variable_name "${array_variable_names[@]}" ; then
            variable_values="$( eval 'for array_element in "${'"$variable_name"'[@]:-}" ; do echo -n "'"'"'$array_element'"'"' " ; done' )"
            # Using an empty default value ( via "${ARRAY[@]:-}" ) in the above 'for' loop is needed for empty array variables because
            # otherwise the 'for' loop would not be run at all for empty arrays like ARRAY=( ) which would result variable_values=
            # instead of the intended variable_values="'' " that is output as ARRAY='' to explicitly show an empty '' value.
            # Welcome to the quoting hell in the command substitution for the variable_values assignment above:
            # cf. "How to escape single quotes within single quoted strings?" at
            # https://stackoverflow.com/questions/1250079/how-to-escape-single-quotes-within-single-quoted-strings
            # that reads (excerpts and a bit changed here):
            #   To use single quotes in the outermost layer ... you can glue both kinds of quotation.
            #   Example:
            #     eval ' ... '"'"' ... '"'"' ... '
            #   Explanation of how '"'"' is interpreted as just ' :
            #   1. ' end first quotation which uses single quotes
            #   2. " start second quotation using double-quotes
            #   3. ' quoted character
            #   4. " end second quotation using double-quotes
            #   5. ' start third quotation using single quotes
            # If you do not place any whitespaces between (1) and (2) or between (4) and (5)
            # the shell will interpret that string as a one long word.
            LogPrint "$( printf "%40s=( %s )" "$variable_name" "$variable_values" )"
        else
            LogPrint "$( printf "%40s='%s'" "$variable_name" "${!variable_name}" )"
        fi
    done
    # Output all BACKUP_* config variable values e.g. as something like
    #   BACKUP_CONFIG_STRING='string of words'
    # or when it is an array variable than as
    #   BACKUP_CONFIG_ARRAY='first element' 'second element' ...
    for variable_name in $( eval echo '${!BACKUP_*}' ) ; do
        case $variable_name in
	    (BACKUP_PROG*)
                ;;
            (*)
                if IsInArray $variable_name "${array_variable_names[@]}" ; then
                    variable_values="$( eval 'for array_element in "${'"$variable_name"'[@]:-}" ; do echo -n "'"'"'$array_element'"'"' " ; done' )"
                    LogPrint "$( printf "%40s=( %s )" "$variable_name" "$variable_values" )"
                else
                    LogPrint "$( printf "%40s='%s'" "$variable_name" "${!variable_name}" )"
                fi
                ;;
        esac
    done
    case "$BACKUP" in
        (NETFS)
            LogPrint "Backup program is '$BACKUP_PROG':"
            # Output all BACKUP_PROG_* config variable values e.g. as something like
            #   BACKUP_PROG_STRING='string of words'
            # or when it is an array variable than as
            #   BACKUP_PROG_ARRAY='first element' 'second element' ...
            for variable_name in $( eval echo '${!BACKUP_PROG_*}' ) ; do
                if IsInArray $variable_name "${array_variable_names[@]}" ; then
                    variable_values="$( eval 'for array_element in "${'"$variable_name"'[@]:-}" ; do echo -n "'"'"'$array_element'"'"' " ; done' )"
                    LogPrint "$( printf "%40s=( %s )" "$variable_name" "$variable_values" )"
                else
                    LogPrint "$( printf "%40s='%s'" "$variable_name" "${!variable_name}" )"
                fi
            done
        ;;
    esac

    LogPrint "Output to $OUTPUT:"
    # Output all $OUTPUT_* config variable values e.g. for OUTPUT=ISO as something like
    #   ISO_CONFIG_STRING='string of words'
    # or when it is an array variable than as
    #   ISO_CONFIG_ARRAY='first element' 'second element' ...
    # and output all OUTPUT_* config variable values e.g. as something like
    #   OUTPUT_CONFIG_STRING='string of words'
    # or when it is an array variable than as
    #   OUTPUT_CONFIG_ARRAY='first element' 'second element' ...
    # and finally output the RESULT_MAILTO config variable value:
    for variable_name in $( eval echo '${!'"$OUTPUT"'_*}' '${!OUTPUT_*}' ) RESULT_MAILTO ; do
        if IsInArray $variable_name "${array_variable_names[@]}" ; then
            variable_values="$( eval 'for array_element in "${'"$variable_name"'[@]:-}" ; do echo -n "'"'"'$array_element'"'"' " ; done' )"
            LogPrint "$( printf "%40s=( %s )" "$variable_name" "$variable_values" )"
        else
            LogPrint "$( printf "%40s='%s'" "$variable_name" "${!variable_name}" )"
        fi
    done

    Print ""

    UserOutput "$SHARE_DIR/lib/validated/$OS_VENDOR_VERSION_ARCH.txt"
    if test -s "$SHARE_DIR/lib/validated/$OS_VENDOR_VERSION_ARCH.txt" ; then
        LogPrint "Your system is validated with the following details:"
        while read -r ; do
            LogPrint "$REPLY"
        done <"$SHARE_DIR/lib/validated/$OS_VENDOR_VERSION_ARCH.txt"
    else
        LogPrint "Your system is not yet validated. Please carefully check all functions"
        LogPrint "and create a validation record with '$PROGRAM validate'. This will help others"
        LogPrint "to know about the validation status of $PRODUCT on this system."
        # if the master OS is validated print out a suitable hint
        if test -s "$SHARE_DIR/lib/validated/$OS_MASTER_VENDOR_VERSION_ARCH.txt" ; then
            LogPrint ""
            LogPrint "Your system is derived from $OS_MASTER_VENDOR_VERSION which is validated:"
            while read -r ; do
                LogPrint "$REPLY"
            done <"$SHARE_DIR/lib/validated/$OS_MASTER_VENDOR_VERSION_ARCH.txt"
        fi
    fi

}

