# shell-script-functions.sh
#
# shell script functions for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# convert tabs into 4 spaces with: expand --tabs=4 file >new-file

# source a file given in $1
function Source () {
    local source_file="$1"
    local source_return_code=0
    # Skip if source file name is empty:
    if test -z "$source_file" ; then
        Debug "Skipping Source() because it was called with empty source file name"
        return
    fi
    # Ensure source file is not a directory:
    test -d "$source_file" && Error "Source file '$source_file' is a directory, cannot source"
    # Skip if source file does not exist of if its content is empty:
    if ! test -s "$source_file" ; then
        Debug "Skipping Source() because source file '$source_file' not found or empty"
        return
    fi
    # Clip leading standard path to rear files (usually /usr/share/rear/):
    local relname="${source_file##$SHARE_DIR/}"
    # Simulate sourcing the scripts in $SHARE_DIR
    if test "$SIMULATE" && expr "$source_file" : "$SHARE_DIR" >/dev/null; then
        LogPrint "Source $relname"
        return
    fi
    # Step-by-step mode or breakpoint if needed
    # Usage of the external variable BREAKPOINT: sudo BREAKPOINT="*foo*" rear mkrescue
    # an empty default value is set to avoid 'set -eu' error exit if BREAKPOINT is unset:
    : ${BREAKPOINT:=}
    if [[ "$STEPBYSTEP" || ( "$BREAKPOINT" && "$relname" == "$BREAKPOINT" ) ]] ; then
        # Use the original STDIN STDOUT and STDERR when 'rear' was launched by the user
        # to get input from the user and to show output to the user (cf. _input-output-functions.sh):
        read -p "Press ENTER to include '$source_file' ... " 0<&6 1>&7 2>&8
    fi
    # The Error function is searching for 'Including .*$last_sourced_script_filename'
    # in RUNTIME_LOGFILE and/or STDOUT_STDERR_FILE so provide that info in both files:
    Log "Including $relname"
    echo "Including $relname" >>$STDOUT_STDERR_FILE
    # DEBUGSCRIPTS mode settings:
    if test "$DEBUGSCRIPTS" ; then
        Debug "Entering debugscript mode via 'set -$DEBUGSCRIPTS_ARGUMENT'."
        local saved_bash_flags_and_options_commands="$( get_bash_flags_and_options_commands )"
        set -$DEBUGSCRIPTS_ARGUMENT
    fi
    # The actual work (source the source file):
    # Do not error out here when 'source' fails (i.e. when 'source' returns a non-zero exit code)
    # because scripts usually return the exit code of their last command
    # cf. https://github.com/rear/rear/issues/1965#issuecomment-439330017
    # and in general ReaR should not error out in a (helper) function but instead
    # a function should return an error code so that its caller can decide what to do
    # cf. https://github.com/rear/rear/pull/1418#issuecomment-316004608
    source "$source_file"
    source_return_code=$?
    test "0" -eq "$source_return_code" || Debug "Source function: 'source $source_file' returns $source_return_code"
    # Ensure that after each sourced file we are back in ReaR's usual working directory
    # that is WORKING_DIR="$( pwd )" when usr/sbin/rear was launched
    # cf. https://github.com/rear/rear/issues/2461
    # Quoting "$WORKING_DIR" is needed to make it behave fail-safe if WORKING_DIR is empty
    # because cd "" succeeds without changing the current directory
    # in contrast to plain cd which changes to the home directory (usually /root)
    # cf. https://github.com/rear/rear/pull/2478#issuecomment-673500099
    cd "$WORKING_DIR" || LogPrintError "Failed to 'cd $WORKING_DIR'"
    # Undo DEBUGSCRIPTS mode settings:
    if test "$DEBUGSCRIPTS" ; then
        Debug "Leaving debugscript mode (back to previous bash flags and options settings)."
        # The only known way how to do 'set +x' after 'set -x' without 'set -x' output for the 'set +x' call
        # is a current shell environment where stderr is redirected to /dev/null before 'set +x' is run via
        #   { set +x ; } 2>/dev/null
        # here we avoid much useless 'set -x' debug output for the apply_bash_flags_and_options_commands call:
        { apply_bash_flags_and_options_commands "$saved_bash_flags_and_options_commands" ; } 2>/dev/null
    fi
    # Breakpoint if needed:
    if [[ "$BREAKPOINT" && "$relname" == "$BREAKPOINT" ]] ; then
        # Use the original STDIN STDOUT and STDERR when 'rear' was launched by the user
        # to get input from the user and to show output to the user (cf. _input-output-functions.sh):
        read -p "Press ENTER to continue ... " 0<&6 1>&7 2>&8
    fi
    # Return the return value of the actual work (source the source file):
    return $source_return_code
}

# Collect scripts given in the stage directory $1
# therein in the standard subdirectories and
# sort them by their script file name and
# Source() the scripts one by one:
function SourceStage () {
    local stage="$1"
    local start_SourceStage=$SECONDS
    Log "======================"
    Log "Running '$stage' stage"
    Log "======================"
    # In debug modes show what stage is run also on the user's terminal:
    test "$DEBUG" && Print "Running '$stage' stage ======================"
    # We always source scripts in the same subdirectory structure.
    # The ls -d {...,...,...} within the $SHARE_DIR/$stage directory expands as intended.
    # The intent is to only list those scripts below the $SHARE_DIR/$stage directory
    # that match the specified backup method and output method
    # and that match the used operating system and architecture and Linux distribution.
    # The pipe sorts the listed scripts by their 3-digit number independent of the directory of the script.
    # We want to make sure that there are no duplicates in the listed scripts
    # so that each script gets executed at most once.
    # cf. https://github.com/rear/rear/issues/3149#issuecomment-1935586311
    # First sed inserts a ! before and after the script number
    # e.g. default/123_some_script.sh becomes default/!123!_some_script.sh
    # which makes the script number field nr. 2 when dividing lines into fields by !
    # so that the subsequent sort can sort by that field.
    # Numeric sort is not needed because all script numbers have same length
    # (without numeric sort 2 and 10 get sorted as first 10 then 2).
    # The final tr removes the ! to restore the original script name.
    # This code breaks if ! or a leading 3-digit number with underscore
    # is used in a directory name of the ReaR subdirectory structure
    # but those directories below the $SHARE_DIR/$stage directory are not named by the user
    # so that it even works when a user runs a git clone in his .../ReaRtest!/ directory.
    # For example a new backup method named '123_backup' is not possible
    # but a new backup method named '123backup' (without underscore) is possible.
    local scripts=( $( cd $SHARE_DIR/$stage
                 ls -d  {default,"$ARCH","$OS","$OS_MASTER_VENDOR","$OS_MASTER_VENDOR_ARCH","$OS_MASTER_VENDOR_VERSION","$OS_VENDOR","$OS_VENDOR_ARCH","$OS_VENDOR_VERSION"}/*.sh \
              "$BACKUP"/{default,"$ARCH","$OS","$OS_MASTER_VENDOR","$OS_MASTER_VENDOR_ARCH","$OS_MASTER_VENDOR_VERSION","$OS_VENDOR","$OS_VENDOR_ARCH","$OS_VENDOR_VERSION"}/*.sh \
              "$OUTPUT"/{default,"$ARCH","$OS","$OS_MASTER_VENDOR","$OS_MASTER_VENDOR_ARCH","$OS_MASTER_VENDOR_VERSION","$OS_VENDOR","$OS_VENDOR_ARCH","$OS_VENDOR_VERSION"}/*.sh \
    "$OUTPUT"/"$BACKUP"/{default,"$ARCH","$OS","$OS_MASTER_VENDOR","$OS_MASTER_VENDOR_ARCH","$OS_MASTER_VENDOR_VERSION","$OS_VENDOR","$OS_VENDOR_ARCH","$OS_VENDOR_VERSION"}/*.sh \
                 | sed -e 's#/\([0-9][0-9][0-9]\)_#/!\1!_#g' | sort -t \! -k 2 -u | tr -d \! ) )
    # If no script is found, then the scripts array contains only one element '.'
    if test "$scripts" = '.' ; then
        Log "Finished running empty '$stage' stage"
        return 0
    fi
    # Source() the scripts one by one:
    local script=''
    for script in "${scripts[@]}" ; do
        # Tell the user about unexpected named scripts.
        # All scripts must be named with a leading three-digit number NNN_something.sh
        # otherwise the above sorting by the 3-digit number may not work as intended
        # so that scripts without leading 3-digit number are likely run in wrong order:
        grep -q '^[0-9][0-9][0-9]_' <<< $( basename $script ) || LogPrintError "Script '$script' without leading 3-digit number 'NNN_' is likely run in wrong order"
        Source $SHARE_DIR/$stage/"$script"
    done
    Log "Finished running '$stage' stage in $(( SECONDS - start_SourceStage )) seconds"
}
