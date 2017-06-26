# _input-output-functions.sh
#
# NOTE:
# This is the first file to be sourced (because of _ in the name) which is why
# it contains some special stuff like EXIT_TASKS that I want to be available everywhere.

# input-output functions for Relax-and-Recover
# plus some special stuff that should be available everywhere.
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# The sequence $'...' is an special bash expansion with backslash-escaped characters
# see "Words of the form $'string' are treated specially" in "man bash"
# that works at least down to bash 3.1 in SLES10:
LF=$'\n'

# Collect exit tasks in this array.
# Without the empty string as initial value ${EXIT_TASKS[@]} would be an unbound variable
# that would result an error exit if 'set -eu' is used:
EXIT_TASKS=("")

# Add $* as an exit task to be done at the end:
function AddExitTask () {
    # NOTE: We add the task at the beginning to make sure that they are executed in reverse order.
    # I use $* on purpose because I want to get one string from all args!
    EXIT_TASKS=( "$*" "${EXIT_TASKS[@]}" )
    Debug "Added '$*' as an exit task"
}

# Add $* as an exit task to be done at the end but do not output a debug message.
# TODO: I <jsmeix@suse.de> wonder why debug messages are suppressed at all?
# I.e. I wonder about the reason behind why QuietAddExitTask is needed?
function QuietAddExitTask () {
    # NOTE: We add the task at the beginning to make sure that they are executed in reverse order.
    # I use $* on purpose because I want to get one string from all args!
    EXIT_TASKS=( "$*" "${EXIT_TASKS[@]}" )
}

# Remove $* from the exit tasks list:
function RemoveExitTask () {
    local removed="" exit_tasks=""
    for (( c=0 ; c<${#EXIT_TASKS[@]} ; c++ )) ; do
        if test "${EXIT_TASKS[c]}" = "$*" ; then
            # the ' ' protect from bash expansion, however unlikely to have a file named EXIT_TASKS in pwd...
            unset 'EXIT_TASKS[c]'
            removed=yes
            Debug "Removed '$*' from the list of exit tasks"
        fi
    done
    if ! test "$removed" = "yes" ; then
        exit_tasks="$( for task in "${EXIT_TASKS[@]}" ; do echo "$task" ; done )"
        Log "Could not remove exit task '$*' (not found). Exit Tasks: '$exit_tasks'"
    fi
}

# Do all exit tasks:
function DoExitTasks () {
    Log "Running exit tasks."
    # kill all running jobs
    JOBS=( $( jobs -p ) )
    # when "jobs -p" results nothing then JOBS is still an unbound variable so that
    # an empty default value is used to avoid 'set -eu' error exit if $JOBS is unset:
    if test -n ${JOBS:-""} ; then
        Log "The following jobs are still active:"
        jobs -l >&2
        kill -9 "${JOBS[@]}" >&2
        # allow system to clean up after killed jobs
        sleep 1
    fi
    for task in "${EXIT_TASKS[@]}" ; do
        Debug "Exit task '$task'"
        eval "$task"
    done
}

# The command (actually the function) DoExitTasks is executed on exit from the shell:
builtin trap "DoExitTasks" EXIT

# Keep PID of main process (i.e. the main script that the user had launched as 'rear'):
readonly MASTER_PID=$$

# Prepare that STDIN STDOUT and STDERR can be later redirected to anywhere
# (e.g. both STDOUT and STDERR can be later redirected to the log file).
# To be able to output on the original STDOUT and STDERR when 'rear' was launched and
# to be able to input (i.e. 'read') from the original STDIN when 'rear' was launched
# (which is usually the keyboard and display of the user who launched 'rear')
# the original STDIN STDOUT and STDERR file descriptors are saved as fd6 fd7 and fd8
# so that ReaR functions for actually intended user messages can use fd7 and fd8
# to show messages to the user regardless whereto STDOUT and STDERR are redirected
# and fd6 to get input from the user regardless whereto STDIN is redirected.
# Duplicate STDIN to fd6 to be used by 'read' in the UserInput function
# cf. http://tldp.org/LDP/abs/html/x17974.html
exec 6<&0
# Close fd6 when exiting:
QuietAddExitTask "exec 6<&-"
# Duplicate STDOUT to fd7 to be used by the Print and UserOutput functions:
exec 7>&1
# Close fd7 when exiting:
QuietAddExitTask "exec 7>&-"
# Duplicate STDERR to fd8 to be used by the PrintError function:
exec 8>&2
# Close fd8 when exiting:
QuietAddExitTask "exec 8>&-"
# TODO: I <jsmeix@suse.de> wonder if it is really needed to explicitly close stuff when exiting
# because during exit all open files (and file descriptors) should be closed automatically.

# USR1 is used to abort on errors.
# It is not using PrintError but does direct output to the original STDERR:
builtin trap "echo '${MESSAGE_PREFIX}Aborting due to an error, check $RUNTIME_LOGFILE for details' 1>&8 ; kill $MASTER_PID" USR1

# Make sure nobody else can use trap:
function trap () {
    BugError "Forbidden usage of trap with '$@'. Use AddExitTask instead."
}

# For actually intended user messages output to the original STDOUT
# but only when the user launched 'rear -v' in verbose mode:
function Print () {
    test "$VERBOSE" && echo -e "${MESSAGE_PREFIX}$*" >&7 || true
}

# For actually intended user error messages output to the original STDERR
# regardless whether or not the user launched 'rear' in verbose mode:
function PrintError () {
    echo -e "${MESSAGE_PREFIX}$*" 1>&8 || true
}

# For messages that should only appear in the log file output to the current STDERR
# because (usually) the current STDERR is redirected to the log file:
function Log () {
    # Have a timestamp with nanoseconds precision in any case
    # so that any subsequent Log() calls get logged with precise timestamps:
    local timestamp=$( date +"%Y-%m-%d %H:%M:%S.%N " )
    if test $# -gt 0 ; then
        echo "${MESSAGE_PREFIX}${timestamp}$*" || true
    else
        echo "${MESSAGE_PREFIX}${timestamp}$( cat )" || true
    fi >&2
}

# For messages that should only appear in the log file when the user launched 'rear -d' in debug mode:
function Debug () {
    test "$DEBUG" && Log "$@" || true
}

# For messages that should appear in the log file and also
# on the user's terminal when the user launched 'rear -v' in verbose mode:
function LogPrint () {
    Log "$@"
    Print "$@"
}

# For messages that should appear in the log file and also
# on the user's terminal regardless whether or not the user launched 'rear' in verbose mode:
function LogPrintError () {
    Log "$@"
    PrintError "$@"
}

# For messages that should only appear in the syslog:
LogToSyslog() {
    # Send a line to syslog or messages file with input string with the tag 'rear':
    logger -t rear -i "${MESSAGE_PREFIX}$*"
}

# Check if any of the arguments is executable (logical OR condition).
# Using plain "type" without any option because has_binary is intended
# to know if there is a program that one can call regardless if it is
# an alias, builtin, function, or a disk file that would be executed
# see https://github.com/rear/rear/issues/729
function has_binary () {
    for bin in $@ ; do
        # Suppress success output via stdout (but keep failure output via stderr):
        if type $bin 1>/dev/null ; then
            return 0
        fi
    done
    return 1
}

# Get the name of the disk file that would be executed.
# In contrast to "type -p" that returns nothing for an alias, builtin, or function,
# "type -P" forces a PATH search for each NAME, even if it is an alias, builtin,
# or function, and returns the name of the disk file that would be executed
# see https://github.com/rear/rear/issues/729
function get_path () {
    type -P $1
}

# Error exit:
function Error () {
    LogPrintError "ERROR: $*"
    LogToSyslog "ERROR: $*"
    # TODO: I <jsmeix@suse.de> wonder if the "has_binary caller" test is still needed nowadays
    # because for me on SLE10 with bash-3.1-24 up to SLE12 with bash-4.2 'caller' is a shell builtin:
    if has_binary caller ; then
        # Print stack strace in reverse order to the current STDERR which is (usually) the log file:
        (   echo "==== ${MESSAGE_PREFIX}Stack trace ===="
            local c=0;
            while caller $((c++)) ; do
                # nothing to do
                :
            done | awk ' { l[NR]=$3":"$1" "$2 }
                         END { for (i=NR; i>0;) print "Trace "NR-i": "l[i--] }
                       '
            echo "${MESSAGE_PREFIX}Message: $*"
            echo "== ${MESSAGE_PREFIX}End stack trace =="
        ) >&2
    fi
    # Make sure Error exits the master process, even if called from child processes:
    kill -USR1 $MASTER_PID
}

# If return code is non-zero, bail out:
function StopIfError () {
    if (( $? != 0 )) ; then
        Error "$@"
    fi
}

# Exit if there is a bug in ReaR:
function BugError () {
    # Get the source file of actual caller script.
    # Usually this is ${BASH_SOURCE[1]} but BugError is also called
    # from (wrapper) functions in this script like BugIfError below.
    # When BugIfError is called the actual caller is the script
    # that had called BugIfError which is ${BASH_SOURCE[2]} because when
    # BugIfError is called ${BASH_SOURCE[0]} and ${BASH_SOURCE[1]}
    # are the same (i.e. this '_input-output-functions.sh' file).
    # Currently it is sufficient to test up to ${BASH_SOURCE[2]}
    # (i.e. currently there is at most one indirection).
    # With bash >= 3 the BASH_SOURCE array variable is supported and even
    # for older bash it should be fail-safe when unset variables evaluate to empty:
    local this_script="${BASH_SOURCE[0]}"
    local caller_source="${BASH_SOURCE[1]}"
    test "$caller_source" = "$this_script" && caller_source="${BASH_SOURCE[2]}"
    test "$caller_source" || caller_source="Relax-and-Recover"
    Error "
====================
BUG in $caller_source:
'$@'
--------------------
Please report this issue at https://github.com/rear/rear/issues
and include the relevant parts from $RUNTIME_LOGFILE
preferably with full debug information via 'rear -d -D $WORKFLOW'
===================="
}

# If return code is non-zero, there is a bug in ReaR:
function BugIfError () {
    if (( $? != 0 )) ; then
        BugError "$@"
    fi
}

# Show the user if there is an error:
PrintIfError() {
    # If return code is non-zero, show that on the user's terminal
    # regardless whether or not the user launched 'rear' in verbose mode:
    if (( $? != 0 )) ; then
        PrintError "$@"
    fi
}

# Log if there is an error;
LogIfError() {
    if (( $? != 0 )) ; then
        Log "$@"
    fi
}

# Log if there is an error and also show it to the user:
LogPrintIfError() {
    # If return code is non-zero, show that on the user's terminal
    # regardless whether or not the user launched 'rear' in verbose mode:
    if (( $? != 0 )) ; then
        LogPrintError "$@"
    fi
}

# Helper function for UserInput that is intended to output to the original STDOUT
# regardless whether or not the user launched 'rear' in verbose mode:
function UserOutput () {
    # Basically same as the function PrintError but to fd7 and without a MESSAGE_PREFIX:
    echo -e "$*" >&7 || true
}

# Helper function for UserInput that is intended to output to the original STDOUT
# regardless whether or not the user launched 'rear' in verbose mode
# plus logging the output in the log file (basically same as function LogPrintError):
function LogUserOutput () {
    Log "$@"
    UserOutput "$@"
}

# General function that is intended for basically any user input:
# Output happens via the original STDOUT and STDERR when 'rear' was launched
# (which is usually the terminal of the user who launched 'rear')
# the original STDOUT and STDERR file descriptors are saved as fd7 and fd8.
function UserInput () {
    # Set defaults or fallback values:
    local timeout=60
    # Avoid stderr if USER_INPUT_TIMEOUT is not set or empty and ignore wrong USER_INPUT_TIMEOUT:
    test "$USER_INPUT_TIMEOUT" -ge 0 2>/dev/null && timeout=$USER_INPUT_TIMEOUT
    local prompt="enter a choice number"
    # Avoid stderr if USER_INPUT_PROMPT is not set or empty:
    test "$USER_INPUT_PROMPT" 2>/dev/null && prompt="$USER_INPUT_PROMPT"
    local output_array=""
    local input_max_chars=1000
    # Avoid stderr if USER_INPUT_MAX_CHARS is not set or empty and ignore wrong USER_INPUT_MAX_CHARS:
    test "$USER_INPUT_MAX_CHARS" -ge 0 2>/dev/null && input_max_chars=$USER_INPUT_MAX_CHARS
    local input_delimiter=""
    local default_choice=""
    local user_input_ID=""
    # Get the options and their arguments:
    local option=""
    # Resetting OPTIND is necessary if getopts was used previously in the script
    # and because we are in a function we can even make OPTIND local:
    local OPTIND=1
    while getopts ":t:p:a:n:d:D:" option ; do
        case $option in
            (t)
                # Avoid stderr if OPTARG is not set or empty or not an integer value:
                test "$OPTARG" -ge 0 2>/dev/null && timeout=$OPTARG || Log "UserInput: Invalid -$option argument '$OPTARG' using fallback '$timeout'"
                ;;
            (p)
                prompt="$OPTARG"
                ;;
            (a)
                output_array="$OPTARG"
                ;;
            (n)
                # Avoid stderr if OPTARG is not set or empty or not an integer value:
                test "$OPTARG" -ge 0 2>/dev/null && input_max_chars=$OPTARG || Log "UserInput: Invalid -$option argument '$OPTARG' using fallback '$input_max_chars'"
                ;;
            (d)
                input_delimiter="$OPTARG"
                ;;
            (D)
                default_choice="$OPTARG"
                ;;
            (I)
                # Avoid stderr if OPTARG is not set or empty or not an integer value:
                test "$OPTARG" -ge 0 2>/dev/null && user_input_ID="$OPTARG" || Log "UserInput: Invalid -$option argument '$OPTARG' ignored"
                ;;
            (\?)
                BugError "UserInput: Invalid option: -$OPTARG"
                ;;
            (:)
                BugError "UserInput: Option -$OPTARG requires an argument"
                ;;
        esac
    done
    # Shift away the options and arguments:
    shift "$(( OPTIND - 1 ))"
    # Everything that is now left in "$@" is neither an option nor an option argument
    # so that now "$@" contains the trailing mass-arguments (POSIX calls them operands):
    local choices=( "$@" )
    local choice_index=0
    if ! test "${choices:=}" ; then
        # It is possible (it is no error) to specify no choices:
        Log "UserInput: No choices specified"
    else
        # Avoid stderr if default_choice is not set or empty or not an integer value:
        if test "$default_choice" -ge 0 2>/dev/null ; then
            # It is possible (it is no error) to specify a number as default choice that has no matching choice:
            test "${choices[$default_choice]:=}" || Log "UserInput: Default choice '$default_choice' not in choices"
        else
            # When the default choice is no number try to find if it is a choice
            # and if found use the choice index as default choice number:
            for choice in "${choices[@]}" ; do
                test "$default_choice" = "$choice" && default_choice=$choice_index
                (( choice_index += 1 ))
            done
            # It is possible (it is no error) to specify anything as default choice.
            # Avoid stderr if default_choice is not set or empty or not an integer value:
            test "$default_choice" -ge 0 2>/dev/null || Log "UserInput: Default choice not found in choices"
        fi
    fi
    # When an empty prompt was specified (via -p '') do not change that:
    if test "$prompt" ; then
        # Avoid stderr if default_choice or timeout is not set or empty or not an integer value:
        if test "$default_choice" -o "$timeout" -ge 1 2>/dev/null ; then
            prompt="$prompt ("
            if test "$default_choice" ; then
                # Avoid stderr if default_choice is not set or empty or not an integer value:
                if test "$default_choice" -ge 0 2>/dev/null ; then
                    prompt="$prompt default $(( default_choice + 1 ))"
                else
                    prompt="$prompt default '$default_choice'"
                fi
            fi
            # Avoid stderr if timeout is not set or empty or not an integer value:
            if test "$timeout" -ge 1 2>/dev/null ; then
                prompt="$prompt timeout $timeout"
            fi
            prompt="$prompt ) "
        fi
    fi
    # The actual work:
    # Show the choices with leading choice numbers 1) 2) 3) ... as in 'select' (i.e. starting at 1):
    local choice_number=1
    Log "UserInput shows the following selection list and prompt:"
    if test "${choices:=}" ; then
        for choice in "${choices[@]}" ; do
            LogUserOutput "$choice_number) $choice"
            (( choice_number += 1 ))
        done
    fi
    # Show the prompt unless an empty prompt was specified (via -p ''):
    test "$prompt" && LogUserOutput "$prompt"
    # Prepare the 'read' call:
    local read_options_and_arguments=""
    # When a zero timeout was specified (via -t 0) do not use it.
    # Avoid stderr if timeout is not set or empty or not an integer value:
    test "$timeout" -ge 1 2>/dev/null && read_options_and_arguments="$read_options_and_arguments -t $timeout"
    # When no output_array was specified (via -a myarr) do not use it:
    test "$output_array" && read_options_and_arguments="$read_options_and_arguments -a $output_array"
    # When zero input_max_chars was specified (via -n 0) do not use it.
    # Avoid stderr if input_max_chars is not set or empty or not an integer value:
    test "$input_max_chars" -ge 1 2>/dev/null && read_options_and_arguments="$read_options_and_arguments -n $input_max_chars"
    # When no input_delimiter was specified (via -d x) do not use it:
    test "$input_delimiter" && read_options_and_arguments="$read_options_and_arguments -d $input_delimiter"
    # Read the user input from the original STDIN that is saved as fd6 (see above):
    local user_input=""
    if read $read_options_and_arguments user_input 0<&6 ; then
        Log "UserInput: 'read' got as user input '$user_input'"
    else
        # Continue in any case because in case of errors the default choice is used.
        # Avoid stderr if timeout is not set or empty or not an integer value:
        if test "$timeout" -ge 1 2>/dev/null ; then
            Log "UserInput: 'read' finished with non-zero exit code probably because 'read' timed out"
        else
            Log "UserInput: 'read' finished with non-zero exit code"
        fi
    fi
    # When an output_array was specified it contains all user input words but we need only the first word:
    test "${output_array:=}" && user_input="${!output_array:=}"
    Log "UserInput: Actually used user input is '$user_input'"
    # When there is no user input use the "best" default choice that exists:
    if ! test "$user_input" ; then
        if ! test "$default_choice" ; then
            LogPrint "UserInput: No user input and no default choice so that the result is ''"
            echo ""
            return 101
        fi
        # Avoid stderr if default_choice is not set or empty or not an integer value:
        if ! test "$default_choice" -ge 0 2>/dev/null ; then
            LogPrint "UserInput: No user input and default choice no possible index in choices so that the result is '$default_choice'"
            echo "$default_choice"
            return 102
        fi
        if ! test "${choices[$default_choice]:=}" ; then
            LogPrint "UserInput: No user input and default choice not in choices so that the result is '$default_choice'"
            echo "$default_choice"
            return 103
        fi
        LogPrint "UserInput: No user input and default choice in choices so that the result is '${choices[$default_choice]}'"
        echo "${choices[$default_choice]}"
        return 104
    fi
    # When there is user input use it regardless of any default choice:
    if ! test "$choices" ; then
        LogPrint "UserInput: User input and no choices so that the result is '$user_input'"
        echo "$user_input"
        return 0
    fi
    # Avoid stderr if user_input is not set or empty or not an integer value:
    if ! test "$user_input" -ge 1 2>/dev/null ; then
        LogPrint "UserInput: User input no possible index in choices so that the result is '$user_input'"
        echo "$user_input"
        return 105
    fi
    choice_index=$(( user_input - 1 ))
    if ! test "${choices[$choice_index]:=}" ; then
        LogPrint "UserInput: User input not in choices so that the result is '$user_input'"
        echo "$user_input"
        return 106
    fi
    LogPrint "UserInput: User input in choices so that the result is '${choices[$choice_index]}'"
    echo "${choices[$choice_index]}"
    return 0
}

# Setup dummy progress subsystem as a default.
# Progress stuff replaced by dummy/noop
# cf. https://github.com/rear/rear/issues/887
ProgressStart() {
    : ;
}
ProgressStop() {
    : ;
}
ProgressError() {
    : ;
}
ProgressStep() {
    : ;
}
ProgressInfo() {
    : ;
}

