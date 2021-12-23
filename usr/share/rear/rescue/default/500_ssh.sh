# SSH client (ssh) and server (sshd) configuration for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# There is nothing to do when there are no SSH binaries on the original system:
has_binary ssh || has_binary sshd || return 0

# Do nothing when not any SSH file should be copied into the recovery system:
if is_false "$SSH_FILES" ; then
    # Print an info if SSH_ROOT_PASSWORD is set but that cannot work when SSH_FILES is set to a 'false' value:
    test "$SSH_ROOT_PASSWORD" && LogPrintError "SSH_ROOT_PASSWORD cannot work when SSH_FILES is set to a 'false' value"
    return 0
fi

# Only support OpenSSH >= 3.1 where /etc/ssh/ is the default directory for keys and configuration files
# according to the OpenSSH release notes for version 3.1/3.1p1 at https://www.openssh.com/releasenotes.html
# cf. https://github.com/rear/rear/pull/1530#issuecomment-337526810 and subsequent comments.
local copy_as_is_ssh_files=()
# The funny [] around a letter makes 'shopt -s nullglob' remove this file from the list if it does not exist.
if is_true "$SSH_FILES" ; then
    # Copy the "usual OpenSSH >= 3.1 files" (including SSH private host keys)
    # into the recovery system to make remote access "just work" in the recovery system
    # (provided SSH_UNPROTECTED_PRIVATE_KEYS is not false - otherwise unprotected keys get excluded)
    # cf. https://github.com/rear/rear/issues/1512 and https://github.com/rear/rear/issues/1511
    copy_as_is_ssh_files=( /etc/s[s]h $ROOT_HOME_DIR/.s[s]h $ROOT_HOME_DIR/.shos[t]s )
else
    # Use a reasonably secure fallback if SSH_FILES is not set or empty:
    contains_visible_char "${SSH_FILES[*]}" || SSH_FILES="avoid_sensitive_files"
    if test "avoid_sensitive_files" = "$SSH_FILES" ; then
        # Avoid copying sensitive SSH files:
        # From /etc/ssh copy only moduli ssh_config sshd_config ssh_known_hosts
        # and from $ROOT_HOME_DIR/.ssh copy only authorized_keys known_hosts (if exists)
        # cf. https://github.com/rear/rear/issues/1512#issuecomment-331638066
        copy_as_is_ssh_files=( /etc/ssh/modu[l]i /etc/ssh/ssh_co[n]fig /etc/ssh/sshd_co[n]fig /etc/ssh/ssh_known_hos[t]s )
        copy_as_is_ssh_files+=( $ROOT_HOME_DIR/.ssh/authorized_ke[y]s $ROOT_HOME_DIR/.ssh/known_hos[t]s )
    else
        # Copy exactly what is specified:
        copy_as_is_ssh_files=( "${SSH_FILES[@]}" )
    fi
fi
contains_visible_char "${copy_as_is_ssh_files[*]}" && COPY_AS_IS+=( "${copy_as_is_ssh_files[@]}" )

# Copy the usual SSH programs into the recovery system:
PROGS+=( ssh sshd scp sftp ssh-agent ssh-keygen ssh-add )

# Copy a sftp-server program (e.g. /usr/lib/ssh/sftp-server) into the recovery system (if exists).
# Because only OpenSSH >= 3.1 is supported where /etc/ssh/ is the default directory for configuration files
# only /etc/ssh/sshd_config is inspected to grep for a sftp-server program therein
# cf. https://github.com/rear/rear/pull/1538#issuecomment-337904240
# The output of the grep command
# grep 'sftp' /etc/ssh/sshd_config 2>/dev/null
# looks like
# Subsystem  sftp    /usr/lib/ssh/sftp-server
local grep_sftp_output=( $( grep 'sftp' /etc/ssh/sshd_config 2>/dev/null ) )
local sftp_program="${grep_sftp_output[2]}"
test "$sftp_program" && PROGS+=( "$sftp_program" )

# We need to add some specific NSS lib for shadow passwords to work on RHEL 6/7
# cf. https://github.com/rear/rear/issues/560#issuecomment-124578636 and subsequent comments:
Log "Adding required libfreeblpriv3.so to LIBS"
LIBS+=( /usr/lib64/libfreeblpriv3.* /lib/libfreeblpriv3.* )

# SSH server (sshd) - this is for logging into the recovery system via SSH:

# Copy sshd user.
# getent will return all entries that match the key(s) exactly - most systems use 'sshd', some may use 'ssh', none should use both.
# Only the first line (first returned entry) will be used by 'read' in 'IFS=: read ... <<<"$getent_passswd_ssh"', so we ask for sshd first.
# CLONE_USERS will also automatically clone the users' primary group.
local sshd_usernames="sshd ssh"
local getent_passswd_ssh=$( getent passwd $sshd_usernames )
if test "$getent_passswd_ssh" ; then
    # 'getent passwd sshd' output is like
    # sshd:x:71:65:SSH daemon:/var/lib/sshd:/bin/false
    local sshd_user sshd_password sshd_uid sshd_gid sshd_gecos sshd_homedir junk
    IFS=: read sshd_user sshd_password sshd_uid sshd_gid sshd_gecos sshd_homedir junk <<<"$getent_passswd_ssh"
    CLONE_USERS+=( $sshd_user )
    # Create the sshd user home directory:
    mkdir $v -p $ROOTFS_DIR/$sshd_homedir
    chmod $v 0700 $ROOTFS_DIR/$sshd_homedir
fi

# Launch sshd during recovery system startup for traditional systems without systemd
# (for systemd there is skel/default/usr/lib/systemd/system/sshd.service):
echo "ssh:23:respawn:/etc/scripts/run-sshd" >>$ROOTFS_DIR/etc/inittab

# Print an info if there is no authorized_keys file for root and no SSH_ROOT_PASSWORD set:
if ! test -f "$ROOT_HOME_DIR/.ssh/authorized_keys" -o "$SSH_ROOT_PASSWORD" ; then
    LogPrintError "To log into the recovery system via ssh set up $ROOT_HOME_DIR/.ssh/authorized_keys or specify SSH_ROOT_PASSWORD"
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

