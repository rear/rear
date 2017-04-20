# 240_include_multipath_tools.sh
# Boot Over SAN executables and other goodies

if ! is_true "$BOOT_OVER_SAN" ; then
    return
fi

PROGS=( "${PROGS[@]}" multipath dmsetup kpartx multipathd scsi_id  )
COPY_AS_IS=( "${COPY_AS_IS[@]}" /etc/multipath.conf /etc/multipath/* /lib*/multipath )
