# 240_include_multipath_tools.sh
# Boot Over SAN executables and other goodies

# Run the following only if BOOT_OVER_SAN is true
is_true "$BOOT_OVER_SAN" || return

PROGS=( "${PROGS[@]}" multipath mpathconf dmsetup kpartx multipathd scsi_id  )
COPY_AS_IS=( "${COPY_AS_IS[@]}" /etc/multipath.conf /etc/multipath/* /lib*/multipath )
