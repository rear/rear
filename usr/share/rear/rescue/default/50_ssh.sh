# 50_ssh.sh
#
# take ssh for Relax-and-Recover
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

    # assume that we have openssh with configs in /etc/ssh

    COPY_AS_IS=( "${COPY_AS_IS[@]}" /etc/ssh* /root/.s[s]h /root/.shos[t]s )
    PROGS=(
    ${PROGS[@]}
    ssh sshd scp sftp
    $(
        read subsys sftp file junk < <( grep sftp /etc/sshd_co[n]fig /etc/ssh/sshd_co[n]fig /etc/openssh/sshd_co[n]fig 2>&8 )
        echo $file
    )
    )

    # we need to add some specific NSS lib for shadow passwords to work on RHEL 6/7
    LIBS=( ${LIBS[@]} /usr/lib64/libfreeblpriv3.* /lib/libfreeblpriv3.* )
    Log "Adding required libfreeblpriv3.so to LIBS"

    # copy ssh user
    if PASSWD_SSH=$(grep ssh /etc/passwd) ; then
    # sshd:x:71:65:SSH daemon:/var/lib/sshd:/bin/false
        echo "$PASSWD_SSH" >>$ROOTFS_DIR/etc/passwd
        IFS=: read user ex uid gid gecos homedir junk <<<"$PASSWD_SSH"
        # add ssh group to be collected later
        CLONE_GROUPS=( "${CLONE_GROUPS[@]}" "$gid" )
        mkdir -p $v -m 0700 "$ROOTFS_DIR$homedir" >&2
        chown $v root.root "$ROOTFS_DIR$homedir" >&2
    fi

    echo "ssh:23:respawn:/bin/sshd -D" >>$ROOTFS_DIR/etc/inittab

    # print a warning if there is no authorized_keys file for root
    if test ! -f "/root/.ssh/authorized_keys" ; then
        LogPrint "TIP: To login as root via ssh you need to set up /root/.ssh/authorized_keys or SSH_ROOT_PASSWORD in your configuration file"
    fi
    
    # Set the SSH root password; if pw is hashed just copy it otherwise use openssl (for backward compatibility)
    if [[ "$SSH_ROOT_PASSWORD" ]] ; then
        case "$SSH_ROOT_PASSWORD" in
        '$1$'*) echo "root:$SSH_ROOT_PASSWORD:::::::" > $ROOTFS_DIR/etc/shadow ;;
        *     ) echo "root:$(echo $SSH_ROOT_PASSWORD | openssl passwd -1 -stdin):::::::" > $ROOTFS_DIR/etc/shadow ;;
        esac
    fi
fi
