# USB output typically resides on a writable disk device, which should be protected against
# accidental overwriting by rear recover. This code registers it as write protected.

WRITE_PROTECTED_PARTITION_TABLE_UUIDS+=( $(lsblk --output PTUUID --noheadings --nodeps "$USB_DEVICE") )
