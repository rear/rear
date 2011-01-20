# input-output-functions.sh
#
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
Usage() {
	echo "$USAGE" 
	exit 1
}
# collect exit tasks in this array
EXIT_TASKS=()
# add $* as a task to be done at the end
AddExitTask() {
	# NOTE: we add the task at the beginning to make sure that they are executed in reverse order
	EXIT_TASKS=( "$*" "${EXIT_TASKS[@]}" ) # I use $* on purpose because I want to get one string from all args!
	Log "Added '$*' as an exit task"
}

# remove $* from the task list
RemoveExitTask() {
	local removed=""
	for (( c=0 ; c<${#EXIT_TASKS[@]} ; c++ )) ; do
		if test "${EXIT_TASKS[c]}" == "$*" ; then
			unset 'EXIT_TASKS[c]' # the ' ' protect from bash expansion, however unlikely to have a file named EXIT_TASKS in pwd...
			removed=yes
			Log "Removed '$*' from the list of exit tasks"
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
	for task in "${EXIT_TASKS[@]}" ; do
		eval "$task"
	done
}
# activate the trap function
trap "DoExitTasks" 0

Error() {
	Log ERROR "$*"
	echo "ERROR: $*" 
	exit 1
}

BugError() {
	Error "BUG BUG BUG! " "$@" "
	Please report this as a bug to the authors of $PRODUCT"
}

Verbose() {
	test "$VERBOSE" && echo "$*"
}

Print() {
	echo -e "$*"
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
	Log "ERROR: $@"
	Error "$@"
}

if tty -s ; then
	######################## BEGIN Progress Indicator
	# ProgressPipe uses fd 8 as a communication pipe
	
	# The ProgressThread listens on stdin and writes out progress chars for each line
	# The signals USR2 and USR1 start and stop the process character printing
	ProgressThread() {
		exec 3>&2- # open fd 3 to real stderr
		debugoutput=0
		trap "progress_counter=-1" USR1
		trap "progress_counter=0" USR2
		trap "debugoutput=1" PWR
		progress_counter=-1
		### A set of spinners coming from Alpine
#		progress_chars=( '<|>' '</>' '<->' '<\>' )
#		progress_chars=( '--|-(o)-|--' '--/-(o)-\--' '----(o)----' '--\-(o)-/--' )
#		progress_chars=( '<|>' '<\>' '<->' '</>' )
#		progress_chars=( '|  ' ' / ' ' _ ' '  \ ' '  |' '  |' ' \ ' ' _ ' ' / ' '|  ')
#		progress_chars=( '.' '..' '...' '....' '...' '..' )
#		progress_chars=( ' . ' ' o ' ' O ' ' o ' )
#		progress_chars=( '....' ' ...' '. ..' '.. .' '... ' )
#		progress_chars=( '.   ' ' .  ' '  . ' '   .' '  . ' ' .  ' )
#		progress_chars=( '.oOo' 'oOo.' 'Oo.o' 'o.oO' )
#		progress_chars=( '.     .' ' .   . ' '  . .  ' '   .   ' '   +   ' '   *   ' '   X   ' '   #   ' '       ')
#		progress_chars=( '. O' 'o o' 'O .' 'o o' )
#		progress_chars=( ' / ' ' _ ' ' \ ' ' | ' ' \ ' ' _ ' )
#		progress_chars=( '    ' '*   ' '-*  ' '--* ' ' --*' '  --' '   -' )
#		progress_chars=( '\/\/' '/\/\' )
#		progress_chars=( '\|/|' '|\|/' '/|\|' '|/|\' )
		progress_chars=( '\' '|' '/' '-' )
		while read command text ; do
			if [ $debugoutput -eq 1 ] ; then
				echo "PROGRESS: $command $text" 1>&3
			fi
			if [ "$command" == "START" ] ; then
				echo -en "\e[2K\r$text  \e7${progress_chars[0]}"
				progress_counter=0
			elif [ "$command" == "INFO" ] ; then
				echo
				echo -en "\e[2K\r$text  \e7"
			fi
			if [ $progress_counter -gt -1 ] ; then
				let progress_counter++
				test $progress_counter -ge ${#progress_chars[@]} && progress_counter=0
				echo -en "\e8${progress_chars[progress_counter]}"

			fi
		done
	}
				
	exec 8> >(ProgressThread) # start ProgressPipe listening at fd 8
	QuietAddExitTask "exec 8>&-" # new method
	# we need the PID of the process thread to be able to signal it
	ProgressPID=$!
	
	ProgressStart() {
		echo -en "\e[2K\r$*  \e7"
		test "$QUIET" || kill -USR2 $ProgressPID
	}
	
	ProgressStop() {
		test "$QUIET" || kill -USR1 $ProgressPID
		echo -e "\e8\e[KOK"
	}
	
	ProgressError() {
		kill -USR1 $ProgressPID
		echo -e "\e8\e[KFAILED"
	}
	
	ProgressStep() {
		echo noop 1>&8
	}

	ProgressStepSingleChar() {
		while read -rn 1 ; do
			echo noop 1>&8
			echo -n "$REPLY" 1>&2
		done
	}
else
	# no tty, disable progress display altogether
	
	exec 8>/dev/null # start ProgressPipe listening at fd 8
	trap "exec 8>&-" 0 # close fd 8 at exit
	
	ProgressStart() {
		echo -n "$*  "
	}
	
	ProgressStop() {
		echo -e "OK"
	}
	
	ProgressError() {
		echo -e "FAILED"
	}
	
	ProgressStep() {
		: ;
	}

	ProgressStepSingleChar() {
		while read -n 1 ; do
			: ;
		done
	}
fi
####################### END Progress Indicator

ProgressStopOrError() {
	test $# -le 0 && Error "ProgressStopOrError called without return code to check !"
	if test "$1" -gt 0 ; then
		shift
		ProgressError
		Log "ERROR: $@"
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
	Log "ERROR: $@"
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
