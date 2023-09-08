# Adapted from 260_rename_diskbyid.sh

# Remove /etc/lvm/devices/system.devices
# The file restricts LVM to disks with given (hardware) IDs (serial
# numbers, WWNs). See lvmdevices(8).
# Unfortunately, when restoring to different disks than in the original 
# system, it will mean that LVM is broken in the recovered system (it
# won't find any disks).  Therefore it is safer to remove the file to
# force the old behavior where LVM scans all disks. This used to be the
# LVM default (use_devicesfile=0).

# There may be other files under /etc/lvm/devices, but they are not used
# by default

local file=/etc/lvm/devices/system.devices
local realfile

realfile="$TARGET_FS_ROOT/$file"
# OK if file not found
test -f "$realfile" || return 0
mv $v "$realfile" "$realfile.rearbak"
LogPrint "Renamed LVM devices file $realfile to $realfile.rearbak
to prevent LVM problems in the recovered system, verify that the file
is correct after booting the recovered system and move it back, or
regenerate it using vgimportdevices."
