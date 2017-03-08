if [[ "$VERBOSE" ]]; then
    WORKFLOW_shell_DESCRIPTION="start a bash within rear; development tool"
fi
WORKFLOWS=( "${WORKFLOWS[@]}" shell )
WORKFLOW_shell () {
    if test "$SIMULATE" ; then
        LogPrint "${BASH_SOURCE[0]} starts a bash within rear"
        return 0
    fi
    export REAR_EVAL="$(declare -p | sed -e 's/^declare .. //' -e '/MASKS=/d' )"
    bash --rcfile $SHARE_DIR/lib/bashrc.rear -i 2>&1
}
