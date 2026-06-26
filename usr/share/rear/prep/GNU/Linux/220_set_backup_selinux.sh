# Set BACKUP_SELINUX based on backup method

# Use bash indirect expansion to get ${BACKUP}_SELINUX value
# For example, if BACKUP=NETFS, this gets NETFS_SELINUX
local selinux_var="${BACKUP}_SELINUX"
if [[ -v $selinux_var ]] ; then
    BACKUP_SELINUX="${!selinux_var}"
else
    BACKUP_SELINUX=0
fi
