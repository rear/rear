# 400_kernel_modules.sh
#
# find kernel and modules for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# Note: The various DRIVERS list variables are set in the previous script.

# 1. take all kernel modules for network and storage devices
# 2. collect running kernel modules
MODULES=(
    ${MODULES[@]}
    ${STORAGE_DRIVERS[@]}
    ${NETWORK_DRIVERS[@]}
    ${CRYPTO_DRIVERS[@]}
    ${VIRTUAL_DRIVERS[@]}
    ${EXTRA_DRIVERS[@]}
    $(lsmod | grep -v '^Modul' | cut -d ' ' -f 1)
)

COPY_AS_IS=(
    "${COPY_AS_IS[@]}"
    /lib/modules/$KERNEL_VERSION/modules.*
    /etc/modules*
    /etc/modprobe*
)
