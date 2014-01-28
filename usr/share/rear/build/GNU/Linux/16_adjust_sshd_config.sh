# 16_adjust_sshd_config.sh
#
# Edit the sshd_config for Relax and Recover to allow password login if set
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
if has_binary sshd; then
    if [[ $SSH_ROOT_PASSWORD ]] ; then
        sed -i 's/.*PermitRootLogin.*/PermitRootLogin yes/g' $ROOTFS_DIR/etc/ssh/sshd_config
        sed -i 's/.*PasswordAuthentication.*/PasswordAuthentication yes/g' $ROOTFS_DIR/etc/ssh/sshd_config
    fi
fi

