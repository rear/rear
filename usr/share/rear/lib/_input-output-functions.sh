# input-output-functions.sh
#
# NOTE: This is the first file to be sourced (because of _ in the name) which is why
#	it contains some special stuff like EXIT_TASKS that I want to be available everywhere

# input-output functions for Relax & Recover
#
#    Relax & Recover is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.

#    Relax & Recover is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with Relax & Recover; if not, write to the Free Software
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
	test "$removed" == "yes" || Log "Could not remove exit task '$*' (not found). Exit Tasks:
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
		kill -9 "${JOBS[@]}"
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
builtin trap "echo 'ABORTING DUE TO AN ERROR, CHECK $LOGFILE FOR DETAILS' 1>&7 ; kill $MASTER_PID" USR1

# make sure nobody else can use trap
function trap () {
	BugError "Forbidden use of trap with '$@'. Use AddExitTask instead."
}

Error() {
	if type caller &>/dev/null ; then
		# Print stack strace on error
		let c=0 ; while caller $c ; do let c++ ; done | sed 's/^/Trace: /' 1>&2 ; unset c
	fi

	VERBOSE=1
	EXIT_CODE=1
	LogPrint "ERROR: $*"
	kill -USR1 $MASTER_PID # make sure that Error exits the master process, even if called from child processes :-)
}

BugError() {
	Error "BUG BUG BUG! " "$@" "
	Please report this as a bug to the authors of $PRODUCT"
}

Debug() {
	test "$DEBUG" && Log "$@"
}

Print() {
	test "$VERBOSE" && echo -e "$*" 1>&7
}

Stamp() {
	date +"%Y-%m-%d %H:%M:%S "
}

Log() {
	if test $# -gt 0 ; then
		echo "$(Stamp)$*" 
	else
		echo "$(Stamp)$(cat)" 
	fi 1>&2
}

LogPrint() {
	Log "$@"
	Print "$@"
}

# log if there is an error and exit
# $1 = return code to check
LogIfError() {
	test $# -le 0 && Error "LogIfError called without return code to check !"
	test $1 -gt 0 || return 0
	shift
	Error "$@"
}

# setup dummy progress subsystem as a default
# not VEROSE, Progress stuff replaced by dummy/noop
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
ProgressStepSingleChar() {
	: ;
}


ProgressStopOrError() {
	test $# -le 0 && Error "ProgressStopOrError called without return code to check !"
	if test "$1" -gt 0 ; then
		shift
		ProgressError
		Error "$@"
	else
		ProgressStop
	fi
}

ProgressStopIfError() {
	test $# -le 0 && Error "ProgressStopIfError called without return code to check !"
	test "$1" -gt 0 || return 0
	shift
	ProgressError
	Error "$@"
}

SpinnerSleep() {
	if test $# -le 0 ; then
		sec=1
	else
		sec=$1
	fi
	for i in `seq 1 $sec`
	do
		sleep 1
		ProgressStep
	done
}
