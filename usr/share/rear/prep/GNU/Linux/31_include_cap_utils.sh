# include utilities needed to set capabilities
if is_true "$NETFS_RESTORE_CAPABILITIES" ; then
    REQUIRED_PROGS=("${REQUIRED_PROGS[@]}" setcap getcap)
fi
