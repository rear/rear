#
# Adapt some SSH configs and as needed regenerate SSH host key:

# There is nothing to do when there are no SSH binaries on the original system:
has_binary ssh || has_binary sshd || return

# Do nothing when not any SSH file should be copied into the recovery system:
is_false "$SSH_FILES" && return

# Patch sshd_config:
# - disable password authentication because rescue system does not have PAM etc.
# - disable challenge response (Kerberos, skey, ...) for same reason
# - disable PAM
# - disable motd printing, our /etc/profile does that
# - if SSH_ROOT_PASSWORD was defined allow root to login via ssh
# The idea is to allow ssh authorized_keys based access in the recovery system
# which has to be enabled on the original system to work in the recovery system.
# The funny [] around a letter makes 'shopt -s nullglob' remove this file from the list if it does not exist.
# Files without a [] are mandatory.
local sshd_config_files=( $ROOTFS_DIR/etc/ssh/sshd_co[n]fig $ROOTFS_DIR/etc/sshd_co[n]fig $ROOTFS_DIR/etc/openssh/sshd_co[n]fig )
if test "${sshd_config_files[*]}" ; then
    sed -i -e 's/ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/ig' \
           -e 's/UsePAM.*/UsePam no/ig' \
           -e 's/ListenAddress.*/ListenAddress 0.0.0.0/ig' \
           -e '1i\PrintMotd no' \
        ${sshd_config_files[@]}
    # Allow password authentication in the recovery system only if SSH_ROOT_PASSWORD is specified:
    if test "$SSH_ROOT_PASSWORD" ; then
        sed -i -e 's/PasswordAuthentication.*/PasswordAuthentication yes/ig' ${sshd_config_files[@]}
        sed -i -e 's/PermitRootLogin.*/PermitRootLogin yes/ig' ${sshd_config_files[@]}
    else
        sed -i -e 's/PasswordAuthentication.*/PasswordAuthentication no/ig' ${sshd_config_files[@]}
    fi
else
    LogPrintError "No sshd configuration files"
fi

# Generate new SSH host key in the recovery system when no SSH host key file
# had been copied into the the recovery system in rescue/default/500_ssh.sh
# cf. https://github.com/rear/rear/issues/1512#issuecomment-331638066
# In SLES12 "man ssh-keygen" reads:
#   -t dsa | ecdsa | ed25519 | rsa | rsa1
#      Specifies the type of key to create.
#      The possible values are "rsa1" for protocol version 1
#      and "dsa", "ecdsa", "ed25519", or "rsa" for protocol version 2.
# The above GitHub issue comment proposes a static
#   ssh-keygen -t ed25519 -N '' -f "..."
# but the key type ed25519 is not supported in older systems like SLES11.
# On SLES10 "man ssh-keygen" reads:
#   -t type
#      Specifies the type of key to create.
#      The possible values are rsa1 for protocol version 1
#      and rsa or dsa for protocol version 2.
# Currently (October 2017) ReaR is kept working on older systems
# like SLES10 cf. https://github.com/rear/rear/issues/1522
# and currently this backward compatibility should not be broken
# (for the future see https://github.com/rear/rear/issues/1390)
# so that we try to generate all possible types of keys provided
# the particular type of key also exists on the original system.
# For example what there is on a default SLES system:
# On a default SLES10 there is
#  /etc/ssh/ssh_host_key
#  /etc/ssh/ssh_host_key.pub
#  /etc/ssh/ssh_host_dsa_key
#  /etc/ssh/ssh_host_dsa_key.pub
#  /etc/ssh/ssh_host_rsa_key
#  /etc/ssh/ssh_host_rsa_key.pub
# On a default SLES11 there is additionally
#  /etc/ssh/ssh_host_ecdsa_key
#  /etc/ssh/ssh_host_ecdsa_key.pub
# On a default SLES12 there is additionally
#  /etc/ssh/ssh_host_ed25519_key
#  /etc/ssh/ssh_host_ed25519_key.pub
# The old rsa1 type for SSH protocol version 1 is not supported here.
# Only SSH protocol version 2 (the default since 2001) is supported:
local ssh_host_key_types="rsa dsa ecdsa ed25519"
local ssh_host_key_type=""
local ssh_host_key_file=""
local recovery_system_key_file=""
local ssh_host_key_exists="no"
for ssh_host_key_type in $ssh_host_key_types ; do
    ssh_host_key_file="etc/ssh/ssh_host_${ssh_host_key_type}_key"
    # Do not overwrite what is already there (could have been copied via COPY_AS_IS):
    if test -f "$ROOTFS_DIR/$ssh_host_key_file" ; then
        Log "Using existing SSH host key $ssh_host_key_file in recovery system"
        ssh_host_key_exists="yes"
        continue
    fi
    # Only generate the particular type of key if it also exists on the original system
    # because it is no longer recommended to use host keys other than rsa and ed25519,
    # see section 2.2.1 in https://bettercrypto.org/static/applied-crypto-hardening.pdf
    # and generating old-style host keys will only help with ssh clients which are
    # very old (OpenSSH versions < 2.9), see https://www.openssh.com/releasenotes.html
    # cf. https://github.com/rear/rear/pull/1530#discussion_r143948453
    if ! test -f "/$ssh_host_key_file" ; then
        Log "Skip generating $ssh_host_key_type type key because there is no /$ssh_host_key_file on the original system"
        continue
    fi
    Log "Generating new SSH host key $ssh_host_key_file in recovery system"
    recovery_system_key_file="$ROOTFS_DIR/$ssh_host_key_file"
    mkdir $v -p $( dirname "$recovery_system_key_file" )
    ssh-keygen $v -t "$ssh_host_key_type" -N '' -f "$recovery_system_key_file" && ssh_host_key_exists="yes" || Log "Cannot generate key type $ssh_host_key_type"
done
# Generate an rsa key as fallback if there is still no SSH host key in the recovery system
# (e.g. if there is no rsa key on the original system and generating all other key types had failed).
# A single key is sufficient because sshd works with one key, and for login purposes, one key is sufficient.
# For backward compatibility starting with SSH protocol version 2 (the default since 2001),
# it should be sufficient to generate an rsa key regardless that an ed25519 key would provide
# better long-term security, but this is probably not necessary for a recovery system:
if is_false "$ssh_host_key_exists" ; then
    ssh_host_key_type="rsa"
    ssh_host_key_file="etc/ssh/ssh_host_${ssh_host_key_type}_key"
    LogPrint "Generating fallback SSH host key $ssh_host_key_file in recovery system because no key is there"
    recovery_system_key_file="$ROOTFS_DIR/$ssh_host_key_file"
    mkdir $v -p $( dirname "$recovery_system_key_file" )
    ssh-keygen $v -t "$ssh_host_key_type" -N '' -f "$recovery_system_key_file" && ssh_host_key_exists="yes" || Log "Cannot generate fallback $ssh_host_key_type key"
fi
is_false "$ssh_host_key_exists" && LogPrintError "No SSH host key etc/ssh/ssh_host_TYPE_key of any type $ssh_host_key_types in recovery system"

# Create possibly missing directories needed by sshd in the recovery system
# cf. https://github.com/rear/rear/issues/1529
# To be on the safe side for other distributions we create the directories
# when they are not there without additional distribution-specific tests.
# At least on Red Hat /var/empty/sshd/etc with mode 0711 can be missing:
if ! test -d "$ROOTFS_DIR/var/empty/sshd/etc" ; then
    Log "Creating var/empty/sshd/etc with mode 0711 (needed by sshd at least on Red Hat)"
    mkdir $v -p $ROOTFS_DIR/var/empty/sshd/etc
    chmod $v 0711 $ROOTFS_DIR/var/empty/sshd/etc
fi
# At least on Ubuntu /var/run/sshd can be missing:
if ! test -d "$ROOTFS_DIR/var/run/sshd" ; then
    Log "Creating var/run/sshd (needed by sshd at least on Ubuntu)"
    mkdir $v -p $ROOTFS_DIR/var/run/sshd
fi

