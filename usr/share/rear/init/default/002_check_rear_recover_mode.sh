
# In general see https://github.com/rear/rear/pull/3206
# and in particular see https://github.com/rear/rear/pull/3206#issuecomment-2122628596
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
if test "$RECOVERY_MODE" ; then
    # We are in the ReaR rescue/recovery system
    # (we are not in PORTABLE mode because PORTABLE is handled above):
    case "$WORKFLOW" in
        (recover|layoutonly|restoreonly|finalizeonly|mountonly|opaladmin|shell|dump|help)
            LogPrint "Running workflow $WORKFLOW within the ReaR rescue/recovery system"
            ;;
        (*)
            Error "The workflow $WORKFLOW is not supported in the ReaR rescue/recovery system,${LF}use --portable to disable this check at your own risk.${LF}ReaR will probably not work as expected and potentially${LF}destroy your backup data,${LF}if you run these workflows in the rescue system!"
            ;;
    esac
else
    # We are in the normal/original system
    # (we are not in the ReaR rescue/recovery system and we are not in PORTABLE mode because PORTABLE is handled above):
    case "$WORKFLOW" in
        (recover|layoutonly|restoreonly|finalizeonly|mountonly)
            Error "The workflow $WORKFLOW is only supported in the ReaR rescue/recovery system,${LF}use --portable to disable this check at your own risk.${LF}ReaR will destroy your system if you run these workflows in the normal/original system!"
            ;;
        (*)
            LogPrint "Running workflow $WORKFLOW on the normal/original system"
            ;;
    esac
fi
