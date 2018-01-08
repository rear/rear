# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# Save the current disk usage (POSIX output format) in the rescue image
# excluding target (ESP) partition(s)
df -Plh -x encfs -x tmpfs -x devtmpfs |  egrep  --invert-match "^(`readlink -f "/dev/disk/by-label/$USB_DEVICE_FILESYSTEM_LABEL"`|`readlink -f /dev/disk/by-label/REAR-EFI`)" > $VAR_DIR/layout/config/df.txt
