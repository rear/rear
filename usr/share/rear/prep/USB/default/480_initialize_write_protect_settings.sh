# USB output typically resides on a writable disk device
# which should be protected against overwriting by "rear recover"
# cf. https://github.com/rear/rear/issues/1271
# This code registers the USB output device as write protected.

# All available IDs of the ReaR recovery system disk (i.e. USB_DEVICE)
# are added to the WRITE_PROTECTED_IDS array.
# IDs are those that 'lsblk' reports (which depends on the lsblk version):
#       UUID filesystem UUID
#     PTUUID partition table identifier (usually UUID)
#   PARTUUID partition UUID
#        WWN unique storage identifier
local ids
ids="$( write_protection_ids "$USB_DEVICE" )"
# ids is a string of IDs separated by newline characters so quoting for 'test' is required
# but no quoting to add them to the array to get each ID as a separated array element:
test "$ids" && WRITE_PROTECTED_IDS+=( $ids ) || LogPrintError "Cannot write protect USB disk '$USB_DEVICE' via ID (no ID found)"

# All available file system labels of the ReaR recovery system disk (i.e. USB_DEVICE)
# are added to the WRITE_PROTECTED_FS_LABEL_PATTERNS array.
# Empty lines in the lsblk output get automatically ignored (i.e. no empty array elements get added)
# and we do not alert the user via LogPrintError because file system labels are optional:
WRITE_PROTECTED_FS_LABEL_PATTERNS+=( $( lsblk -ino LABEL "$USB_DEVICE" ) ) || DebugPrint "Cannot write protect USB disk '$USB_DEVICE' via file system label (none found)"
