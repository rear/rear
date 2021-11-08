# USB output typically resides on a writable disk device
# which should be protected against overwriting by "rear recover"
# cf. https://github.com/rear/rear/issues/1271
# This code registers the USB output device as write protected.

# The values of the 'lsblk' output columns in WRITE_PROTECTED_ID_TYPES
# of the ReaR recovery system disk (parent of USB_DEVICE) are automatically added
# to the WRITE_PROTECTED_IDS array during "rear mkrescue/mkbackup".
# The default WRITE_PROTECTED_ID_TYPES are UUID PTUUID PARTUUID WWN.
local ids
ids="$( write_protection_ids "$USB_DEVICE" )"
# ids is a string of IDs separated by newline characters so quoting for 'test' is required
# but no quoting to add them to the array to get each ID as a separated array element:
if test "$ids" ; then
    WRITE_PROTECTED_IDS+=( $ids )
    DebugPrint "USB disk IDs of '$USB_DEVICE' added to WRITE_PROTECTED_IDS"
else
    LogPrintError "Cannot write protect USB disk of '$USB_DEVICE' via ID (no ID found)"
fi

# The file system label of the ReaR data partition (i.e. USB_DEVICE) on the ReaR recovery system disk
# is automatically added to WRITE_PROTECTED_FS_LABEL_PATTERNS during "rear mkrescue/mkbackup".
# Empty lines in the lsblk output get automatically ignored (i.e. no empty array elements get added)
# and we do not alert the user via LogPrintError because file system labels are optional:
if WRITE_PROTECTED_FS_LABEL_PATTERNS+=( $( lsblk -ino LABEL "$USB_DEVICE" ) ) ; then
    DebugPrint "File system label of '$USB_DEVICE' added to WRITE_PROTECTED_FS_LABEL_PATTERNS"
else
    DebugPrint "Cannot write protect USB disk of '$USB_DEVICE' via file system label (none found)"
fi
