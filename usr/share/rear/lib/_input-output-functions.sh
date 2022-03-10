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

# Keep PID of main process (i.e. the main script that the user had launched as 'rear'):
readonly MASTER_PID=$$

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

# Output PIDs of all descendant processes of a parent process PID (specified as $1)
# i.e. the parent and its direct children plus recursively all subsequent children of children
# (i.e. parent PID, children PIDs, grandchildren PIDs, great-grandchildren PIDs, and so on)
# where each PID is output on a separated line.
# Calling "ps --ppid $parent_pid -o pid=" recursively is needed
# because otherwise it does not work on all systems.
# E.g. on SLES10 and SLES11 it would work to simply call "ps -g $parent_pid -o pid="
#   # sleep 20 | grep foo & ( sleep 30 | grep bar & ) ; sleep 1 ; ps f -g $$
#   [1] 3622
#     PID TTY      STAT   TIME COMMAND
#    3372 pts/0    Ss     0:00 -bash
#    3621 pts/0    S      0:00  \_ sleep 20
#    3622 pts/0    S      0:00  \_ grep foo
#    3627 pts/0    R+     0:00  \_ ps f -g 3372
#    3625 pts/0    S      0:00 grep bar
#    3624 pts/0    S      0:00 sleep 30
# but this way it does no longer work e.g. on SLES12 or openSUSE Leap 42.3
#   # sleep 20 | grep foo & ( sleep 30 | grep bar & ) ; sleep 1 ; ps f -g $$ ; ps --ppid $$ -o pid,args
#   [1] 6518
#     PID TTY      STAT   TIME COMMAND
#     PID COMMAND
#    6517 sleep 20
#    6518 grep --color=auto foo
#    6524 ps --ppid 2674 -o pid,args
# where there is really no longer any output of the "ps f -g $$" command.
# Because of the recursion the output of the deepest nested call appears first
# so that it lists latest descendants PIDs first and the initial parent PID last
# (i.e. great-grandchildren PIDs, grandchildren PIDs, children PIDs, parent PID)
# so that the output ordering is already the right ordering to cleanly terminate
# a sub-tree of processes below a parent process and finally the parent process
# (i.e. first terminate great-grandchildren processes, then grandchildren processes,
# then children processes, and finally terminate the parent process itself).
# This termination functionality is used in the DoExitTasks() function.
function descendants_pids () { 
    local parent_pid=$1
    # Successfully ignore PIDs that do not exist or do no longer exist:
    kill -0 $parent_pid 2>/dev/null || return 0
    # Recursively call this function for the actual children:
    local child_pid="" 
    for child_pid in $( ps --ppid $parent_pid -o pid= ) ; do
        # At least the sub-shell of the $( ps --ppid $parent_pid -o pid= )
        # is always reported as a child_pid so that the following test avoids
        # that descendants_pids is uselessly recursively called for it:
        kill -0 $child_pid 2>/dev/null && descendants_pids $child_pid
    done
    # Only show PIDs that actually still exist which skips PIDs of children
    # that were running a short time (like called programs by this function)
    # and had already finished here:
    kill -0 $parent_pid 2>/dev/null && echo $parent_pid || return 0
}

# Show descendant processes PIDs with their commands in the log
# so that later the plain PIDs in the log get more comprehensible
# (e.g. when terminate_descendants_pids is called afterwards):
function log_descendants_pids () {
    # What works sufficiently on all systems is "pstree -Aplau MASTER_PID"
    # but the pstree command is not available by default in the ReaR recovery system
    # (cf. https://github.com/rear/rear/issues/1755) so that the ps command is used as fallback.
    # Because "ps f -g MASTER_PID -o pid,args" only works on older systems like SLES10 and SLES11
    # (cf. the above comment for the descendants_pids function)
    # a last resort fallback "ps --ppid MASTER_PID -o pid,args" is used for newer systems like SLES12
    # (at least on SLES12 "ps f -g MASTER_PID -o pid,args" results non-zero exit code when nothing is shown):
    Log "$( pstree -Aplau $MASTER_PID || ps f -g $MASTER_PID -o pid,args || ps --ppid $MASTER_PID -o pid,args )"
}

# Terminate all still running descendant processes of MASTER_PID but do not terminate the MASTER_PID process itself.
# First terminate great-grandchildren processes, then grandchildren processes, then children processes.
# This termination functionality is used in the DoExitTasks() function.
function terminate_descendants_from_grandchildren_to_children () {
    # Some descendant processes commands could be much too long (e.g. a 'tar ...' command)
    # to be usefully shown completely in the below LogPrint information (could be many lines)
    # so that the descendant process command output is truncated after at most remaining_columns.
    # We reserve 40 characters for the log prefix and show at most 40 characters of the command.
    # The shell variable COLUMNS is not defined in noninteractive bash, so we set a fallback
    # cf. https://github.com/rear/rear/pull/1720#discussion_r328686592
    local remaining_columns
    test $COLUMNS && remaining_columns=$COLUMNS || remaining_columns=80
    remaining_columns=$(( remaining_columns - 40 ))
    test $remaining_columns -ge 40 || remaining_columns=40
    # Terminate all still running descendant processes of MASTER_PID
    # but do not terminate the MASTER_PID process itself because
    # the MASTER_PID process must run the exit tasks below:
    local descendant_pid=""
    local not_yet_terminated_pids=""
    # Send SIGTERM to all still running descendant processes of MASTER_PID:
    for descendant_pid in $( descendants_pids $MASTER_PID ) ; do
        # The descendant_pids() function outputs at least MASTER_PID
        # plus the PID of the subshell of the $( descendants_pids MASTER_PID )
        # so that it is tested that a descendant_pid is not MASTER_PID
        # and that a descendant_pid is still running before SIGTERM is sent:
        test $MASTER_PID -eq $descendant_pid && continue
        kill -0 $descendant_pid || continue
        LogPrint "Terminating descendant process $descendant_pid $( ps -p $descendant_pid -o args= | cut -b-$remaining_columns )"
        kill -SIGTERM $descendant_pid 1>&2
        # For each descendant process wait one second to let it terminate to be on the safe side
        # that e.g. grandchildren can actually cleanly terminate before children get SIGTERM sent
        # i.e. every child process can cleanly terminate before its parent gets SIGTERM:
        sleep 1
        if kill -0 $descendant_pid ; then
            # Keep the current ordering also in not_yet_terminated_pids
            # i.e. grandchildren before children:
            not_yet_terminated_pids="$not_yet_terminated_pids $descendant_pid"
            LogPrint "Descendant process $descendant_pid not yet terminated"
        fi
    done
    # No need to kill a descendant processes if all were already terminated:
    test "$not_yet_terminated_pids" || return 0
    # Kill all not yet terminated descendant processes:
    for descendant_pid in $not_yet_terminated_pids ; do
        if kill -0 $descendant_pid ; then
            LogPrint "Killing descendant process $descendant_pid $( ps -p $descendant_pid -o args= | cut -b-$remaining_columns )"
            kill -SIGKILL $descendant_pid 1>&2
            # For each killed descendant process wait one second to let it die to be on the safe side
            # that e.g. grandchildren were actually removed by the kernel before children get SIGKILL sent
            # i.e. every child process is already gone before its parent process may get SIGKILL so that
            # the parent (that may wait for its child) has a better chance to still cleanly terminate:
            sleep 1
            kill -0 $descendant_pid && LogPrint "Killed descendant process $descendant_pid still there"
        else
            # Show a counterpart message to the above 'not yet terminated' message
            # e.g. after a child process was killed its parent may have terminated on its own:
            LogPrint "Descendant process $descendant_pid terminated"
        fi
    done
}

# Terminate all still running descendant processes of MASTER_PID but do not terminate the MASTER_PID process itself.
# First children processes, then grandchildren processes, then great-grandchildren processes.
# This termination functionality is used in the Error() function.
# The following code is basically the same as in terminate_descendants_from_grandchildren_to_children (see there for explanatory comments)
# except small but crucial differences here which is the reason why that kind of code exists two times.
function terminate_descendants_from_children_to_grandchildren () {
    # Some descendant processes commands could be much too long (e.g. a 'tar ...' command):
    local remaining_columns
    test $COLUMNS && remaining_columns=$COLUMNS || remaining_columns=80
    remaining_columns=$(( remaining_columns - 40 ))
    test $remaining_columns -ge 40 || remaining_columns=40
    # Terminate all still running descendant processes of MASTER_PID
    # but do not terminate the MASTER_PID process itself because
    # the MASTER_PID process must run the exit tasks below
    # and do not terminate the current process that runs this code here.
    local current_pid=""
    local descendant_pid=""
    local not_yet_terminated_pids=""
    local descendant_pids_from_children_to_parent="$( descendants_pids $MASTER_PID )"
    # Reverse the ordering of the PIDs to get them from parent to children:
    local descendant_pids_from_parent_to_children=""
    for descendant_pid in $descendant_pids_from_children_to_parent ; do
        descendant_pids_from_parent_to_children="$descendant_pid $descendant_pids_from_parent_to_children"
    done
    # Send SIGTERM to all still running descendant processes of MASTER_PID
    # except the current process that runs this code here which is usually MASTER_PID
    # but this code here could be also run within a (possibly deeply nested) subshell:
    if test "$BASHPID" ; then
        current_pid=$BASHPID
    else
        # When there is no BASHPID we need to determine our current PID indirectly.
        # Things like https://stackoverflow.com/questions/20725925/get-pid-of-current-subshell
        # to get the current PID by calling a subshell like "( : ; bash -c 'echo $PPID' )"
        # do not work when the current PID is already a (possibly deeply nested) subshell.
        # Interestingly on command line "mypid=$( bash -c 'echo $PPID' )"
        # works even in a nested subshell but it does no longer work when it is used in a sourced script.
        # One way that works is that our current PID is the parent PID of a command that is called directly here
        # (without any indirection via another subshell like "current_pid=$( whatever_command )" or when using a pipe)
        # like "tmpfile=$( mktemp ) ; cat /proc/self/stat >$tmpfile ; current_pid=$( cut -d ' ' -f4 $tmpfile ) ; rm $tmpfile"
        # but the simplest way is using the bash builtin 'read' to get our current PID directly from /proc/self/stat
        # (our current PID is the first field in /proc/self/stat and our parent PID is the fourth field):
        read current_pid junk </proc/self/stat
    fi
    for descendant_pid in $descendant_pids_from_parent_to_children ; do
        # Test that a descendant_pid is not MASTER_PID or the current process that runs this code here
        # and that a descendant_pid is still running before SIGTERM is sent:
        test $MASTER_PID -eq $descendant_pid && continue
        test $current_pid -eq $descendant_pid && continue
        kill -0 $descendant_pid || continue
        LogPrint "Terminating child process $descendant_pid $( ps -p $descendant_pid -o args= | cut -b-$remaining_columns )"
        kill -SIGTERM $descendant_pid 1>&2
    done
    # In contrast to the terminate_descendants_from_grandchildren_to_children function above
    # we do not wait here one second for each processes when it gets SIGTERM above
    # because we send SIGTERM first to children then to grandchildren
    # so that it does not make sense to give a grandchild one second
    # to let it cleanly terminate before its paretnt child gets SIGTERM.
    # Wait one second to let the above processes that got SIGTERM actually terminate
    # before determining which did not yet terminate and should get a SIGKILL:
    sleep 1
    # Determine which of the above processes that got SIGTERM did not yet terminate
    # except MASTER_PID and the current process that runs this code here:
    for descendant_pid in $descendant_pids_from_parent_to_children ; do
        test $MASTER_PID -eq $descendant_pid && continue
        test $current_pid -eq $descendant_pid && continue
        if kill -0 $descendant_pid ; then
            # Keep the current ordering also in not_yet_terminated_pids
            # i.e. children before grandchildren:
            not_yet_terminated_pids="$not_yet_terminated_pids $descendant_pid"
            LogPrint "Child process $descendant_pid not yet terminated"
        fi
    done
    # No need to kill a descendant processes if all were already terminated:
    test "$not_yet_terminated_pids" || return 0
    # Kill all not yet terminated descendant processes that already got SIGTERM above:
    for descendant_pid in $not_yet_terminated_pids ; do
        if kill -0 $descendant_pid ; then
            LogPrint "Killing child process $descendant_pid $( ps -p $descendant_pid -o args= | cut -b-$remaining_columns )"
            kill -SIGKILL $descendant_pid 1>&2
        else
            # Show a counterpart message to the above 'not yet terminated' message:
            LogPrint "Child process $descendant_pid terminated"
        fi
    done
    # In contrast to the terminate_descendants_from_grandchildren_to_children function above
    # we do not wait here one second for each processes when it gets SIGKILL above
    # with the same reasoning behind as above where SIGTERM was sent.
    # Wait one second the let the killed descendant processes actually die:
    sleep 1
    # Show which killed descendant processes are still there:
    for descendant_pid in $not_yet_terminated_pids ; do
        kill -0 $descendant_pid && LogPrint "Killed child process $descendant_pid still there"
    done
}

# Do all exit tasks:
function DoExitTasks () {
    # First of all restore the ReaR default bash flags and options (see usr/sbin/rear)
    # because otherwise in case of a bash error exit when e.g. "set -e -u -o pipefail" was set
    # all the exit tasks related code would also run with "set -e -u -o pipefail" still set
    # which may abort exit tasks related code anywhere with a "sudden death" bash error exit
    # where in particular no longer the EXIT_FAIL_MESSAGE (cf. below) would be shown
    # so that for the user ReaR would "just somehow silently abort" in this case
    # cf. https://github.com/rear/rear/issues/1747#issuecomment-371055121
    # and https://github.com/rear/rear/issues/700#issuecomment-327755633
    # To avoid useless 'set -x' debug output for the apply_bash_flags_and_options_commands call
    # run it in the current shell environment where stderr is redirected to /dev/null before:
    { apply_bash_flags_and_options_commands "$DEFAULT_BASH_FLAGS_AND_OPTIONS_COMMANDS" ; } 2>/dev/null
    # Apply debugscript mode also for the exit tasks:
    test "$DEBUGSCRIPTS" && set -$DEBUGSCRIPTS_ARGUMENT
    LogPrint "Exiting $PROGRAM $WORKFLOW (PID $MASTER_PID) and its descendant processes ..."
    # Wait some time to let descendant processes terminate on their own
    # e.g. after Ctrl+C by the user descendant processes should terminate on their own
    # at least the "foreground processes" (with the current terminal process group ID)
    # but "background processes" would not terminate on their own after Ctrl+C
    # cf. https://github.com/rear/rear/issues/1712
    # and also the Error function terminates descendant processes on its own via
    # terminate_descendants_from_children_to_grandchildren that sleeps two times one second
    # so that we wait here three seconds to be on the safe side that a possibly running
    # terminate_descendants_from_children_to_grandchildren has done its job and finished
    # to avoid that two functions run in parallel that terminate descendant processes:
    sleep 3
    # Show descendant processes PIDs with their commands in the log
    # so that the plain PIDs in the log get more comprehensible
    # when terminate_descendants_from_grandchildren_to_children is called afterwards:
    log_descendants_pids
    # Terminate all still running descendant processes of MASTER_PID
    # but do not terminate the MASTER_PID process itself because
    # the MASTER_PID process must run the exit tasks below:
    terminate_descendants_from_grandchildren_to_children
    # Finally run the exit tasks:
    LogPrint "Running exit tasks"
    local exit_task=""
    for exit_task in "${EXIT_TASKS[@]}" ; do
        Debug "Exit task '$exit_task'"
        eval "$exit_task"
    done
}

# The command (actually the function) DoExitTasks is executed on exit from the shell:
builtin trap "DoExitTasks" EXIT

# Prepare that STDIN STDOUT and STDERR can be later redirected to anywhere
# (e.g. both STDOUT and STDERR can be later redirected to the log file).
# To be able to output on the original STDOUT and STDERR when 'rear' was launched and
# to be able to input (i.e. 'read') from the original STDIN when 'rear' was launched
# (which is usually the keyboard and display of the user who launched 'rear')
# the original STDIN STDOUT and STDERR file descriptors are saved as fd6 fd7 and fd8
# so that ReaR functions for actually intended user messages can use fd7 and fd8
# to show messages to the user regardless where to STDOUT and STDERR are redirected
# and fd6 to get input from the user regardless where to STDIN is redirected.
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

# Verbose exit in case of errors which is in particular needed when 'set -e' is active because
# otherwise a 'set -e' error exit would happen silently which could look as if all was o.k.
# cf. https://github.com/rear/rear/issues/700#issuecomment-327755633
# The separated EXIT_FAIL_MESSAGE variable is used to denote a failure exit.
# One cannot use EXIT_CODE for that because there are cases where a non-zero exit code
# is the intended outcome (e.g. in the 'checklayout' workflow, cf. usr/sbin/rear):
QuietAddExitTask "(( EXIT_FAIL_MESSAGE )) && echo '${MESSAGE_PREFIX}$PROGRAM $WORKFLOW failed, check $RUNTIME_LOGFILE for details' 1>&8"

# USR1 is used to abort on errors.
# It is not using PrintError but does direct output to the original STDERR.
# Set EXIT_FAIL_MESSAGE to 0 to avoid an additional failed message via the QuietAddExitTask above:
builtin trap "EXIT_FAIL_MESSAGE=0 ; echo '${MESSAGE_PREFIX}Aborting due to an error, check $RUNTIME_LOGFILE for details' 1>&8 ; kill $MASTER_PID" USR1

# Make sure nobody else can use trap:
function trap () {
    BugError "Forbidden usage of trap with '$*'. Use AddExitTask instead."
}

# For actually intended user messages output to the original STDOUT
# but only when the user launched 'rear -v' in verbose mode:
function Print () {
    # It is crucial to append to /dev/$DISPENSABLE_OUTPUT_DEV when $DISPENSABLE_OUTPUT_DEV is not 'null'.
    # In debugscript mode $DISPENSABLE_OUTPUT_DEV is 'stderr' (see usr/sbin/rear)
    # and /dev/stderr is fd2 which is redirected to append to RUNTIME_LOGFILE (see usr/sbin/rear)
    # so that 2>/dev/stderr would truncate RUNTIME_LOGFILE to zero size (see 'REDIRECTION' in "man bash")
    # but 2>>/dev/stderr does not change things so that fd2 output is still appended to RUNTIME_LOGFILE:
    { test "$VERBOSE" && echo "${MESSAGE_PREFIX}$*" 1>&7 || true ; } 2>>/dev/$DISPENSABLE_OUTPUT_DEV
}

# For normal output messages that are intended for user dialogs.
# For error messages that are intended for the user use 'PrintError'.
# In contrast to the 'Print' function output to the original STDOUT
# regardless whether or not the user launched 'rear' in verbose mode
# but output to the original STDOUT without a MESSAGE_PREFIX because
# MESSAGE_PREFIX is not helpful in normal user dialog output messages:
function UserOutput () {
    { echo "$*" 1>&7 || true ; } 2>>/dev/$DISPENSABLE_OUTPUT_DEV
}

# For actually intended user error messages output to the original STDERR
# regardless whether or not the user launched 'rear' in verbose mode:
function PrintError () {
    { echo "${MESSAGE_PREFIX}$*" 1>&8 || true ; } 2>>/dev/$DISPENSABLE_OUTPUT_DEV
}

# For messages that should only appear in the log file output to the current STDERR
# because (usually) the current STDERR is redirected to the log file:
function Log () {
    # RUNTIME_LOGFILE does not yet exists in case of early Error() in usr/sbin/rear
    test -w "$RUNTIME_LOGFILE" || return 0
    # Have a timestamp with nanoseconds precision in any case
    # so that any subsequent Log() calls get logged with precise timestamps:
    { local timestamp=$( date +"%Y-%m-%d %H:%M:%S.%N " )
      local prefix="${MESSAGE_PREFIX}${timestamp}"
      # prefix_blanks has the printable characters in prefix replaced with blanks for indentation:
      local prefix_blanks="$( tr '[:print:]' ' ' <<<"$prefix" )"
      local message=""
      local log_message=""
      test $# -gt 0 && message="$*" || message="$( cat )"
      # The first line of message is prefixed with MESSAGE_PREFIX and timestamp
      # and all subsequent lines in message are indented by prefix_blanks
      # via bash parameter expansion ${message//$LF/$LF$prefix_blanks}
      #   ${...}            - interpret ... using parameter expansion
      #   message           - name of the variable containing the content
      #   //...             - replace all instances of ...
      #   $LF               - the literal newline character (see 'LF' above)
      #   /...              - replace with ...
      #   $LF$prefix_blanks - the literal newline character followed by the indentation blanks
      # cf. https://superuser.com/questions/955935/how-can-i-replace-a-newline-with-its-escape-sequence
      # that uses the literal newline character inline as in ${...//$'\n'/...}
      # but that results partially wrong parameter expansion with bash version 3.1.17 in SLES10
      # that seems to get somehow confused by the single quotes within parameter expansion:
      #   # MESSAGE_PREFIX="message prefix "
      #   # timestamp=$( date +"%Y-%m-%d %H:%M:%S.%N " )
      #   # message="$( echo -e 'fist line\nsecond line\nthird line')"
      #   # prefix="${MESSAGE_PREFIX}${timestamp}"
      #   # prefix_blanks="$( tr '[:print:]' ' ' <<<"$prefix" )"
      #   # log_message="${MESSAGE_PREFIX}${timestamp}${message//$'\n'/$'\n'$prefix_blanks}"
      #   # echo "$log_message"
      #   message prefix 2021-06-24 10:49:39.824719000 fist line'
      #   '                                             second line'
      #   '                                             third line
      # so we use the LF variable (cf. how LF is set above)
      #   # LF=$'\n'
      #   # log_message="${MESSAGE_PREFIX}${timestamp}${message//$LF/$LF$prefix_blanks}"
      #   # echo "$log_message"
      #   message prefix 2021-06-24 10:49:39.824719000 fist line
      #                                                second line
      #                                                third line
      # to make that parameter expansion also works with bash version 3.1.17 in SLES10:
      log_message="${MESSAGE_PREFIX}${timestamp}${message//$LF/$LF$prefix_blanks}"
    } 2>>/dev/$DISPENSABLE_OUTPUT_DEV
    # Append the log message explicitly to the log file to ensure that intended log messages
    # actually appear in the log file even inside { ... } 2>>/dev/$DISPENSABLE_OUTPUT_DEV
    # e.g. as in { COMMAND || Log "COMMAND failed" ; } 2>>/dev/$DISPENSABLE_OUTPUT_DEV
    # cf. the 2>>/dev/$DISPENSABLE_OUTPUT_DEV usage in the RequiredSharedObjects function
    # and in build/GNU/Linux/100_copy_as_is.sh and build/GNU/Linux/390_copy_binaries_libraries.sh
    echo "$log_message" >>"$RUNTIME_LOGFILE" || true
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

# For important messages that should appear in the log file and also
# on the user's terminal regardless whether or not the user launched 'rear' in verbose mode.
# LogPrintError does not error out (the Error function is meant to error out).
# LogPrintError is meant to show error messages when we do not want to error out,
# (for example when at the end of "rear recover" it failed to install a bootloader).
# LogPrintError is also meant to show important "error-like" messages to the user
# (for example when the user must decide if that means a real error in his case)
# and other important messages that must appear on the user's terminal
# cf. https://blog.schlomo.schapiro.org/2015/04/warning-is-waste-of-my-time.html
function LogPrintError () {
    Log "$@"
    PrintError "$@"
}

# For messages that should only appear in the syslog:
function LogToSyslog () {
    # Send a line to syslog or messages file with input string with the tag 'rear':
    logger -t rear -i "${MESSAGE_PREFIX}$*"
}

# Check if any of the arguments is executable (logical OR condition).
# Using plain "type" without any option because has_binary is intended
# to know if there is a program that one can call regardless if it is
# an alias, builtin, function, or a disk file that would be executed
# see https://github.com/rear/rear/issues/729
function has_binary () {
    for bin in "$@" ; do
        # Suppress success output via stdout which is crucial when has_binary is called
        # in other functions that provide their intended function results via stdout
        # to not pollute intended function results with intermixed has_binary stdout
        # (e.g. the RequiredSharedObjects function) but keep failure output via stderr:
        type $bin 1>/dev/null && return 0
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

# Output the source file of the actual caller script and its line number:
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

# Error exit:
function Error () {
    # Get the last sourced script out of the log file:
    # Using the CallerSource function is not sufficient here because CallerSource results
    # the file where this Error function is called which can also be a lib/*-functions.sh
    # but showing *-functions.sh would not be as helpful for the user as the last actual script.
    # Each sourced script gets logged as 'timestamp Including sub-path/to/script_file_name.sh' and
    # valid script files names are of the form NNN_script_name.sh (i.e. with leading 3-digit number)
    # but also the outdated scripts with leading 2-digit number get sourced
    # see the SourceStage function in lib/framework-functions.sh
    # so that we grep for script files names with two or more leading numbers:
    if test -s "$RUNTIME_LOGFILE" ; then
        { local last_sourced_script_log_entry=( $( grep -o ' Including .*/[0-9][0-9].*\.sh' $RUNTIME_LOGFILE | tail -n 1 ) )
          # The last_sourced_script_log_entry contains: Including sub-path/to/script_file_name.sh
          local last_sourced_script_sub_path="${last_sourced_script_log_entry[1]}"
          local last_sourced_script_filename="$( basename $last_sourced_script_sub_path )"
          # When it errors out in sbin/rear last_sourced_script_filename is empty which would result bad looking output
          # cf. https://github.com/rear/rear/issues/1965#issuecomment-439437868
          test "$last_sourced_script_filename" || last_sourced_script_filename="$SCRIPT_FILE"
        } 2>>/dev/$DISPENSABLE_OUTPUT_DEV
    fi
    # Do not log the error message right now but after the currently last log messages were shown:
    PrintError "ERROR: $*"
    # Show some additional hopefully meaningful output on the user's terminal
    # (no need to log that again here because it is already in the log file)
    # in particular the normal stdout and stderr messages of the last called programs
    # to make the root cause more obvious to the user without the need to analyze the log file
    # cf. https://github.com/rear/rear/issues/1875#issuecomment-407039065
    # Extract lines starting when the last script was sourced (logged as 'Including sub-path/to/script.sh')
    # but do not use last_sourced_script_sub_path because it contains '/' characters that let sed fail with
    #   sed: -e expression #1, char ...: extra characters after command
    # because the '/' characters would need to be escaped in the sed expression so that
    # we simply use last_sourced_script_filename in the sed expression.
    # Extract at most up to a line that is usually logged as '++ Error ...' or '++ BugError ...'
    # (but do not stop at lines that are logged like '++ StopIfError ...' or '++ PrintError ...')
    # if such a '+ Error' or '+ BugError' line exists, otherwise sed proceeds to the end
    # (the sed pattern '[Bug]*Error' is fuzzy because it would also match things like 'uuggError').
    # The reason to stop at a line that contains '+ [Bug]*Error ' is that in debugscript mode '-D'
    # a BugError or Error function call with a multi line error message (e.g. BugError does that)
    # results 'set -x' debug output of that function call in the log file that looks like:
    #   ++ [Bug]Error 'first error message line
    #   second error message line
    #   third error message line
    #   ...
    #   last error message line'
    # Because of the newlines in the error message subsequent lines appear without a leading '+' character
    # so that those debug output lines are indistinguishable from normal stdout/stderr output of programs,
    # cf. https://github.com/rear/rear/pull/1877
    # Thereafter ('+ [Bug]*Error ' lines were needed before) skip 'set -x' lines (lines that start with a '+' character)
    # and skip the initial 'Including sub-path/to/script.sh' line that is always found
    # to keep only the actual stdout and stderr messages of the last called programs
    # so we can test if messages were actually found via 'test "string of messages"' for emptiness.
    # Show at most the last 8 lines because too much before the actual error may cause more confusion than help.
    # Add two spaces indentation for better readability what those extracted log file lines are.
    # Some messages could be too long to be usefully shown on the user's terminal so that they are truncated after 200 bytes:
    if test -s "$RUNTIME_LOGFILE" ; then
        { local last_sourced_script_log_messages="$( sed -n -e "/Including .*$last_sourced_script_filename/,/+ [Bug]*Error /p" $RUNTIME_LOGFILE | egrep -v "^\+|Including .*$last_sourced_script_filename" | tail -n 8 | sed -e 's/^/  /' | cut -b-200 )" ; } 2>>/dev/$DISPENSABLE_OUTPUT_DEV
        if test "$last_sourced_script_log_messages" ; then
            PrintError "Some latest log messages since the last called script $last_sourced_script_filename:"
            PrintError "$last_sourced_script_log_messages"
        fi
    fi
    # In non-debug modes stdout and stderr are redirected to STDOUT_STDERR_FILE="$TMP_DIR/rear.$WORKFLOW.stdout_stderr" if possible
    # but in certain cases (e.g. for the 'help' workflow where no $TMP_DIR exists) STDOUT_STDERR_FILE=/dev/null
    # so we extract some latest messages only if STDOUT_STDERR_FILE is a regular file:
    if test -f "$STDOUT_STDERR_FILE" ; then
        # We use the same extraction pipe as above because STDOUT_STDERR_FILE may also contain 'set -x' and things like that
        # because scripts could use 'set -x' and things like that as needed (e.g. diskrestore.sh runs with 'set -x'):
        { local last_sourced_script_stdout_stderr_messages="$( sed -n -e "/Including .*$last_sourced_script_filename/,/+ [Bug]*Error /p" $STDOUT_STDERR_FILE | egrep -v "^\+|Including .*$last_sourced_script_filename" | tail -n 8 | sed -e 's/^/  /' | cut -b-200 )" ; } 2>>/dev/$DISPENSABLE_OUTPUT_DEV
        if test "$last_sourced_script_stdout_stderr_messages" ; then
            # When stdout and stderr are redirected to STDOUT_STDERR_FILE messages of the last called programs cannot be in the log
            # so we use LogPrintError and 'echo "string of messages" >>$RUNTIME_LOGFILE' (the latter avoids the timestamp prefix)
            # to have the extracted messages stored in the log so that they are later available (in contrast to terminal output).
            # The full stdout and stderr messages are available in STDOUT_STDERR_FILE:
            LogPrintError "Some messages from $STDOUT_STDERR_FILE since the last called script $last_sourced_script_filename:"
            PrintError "$last_sourced_script_stdout_stderr_messages"
            echo "$last_sourced_script_stdout_stderr_messages" >>"$RUNTIME_LOGFILE"
        fi
    fi
    # Show some generic info about debugging:
    if test "$DEBUG" ; then
        # We are in debug mode but not in debugscript mode:
        test "$DEBUGSCRIPTS" || PrintError "You may use debugscript mode '-D' for full debug messages with 'set -x' output"
    else
        # We are not in debug mode:
        PrintError "Use debug mode '-d' for some debug messages or debugscript mode '-D' for full debug messages with 'set -x' output"
    fi
    # Log the error message:
    Log "ERROR: $*"
    LogToSyslog "ERROR: $*"
    # Print stack strace in reverse order to the current STDERR which is (usually) the log file:
    ( echo "===== ${MESSAGE_PREFIX}Stack trace ====="
      local c=0;
      while caller $((c++)) ; do
          :
      done | awk ' { l[NR]=$3":"$1" "$2 }
                   END { for (i=NR; i>0;) print "Trace "NR-i": "l[i--] }
                 '
      echo "=== ${MESSAGE_PREFIX}End stack trace ==="
    ) 1>&2
    # Make sure Error exits the master process, even if called from child processes.
    # We must send USR1 to MASTER_PID before we terminate all still running descendant processes of MASTER_PID below
    # because when the Error function is called from a subshell we are one of those still running descendant processes:
    kill -USR1 $MASTER_PID
    # That USR1 has a trap (see above) that does 'kill MASTER_PID' whicht triggers another trap on EXIT that calls DoExitTasks().
    # When the Error function is called from within a subshell (cf. layout/save/GNU/Linux/230_filesystem_layout.sh) like 
    #   ( echo "additional content for file" || Error "failed to append content to file" ) >> file
    # the Error function does not let MASTER_PID exit because the parent shell waits until its subshell has finished
    # so that the USR1 that was sent above to MASTER_PID will be processed only after the subshell has finished
    # cf. https://github.com/rear/rear/issues/2089#issuecomment-474260332 that reads (excerpts)
    #    A nice clean reproducer on plain command line (needs a recent bash that supports BASHPID):
    #       # export MASTERPID=$BASHPID
    #       # trap "echo $MASTERPID got USR1" USR1
    #       # ( echo begin subshell $BASHPID parent $MASTERPID
    #           pstree -Aplau $MASTERPID
    #           kill -USR1 $MASTERPID
    #           echo sent USR1 to $MASTERPID in subshell
    #           echo other stuff in subshell
    #           echo subshell done )
    #    Running that reproducer results:
    #       begin subshell 26109 parent 26108
    #       bash,26108
    #         `-bash,26109
    #             `-pstree,26110 -Aplau 26108
    #       sent USR1 to 26108 in subshell
    #       other stuff in subshell
    #       subshell done
    #       26108 got USR1
    #   It shows that the parent waits until its subshell child has finished and then the parent processes the signal.
    #   This behaviour matches what "man bash" reads for "SIGNALS":
    #      If bash is waiting for a command to complete
    #      and receives a signal for which a trap has been set,
    #      the trap will not be executed until the command completes.
    # This means when the Error function is called from within a subshell only USR1 is sent to MASTER_PID
    # and the subshell continues with all its code after the Error function until the subshell finishes.
    # This would result unintendedly executed code (with all its unexpected messages in the log file) and
    # also further Error function calls with error messages on the user's terminal from subsequent failures
    # after the initial error, e.g. see https://github.com/rear/rear/issues/2087#issue-421604286 that shows
    #   ERROR: Partition number '0' of partition mmcblk0boot0 is not a valid number.
    #   ERROR: Partition number '' of partition mmcblk0rpmb is not a valid number.
    #   ERROR: Partition mmcblk0rpmb is numbered ''. More than 128 partitions is not supported.
    #   Aborting due to an error, check /var/log/rear/rear-testvm02.log for details
    # where only the first error message should have been shown and a direct abort should have happened.
    # This is the reason why we have to terminate all still running descendant processes of MASTER_PID
    # but do not terminate the MASTER_PID process itself because the MASTER_PID process must run
    # the exit tasks via DoExitTasks via trap on EXIT via trap on USR1 (see above).
    # How to cleanly error out from within a lower level of nested subshells as in this code:
    #   ( LogPrint "Begin first subshell"
    #     ( LogPrint "Begin second subshell"
    #       Error "First error"
    #       Error "Second error"
    #       LogPrint "End second subshell"
    #     )
    #     LogPrint "Code in first subshell after second subshell"
    #     LogPrint "End of first subshell"
    #   )
    # It should error out at "First error" and not execute any code after that.
    # If we terminate the second subshell here (i.e. the one that currently runs this 'Error "First error"' function)
    # we could avoid that the second subshell unintendedly continues and runs the 'Error "Second error"' function
    # but its parent (i.e. the first subshell that has waited for its second subshell child to finish)
    # would then continue and unintendedly execute the "Code in first subshell after second subshell".
    # Therefore we terminate all still running processes (except MASTER_PID) starting with children to grandchildren
    # so that we terminate first the first subshell and then the second subshell.
    # This way when the second subshell gets terminated its parent was already terminated
    # so that in the end there will be no unintendedly executed code after the "First error".
    # The following code is basically the same as in DoExitTasks (see there for explanatory comments)
    # except small but crucial differences here which is the reason why that kind of code exists two times.
    # First of all restore the ReaR default bash flags and options of MASTER_PID (i.e. of usr/sbin/rear):
    { apply_bash_flags_and_options_commands "$DEFAULT_BASH_FLAGS_AND_OPTIONS_COMMANDS" ; } 2>/dev/null
    # Keep debugscript mode also here if it was used before:
    test "$DEBUGSCRIPTS" && set -$DEBUGSCRIPTS_ARGUMENT
    LogPrint "Error exit of $PROGRAM $WORKFLOW (PID $MASTER_PID) and its descendant processes"
    # Show descendant processes PIDs with their commands in the log
    # so that the plain PIDs in the log get more comprehensible
    # when terminate_descendants_from_children_to_grandchildren is called afterwards:
    log_descendants_pids
    # Terminate all still running descendant processes of MASTER_PID
    # but do not terminate the MASTER_PID process itself because
    # the MASTER_PID process must run the exit tasks via DoExitTasks (see above)
    # and do not terminate the current process that runs this code here
    # because the terminate_descendants_from_children_to_grandchildren function
    # should run to its end because it may have to kill descendant processes:
    terminate_descendants_from_children_to_grandchildren
    # Now only the process that runs this code here is left.
    # If that process is MASTER_PID all is o.k. but if that process is run within a subshell
    # we must not return here from the Error funtion to its caller because that would let
    # the subshell continue with all its code after the Error function until the subshell finishes
    # so that if we are in a subshell here we exit from that subshell here:
    if test $BASH_SUBSHELL -gt 0 ; then
        LogPrint "Exiting subshell $BASH_SUBSHELL (where the actual error happened)"
        test $EXIT_CODE -gt 1 && exit $EXIT_CODE || exit 1
    fi
}

# Exit if there is a bug in ReaR:
function BugError () {
    { local caller_source="$( CallerSource )" ; } 2>>/dev/$DISPENSABLE_OUTPUT_DEV
    Error "
====================
BUG in $caller_source:
'$*'
--------------------
Please report it at $BUG_REPORT_SITE
and include all related parts from $RUNTIME_LOGFILE
preferably the whole debug information via 'rear -D $WORKFLOW'
===================="
}

# Using the ...IfError functions can result unexpected behaviour in certain cases.
#
# Using $? in an ...IfError function message like
#   COMMAND
#   StopIfError "COMMAND failed with error code $?"
# lets $? evaluate to an unintended value (usually 0) for example as in
#   # cat QQQ ; if (( $? != 0 )) ; then echo "ERROR $?" ; fi
#   cat: QQQ: No such file or directory
#   ERROR 0
# In contrast using bash directly as in
#   # cat QQQ || echo "ERROR $?"
#   cat: QQQ: No such file or directory
#   ERROR 1
# works as expected.
#
# The ...IfError functions fail when 'set -e' is set
# cf. https://github.com/rear/rear/issues/534
# for example code like
#   set -e
#   COMMAND
#   StopIfError "COMMAND failed"
# cannot work because 'set -e' exits the script when COMMAND results non-zero exit code
# so that the subsequent StopIfError is never reached.
# In contrast using bash directly as in
#   set -e
#   COMMAND || Error "COMMAND failed"
# works as expected.
#
# The ...IfError functions fail when $( COMMAND )
# command substitution is used in the ...IfError functions message
# cf. https://github.com/rear/rear/issues/1415#issuecomment-315692391
# for example code like
#   COMMAND1
#   StopIfError "... $( COMMAND2 ) ..."
# cannot work because $? that is tested in the ...IfError functions
# will be the one from COMMAND2 and not the one from COMMAND1
# so that StopIfError errors out when COMMAND2 fails but not when COMMAND1 fails.
# In contrast using bash directly as in
#   COMMAND1 || Error "... $( COMMAND2 ) ..."
# works as expected when $? is not used in the Error function message.
# When $? should be used in the Error function message it must be before $( COMMAND2 ).
# When $? is before $( COMMAND2 ) it evaluates to the exit code of COMMAND1.
# When $? is after $( COMMAND2 ) it evaluates to the exit code of COMMAND2.
# At least with bash-4.4 in openSUSE Leap 15.1 one gets
#   # cat QQQ || echo "ERROR $? $( grep -Q '/' /etc/fstab ) $?" 
#   cat: QQQ: No such file or directory
#   grep: invalid option -- 'Q'
#   Usage: grep [OPTION]... PATTERN [FILE]...
#   Try 'grep --help' for more information.
#   ERROR 1  2
# when COMMAND1 fails with exit code 1 and COMMAND2 fails with exit code 2
# versus
#   # cat QQQ || echo "ERROR $? $( grep -q '/' /etc/fstab ) $?" 
#   cat: QQQ: No such file or directory
#   ERROR 1  0
# when COMMAND1 fails with exit code 1 and COMMAND2 succeeds.

# If return code is non-zero, bail out:
function StopIfError () {
    if (( $? != 0 )) ; then
        Error "$@"
    fi
}

# If return code is non-zero, there is a bug in ReaR:
function BugIfError () {
    if (( $? != 0 )) ; then
        BugError "$@"
    fi
}

# Show the user if there is an error:
function PrintIfError () {
    # If return code is non-zero, show that on the user's terminal
    # regardless whether or not the user launched 'rear' in verbose mode:
    if (( $? != 0 )) ; then
        PrintError "$@"
    fi
}

# Log if there is an error;
function LogIfError () {
    if (( $? != 0 )) ; then
        Log "$@"
    fi
}

# Log if there is an error and also show it to the user:
function LogPrintIfError () {
    # If return code is non-zero, show that on the user's terminal
    # regardless whether or not the user launched 'rear' in verbose mode:
    if (( $? != 0 )) ; then
        LogPrintError "$@"
    fi
}

function cleanup_build_area_and_end_program () {
    # Cleanup build area
    local mounted_in_BUILD_DIR
    Log "Finished $PROGRAM $WORKFLOW in $(( $( date +%s ) - START_SECONDS )) seconds"
    # is_true is in lib/global-functions.sh which is not yet sourced in case of early Error() in usr/sbin/rear
    if has_binary is_true && is_true "$KEEP_BUILD_DIR" ; then
        mounted_in_BUILD_DIR="$( mount | grep "$BUILD_DIR" | sed -e 's/^/  /' )"
        if test "$mounted_in_BUILD_DIR" ; then
            LogPrintError "Caution - there is something mounted within the build area"
            LogPrintError "$mounted_in_BUILD_DIR"
            LogPrintError "You must manually umount that before you may remove the build area"
        fi
        # Show this message also inside the recovery system (e.g. at the end of "rear -D recover")
        # because there may be a reason why manually removing the build area is wanted
        # (e.g. some additional manual things need be done before rebooting).
        # In any case one must be careful if one wants to remove the build area because
        # e.g. the NFS share with the backup.tar.gz may still be erroneously mounted therein.
        LogPrint "To remove the build area you may use (with caution): rm -Rf --one-file-system $BUILD_DIR"
    else
        Log "Removing build area $BUILD_DIR"
        # Use '--one-file-system' to be safe against also deleting by accident
        # all mounted things below mountpoints in TMP_DIR or ROOTFS_DIR
        # (regardless if mountpoints in TMP_DIR or ROOTFS_DIR may happen):
        rm -Rf --one-file-system $TMP_DIR || LogPrintError "Failed to 'rm -Rf --one-file-system $TMP_DIR'"
        rm -Rf --one-file-system $ROOTFS_DIR || LogPrintError "Failed to 'rm -Rf --one-file-system $ROOTFS_DIR'"
        # Before removing BUILD_DIR check that outputfs is gone (i.e. check that nothing is mounted there):
        if mountpoint -q "$BUILD_DIR/outputfs" ; then
            # If still mounted wait a bit (perhaps some ongoing umount needs more time) then try lazy umount:
            sleep 2
            # umount_mountpoint_lazy is in lib/global-functions.sh
            # which is not yet sourced in case of early Error() in usr/sbin/rear
            has_binary umount_mountpoint_lazy && umount_mountpoint_lazy $BUILD_DIR/outputfs
        fi
        # remove_temporary_mountpoint is in lib/global-functions.sh
        # which is not yet sourced in case of early Error() in usr/sbin/rear
        if has_binary remove_temporary_mountpoint ; then
            # It is a bug in ReaR if BUILD_DIR/outputfs was not properly umounted and made empty by the scripts before:
            remove_temporary_mountpoint "$BUILD_DIR/outputfs" || BugError "Directory $BUILD_DIR/outputfs not empty, cannot remove"
        fi
        if ! rmdir $v "$BUILD_DIR" ; then
            LogPrintError "Could not remove build area $BUILD_DIR (something still exists therein)"
            mounted_in_BUILD_DIR="$( mount | grep "$BUILD_DIR" | sed -e 's/^/  /' )"
            if test "$mounted_in_BUILD_DIR" ; then
                LogPrintError "Something is still mounted within the build area"
                LogPrintError "$mounted_in_BUILD_DIR"
                LogPrintError "You must manually umount it, then you could manually remove the build area"
            fi
            LogPrintError "To manually remove the build area use (with caution): rm -Rf --one-file-system $BUILD_DIR"
        fi
    fi
    Log "End of program '$PROGRAM' reached"
}

# UserInput is a general function that is intended for basically any user input.
#   Output happens via the original STDOUT and STDERR when 'rear' was launched
#   (which is usually the terminal of the user who launched 'rear') and
#   input is read from the original STDIN when 'rear' was launched
#   (which is usually the keyboard of the user who launched 'rear').
# Synopsis:
#   UserInput -I user_input_ID [-C] [-r] [-s] [-t timeout] [-p prompt] [-a input_words_array_name] [-n input_max_chars] [-d input_delimiter] [-D default_input] [choices]
#   The options -r -s -t -p -a -n -d  match the ones for the 'read' bash builtin.
#   The option [choices] are the values that are shown to the user as available choices like if a 'select' bash keyword was used.
#   The option [-D default_input] specifies what is used as default response when the user does not enter something.
#       Usually this is one of the choice values or one of the a choice numbers '1' '2' '3' ...
#       that are shown to the user (the choice numbers are shown as in 'select' (i.e. starting at 1)
#       but the default input can be anything else (in particular for free input without predefined choices)
#       so that e.g. '-D 0' is not the first choice but lets the default input be '0' (regardles of choices).
#   The option '-I user_input_ID' is required so that UserInput can work full automated (e.g. when ReaR runs unattended)
#       via user-specified variables that get named USER_INPUT_user_input_ID (i.e. prefixed with 'USER_INPUT_')
#       so that the user can (as he needs it) predefine user input values like
#           USER_INPUT_FOO_CONFIRMATION='input for UserInput -I FOO_CONFIRMATION'
#           USER_INPUT_BAR_CHOICE='input for UserInput -I BAR_CHOICE'
#           USER_INPUT_BAZ_DIALOG='input for UserInput -I BAZ_DIALOG'
#           (with actually meaningful words for FOO, BAR, and BAZ)
#       that will be autoresponded with the value of the matching USER_INPUT_user_input_ID variable.
#       Accordingly only a valid variable name can be used as user_input_ID value.
#       Different UserInput calls must use different '-I user_input_ID' option values but
#       same UserInput calls in different scripts can use same '-I user_input_ID' option values.
#       It is recommended to use meaningful and explanatory user_input_ID values
#       which helps the user to specify automated input via meaningful USER_INPUT_user_input_ID variables
#       and it avoids that different UserInput calls accidentally use same user_input_ID values.
#       It is required to use uppercase user_input_ID values because the USER_INPUT_user_input_ID variables
#       are user configuration variables and all user configuration variables have uppercase letters.
#   The option [-C] specifies confidential user input mode. In this mode no input values are logged.
#       This means that neither the actual user input nor the default input nor the choices values are logged but
#       the prompt, the actual input, the default value, and the choices are still shown on the user's terminal.
#       In confidential user input mode the actual input coming from the user's terminal is still echoed
#       on the user's terminal unless also the -s option is specified.
#       When usr/sbin/rear is run in debugscript mode (which runs the scripts with 'set -x') arbitrary values
#       appear in the log file so that the confidential user input mode does not help in debugscript mode.
#       If confidential user input is needed also in debugscript mode the caller of the UserInput function
#       must call it in an appropriate (temporary) environment e.g. with STDERR redirected to /dev/null like
#           { password="$( UserInput -I PASSWORD -C -r -s -p 'Enter the pasword' )" ; } 2>/dev/null
#       The redirection must be done via a compound group command { confidential_command ; } 2>/dev/null
#       even for a single confidential command to ensure STDERR is redirected to /dev/null also for 'set -x'
#       otherwise the confidential command and its arguments would be shown in the log file, for example
#           { openssl des3 -salt -k secret_passphrase ; } 2>/dev/null
#       where the secret passphrase must not appear in the log, cf. https://github.com/rear/rear/issues/2155
# Result:
#   Any actual user input or an automated user input or the default response is output via STDOUT.
# Return code:
#   The UserInput return code is the return code of the 'read' bash builtin that is called to get user input.
#   When the UserInput function is called with right syntax its return code is 0
#   for any actual user input and in case of any (non empty) automated user input.
#   The return code is 1 when the 'read' call timed out (i.e. when there was no actual user input)
#   so that one can distinguish between an explicitly provided user input and no actual user input
#   even if the explicitly provided user input is the same as the default so that it makes a difference
#   whether or not the user explicitly chose and confirmed that the default is what he actually wants
#   or if he let things "just happen" inattentively via timeout where it is important to have a big timeout
#   so that an attentive user will actively provide user input to proceed even if it is same as the default.
# Usage examples:
# * Wait endlessly until the user hits the [Enter] key (without '-t 0' a default timeout is used):
#       UserInput -I WAIT_UNTIL_ENTER -t 0 -p 'Press [Enter] to continue'
# * Wait up to 30 seconds until the user hits the [Enter] key (i.e. proceed automatically after 30 seconds):
#       UserInput -I WAIT_FOR_ENTER_OR_TIMEOUT -t 30 -p 'Press [Enter] to continue'
# * Get an input value from the user (proceed automatically with empty input_value after the default timeout).
#   Leading and trailing spaces are cut from the actual user input:
#       input_value="$( UserInput -I FOO_INPUT -p 'Enter the input value' )"
# * Get an input value from the user (proceed automatically with the 'default input' after 2 minutes).
#   The timeout interrupts ongoing user input so that 'default input' is used when the user
#   does not hit the [Enter] key to finish his input before the timeout happens:
#       input_value="$( UserInput -I FOO_INPUT -t 120 -p 'Enter the input value' -D 'default input' )"
# * Get an input value from the user by offering him possible choices (proceed with the default choice after the default timeout).
#   The shown choice numbers start with 1 so that '-D 2' specifies the second choice as default choice:
#       input_value="$( UserInput -I BAR_CHOICE -p 'Select a choice' -D 2 'first choice' 'second choice' 'third choice' )"
# * When the user enters an arbitrary value like 'foo bar' this actual user input is used as input_value.
#   The UserInput function provides the actual user input and its caller needs to check the actual user input.
#   To enforce that the actual user input is one of the choices an endless retrying loop could be used like:
#       choices=( 'first choice' 'second choice' 'third choice' )
#       until IsInArray "$input_value" "${choices[@]}" ; do
#           input_value="$( UserInput -I BAR_CHOICE -p 'Select a choice' -D 'second choice' "${choices[@]}" )"
#       done
#   Because the default choice is one of the choices the endless loop does not contradict that ReaR can run unattended.
#   When that code runs unattended (i.e. without actual user input) the default choice is used after the default timeout.
# * The default choice can be anything as in:
#       input_value="$( UserInput -I BAR_CHOICE -p 'Select a choice' -D 'fallback value' -n 1 'first choice' 'second choice' 'third choice' )"
#   The caller needs to check the actual input_value which could be 'fallback value' when the user hits the [Enter] key
#   or one of 'first choice' 'second choice' 'third choice' when the user hits the [1] [2] or [3] key respectively
#   or any other character as actual user input ('-n 1' limits the actual user input to one single character).
# * When up to 9 possible choices are shown using '-n 1' lets the user choose one by only pressing a [1] ... [9] key
#   without the additional [Enter] key that is normally needed to submit the input. With an endless loop that retries
#   when the actual user input is not one of the choices it is possible to implement valid and convenient user input:
#       choices=( 'default choice' 'first alternative choice' 'second alternative choice' )
#       until IsInArray "$choice" "${choices[@]}" ; do
#           choice="$( UserInput -I BAZ_CHOICE -t 60 -p 'Hit a choice number key' -D 1 -n 1 "${choices[@]}" )"
#       done
# * To to let UserInput autorespond full automated a predefined user input value specify the user input value
#   with a matching USER_INPUT_user_input_ID variable (e.g. specify that it in your local.conf file) like
#       USER_INPUT_BAR_CHOICE='third choice'
#   which lets a 'UserInput -I BAR_CHOICE' call autorespond with 'third choice'.
#   No USER_INPUT_BAR_CHOICE variable should exist to get real user input for a 'UserInput -I BAR_CHOICE' call
#   or the user can interupt any automated response within a relatively short time (minimum is only 1 second).
function UserInput () {
    # First and foremost log that UserInput was called (but be confidential here):
    local caller_source="$( CallerSource )"
    Log "UserInput: called in $caller_source"
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
    local input_words_array_name=""
    local input_max_chars=0
    # Avoid stderr if USER_INPUT_MAX_CHARS is not set or empty and ignore useless '0' or wrong USER_INPUT_MAX_CHARS:
    test "$USER_INPUT_MAX_CHARS" -ge 1 2>/dev/null && input_max_chars=$USER_INPUT_MAX_CHARS
    local input_delimiter=""
    local default_input=""
    local user_input_ID=""
    local confidential_mode="no"
    local raw_input="no"
    local silent_input="no"
    # Get the options and their arguments:
    local option=""
    # Resetting OPTIND is necessary if getopts was used previously in the script
    # and because we are in a function we can even make OPTIND local:
    local OPTIND=1
    while getopts ":t:p:a:n:d:D:I:Crs" option ; do
        case $option in
            (t)
                # Avoid stderr if OPTARG is not set or empty or not an integer value:
                test "$OPTARG" -ge 0 2>/dev/null && timeout=$OPTARG || Log "UserInput: Invalid -$option argument '$OPTARG' using fallback '$timeout'"
                ;;
            (p)
                prompt="$OPTARG"
                ;;
            (a)
                input_words_array_name="$OPTARG"
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
                user_input_ID="$OPTARG"
                ;;
            (C)
                confidential_mode="yes"
                ;;
            (r)
                raw_input="yes"
                ;;
            (s)
                silent_input="yes"
                ;;
            (\?)
                BugError "UserInput: Invalid option: -$OPTARG"
                ;;
            (:)
                BugError "UserInput: Option -$OPTARG requires an argument"
                ;;
        esac
    done
    test $user_input_ID || BugError "UserInput: Option '-I user_input_ID' required"
    test "$( echo $user_input_ID | tr -c -d '[:lower:]' )" && BugError "UserInput: Option '-I' argument '$user_input_ID' must not contain lower case letters"
    declare $user_input_ID="dummy" || BugError "UserInput: Option '-I' argument '$user_input_ID' not a valid variable name"
    # Shift away the options and arguments:
    shift "$(( OPTIND - 1 ))"
    # Everything that is now left in "$@" is neither an option nor an option argument
    # so that now "$@" contains the trailing mass-arguments (POSIX calls them operands):
    local choices=( "$@" )
    local choice=""
    local choice_index=0
    local choice_number=1
    if test "${choices:=}" ; then
        if test "$default_input" ; then
            # Avoid stderr if default_input is not set or empty or not an integer value:
            if test "$default_input" -ge 1 2>/dev/null ; then
                choice_index=$(( default_input - 1 ))
                # It is possible (it is no error) to specify a number as default input that has no matching choice:
                test "${choices[$choice_index]:=}" && Log "UserInput: Default input not in choices"
            else
                # When the default input is no number try to find it in the choices
                # and if found use its choice number as default input:
                for choice in "${choices[@]}" ; do
                    if test "$default_input" = "$choice" ; then
                        Log "UserInput: Default input in choices - using choice number $choice_number as default input"
                        default_input=$choice_number
                        break
                    fi
                    (( choice_number += 1 ))
                done
                # It is possible (it is no error) to specify anything as default input.
                # Avoid stderr if default_input is not set or empty or not an integer value:
                test "$default_input" -ge 1 2>/dev/null || Log "UserInput: Default input not found in choices"
            fi
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
        test "$default_input" && default_and_timeout="default '$default_input'"
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
    # In debug mode show the user the script that called UserInput and what user_input_ID was specified
    # so that the user can prepare an automated response for that UserInput call (without digging in the code):
    DebugPrint "UserInput -I $user_input_ID needed in $caller_source"
    # First of all show the prompt unless an empty prompt was specified (via -p '')
    # so that the prompt can be used as some kind of header line that introduces the user input
    # and separates the following user input from arbitrary other output lines before:
    test "$prompt" && LogUserOutput "$prompt"
    # List the choices (if exists):
    if test "${choices:=}" ; then
        # This comment contains the opening parentheses ( ( ( to keep paired parentheses:
        # Show the choices with leading choice numbers 1) 2) 3) ... as in 'select' (i.e. starting at 1):
        choice_number=1
        for choice in "${choices[@]}" ; do
            # This comment contains the opening parenthesis ( to keep paired parenthesis:
            is_true "$confidential_mode" && UserOutput "$choice_number) $choice" || LogUserOutput "$choice_number) $choice"
            (( choice_number += 1 ))
        done
    fi
    # Finally show the default and/or the timeout (if exists):
    if test "$default_and_timeout" ; then
        is_true "$confidential_mode" && UserOutput "($default_and_timeout)" || LogUserOutput "($default_and_timeout)"
    fi
    # Prepare the 'read' call:
    local read_options_and_arguments=""
    is_true "$raw_input" && read_options_and_arguments="$read_options_and_arguments -r"
    is_true "$silent_input" && read_options_and_arguments="$read_options_and_arguments -s"
    # When a zero timeout was specified (via -t 0) do not use it.
    # Avoid stderr if timeout is not set or empty or not an integer value:
    test "$timeout" -ge 1 2>/dev/null && read_options_and_arguments="$read_options_and_arguments -t $timeout"
    # When no input_words_array_name was specified (via -a myarr) do not use it:
    test "$input_words_array_name" && read_options_and_arguments="$read_options_and_arguments -a $input_words_array_name"
    # When zero input_max_chars was specified (via -n 0) do not use it.
    # Avoid stderr if input_max_chars is not set or empty or not an integer value:
    test "$input_max_chars" -ge 1 2>/dev/null && read_options_and_arguments="$read_options_and_arguments -n $input_max_chars"
    # When no input_delimiter was specified (via -d x) do not use it:
    test "$input_delimiter" && read_options_and_arguments="$read_options_and_arguments -d $input_delimiter"
    # Get the actual user input value:
    local input_string=""
    # When a predefined user input value exists use that as automated user input:
    local predefined_input_variable_name="USER_INPUT_$user_input_ID"
    if test "${!predefined_input_variable_name:-}" ; then
        if is_true "$confidential_mode" ; then
            if is_true "$silent_input" ; then
                UserOutput "UserInput: Will use predefined input in $predefined_input_variable_name"
            else
                UserOutput "UserInput: Will use predefined input in $predefined_input_variable_name='${!predefined_input_variable_name}'"
            fi
        else
            LogUserOutput "UserInput: Will use predefined input in $predefined_input_variable_name='${!predefined_input_variable_name}'"
        fi
        # Let the user interrupt the automated user input:
        LogUserOutput "Hit any key to interrupt the automated input (timeout $automated_input_interrupt_timeout seconds)"
        # automated_input_interrupt_timeout is at least 1 second (see above) and do not echo the input (it is meaningless here)
        # and STDOUT is also meaningless (not used) and STDERR can still go into the log (no 'read -p prompt' is used):
        if read -t $automated_input_interrupt_timeout -n 1 -s 0<&6 ; then
            Log "UserInput: automated input interrupted by user"
            # Show the prompt again (or at least the default prompt) to signal the user that now he can and must enter something:
            test "$prompt" && LogUserOutput "$prompt" || LogUserOutput "$default_prompt"
            if test "$default_and_timeout" ; then
                is_true "$confidential_mode" && UserOutput "($default_and_timeout)" || LogUserOutput "($default_and_timeout)"
            fi
        else
            input_string="${!predefined_input_variable_name}"
            # When a (non empty) input_words_array_name was specified it must contain all user input words:
            test "$input_words_array_name" && read -a "$input_words_array_name" <<<"$input_string"
        fi
    fi
    # When there is no (non empty) automated user input read the user input:
    local return_code=0
    if ! contains_visible_char "$input_string" ; then
        # Read the user input from the original STDIN that is saved as fd6 (see above).
        # STDOUT is meaningless because 'read' echoes input from a terminal directly onto the terminal (not via STDOUT) and
        # STDERR can still go into the log because no 'read' prompt is used (the prompt is already shown via LogUserOutput):
        if read $read_options_and_arguments input_string 0<&6 ; then
            is_true "$confidential_mode" && Log "UserInput: 'read' got user input" || Log "UserInput: 'read' got as user input '$input_string'"
        else
            return_code=1
            # Continue in any case because in case of errors the default input is used.
            # Avoid stderr if timeout is not set or empty or not an integer value:
            if test "$timeout" -ge 1 2>/dev/null ; then
                Log "UserInput: 'read' timed out with non-zero exit code"
            else
                Log "UserInput: 'read' finished with non-zero exit code"
            fi
        fi
    fi
    # When an input_words_array_name was specified it contains all user input words
    # so that the words in input_words_array_name are copied into input_string:
    if test "$input_words_array_name" ; then
        # Regarding how to get all array elements when the array name is in a variable, see
        # https://unix.stackexchange.com/questions/60584/how-to-use-a-variable-as-part-of-an-array-name
        # Assume input_words_array_name="myarr" then input_words_array_name_dereferenced="myarr[*]"
        # and "${!input_words_array_name_dereferenced}" becomes "${myarr[*]}"
        # Avoid ShellCheck false error indication for code like
        #   string_appended="$string[*]"
        #                    ^-- SC1087: Use braces when expanding arrays, e.g. ${array[idx]}
        # by appending '[*]' to a string variable in a separated command:
        local input_words_array_name_dereferenced="$input_words_array_name"
        input_words_array_name_dereferenced+='[*]'
        input_string="${!input_words_array_name_dereferenced}"
    fi
    # When there is no user input or when the user input is only spaces use the "best" fallback or default that exists.
    if ! contains_visible_char "$input_string" ; then
        # There is no real user input (user input is empty or only spaces):
        if ! contains_visible_char "$default_input" ; then
            # There is neither real user input nor a real default input:
            DebugPrint "UserInput: Neither real user input nor real default input (both empty or only spaces) results ''"
            echo ""
            return $return_code
        fi
        # When there is a real default input but no real user input use the default input as user input:
        DebugPrint "UserInput: No real user input (empty or only spaces) - using default input"
        input_string="$default_input"
    fi
    # Now there is real input in input_string (neither empty nor only spaces):
    # When there are no choices result the input as is:
    if ! test "$choices" ; then
        is_true "$confidential_mode" || DebugPrint "UserInput: No choices - result is '$input_string'"
        echo "$input_string"
        return $return_code
    fi
    # When there are choices:
    # Avoid stderr if input_string is not set or empty or not an integer value:
    if test "$input_string" -ge 1 2>/dev/null ; then
        # There are choices and the user input is a positive integer value:
        choice_index=$(( input_string - 1 ))
        if test "${choices[$choice_index]:=}" ; then
            # The user input is a valid choice number:
            is_true "$confidential_mode" || DebugPrint "UserInput: Valid choice number result '${choices[$choice_index]}'"
            echo "${choices[$choice_index]}"
            return $return_code
        fi
    fi
    # When the input is not a a valid choice number or
    # when the input is an existing choice string or
    # when the input is anything else:
    is_true "$confidential_mode" || DebugPrint "UserInput: Result is '$input_string'"
    echo "$input_string"
    return $return_code
}

# Setup dummy progress subsystem as a default.
# Progress stuff replaced by dummy/noop
# cf. https://github.com/rear/rear/issues/887
function ProgressStart () {
    : ;
}
function ProgressStop () {
    : ;
}
function ProgressError () {
    : ;
}
function ProgressStep () {
    : ;
}
function ProgressInfo () {
    : ;
}

