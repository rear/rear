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
        jobs -l 1>&2
        kill -9 "${JOBS[@]}" 1>&2
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
    test "$VERBOSE" && echo -e "${MESSAGE_PREFIX}$*" 1>&7 || true
}

# For normal output messages that are intended for user dialogs.
# For error messages that are intended for the user use 'PrintError'.
# In contrast to the 'Print' function output to the original STDOUT
# regardless whether or not the user launched 'rear' in verbose mode
# but output to the original STDOUT without a MESSAGE_PREFIX because
# MESSAGE_PREFIX is not helpful in normal user dialog output messages:
function UserOutput () {
    echo -e "$*" 1>&7 || true
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
    fi 1>&2
}

# For messages that should only appear in the log file when the user launched 'rear -d' in debug mode:
function Debug () {
    test "$DEBUG" && Log "$@" || true
}

# For messages that should appear in the log file when the user launched 'rear -d' in debug mode and
# that also appear on the user's terminal (in debug mode the verbose mode is set automatically):
function DebugPrint () {
    Debug "$@"
    test "$DEBUG" && Print "$@" || true
}

# For messages that should appear in the log file and also
# on the user's terminal when the user launched 'rear -v' in verbose mode:
function LogPrint () {
    Log "$@"
    Print "$@"
}

# For output plus logging that is intended for user dialogs.
# 'LogUserOutput' belongs to 'UserOutput' like 'LogPrint' belongs to 'Print':
function LogUserOutput () {
    Log "$@"
    UserOutput "$@"
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
        ) 1>&2
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

# Output the source file of the actual caller script:
function CallerSource () {
    # Get the source file of actual caller script.
    # Usually this is ${BASH_SOURCE[1]} but CallerSource is also called
    # from functions in this script like BugError and UserInput below
    # and BugError is again called from BugIfError in this script.
    # When BugIfError is called the actual caller is the script
    # that had called BugIfError which is ${BASH_SOURCE[3]}
    # because when BugIfError is called from a script
    # ${BASH_SOURCE[0]} is '_input-output-functions.sh' for the CallerSource call
    # ${BASH_SOURCE[1]} is '_input-output-functions.sh' for the BugError call
    # ${BASH_SOURCE[2]} is '_input-output-functions.sh' for the BugIfError call
    # ${BASH_SOURCE[3]} is the script that had called BugIfError.
    # Currently it is sufficient to inspect the execution call stack up to ${BASH_SOURCE[3]}
    # (i.e. currently there are at most three indirections as described above).
    # With bash >= 3 the BASH_SOURCE array variable is supported and even
    # for older bash it should be fail-safe when unset variables evaluate to empty:
    local this_script="${BASH_SOURCE[0]}"
    # Note the "off by one" for the BASH_LINENO array index because
    # https://www.gnu.org/software/bash/manual/html_node/Bash-Variables.html
    # reads (excerpt):
    # ${BASH_LINENO[$i]} is the line number in the source file (${BASH_SOURCE[$i+1]}) where ${FUNCNAME[$i]} was called
    # (or ${BASH_LINENO[$i-1]} if referenced within another shell function). Use LINENO to obtain the current line number.
    local caller_source="${BASH_SOURCE[1]}"
    local caller_source_lineno="${BASH_LINENO[0]}"
    if test "$caller_source" = "$this_script" ; then
        caller_source="${BASH_SOURCE[2]}"
        caller_source_lineno="${BASH_LINENO[1]}"
    fi
    if test "$caller_source" = "$this_script" ; then
        caller_source="${BASH_SOURCE[3]}"
        caller_source_lineno="${BASH_LINENO[2]}"
    fi
    if test "$caller_source" ; then
        echo "$caller_source line $caller_source_lineno"
        return 0
    fi
    # Fallback output:
    echo "Relax-and-Recover"
}

# Exit if there is a bug in ReaR:
function BugError () {
    local caller_source="$( CallerSource )"
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

# General function that is intended for basically any user input.
#   Output happens via the original STDOUT and STDERR when 'rear' was launched
#   (which is usually the terminal of the user who launched 'rear') and
#   input is read from the original STDIN when 'rear' was launched
#   (which is usually the keyboard of the user who launched 'rear').
# Synopsis:
#   UserInput [-t timeout] [-p prompt] [-a output_array] [-n input_max_chars] [-d input_delimiter] [-D default_input] [-I user_input_ID] [choices]
#   The options -t -p -a -n -d  match the ones for the 'read' bash builtin.
#   The option [choices] are the values that are shown to the user as available choices as in the select bash keyword.
#   The option [-D default_input] specifies what is used as default response when the user does not enter something.
#       Usuallly this is one of the choices values or an index of one of the choices (the first choice has index 0)
#       but the default input can be anything else (in particular for free input without predefined choices).
#   The option [-I user_input_ID] is intended to make UserInput working full automated (e.g. when ReaR runs unattended)
#       via a user-specified array of user input values like
#           USER_INPUT_VALUES[123]='input for UserInput -I 123'
#           USER_INPUT_VALUES[456]='input for UserInput -I 456'
#           USER_INPUT_VALUES[789]='input for UserInput -I 789'
#       where each USER_INPUT_VALUES array member index that matches a user_input_ID of a particular 'UserInput -I' call
#       that will be autoresponded with the matching value of the user input array.
# Usage examples:
# * Wait endlessly until the user hits the [Enter] key (without '-t 0' a default timeout is used):
#       UserInput -t 0 -p 'Press [Enter] to continue'
# * Wait up to 30 seconds until the user hits the [Enter] key (i.e. proceed automatically after 30 seconds):
#       UserInput -t 30 -p 'Press [Enter] to continue'
# * Get an input value from the user (proceed automatically with empty input_value after the default timeout).
#   Leading and trailing spaces are cut from the actual user input:
#       input_value="$( UserInput -p 'Enter the input value' )"
# * Get an input value from the user (proceed automatically with the 'default input' after 2 minutes).
#   The timeout interrupts ongoing user input so that 'default input' is used when the user
#   does not hit the [Enter] key to finish his input before the timeout happens:
#       input_value="$( UserInput -t 120 -p 'Enter the input value' -D 'default input' )"
# * Get an input value from the user by offering him possible choices (proceed with the default choice after the default timeout).
#   The choices index starts with 0 so that '-D 1' specifies the second choice as default choice:
#       input_value="$( UserInput -p 'Select a choice' -D 1 'first choice' 'second choice' 'third choice' )"
# * When the user enters an arbitrary value like 'foo bar' this actual user input is used as input_value.
#   The UserInput function provides the actual user input and its caller needs to check the actual user input.
#   To enforce that the actual user input is one of the choices an endless retrying loop could be used like:
#       choices=( 'first choice' 'second choice' 'third choice' )
#       until IsInArray "$input_value" "${choices[@]}" ; do
#           input_value="$( UserInput -p 'Select a choice' -D 'second choice' "${choices[@]}" )"
#       done
#   Because the default choice is one of the choices the endless loop does not contradict that ReaR can run unattended.
#   When that code runs unattended (i.e. without actual user input) the default choice is used after the default timeout.
# * The default choice can be anything as in:
#       input_value="$( UserInput -p 'Select a choice' -D 'fallback value' -n 1 'first choice' 'second choice' 'third choice' )"
#   The caller needs to check the actual input_value which could be 'fallback value' when the user hits the [Enter] key
#   or one of 'first choice' 'second choice' 'third choice' when the user hits the [1] [2] or [3] key respectively
#   or any other character as actual user input ('-n 1' limits the actual user input to one single character).
# * When up to 9 possible choices are shown using '-n 1' lets the user choose one by only pressing a [1] ... [9] key
#   without the additional [Enter] key that is normally needed to submit the input. With an endless loop that retries
#   when the actual user input is not one of the choices it is possible to implement valid and convenient user input:
#       choices=( 'default choice' 'first alternative choice' 'second alternative choice' )
#       until IsInArray "$choice" "${choices[@]}" ; do
#           choice="$( UserInput -t 60 -p 'Hit a choice number key' -D 0 -n 1 "${choices[@]}" )"
#       done
# * To to let UserInput autorespond full automated a predefined user input value specify the user input value
#   with a matching index in the USER_INPUT_VALUES array (e.g. specify that it in your local.conf file) like
#       USER_INPUT_VALUES[123]='third choice'
#   and call UserInput with that USER_INPUT_VALUES array index as the '-I' option value like
#       input_value="$( UserInput -p 'Select a choice' -D 1 -I 123 'first choice' 'second choice' 'third choice' )"
#   which lets UserInput autorespond with 'third choice'.
#   This means a precondition for an automated response is that a UserInput call has a user_input_ID specified.
#   No predefined user input value should exist to get real user input for a 'UserInput -I 123' call
#   or an existing predefined user input value should be unset before 'UserInput -I 123' is called like
#       unset 'USER_INPUT_VALUES[123]'
#   or the user can interupt any automated response within a relatively short time (minimum is only 1 second).
function UserInput () {
    # First and foremost log how UserInput was actually called so that subsequent 'Log' messages are comprehensible:
    Log "UserInput $*"
    # Set defaults or fallback values:
    # Have a relatively big default timeout of 5 minutes to avoid that the timeout interrupts ongoing user input:
    local timeout=300
    # Avoid stderr if USER_INPUT_TIMEOUT is not set or empty and ignore wrong USER_INPUT_TIMEOUT:
    test "$USER_INPUT_TIMEOUT" -ge 0 2>/dev/null && timeout=$USER_INPUT_TIMEOUT
    # Have some seconds (at least one second) delay when an automated user input is used to be fail-safe against
    # a possibly false specified predefined user input value for an endless retrying loop of UserInput calls
    # that would (without the delay) run in a tight loop that wastes resources (CPU, diskspace, and memory)
    # and fills up the ReaR log file (and the disk - which is a ramdisk for 'rear recover')
    # with some KiB data each second that may let 'rear recover' fail with 'out of diskspace/memory'.
    # The default automated input interrupt timeout is 5 seconds to give the user a reasonable chance
    # to recognize the right automated input on his screen and interrupt it when needed:
    local automated_input_interrupt_timeout=5
    # Avoid stderr if USER_INPUT_INTERRUPT_TIMEOUT is not set or empty and ignore wrong USER_INPUT_INTERRUPT_TIMEOUT:
    test "$USER_INPUT_INTERRUPT_TIMEOUT" -ge 1 2>/dev/null && automated_input_interrupt_timeout=$USER_INPUT_INTERRUPT_TIMEOUT
    local default_prompt="enter your input"
    local prompt="$default_prompt"
    # Avoid stderr if USER_INPUT_PROMPT is not set or empty:
    test "$USER_INPUT_PROMPT" 2>/dev/null && prompt="$USER_INPUT_PROMPT"
    local output_array=""
    local input_max_chars=1000
    # Avoid stderr if USER_INPUT_MAX_CHARS is not set or empty and ignore wrong USER_INPUT_MAX_CHARS:
    test "$USER_INPUT_MAX_CHARS" -ge 0 2>/dev/null && input_max_chars=$USER_INPUT_MAX_CHARS
    local input_delimiter=""
    local default_input=""
    local user_input_ID=""
    # Get the options and their arguments:
    local option=""
    # Resetting OPTIND is necessary if getopts was used previously in the script
    # and because we are in a function we can even make OPTIND local:
    local OPTIND=1
    while getopts ":t:p:a:n:d:D:I:" option ; do
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
                default_input="$OPTARG"
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
    if test "${choices:=}" ; then
        # Avoid stderr if default_input is not set or empty or not an integer value:
        if test "$default_input" -ge 0 2>/dev/null ; then
            # It is possible (it is no error) to specify a number as default input that has no matching choice:
            test "${choices[$default_input]:=}" || Log "UserInput: Default choice '$default_input' not in choices"
        else
            # When the default input is no number try to find if it is a choice
            # and if found use the choice index as default input:
            for choice in "${choices[@]}" ; do
                test "$default_input" = "$choice" && default_input=$choice_index
                (( choice_index += 1 ))
            done
            # It is possible (it is no error) to specify anything as default input.
            # Avoid stderr if default_input is not set or empty or not an integer value:
            test "$default_input" -ge 0 2>/dev/null || Log "UserInput: Default choice not found in choices"
        fi
        # Use a better default prompt if no prompt was specified when there are choices:
        test "$default_prompt" = "$prompt" && prompt="enter a choice number"
    else
        # It is possible (it is no error) to specify no choices:
        Log "UserInput: No choices specified"
    fi
    # Prepare what to show as default and/or timeout:
    local default_and_timeout=""
    # Avoid stderr if default_input or timeout is not set or empty or not an integer value:
    if test "$default_input" -o "$timeout" -ge 1 2>/dev/null ; then
        if test "$default_input" ; then
            # Avoid stderr if default_input is not set or empty or not an integer value:
            if test "$default_input" -ge 0 2>/dev/null ; then
                # The default input is a number:
                if test "${choices[$default_input]:=}" ; then
                    # When the default input is a number that is a valid choice index,
                    # show the default as the choice number that is shown (cf. choice_number below):
                    default_and_timeout="default $(( default_input + 1 ))"
                else
                    # When the default input number is not a valid choice index, show it as is:
                    default_and_timeout="default $default_input"
                fi
            else
                # Show the default input string as is:
                default_and_timeout="default '$default_input'"
            fi
        fi
        # Avoid stderr if timeout is not set or empty or not an integer value:
        if test "$timeout" -ge 1 2>/dev/null ; then
            if test "$default_and_timeout" ; then
                default_and_timeout="$default_and_timeout timeout $timeout seconds"
            else
                default_and_timeout="timeout $timeout seconds"
            fi
        fi
    fi
    # The actual work:
    # Have caller_source as an array so that plain $caller_source is only the filename (with path):
    local caller_source=( $( CallerSource ) )
    # Avoid stderr if user_input_ID is not set or empty or not an integer value:
    if test "$user_input_ID" -ge 0 2>/dev/null ; then
        # In debug mode show the user the script that called UserInput and what user_input_ID was specified
        # so that the user can prepare an automated response for that UserInput call (without digging in the code):
        DebugPrint "UserInput -I $user_input_ID needed in ${caller_source[@]}"
    else
        # Generate a unique default user_input_ID if it was not specified:
        # The generated user_input_ID should be different for different scripts
        # wherefrom the UserInput is called (i.e. different caller_source) and it should be different
        # for different visual appearence to the user (i.e. different choices, prompt, and default_input)
        # but it should be independent of the caller script path (ReaR installation path must not matter)
        # and it should be independent of non-meaningful characters in what is shown to the user like
        # whitespaces and special characters so that it only depends on letters (case insensitive) and digits.
        # Intentionally same caller script basename in different ReaR subdirectories
        # (e.g. the various 400_restore_backup.sh scripts for different backup methods)
        # does not result different generated user_input_ID so that UserInput calls with same visual appearence
        # (regarding meaningful characters) in caller scripts with same basename get same generated user_input_ID.
        # E.g. when several scripts with same basename call the same
        #   UserInput -p 'Press [Enter] to continue'
        # then same UserInput calls for same purpose (same basename callers is considered same purpose)
        # get same generated user_input_ID. If this is not wanted user_input_ID must be explicitly specified.
        local caller_source_filename="$( basename $caller_source )"
        local hash_input=$( echo "$caller_source_filename" "${choices[@]}" "$prompt" "$default_input" | tr -c -d '[:alnum:]' | tr '[:upper:]' '[:lower:]' )
        # Neither 'sum' nor 'cksum' is in PROGS nor REQUIRED_PROGS so that 'md5sum' is used if it is there.
        # Because 'md5sum' is only in PROGS but not in REQUIRED_PROGS do a simple fallback if 'md5sum' is not there:
        local hash_hex=""
        if has_binary md5sum ; then
            # Have hash_hex as an array so that plain $hash_hex is the actual md5sum
            # because 'md5sum' outputs the actual md5sum plus the filename (which is '-' here for stdin):
            hash_hex=( $( echo "$hash_input" | md5sum ) )
        else
            Log "No 'md5sum' there, using simple fallback to generate user_input_ID"
            # The md5sum is a 32 characters hex-number so that we produce that also as fallback.
            # The main drawback of the simple fallback is that only the first 32 input characters matter:
            local lower_alnum='0123456789abcdefghijklmnopqrstuvwxyz'
            # Avoid possibly leading '0' digits to get a hex-number with 32 significant digits:
            local hex_no_null='123456789abcdef123456789abcdef123456'
            hash_hex=$( echo "$hash_input" | tr -c -d "$lower_alnum" | tr "$lower_alnum" "$hex_no_null" | head -c 32 )
        fi
        # The actual md5sum is a 32 characters hex-number like 'b1946ac92492d2347c6235b4d2611184'
        # which results a decimal integer up to 340282366920938463463374607431768211455 (it has 39 digits) as result of
        #   echo "ibase=16; FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF" | bc -l
        # Note that 'bc' requires upper case characters for hex-number input:
        local hash_uppercase=$( echo $hash_hex | tr '[:lower:]' '[:upper:]' )
        local hash_decimal=$( echo "ibase=16 ; $hash_uppercase" | bc -l )
        # In bash 3.x the array index must be a decimal integer number up to 2^63 - 1 = 9223372036854775807 (it has 19 digits)
        # so that the md5sum output must be converted into a decimal integer number with 18 digits.
        # Because all substrings of a good hash (and md5 is reasonably good despite being cryptographically unsafe)
        # are equally random one can take any bits you like from the string, cf.
        # https://crypto.stackexchange.com/questions/26850/what-is-degree-of-randomness-in-individual-bits-of-md5-hash
        # https://stackoverflow.com/questions/3819712/is-any-substring-of-a-hash-md5-sha1-more-random-than-another
        # we take the first 18 digits of the up to 39 digits from the decimal integer md5sum as generated user_input_ID:
        user_input_ID=$( echo $hash_decimal | head -c 18 )
        # In debug mode show the user the script that called UserInput and what generated user_input_ID it has
        # so that the user can prepare an automated response for that UserInput call (without digging in the code):
        DebugPrint "UserInput (generated ID $user_input_ID) needed in ${caller_source[@]}"
    fi
    # First of all show the prompt unless an empty prompt was specified (via -p '')
    # so that the prompt can be used as some kind of header line that introduces the user input
    # and separates the following user input from arbitrary other output lines before:
    test "$prompt" && LogUserOutput "$prompt"
    # List the choices (if exists):
    if test "${choices:=}" ; then
        # This comment contains the opening parentheses ( ( ( to keep paired parentheses:
        # Show the choices with leading choice numbers 1) 2) 3) ... as in 'select' (i.e. starting at 1):
        local choice_number=1
        for choice in "${choices[@]}" ; do
            # This comment contains the opening parenthesis ( to keep paired parenthesis:
            LogUserOutput "$choice_number) $choice"
            (( choice_number += 1 ))
        done
    fi
    # Finally show the default and/or the timeout (if exists):
    test "$default_and_timeout" && LogUserOutput "($default_and_timeout)"
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
    # Get the user input:
    local user_input=""
    # When a (non empty) predefined user input value exists use that as automated user input:
    if test "${USER_INPUT_VALUES[$user_input_ID]:-}" ; then
        LogUserOutput "UserInput: Will use predefined input '${USER_INPUT_VALUES[$user_input_ID]}' from USER_INPUT_VALUES[$user_input_ID]"
        # Let the user interrupt the automated user input:
        LogUserOutput "Hit any key to interrupt the automated input (timeout $automated_input_interrupt_timeout seconds)"
        # automated_input_interrupt_timeout is at least 1 second (see above) and do not echo the input (it is meaningless here):
        if read -t $automated_input_interrupt_timeout -n 1 -s 0<&6 ; then
            Log "UserInput: automated input interrupted by user"
            # Show the prompt again (or at least the default prompt) to signal the user that now he can and must enter something:
            test "$prompt" && LogUserOutput "$prompt" || LogUserOutput "$default_prompt"
            test "$default_and_timeout" && LogUserOutput "($default_and_timeout)"
        else
            user_input="${USER_INPUT_VALUES[$user_input_ID]}"
            # When a (non empty) output_array was specified it must contain all user input words:
            test "$output_array" && read -a "$output_array" <<<"$user_input"
        fi
    fi
    # When there is no (non empty) automated user input read the user input:
    if ! test "$user_input" ; then
        # Read the user input from the original STDIN that is saved as fd6 (see above):
        if read $read_options_and_arguments user_input 0<&6 ; then
            Log "UserInput: 'read' got as user input '$user_input'"
        else
            # Continue in any case because in case of errors the default input is used.
            # Avoid stderr if timeout is not set or empty or not an integer value:
            if test "$timeout" -ge 1 2>/dev/null ; then
                Log "UserInput: 'read' finished with non-zero exit code probably because 'read' timed out"
            else
                Log "UserInput: 'read' finished with non-zero exit code"
            fi
        fi
    fi
    # When an output_array was specified it contains all user input words and then output_array is meant for the actual result.
    # To be able to return something via 'echo' even when an output_array was specified we use only the first word here
    # which should be sufficient because when the complete user input is needed the output_array can and must be used:
    if test "$output_array" ; then
        Log "UserInput: The output array '$output_array' contains all user input words."
        user_input="${!output_array}"
        Log "UserInput: To return something only the first user input word '$user_input' is used."
    fi
    # When there is no user input or when the user input is only spaces use the "best" fallback or default that exists
    # (to test for non-empty and no-spaces user input there must be no double quotes because test " " results true):
    if ! test $user_input ; then
        if ! test "$default_input" ; then
            DebugPrint "UserInput: No user input and no default input so that the result is ''"
            echo ""
            return 101
        fi
        # Avoid stderr if default_input is not set or empty or not an integer value:
        if ! test "$default_input" -ge 0 2>/dev/null ; then
            DebugPrint "UserInput: No user input and default input no possible index in choices so that the result is '$default_input'"
            echo "$default_input"
            return 102
        fi
        if ! test "${choices[$default_input]:=}" ; then
            DebugPrint "UserInput: No user input and default input not in choices so that the result is '$default_input'"
            echo "$default_input"
            return 103
        fi
        DebugPrint "UserInput: No user input but default input in choices so that the result is '${choices[$default_input]}'"
        echo "${choices[$default_input]}"
        return 104
    fi
    # When there is user input use it regardless of any default input:
    if ! test "$choices" ; then
        DebugPrint "UserInput: User input and no choices so that the result is '$user_input'"
        echo "$user_input"
        return 0
    fi
    # Avoid stderr if user_input is not set or empty or not an integer value:
    if ! test "$user_input" -ge 1 2>/dev/null ; then
        DebugPrint "UserInput: User input no possible index in choices so that the result is '$user_input'"
        echo "$user_input"
        return 105
    fi
    choice_index=$(( user_input - 1 ))
    if ! test "${choices[$choice_index]:=}" ; then
        DebugPrint "UserInput: User input not in choices so that the result is '$user_input'"
        echo "$user_input"
        return 106
    fi
    DebugPrint "UserInput: User input in choices so that the result is '${choices[$choice_index]}'"
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

