# SSH client (ssh) and server (sshd) configuration for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# There is nothing to do when there are no SSH binaries on the original system:
has_binary ssh || has_binary sshd || return

# Do nothing when not any SSH file should be copied into the recovery system:
is_false "$SSH_FILES" && return

# Assume that we have openssh with configs in /etc/ssh

# The funny [] around a letter makes 'shopt -s nullglob' remove this file from the list if it does not exist.
# Files without a [] are mandatory.

local copy_as_is_ssh_files=()
if is_true "$SSH_FILES" ; then
    # Copy all the "usual SSH files" (including SSH private host keys) to make things "just work"
    # into the recovery system, cf. https://github.com/rear/rear/issues/1512
    copy_as_is_ssh_files=( /etc/ssh* /etc/openssh* /etc/centrifydc/ssh* /root/.s[s]h /root/.shos[t]s )
else
    # Use a reasonably secure fallback if SSH_FILES is not set or empty:
    test "$SSH_FILES" || SSH_FILES="avoid_sensitive_files"
    if test "avoid_sensitive_files" = "$SSH_FILES" ; then
        # Avoid copying sensitive SSH files:
        # From /etc/ssh copy only moduli ssh_config sshd_config ssh_known_hosts
        # and from /root/.ssh copy only authorized_keys known_hosts (if exists)
        # cf. https://github.com/rear/rear/issues/1512#issuecomment-331638066
        copy_as_is_ssh_files=( /etc/ssh/modu[l]i /etc/ssh/ssh_co[n]fig /etc/ssh/sshd_co[n]fig /etc/ssh/ssh_known_hos[t]s )
        copy_as_is_ssh_files=( "${copy_as_is_ssh_files[@]}" /root/.ssh/authorized_ke[y]s /root/.ssh/known_hos[t]s )
    else
        # Copy exactly what is specified:
        copy_as_is_ssh_files=( "${SSH_FILES[@]}" )
    fi
fi
test "${copy_as_is_ssh_files[*]}" && COPY_AS_IS=( "${COPY_AS_IS[@]}" "${copy_as_is_ssh_files[@]}" )

PROGS=(
    "${PROGS[@]}"
    ssh sshd scp sftp ssh-agent ssh-keygen
    $( read subsys sftp original_file junk < <( grep sftp /etc/sshd_co[n]fig /etc/ssh/sshd_co[n]fig /etc/openssh/sshd_co[n]fig /etc/centrifydc/ssh/sshd_co[n]fig 2>/dev/null )
       echo $original_file
     )
)

# Part 1: SSH server (sshd) - this is for logging into the recovery system via SSH

# we need to add some specific NSS lib for shadow passwords to work on RHEL 6/7
LIBS=( "${LIBS[@]}" /usr/lib64/libfreeblpriv3.* /lib/libfreeblpriv3.* )
Log "Adding required libfreeblpriv3.so to LIBS"

# Copy ssh user.
# getent will return all entries that match the key(s) exactly - most systems use 'sshd', some may use 'ssh', none should use both.
# CLONE_USERS will also automatically clone the users' primary group
# Only the first line (first returned entry) will be used by 'read' in 'IFS=: read ... <<<"$passswd_ssh"', so we ask for sshd first.
local passswd_ssh=$( getent passwd sshd ssh )
if test "$passswd_ssh" ; then
    # sshd:x:71:65:SSH daemon:/var/lib/sshd:/bin/false
    IFS=: read user ex uid gid gecos homedir junk <<<"$passswd_ssh"
    CLONE_USERS=( "${CLONE_USERS[@]}" $user )
    DIRECTORIES_TO_CREATE=( "${DIRECTORIES_TO_CREATE[@]}" "$homedir 0700 root root" )
fi

echo "ssh:23:respawn:/bin/sshd -D" >>$ROOTFS_DIR/etc/inittab

# Print an info if there is no authorized_keys file for root and no SSH_ROOT_PASSWORD set:
if ! test -f "/root/.ssh/authorized_keys" -o "$SSH_ROOT_PASSWORD" ; then
    LogPrint "To log into the recovery system via ssh set up /root/.ssh/authorized_keys or specify SSH_ROOT_PASSWORD"
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
            echo "root:$( echo $SSH_ROOT_PASSWORD | openssl passwd -1 -stdin ):::::::" > $ROOTFS_DIR/etc/shadow
            ;;
    esac
fi

