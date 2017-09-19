# 500_ssh.sh
#
# take ssh for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

if has_binary sshd; then

    # assume that we have openssh with configs in /etc/ssh

    COPY_AS_IS=( "${COPY_AS_IS[@]}" /etc/ssh* /root/.s[s]h /root/.shos[t]s )
    PROGS=(
    ${PROGS[@]}
    ssh sshd scp sftp
    $(
        read subsys sftp file junk < <( grep sftp /etc/sshd_co[n]fig /etc/ssh/sshd_co[n]fig /etc/openssh/sshd_co[n]fig /etc/centrifydc/ssh/sshd_co[n]fig 2>/dev/null )
        echo $file
    )
    )

    # we need to add some specific NSS lib for shadow passwords to work on RHEL 6/7
    LIBS=( ${LIBS[@]} /usr/lib64/libfreeblpriv3.* /lib/libfreeblpriv3.* )
    Log "Adding required libfreeblpriv3.so to LIBS"

    # copy ssh user
    # getent will return all entries that match the key(s) exactly - most systems use 'sshd', some may use 'ssh', none should use both.
    # Only the first line (first returned entry) will be used by 'read' in 'IFS=: read ... <<<"$PASSWD_SSH"', so we ask for sshd first.
    PASSWD_SSH=$(getent passwd sshd ssh)
    if test -n "$PASSWD_SSH" ; then
    # sshd:x:71:65:SSH daemon:/var/lib/sshd:/bin/false
        IFS=: read user ex uid gid gecos homedir junk <<<"$PASSWD_SSH"
	# skip if this user exists already in the restore system
	if ! egrep -q "^$user:" $TARGET_FS_ROOT/etc/passwd ; then
		echo "$PASSWD_SSH" >>$ROOTFS_DIR/etc/passwd
	fi
        # add ssh group to be collected later
        CLONE_GROUPS=( "${CLONE_GROUPS[@]}" "$gid" )
        mkdir -p $v -m 0700 "$ROOTFS_DIR$homedir" >&2
        chown $v root.root "$ROOTFS_DIR$homedir" >&2
    fi

    echo "ssh:23:respawn:/bin/sshd -D" >>$ROOTFS_DIR/etc/inittab

    # print a warning if there is no authorized_keys file for root and no SSH_ROOT_PASSWORD set
    if ! test -f "/root/.ssh/authorized_keys" -o "$SSH_ROOT_PASSWORD" ; then
        LogPrint "TIP: To login as root via ssh you need to set up /root/.ssh/authorized_keys or SSH_ROOT_PASSWORD in your configuration file"
    fi

    # Set the SSH root password; if pw is encrypted just copy it otherwise use openssl (for backward compatibility)
    # Encryption syntax is detected as a '$D$' or '$Dx$' prefix in the password, where D is a single digit and x is one lowercase character.
    # For more information on encryption IDs, check out the NOTES section of the man page for crypt(3).
    # The extglob shell option is required for this to work.
    if test "$SSH_ROOT_PASSWORD" ; then
        case "$SSH_ROOT_PASSWORD" in
            (\$[0-9]?([a-z])\$*)
                echo "root:$SSH_ROOT_PASSWORD:::::::" > $ROOTFS_DIR/etc/shadow
                ;;
            (*)
                echo "root:$(echo $SSH_ROOT_PASSWORD | openssl passwd -1 -stdin):::::::" > $ROOTFS_DIR/etc/shadow
                ;;
        esac
    fi
fi

