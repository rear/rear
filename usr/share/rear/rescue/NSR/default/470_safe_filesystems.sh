# 470_safe_filesystems.sh
#
savefs -p -s $NSRSERVER 2>&1 | awk -F '(=|,)' '/path/ { printf ("%s ", $2) }' > $VAR_DIR/recovery/nsr_paths
[[ ! -s $VAR_DIR/recovery/nsr_paths ]] && Error "The savefs command could not retrieve the \"save sets\" from this client"

LogPrint "EMC Networker will recover these filesystems: $( cat $VAR_DIR/recovery/nsr_paths )"
