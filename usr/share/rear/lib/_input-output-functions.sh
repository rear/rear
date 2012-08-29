# input-output-functions.sh
#
# NOTE: This is the first file to be sourced (because of _ in the name) which is why
#	it contains some special stuff like EXIT_TASKS that I want to be available everywhere

# input-output functions for Relax-and-Recover
#
#    Relax-and-Recover is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.

#    Relax-and-Recover is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with Relax-and-Recover; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
#

LF="
"
# collect exit tasks in this array
EXIT_TASKS=()
# add $* as a task to be done at the end
AddExitTask() {
	# NOTE: we add the task at the beginning to make sure that they are executed in reverse order
	EXIT_TASKS=( "$*" "${EXIT_TASKS[@]}" ) # I use $* on purpose because I want to get one string from all args!
	Debug "Added '$*' as an exit task"
}
QuietAddExitTask() {
	EXIT_TASKS=( "$*" "${EXIT_TASKS[@]}" ) # I use $* on purpose because I want to get one string from all args!
}

# remove $* from the task list
RemoveExitTask() {
	local removed=""
	for (( c=0 ; c<${#EXIT_TASKS[@]} ; c++ )) ; do
		if test "${EXIT_TASKS[c]}" == "$*" ; then
			unset 'EXIT_TASKS[c]' # the ' ' protect from bash expansion, however unlikely to have a file named EXIT_TASKS in pwd...
			removed=yes
			Debug "Removed '$*' from the list of exit tasks"
		fi
	done
	[ "$removed" == "yes" ]
	LogIfError "Could not remove exit task '$*' (not found). Exit Tasks:
$(
	for task in "${EXIT_TASKS[@]}" ; do
		echo "$task"
	done
)"
}

# do all exit tasks
DoExitTasks() {
	Log "Running exit tasks."
	# kill all running jobs
	JOBS=( $(jobs -p) )
	if test "$JOBS" ; then
                Log "The following jobs are still active:"
                jobs -l >&2
		kill -9 "${JOBS[@]}" >&2
		sleep 1 # allow system to clean up after killed jobs
	fi
	for task in "${EXIT_TASKS[@]}" ; do
		Debug "Exit task '$task'"
		eval "$task"
	done
}
# activate the trap function
builtin trap "DoExitTasks" 0
# keep PID of main process
MASTER_PID=$$
# duplication STDOUT to fd7 to use for Print
exec 7>&1
QuietAddExitTask "exec 7>&-"
# USR1 is used to abort on errors, not using Print to always print to the original STDOUT, even if quiet
builtin trap "echo 'Aborting due to an error, check $LOGFILE for details' >&7 ; kill $MASTER_PID" USR1

# make sure nobody else can use trap
function trap () {
	BugError "Forbidden use of trap with '$@'. Use AddExitTask instead."
}

# Check if any of the binaries/aliases exist
has_binary() {
	for bin in $@; do
		if type $bin >&8 2>&1; then
			return 0
		fi
	done
	return 1
}

get_path() {
	type -p $1 2>&8
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
	kill -USR1 $MASTER_PID # make sure that Error exits the master process, even if called from child processes :-)
}

StopIfError() {
	# If return code is non-zero, bail out
	if (( $? != 0 )); then
		Error "$@"
	fi
}

BugError() {
	# If first argument is numerical, use it as exit code
	if [ $1 -eq $1 ] 2>&8; then
		EXIT_CODE=$1
		shift
	else
		EXIT_CODE=1
	fi
	Error "BUG BUG BUG! " "$@" "
=== Issue report ===
Please report this unexpected issue at: https://github.com/rear/rear/issues
Also include the relevant bits from $LOGFILE

HINT: If you can reproduce the issue, try using the -d or -D option !
===================="
}

BugIfError() {
	# If return code is non-zero, bail out
	if (( $? != 0 )); then
		BugError "$@"
	fi
}

Debug() {
	test "$DEBUG" && Log "$@"
}

Print() {
	test "$VERBOSE" && echo -e "$*" >&7
}

# print if there is an error
PrintIfError() {
	# If return code is non-zero, bail out
	if (( $? != 0 )); then
		Print "$@"
	fi
}

if [[ "$DEBUG" || "$DEBUG_SCRIPTS" ]]; then
	Stamp() {
		date +"%Y-%m-%d %H:%M:%S.%N "
	}
else
	Stamp() {
		date +"%Y-%m-%d %H:%M:%S "
	}
fi

Log() {
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

LogPrint() {
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