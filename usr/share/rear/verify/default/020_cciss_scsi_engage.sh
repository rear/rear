# We need to re-engage CCISS scsi subsystem to make sure the tape device is present again.

# Nothing to do when no cciss kernel module is loaded:
grep -q '^cciss ' /proc/modules || return 0

# Make the CCISS tape device visible:
for host in /proc/driver/cciss/cciss? ; do
    Log "Engage SCSI on host $host"
    echo engage scsi >$host
done

sleep 2

