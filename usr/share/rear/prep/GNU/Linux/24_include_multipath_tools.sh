# 24_include_multipath_tools.sh
# Boot Over SAN executables and other goodies

[[ $BOOT_OVER_SAN != ^[yY1] ]] && return

PROGS=( "${PROGS[@]}" multipath dmsetup kpartx multipathd scsi_id  )
COPY_AS_IS=( "${COPY_AS_IS[@]}" /etc/multipath/bindings /etc/multipath/wwids /etc/multipath.conf )
