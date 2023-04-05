### Disable OBDR mode
###

if ! grep -q '^cciss ' -e '^hpsa ' /proc/modules; then
    return
fi

if ! type -p lsscsi &>/dev/null; then
    echo "WARNING: Missing required lsscsi binary" >&2
    return
fi

if ! type -p sg_wr_mode &>/dev/null; then
    echo "WARNING: Missing required sg_wr_mode binary" >&2
    return
fi

### Wait for SCSI engage to settle before disabling OBDR
sleep 2

### Find CCISS tape host device
CDROM_DEVICE="$(lsscsi | awk '/ +cd\/dvd +HP +Ultrium/ { print $7; exit }')"

### Disable OBDR mode
if [[ "$CDROM_DEVICE" && -b $CDROM_DEVICE ]]; then
    echo "Disable OBDR mode for device $CDROM_DEVICE" >&2
    sg_wr_mode -f -p 3eh -c 3e,2,0,0 $CDROM_DEVICE
    sleep 2
fi

### Find Host/Channel/Id/Lun of device
### On systems with large number of connected perhepials, we need to find proper HCIL from lsscsi, f.x.
### [2:0:10:0]   tape    HP       Ultrium 6-SCSI   25MW  /dev/st6
### As awk's Field Separator use three characters '] [ :' , but we have to double escape brackets 
### Ref. https://www.gnu.org/software/gawk/manual/html_node/Command-Line-Field-Separator.html
HCIL="$(lsscsi | awk 'BEGIN {FS="[\\]|\\[|:]"} / +cd\/dvd +HP +Ultrium/ { print $2, $3, $4, $5; exit }')"

### Rescan device to turn cdrom into tape device
if [[ "$HCIL" ]]; then
    echo "Rescan single device using $HCIL" >&2
    echo "scsi remove-single-device $HCIL" >/proc/scsi/scsi
    sleep 2
    echo "scsi add-single-device $HCIL" >/proc/scsi/scsi

    ### FIXME: Monitor for the device instead ?
    echo "Wait for devices to settle" >&2
    sleep 10
fi
