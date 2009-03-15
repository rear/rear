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
		Error "$@"
	}
		
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
		progress_chars=( \\ \| / - )
		while read command text ; do
			test "$debugoutput" -eq 1 && echo "PROGRESS: $command $text" 1>&3
			if [[ "$command" == START ]] ; then
				echo -en "$text  "
				progress_counter=0
			fi
			if [ "$command" = "INFO" ] ; then
				echo -en "\r$text  "
			fi
			if [[ "$progress_counter" -gt -1 ]] ; then
				let progress_counter++
				test "$progress_counter" -gt 3 && progress_counter=0
				echo -en "\b""${progress_chars[progress_counter]}"
			fi
		done
	}
				
	exec 8> >(ProgressThread) # start ProgressPipe listening at fd 8
	trap "exec 8>&-" 0 # close fd 8 at exit
	# we need the PID of the process thread to be able to signal it
	ProgressPID=$!
	
	ProgressStart() {
		echo -n "$*  "
		test "$QUIET" || kill -USR2 $ProgressPID
	}
	
	ProgressStop() {
		test "$QUIET" || kill -USR1 $ProgressPID
		echo -e "\bOK"
	}
	
	ProgressError() {
		kill -USR1 $ProgressPID
		echo -e "\bFAILED"
	}
	
	ProgressStep() {
		echo noop 1>&8
	}

	ProgressStepSingleChar() {
		while read -rn 1 ; do
			echo noop 1>&8
			test -z "$REPLY" && echo 1>&2 || echo -n "$REPLY" 1>&2
		done
	}
else
	# no tty, disable progress display altogether
	ProgressStopOrError() {
		test $# -le 0 && Error "ProgressStopOrError called without return code to check !"
		if test $1 -gt 0 ; then
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
		test $1 -gt 0 || return 0
		shift
		ProgressError
		Log "ERROR: $@"
		Error "$@"
	}
		
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

