# In the ReaR rescue/recovery system the only possible workflow is 'recover'
# and its partial workflows 'layoutonly' 'restoreonly' 'finalizeonly'
# cf. https://github.com/rear/rear/issues/987
# and https://github.com/rear/rear/issues/1088
# In the ReaR rescue/recovery system /etc/rear-release is unique (it does not exist otherwise):
test -f /etc/rear-release || return 0
case "$WORKFLOW" in
    (recover|layoutonly|restoreonly|finalizeonly)
        LogPrint "Running workflow $WORKFLOW within the ReaR rescue/recovery system"
        ;;
    (*)
        Error "The workflow $WORKFLOW is not supported in the ReaR rescue/recovery system"
        ;;
esac

