# USB output typically resides on a writable disk device
# which should be protected against overwriting by "rear recover"
# cf. https://github.com/rear/rear/issues/1271
# This code registers the USB output device as write protected.

# All available UUIDs of the ReaR recovery system disk (i.e. USB_DEVICE)
# are added to the WRITE_PROTECTED_UUIDS array.
# UUIDs are those that 'lsblk' reports (which depends on the lsblk version):
#       UUID filesystem UUID
#     PTUUID partition table identifier (usually UUID)
#   PARTUUID partition UUID
local uuids
uuids="$( write_protection_uuids "$USB_DEVICE" )"
# uuids is a string of UUIDs separated by newline characters so quoting for 'test' is required
# but no quoting to add them to the array to get each UUID as a separated array element:
test "$uuids" && WRITE_PROTECTED_UUIDS+=( $uuids ) || LogPrintError "Cannot write protect USB disk '$USB_DEVICE' via UUID (no UUID found)"

# All available file system labels of the ReaR recovery system disk (i.e. USB_DEVICE)
# are added to the WRITE_PROTECTED_FS_LABEL_PATTERNS array.
# Empty lines in the lsblk output get automatically ignored (i.e. no empty array elements get added)
# and we do not alert the user via LogPrintError because file system labels are optional:
WRITE_PROTECTED_FS_LABEL_PATTERNS+=( $( lsblk -ino LABEL "$USB_DEVICE" ) ) || DebugPrint "Cannot write protect USB disk '$USB_DEVICE' via file system label (none found)"
