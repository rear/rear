# Initialize the CCISS tape drive

if ! grep -q '^cciss ' /proc/modules; then
    return
fi

# make the CCISS tape device visible
for host in /proc/driver/cciss/cciss?; do
    echo "Engage SCSI on host $host" >&2
    echo engage scsi >$host
done

sleep 2

# find CCISS tape host device
CDROM_DEVICE="$(lsscsi | awk '/ +cd\/dvd +HP +Ultrium/ { print $7; exit }')"

# disable OBDR mode
if [[ "$CDROM_DEVICE" && -b $CDROM_DEVICE ]]; then
    echo "Disable OBDR mode for device $CDROM_DEVICE" >&2
    sg_wr_mode -f -p 3eh -c 3e,2,0,0 $CDROM_DEVICE
    sleep 2
fi

# find Host/Channel/Id/Lun of device
HCIL="$(lsscsi | awk 'BEGIN {FS=""} / +cd\/dvd +HP +Ultrium/ { print $2, $4, $6, $8; exit }')"

# rescan device to turn cdrom into tape device
if [[ "$HCIL" ]]; then
    echo "Rescan single device using $HCIL" >&2
    echo "scsi remove-single-device $HCIL" >/proc/scsi/scsi
    sleep 2
    echo "scsi add-single-device $HCIL" >/proc/scsi/scsi

    ### FIXME: Monitor for the device instead ?
    echo "Wait for devices to settle" >&2
    sleep 10
fi
