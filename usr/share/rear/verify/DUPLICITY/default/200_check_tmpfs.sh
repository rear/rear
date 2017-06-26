# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# mount tmpfs on /tmp if not present
mount | grep -q /tmp
if [[ $? -ne 0 ]]; then
    LogPrint "File system /tmp not present - try to mount it via tmpfs"
    mount -t tmpfs  tmpfs  /tmp >/dev/null
    LogIfError "Could not mount tmpfs on /tmp"
fi
