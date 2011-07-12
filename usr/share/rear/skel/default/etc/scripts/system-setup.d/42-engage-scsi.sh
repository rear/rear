### Initialize the CCISS tape drive
###

if ! grep -q '^cciss ' /proc/modules; then
    return
fi

### Make the CCISS tape device visible
for host in /proc/driver/cciss/cciss?; do
    echo "Engage SCSI on host $host" >&2
    echo engage scsi >$host
done
