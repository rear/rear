# SSH client (ssh) and server (sshd) configuration for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

has_binary ssh || has_binary sshd || return

# assume that we have openssh with configs in /etc/ssh

# The funny [] around a letter makes shopt -s nullglob remove this file from the list if it does not exist,
# files without a [] are mandatory.

COPY_AS_IS=( "${COPY_AS_IS[@]}" /etc/ssh* /root/.ssh/[a]uthorized_keys /root/.shos[t]s )
PROGS=(
    "${PROGS[@]}"
    ssh sshd scp sftp ssh-agent
    $(
        read subsys sftp original_file junk < <( grep sftp /etc/sshd_co[n]fig /etc/ssh/sshd_co[n]fig /etc/openssh/sshd_co[n]fig /etc/centrifydc/ssh/sshd_co[n]fig 2>/dev/null )
        echo $original_file
    )
)

# Part 1: SSH server (sshd) - this is for logging into the recovery system via SSH

# we need to add some specific NSS lib for shadow passwords to work on RHEL 6/7
LIBS=( "${LIBS[@]}" /usr/lib64/libfreeblpriv3.* /lib/libfreeblpriv3.* )
Log "Adding required libfreeblpriv3.so to LIBS"

# copy ssh user
# getent will return all entries that match the key(s) exactly - most systems use 'sshd', some may use 'ssh', none should use both.
# Only the first line (first returned entry) will be used by 'read' in 'IFS=: read ... <<<"$PASSWD_SSH"', so we ask for sshd first.
PASSWD_SSH=$(getent passwd sshd ssh)
if test -n "$PASSWD_SSH" ; then
    # sshd:x:71:65:SSH daemon:/var/lib/sshd:/bin/false
        IFS=: read user ex uid gid gecos homedir junk <<<"$PASSWD_SSH"
    # skip if this user exists already in the restore system
    if ! egrep -q "^$user:" $ROOTFS_DIR/etc/passwd ; then
        echo "$PASSWD_SSH" >>$ROOTFS_DIR/etc/passwd
    fi
    # add ssh group to be collected later
    CLONE_GROUPS=( "${CLONE_GROUPS[@]}" "$gid" )
    mkdir -p $v -m 0700 "$ROOTFS_DIR/$homedir" >&2
    chown $v root:root "$ROOTFS_DIR/$homedir" >&2
fi

echo "ssh:23:respawn:/bin/sshd -D" >>$ROOTFS_DIR/etc/inittab

# print a warning if there is no authorized_keys file for root and no SSH_ROOT_PASSWORD set
if ! test -f "/root/.ssh/authorized_keys" -o "$SSH_ROOT_PASSWORD" ; then
    LogPrint "TIP: To log into the recovery system as root via ssh you need to set up /root/.ssh/authorized_keys or SSH_ROOT_PASSWORD in your configuration file"
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

local target_dir="$ROOTFS_DIR/root/.ssh" original_file target_file

mkdir -p -m u=rwx,go=- "$target_dir"  # COPY_AS_IS will take effect later, so create the target .ssh directory first

for original_file in /root/.ssh/id_* /root/.ssh/known_host[s]; do
    target_file="$target_dir/$(basename "$original_file")"
    cp -p "$original_file" "$target_file"

    case "$original_file" in
        (*/id_*.pub|*/known_hosts)
            # Public key files or 'knownhosts' contain no secrets and can be copied as-is
            Log "Copying $original_file"
            ;;

        (*/id_*)
            # Unprotected private key files will be passphrase-protected, if configured, or discarded

            # This ssh-keygen invocation checks if a passphrase change succeeds with an empty passphrase for
            # authentication. If so, the private key file is not currently passphrase-protected.
            if ssh-keygen -q -p -P '' -N '' -f "$target_file" >/dev/null 2>&1; then
                # Handle the unprotected private key file

                if [ -n "$SSH_PRIVATE_KEYS_RECOVER_PASSPHRASE" ]; then
                    Log "Copying private key $original_file, adding passphrase-protection"
                    ssh-keygen -p -P '' -N "$SSH_PRIVATE_KEYS_RECOVER_PASSPHRASE" -f "$target_file" || Error "Could not set SSH passphrase for $target_file"
                else
                    LogPrint "TIP: To have the unprotected SSH private key $original_file copied to the rescue system, see SSH_PRIVATE_KEYS_RECOVER_PASSPHRASE in default.conf"
                    rm "$target_file"
                fi
            else
                Log "Copying protected private key $original_file retaining its original passphrase"
            fi
            ;;
    esac
done
