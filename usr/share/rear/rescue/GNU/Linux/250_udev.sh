# take udev into our rescue system

# skip for old udev that does not have rules in /etc/udev/rules.d
have_udev || return 0

# basic udev stuff
COPY_AS_IS+=( /etc/udev /etc/sysconfig/udev /lib/udev /usr/lib/udev )

# some distros keep many udev binaries outside of /lib/udev
PROGS+=(
ata_id
cdrom_id
edd_id
path_id
scsi_id
usb_id
vol_id
udev
udevadm
udevcontrol
udevd
udevsettle
udevstart
udevtest
udevtrigger
udevinfo
kpartx
scsi_tur
biosdevname
)
