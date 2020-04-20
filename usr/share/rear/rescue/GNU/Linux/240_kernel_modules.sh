# 400_kernel_modules.sh
#
# find kernel and modules for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# The special user setting MODULES=( 'no_modules' ) enforces that
# no kernel modules get included in the rescue/recovery system
# regardless of what modules are currently loaded.
# Test the first MODULES array element because other scripts
# in particular rescue/GNU/Linux/240_kernel_modules.sh
# already appended other modules to the MODULES array:
test "no_modules" = "$MODULES" && return

# Note: The various DRIVERS list variables are set in the previous script.

# 1. take all kernel modules for network and storage devices
# 2. collect running kernel modules
MODULES+=(
    ${STORAGE_DRIVERS[@]}
    ${NETWORK_DRIVERS[@]}
    ${CRYPTO_DRIVERS[@]}
    ${VIRTUAL_DRIVERS[@]}
    ${EXTRA_DRIVERS[@]}
    $( lsmod | grep -v '^Modul' | cut -d ' ' -f 1 )
)

COPY_AS_IS+=(
    /lib/modules/$KERNEL_VERSION/modules.*
    /etc/modules*
    /etc/modules-load?d
    /etc/modprobe*
)
