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

# Prepare that STDOUT and STDERR can be later redirected to anywhere
# (e.g. both STDOUT and STDERR can be later redirected to the log file).
# To be able to output on the original STDOUT and STDERR when 'rear' was launched
# (which is usually the terminal of the user who launched 'rear')
# the original STDOUT and STDERR file descriptors are saved as fd7 and fd8
# so that ReaR functions for actually intended user messages can use fd7 and fd8
# to show messages to the user regardless whereto STDOUT and STDERR are redirected.
# Duplicate STDOUT to fd7 to be used by the Print function:
exec 7>&1
# Close fd7 when exiting:
QuietAddExitTask "exec 7>&-"
# Duplicate STDERR to fd8 to be used by the PrintError function:
exec 8>&2
# Close fd8 when exiting:
QuietAddExitTask "exec 8>&-"

# USR1 is used to abort on errors.
# It is not using PrintError but does direct output to the original STDERR:
builtin trap "echo '${MESSAGE_PREFIX}Aborting due to an error, check $RUNTIME_LOGFILE for details' >&8 ; kill $MASTER_PID" USR1

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
    echo -e "${MESSAGE_PREFIX}$*" >&8 || true
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
        if type $bin &>/dev/null ; then
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
    type -P $1 2>/dev/null
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

