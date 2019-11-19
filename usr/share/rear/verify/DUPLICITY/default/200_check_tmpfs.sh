# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# mount tmpfs on /tmp if not present
mountpoint -q /tmp && return 0
LogPrint "File system /tmp not present - mounting it via tmpfs"
mount -t tmpfs  tmpfs  /tmp || Error "Failed to mount tmpfs on /tmp"
