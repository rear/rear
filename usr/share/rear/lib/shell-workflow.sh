if [[ "$VERBOSE" ]]; then
    WORKFLOW_shell_DESCRIPTION="start a bash within rear; development tool"
fi
WORKFLOWS+=( shell )
WORKFLOW_shell () {
    if test "$SIMULATE" ; then
        LogPrint "${BASH_SOURCE[0]} starts a bash within rear"
        return 0
    fi
    export REAR_EVAL="$(declare -p | sed -e 's/^declare .. //' -e '/MASKS=/d' )"
    # Use the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
    bash --rcfile $SHARE_DIR/lib/bashrc.rear -i 0<&6 1>&7 2>&8
}
