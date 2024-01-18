if [[ "$VERBOSE" ]]; then
    WORKFLOW_shell_DESCRIPTION="start a bash within rear; development tool"
fi
WORKFLOWS+=( shell )
WORKFLOW_shell () {
    if test "$SIMULATE" ; then
        LogPrint "${BASH_SOURCE[0]} starts a bash within rear"
        return 0
    fi
    # mask variables that cause errors in the ReaR Shell and use full declare syntax to support also associative Bash arrays
    export REAR_EVAL="$(declare -p | grep -Ev 'declare .. (VERBOSE|MASTER_PID|WORKING_DIR|MASKS)=.*')"
    # Use the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
    bash --rcfile $SHARE_DIR/lib/rear-shell.bashrc -i 0<&6 1>&7 2>&8
}
