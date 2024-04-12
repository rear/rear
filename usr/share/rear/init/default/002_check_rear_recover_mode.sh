is_true "$PORTABLE" && return

# In the ReaR rescue/recovery system the only possible workflows are
# - 'recover' and its partial workflows 'layoutonly' 'restoreonly' 'finalizeonly'
# - 'mountonly'
# - 'opaladmin'
# - 'shell'
# - 'help'
# cf. https://github.com/rear/rear/issues/719
# and https://github.com/rear/rear/issues/987
# and https://github.com/rear/rear/issues/1088
# and https://github.com/rear/rear/issues/3170#issuecomment-1981222992
# and https://github.com/rear/rear/issues/1901
# In particular in the normal/original system the workflows
# recover layoutonly restoreonly finalizeonly and mountonly
# must not run because they can destroy the original system
# cf. https://github.com/rear/rear/issues/2387#issuecomment-626303944
# In the ReaR rescue/recovery system /etc/rear-release is unique (it does not exist otherwise):
if test -f /etc/rear-release ; then
    # We are in the ReaR rescue/recovery system:
    case "$WORKFLOW" in
        (recover|layoutonly|restoreonly|finalizeonly|mountonly|opaladmin|shell|dump|help)
            LogPrint "Running workflow $WORKFLOW within the ReaR rescue/recovery system"
            ;;
        (*)
            Error "The workflow $WORKFLOW is not supported in the ReaR rescue/recovery system,${LF}use --portable to disable this check at your own risk.${LF}ReaR will probably not work as expected and potentially${LF}destroy your backup data,${LF}if you run these workflows in the rescue system!"
            ;;
    esac
else
    # We are in the normal/original system:
    case "$WORKFLOW" in
        (recover|layoutonly|restoreonly|finalizeonly|mountonly)
            Error "The workflow $WORKFLOW is only supported in the ReaR rescue/recovery system,${LF}use --portable to disable this check at your own risk.${LF}ReaR will destroy your system if you run these workflows in the normal/original system!"
            ;;
        (*)
            LogPrint "Running workflow $WORKFLOW on the normal/original system"
            ;;
    esac
fi
