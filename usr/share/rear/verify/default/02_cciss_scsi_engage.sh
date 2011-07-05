# We need to re-engage CCISS scsi subsystem to make sure the tape device is
# present again

if ! grep -q '^cciss ' /proc/modules; then
    return
fi

# make the CCISS tape device visible
for host in /proc/driver/cciss/cciss?; do
    Log "Engage SCSI on host $host"
    echo engage scsi >$host 2>/dev/null
done

sleep 2
