# include utilities needed to set capabilities
if [ "$BACKUP_CAP" == "y" ] ; then
    REQUIRED_PROGS=("${REQUIRED_PROGS[@]}" setcap getcap)
    Log "Tools to set capabilities."
fi
