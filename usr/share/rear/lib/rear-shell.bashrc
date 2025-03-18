PS1="REAR \h:\w # "
alias dir='ls -l'
alias ll='ls -l'
alias la='ls -la'
alias l='ls -alF'
alias ls-l='ls -l'
alias md='mkdir -p'
alias which='type -p'
alias rehash='hash -r'

# ReaR helpers
function show {
    declare -p $(compgen -v | grep -iF "${1:-_}")
}

# mandatory for our scripts to work
shopt -s nullglob extglob

eval "$REAR_EVAL" &>/dev/null
unset REAR_EVAL # reduce environmental pollution

VERBOSE=1

# source Relax-and-Recover functions
for script in $SHARE_DIR/lib/*functions.sh ; do source $script ; done
source $SHARE_DIR/lib/progresssubsystem.nosh

# Set EXIT_FAIL_MESSAGE to 0 to avoid a false exit failure message from the exit task
# "(( EXIT_FAIL_MESSAGE )) && echo '${MESSAGE_PREFIX}$PROGRAM $WORKFLOW failed, check $RUNTIME_LOGFILE for details' 1>&8"
# that is set in lib/_framework-setup-and-functions.sh which is sourced above for this shell here.
# Because we have two shells where ReaR's exit tasks are set (both via lib/_framework-setup-and-functions.sh)
# exiting this bash here runs ReaR's exit tasks and then this workflow finishes
# which lets the outer bash that runs rear finish which also runs ReaR's exit tasks:
#   # usr/sbin/rear -v shell
#   ...
#   REAR localhost:~/usr/share/rear # pstree -Aplau | grep -B2 -A1 bashrc.rear
#    `-bash,7549
#        `-rear,13862 usr/sbin/rear -v shell
#            `-bash,14076 --rcfile /usr/share/rear/lib/bashrc.rear -i
#                |-grep,14190 --color=auto -B2 -A1 bashrc.rear
#                `-pstree,14189 -Aplau
#   REAR localhost:~/usr/share/rear # exit
#   exit
#   Exiting rear shell (PID 14076) and its descendant processes ...
#   Running exit tasks
#   Exiting rear shell (PID 13862) and its descendant processes ...
#   Running exit tasks
# Without EXIT_FAIL_MESSAGE=0 that would look like
#   Exiting rear shell (PID 14076) and its descendant processes ...
#   Running exit tasks
#   rear shell failed, check /var/log/rear/rear-localhost.log for details
#   Exiting rear shell (PID 13862) and its descendant processes ...
#   Running exit tasks
EXIT_FAIL_MESSAGE=0

echo "
This is the interactive shell (bash) within $PRODUCT.
It is intended for development and testing of $PRODUCT
to find out how things behave within the $PRODUCT environment.
For example you can call $PRODUCT specific functions
or source $PRODUCT scripts to test their behaviour.

Helper commands:
show <var name fragment>    dumps all matching variables
Source .../script.sh        runs a single ReaR script
SourceStage stage/subdir    runs an entire stage or a subdir, e.g. verify/PPDM

SHARE_DIR=$SHARE_DIR BUILD_DIR=$BUILD_DIR
"

WORKING_DIR=$SHARE_DIR # ensure that we can run Source ...script.sh via tab completion and that the Source function will stay there
cd $SHARE_DIR
