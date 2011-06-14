# Include software raid tools

grep -q blocks /proc/mdstat 2>/dev/null || return

Log "Software RAID detected. Including mdadm tools."

PROGS=( "${PROGS[@]}"
mdadm
)
COPY_AS_IS=( "${COPY_AS_IS[@]}"
/etc/mdadm.conf
)
