# especially for Ubuntu 14.04 the udevd does not create the SCSI devices under /dev
[[ ! -x /bin/MAKEDEV ]] && return
cd /dev
# check the devices seen in /sys/block
ls /sys/block | grep -v -e loop -e ram | while read DEV
do
    # DEV can be sda, sr, ...
    DEV=$( echo $DEV | tr -s -d '[:digit:]' '' ) # remove digits
    [[ -b $DEV ]] && continue
    echo "MAKEDEV $DEV"
    MAKEDEV $DEV
done
cd /

