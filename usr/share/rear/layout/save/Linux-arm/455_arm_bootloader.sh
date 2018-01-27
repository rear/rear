# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

[ "$BOOTLOADER" = "ARM" ] || return 0

# Currently we just warn
LogWarn "Warning: BOOTLOADER = ARM is just an Dummy!"
