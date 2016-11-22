# input-output-functions.sh
#
# NOTE: This is the first file to be sourced (because of _ in the name) which is why
#	it contains some special stuff like EXIT_TASKS that I want to be available everywhere

# input-output functions for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# the sequence $'...' is an special bash expansion with backslash-escaped characters
# see "Words of the form $'string' are treated specially" in "man bash"
# that works at least down to bash 3.1 in SLES10:
LF=$'\n'

# collect exit tasks in this array
# without the empty string as initial value ${EXIT_TASKS[@]} would be an unbound variable
# that would result an error exit if 'set -eu' is used:
EXIT_TASKS=("")
# add $* as a task to be done at the end
function AddExitTask () {
    # NOTE: we add the task at the beginning to make sure that they are executed in reverse order
    # I use $* on purpose because I want to get one string from all args!
    EXIT_TASKS=( "$*" "${EXIT_TASKS[@]}" )
    Debug "Added '$*' as an exit task"
}
function QuietAddExitTask () {
    # I use $* on purpose because I want to get one string from all args!
    EXIT_TASKS=( "$*" "${EXIT_TASKS[@]}" )
}

# remove $* from the task list
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

# do all exit tasks
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

# activate the trap function
builtin trap "DoExitTasks" 0
# keep PID of main process
readonly MASTER_PID=$$
# duplication STDOUT to fd7 to use for Print
exec 7>&1
QuietAddExitTask "exec 7>&-"
# USR1 is used to abort on errors, not using Print to always print to the original STDOUT, even if quiet
builtin trap "echo 'Aborting due to an error, check $LOGFILE for details' >&7 ; kill $MASTER_PID" USR1

# make sure nobody else can use trap
function trap () {
    BugError "Forbidden use of trap with '$@'. Use AddExitTask instead."
}

# Check if any of the arguments is executable (logical OR condition).
# Using plain "type" without any option because has_binary is intended
# to know if there is a program that one can call regardless if it is
# an alias, builtin, function, or a disk file that would be executed
# see https://github.com/rear/rear/issues/729
function has_binary () {
    for bin in $@ ; do
        if type $bin >&8 2>&1 ; then
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
    type -P $1 2>&8
}

Error() {
	# If first argument is numerical, use it as exit code
	if [ $1 -eq $1 ] 2>&8; then
		EXIT_CODE=$1
		shift
	else
		EXIT_CODE=1
	fi
	VERBOSE=1
	LogPrint "ERROR: $*"
	if has_binary caller; then
		# Print stack strace on errors in reverse order
		(
			echo "=== Stack trace ==="
			local c=0;
			while caller $((c++)); do :; done | awk '
				{ l[NR]=$3":"$1" "$2 }
				END { for (i=NR; i>0;) print "Trace "NR-i": "l[i--] }
			'
			echo "Message: $*"
			echo "==================="
		) >&2
	fi
	LogToSyslog "ERROR: $*"
	kill -USR1 $MASTER_PID # make sure that Error exits the master process, even if called from child processes :-)
}

StopIfError() {
	# If return code is non-zero, bail out
	if (( $? != 0 )); then
		Error "$@"
	fi
}

function BugError () {
    EXIT_CODE=1
    # If first argument is numerical, use it as exit code:
    if [ $1 -eq $1 ] 2>/dev/null ; then
        EXIT_CODE=$1
        shift
    fi
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
    # Call Error explicitly with the above set EXIT_CODE:
    Error $EXIT_CODE "
====================
BUG in $caller_source:
'$@'
--------------------
Please report this issue at https://github.com/rear/rear/issues
and include the relevant parts from $LOGFILE
preferably with full debug information via 'rear -d -D $WORKFLOW'
===================="
}

BugIfError() {
	# If return code is non-zero, bail out
	if (( $? != 0 )); then
		BugError "$@"
	fi
}

function Debug () {
    test -n "$DEBUG" && Log "$@" || true
}

function Print () {
    test -n "$VERBOSE" && echo -e "$*" >&7 || true
}

# print if there is an error
PrintIfError() {
	# If return code is non-zero, bail out
	if (( $? != 0 )); then
		Print "$@"
	fi
}

if [[ "$DEBUG" || "$DEBUGSCRIPTS" ]]; then
	Stamp() {
		date +"%Y-%m-%d %H:%M:%S.%N "
	}
else
	Stamp() {
		date +"%Y-%m-%d %H:%M:%S "
	}
fi

function Log () {
    if test $# -gt 0 ; then
        echo "$(Stamp)$*"
    else
        echo "$(Stamp)$(cat)"
    fi >&2
}

# log if there is an error
LogIfError() {
	# If return code is non-zero, bail out
	if (( $? != 0 )); then
		Log "$@"
	fi
}

function LogPrint () {
    Log "$@"
    Print "$@"
}

# log/print if there is an error
LogPrintIfError() {
	# If return code is non-zero, bail out
	if (( $? != 0 )); then
		LogPrint "$@"
	fi
}

# setup dummy progress subsystem as a default
# not VERBOSE, Progress stuff replaced by dummy/noop
exec 8>/dev/null # start ProgressPipe listening at fd 8
QuietAddExitTask "exec 8>&-" # new method, close fd 8 at exit

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

LogToSyslog() {
    # send a line to syslog or messages file with input string
    logger -t rear -i "$*"
}

