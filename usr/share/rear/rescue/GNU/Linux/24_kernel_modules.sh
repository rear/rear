# #40_kernel_modules.sh
#
# find kernel and modules for Relax-and-Recover
#
#    Relax-and-Recover is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.

#    Relax-and-Recover is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with Relax-and-Recover; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
#

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
