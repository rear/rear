# save also the original /proc/partitions
mkdir -p $VAR_DIR/recovery/proc
grep '[0-9]' </proc/partitions >"$VAR_DIR/recovery/proc/partitions"
