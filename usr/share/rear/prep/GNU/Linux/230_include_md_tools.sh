# Include software raid tools

grep -q blocks /proc/mdstat 2>/dev/null || return 0

Log "Software RAID detected. Including mdadm tools."

PROGS=( "${PROGS[@]}"
mdadm
)
