# dump-workflow.sh
#
# dump workflow for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

LOCKLESS_WORKFLOWS+=( dump )
WORKFLOW_dump_DESCRIPTION="dump configuration and system information"
WORKFLOWS+=( dump )
WORKFLOW_dump () {

    # Do nothing in simulation mode, cf. https://github.com/rear/rear/issues/1939
    if is_true "$SIMULATE" ; then
        LogPrint "${BASH_SOURCE[0]} dumps configuration and system information"
        return 0
    fi

    function output_variable_assignment () {
        local variable_name=$1
        test -v "$variable_name" || return 1
        if test "$DEBUG" ; then
            # In debug mode show the 'declare -p' output as is (only indented by two spaces):
            LogUserOutput "$( declare -p $variable_name | sed -e 's/^/  /' )"
        else
            # When not in debug mode beautify/simplify the 'declare -p' output
            # for example for ARRAY=( '' 'this' ' ' 'that' 'something else' ) the 'declare -p' output is
            #   declare -a ARRAY=([0]="" [1]="this" [2]=" " [3]="that" [4]="something else")
            # which gets beautified/simplified for better readability via 'sed' into 
            #   ARRAY=("" "this" " " "that" "something else")
            # see https://github.com/rear/rear/pull/2014#issuecomment-453503218
            # but that 'sed' modification does not work fully fail safe in any case
            # see https://github.com/rear/rear/pull/2014#issuecomment-453509407
            # but it is considered to not cause harm for arrays that are actually used in ReaR
            # see https://github.com/rear/rear/pull/2014#issuecomment-453996364
            LogUserOutput "$( declare -p $variable_name | sed -e 's/^declare -[[:alpha:]-]* /  /' -e 's/\([( ]\)\[[[:digit:]]\+\]=/\1/g' )"
        fi
    }

    LogUserOutput "# Begin dumping out configuration and system information:"

    if [ "$ARCH" != "$REAL_ARCH" ] ; then
        LogUserOutput "# This is a '$REAL_ARCH' system, compatible with '$ARCH'."
    fi

    LogUserOutput "# Configuration tree:"
    for config in "$ARCH" "$OS" \
                  "$OS_MASTER_VENDOR" "$OS_MASTER_VENDOR_ARCH" "$OS_MASTER_VENDOR_VERSION" "$OS_MASTER_VENDOR_VERSION_ARCH" \
                  "$OS_VENDOR" "$OS_VENDOR_ARCH" "$OS_VENDOR_VERSION" "$OS_VENDOR_VERSION_ARCH" ; do
        test "$config" || continue
        LogUserOutput "  # $config.conf : $( test -s $SHARE_DIR/conf/$config.conf && echo OK || echo missing/empty )"
    done
    for config in site local ; do
        LogUserOutput "  # $config.conf : $( test -s $CONFIG_DIR/"$config".conf && echo OK || echo missing/empty )"
    done

    LogUserOutput "# System definition:"
    for variable_name in "ARCH" "OS" \
               "OS_MASTER_VENDOR" "OS_MASTER_VERSION" "OS_MASTER_VENDOR_ARCH" "OS_MASTER_VENDOR_VERSION" "OS_MASTER_VENDOR_VERSION_ARCH" \
               "OS_VENDOR" "OS_VERSION" "OS_VENDOR_ARCH" "OS_VENDOR_VERSION" "OS_VENDOR_VERSION_ARCH" ; do
        output_variable_assignment $variable_name
    done

    LogUserOutput "# Backup with $BACKUP:"
    # Output all $BACKUP_* config variable values e.g. for BACKUP=NETFS as something like
    #   NETFS_CONFIG_STRING="string of words"
    # or when it is an array variable than as
    #   NETFS_CONFIG_ARRAY=("first element" "second element" ... )
    for variable_name in $( eval echo '${!'"$BACKUP"'_*}' ) ; do
        # The command substitution for the list of items in the above 'for' loop evaluates
        # to all $BACKUP_* config variable names e.g. for BACKUP=NETFS to something like:
        #   ++ eval echo '${!NETFS_*}'
        #   +++ echo NETFS_CONFIG_STRING NETFS_CONFIG_ARRAY ...
        output_variable_assignment $variable_name
    done
    # Output all BACKUP_* config variable values e.g. as something like
    #   BACKUP_CONFIG_STRING="string of words"
    # or when it is an array variable than as
    #   BACKUP_CONFIG_ARRAY=("first element" "second element" ... )
    for variable_name in $( eval echo '${!BACKUP_*}' ) ; do
        case $variable_name in
	    (BACKUP_PROG*)
                ;;
            (*)
                output_variable_assignment $variable_name
                ;;
        esac
    done
    case "$BACKUP" in
        (NETFS)
            LogUserOutput "# Backup program is '$BACKUP_PROG':"
            # Output all BACKUP_PROG_* config variable values e.g. as something like
            #   BACKUP_PROG_STRING="string of words"
            # or when it is an array variable than as
            #   BACKUP_PROG_ARRAY=("first element" "second element" ... )
            for variable_name in $( eval echo '${!BACKUP_PROG_*}' ) ; do
                output_variable_assignment $variable_name
            done
        ;;
    esac

    LogUserOutput "# Output to $OUTPUT:"
    # Output all $OUTPUT_* config variable values e.g. for OUTPUT=ISO as something like
    #   ISO_CONFIG_STRING="string of words"
    # or when it is an array variable than as
    #   ISO_CONFIG_ARRAY=("first element" "second element" ... )
    # and output all OUTPUT_* config variable values e.g. as something like
    #   OUTPUT_CONFIG_STRING="string of words"
    # or when it is an array variable than as
    #   OUTPUT_CONFIG_ARRAY=("first element" "second element" ... )
    # and finally output the RESULT_MAILTO config variable value:
    for variable_name in $( eval echo '${!'"$OUTPUT"'_*}' '${!OUTPUT_*}' ) RESULT_MAILTO ; do
        output_variable_assignment $variable_name
    done

    LogUserOutput "# Validation status:"
    validation_file="$SHARE_DIR/lib/validated/$OS_VENDOR_VERSION_ARCH.txt"
    LogUserOutput "  # $validation_file : $( test -s $validation_file && echo OK || echo missing/empty )"
    if test -s "$validation_file" ; then
        LogUserOutput "  # Your system is validated with the following details:"
        while read -r ; do
            LogUserOutput "  # $REPLY"
        done <"$validation_file"
    else
        LogUserOutput "  # Your system is not yet validated. Please carefully check all functions"
        LogUserOutput "  # and create a validation record with '$PROGRAM validate'. This will help others"
        LogUserOutput "  # to know about the validation status of $PRODUCT on this system."
        # Show a hint when there is no OS_VENDOR_VERSION_ARCH.txt but OS_MASTER_VENDOR_VERSION_ARCH.txt exists:
        validation_file="$SHARE_DIR/lib/validated/$OS_MASTER_VENDOR_VERSION_ARCH.txt"
        if test -s "$validation_file" ; then
            LogUserOutput "  # $validation_file : OK"
            LogUserOutput "  # Your system is derived from $OS_MASTER_VENDOR_VERSION which is validated:"
            while read -r ; do
                LogUserOutput "  # $REPLY"
            done <"$validation_file"
        fi
    fi

    LogUserOutput "# End of dump configuration and system information."

}

